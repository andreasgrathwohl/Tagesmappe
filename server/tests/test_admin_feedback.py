import re
from datetime import UTC, datetime, timedelta
from uuid import uuid4

import pytest

from frontstage_service.models import FeedbackFilter, FeedbackIn

PASSWORD = "richtiges-passwort"

DEVICE_INFO = {
    "appVersion": "0.1.0",
    "build": "1",
    "systemName": "iPadOS",
    "systemVersion": "19.0",
    "modelIdentifier": "iPad14,3",
    "dataLocation": "iCloud",
    "baseTone": "warm",
    "accent": None,
    "appearanceMode": "system",
    "isUnlocked": False,
    "languageCode": "de",
}


def token_of(html: str) -> str:
    match = re.search(r'"X-CSRF-Token":\s*"([^"]+)"', html)
    assert match
    return match.group(1)


def post(client, path: str, **data):
    token = token_of(client.get("/admin/").text)
    return client.post(path, data={"csrf_token": token, **data})


def seed(
    app, clock, kind: str, text: str, *, days: int = 0, images: int = 0, device: bool = False, topic=None
):
    clock.now = datetime(2026, 11, 10, 8, 30, tzinfo=UTC) + timedelta(days=days)
    feedback = FeedbackIn.model_validate(
        {
            "clientDraftId": str(uuid4()),
            "kind": kind,
            "text": text,
            "topic": topic,
            "appVersion": "0.1.0 (1)",
            "deviceInfo": DEVICE_INFO if device else None,
        }
    )
    record = app.state.repository.insert(feedback, images)
    for position in range(1, images + 1):
        app.state.attachment_store.save(record.id, position, b"\x89PNG-fake-" + bytes([position]), "png")
    app.state.attachment_store.publish(record.id)
    return record


@pytest.fixture
def logged_in_client(client):
    """Angemeldeter Client mit fünf Rückmeldungen (AK-62): drei Hinweise, zwei Ideen."""
    page = client.get("/admin/login")
    token = re.search(r'name="csrf_token" value="([^"]+)"', page.text).group(1)
    r = client.post("/admin/login", data={"password": PASSWORD, "csrf_token": token})
    assert r.status_code == 303
    return client


@pytest.fixture
def records(logged_in_client, clock):
    app = logged_in_client.app
    return [
        seed(app, clock, "issue", "Hinweis eins", days=0, topic="dayView"),
        seed(app, clock, "idea", "Idee zwei", days=1),
        seed(app, clock, "issue", "Hinweis drei mit Bild", days=2, images=2, device=True),
        seed(app, clock, "idea", "Idee vier", days=3),
        seed(app, clock, "issue", "Hinweis fünf", days=4),
    ]


def test_list_shows_all_newest_first(logged_in_client, records):
    r = logged_in_client.get("/admin/")
    assert r.status_code == 200
    assert "5 Rückmeldungen" in r.text
    assert r.text.index("Hinweis fünf") < r.text.index("Idee vier") < r.text.index("Hinweis eins")
    assert "Europe/Berlin" not in r.text
    assert "14.11.2026" in r.text and "09:30" in r.text  # 08:30 UTC = 09:30 MEZ
    assert f"/admin/feedback/{records[0].id}" in r.text
    assert "Bildschirmfotos" in r.text  # Spaltenkopf der Bilderzahl


def test_filter_issue_shows_three(logged_in_client, records):  # AK-62
    r = logged_in_client.get("/admin/", params={"kind": "issue"})
    assert "3 Rückmeldungen" in r.text
    assert "Idee zwei" not in r.text
    r = logged_in_client.get("/admin/", params={"since": "2026-11-12", "until": "2026-11-13"})
    assert "2 Rückmeldungen" in r.text


def test_htmx_filter_returns_table_partial_only(logged_in_client, records):
    r = logged_in_client.get("/admin/", params={"kind": "idea"}, headers={"HX-Request": "true"})
    assert r.status_code == 200
    assert "<html" not in r.text and "2 Rückmeldungen" in r.text
    full = logged_in_client.get("/admin/")
    assert "<html" in full.text and 'id="table"' in full.text and 'hx-push-url="true"' in full.text


def test_htmx_history_restore_returns_full_page(logged_in_client, records):
    r = logged_in_client.get(
        "/admin/",
        params={"kind": "idea"},
        headers={"HX-Request": "true", "HX-History-Restore-Request": "true"},
    )
    assert r.status_code == 200 and "<html" in r.text and 'id="table"' in r.text


def test_invalid_filter_values_are_ignored(logged_in_client, records):
    r = logged_in_client.get(
        "/admin/", params={"kind": "xyz", "status": "foo", "since": "2026-13-40", "until": "x", "page": "abc"}
    )
    assert r.status_code == 200
    assert "5 Rückmeldungen" in r.text
    assert logged_in_client.get("/admin/", params={"page": "-4"}).status_code == 200
    assert logged_in_client.get("/admin/", params={"page": "999"}).status_code == 200


def test_parse_filter_unit():
    from frontstage_service.admin.filters import parse_filter

    assert parse_filter(None, None, None, None) == FeedbackFilter()
    assert parse_filter("idea", "inProgress", "2026-01-02", "2026-02-03").kind.value == "idea"
    assert parse_filter("bad", "bad", "2026-13-40", "") == FeedbackFilter()


def test_empty_states(logged_in_client):
    r = logged_in_client.get("/admin/")
    assert "Noch keine Rückmeldungen." in r.text
    r = logged_in_client.get("/admin/", params={"kind": "idea"})
    assert "Keine Rückmeldungen für diese Filter." in r.text
    assert "Filter zurücksetzen" in r.text


def test_pagination_fifty_per_page(logged_in_client, clock):
    for i in range(53):
        seed(logged_in_client.app, clock, "idea", f"Eintrag {i:02d}", days=0)
        clock.now += timedelta(seconds=i)
    p1 = logged_in_client.get("/admin/")
    assert "53 Rückmeldungen" in p1.text and p1.text.count("<tr") == 51  # Kopf + 50
    p2 = logged_in_client.get("/admin/", params={"page": 2, "kind": "idea"})
    assert p2.text.count("<tr") == 4 and "kind=idea" in p2.text


def test_detail_shows_text_device_info_and_images(logged_in_client, records):
    rec = records[2]
    r = logged_in_client.get(f"/admin/feedback/{rec.id}")
    assert r.status_code == 200
    assert rec.reference in r.text and "Hinweis drei mit Bild" in r.text
    assert "iPad14,3" in r.text and "<dl" in r.text
    assert 'alt="Bildschirmfoto 1"' in r.text and 'alt="Bildschirmfoto 2"' in r.text
    assert f"/admin/attachments/{rec.id}/2" in r.text
    img = logged_in_client.get(f"/admin/attachments/{rec.id}/1")
    assert img.status_code == 200 and img.headers["content-type"] == "image/png"
    assert "Keine Geräteangaben" in logged_in_client.get(f"/admin/feedback/{records[0].id}").text
    assert "Hilfethema" in r.text


def test_detail_labels_device_info_in_german(logged_in_client, records):
    r = logged_in_client.get(f"/admin/feedback/{records[2].id}")
    for label in ("Gerätemodell", "Datenort", "Grundton", "Akzentfarbe", "Hell/Dunkel", "Freigeschaltet"):
        assert f"<dt>{label}</dt>" in r.text
    assert "<dt>appearanceMode</dt>" not in r.text and "<dt>isUnlocked</dt>" not in r.text
    assert "<dd>Nein</dd>" in r.text and "<dd>False</dd>" not in r.text
    # Reihenfolge wie im Vertrag, nicht alphabetisch nach Schlüssel
    assert r.text.index("<dt>Gerätemodell</dt>") < r.text.index("<dt>Datenort</dt>")


def test_text_is_escaped(logged_in_client, clock):
    rec = seed(logged_in_client.app, clock, "issue", "<script>alert(1)</script>\nzweite Zeile")
    r = logged_in_client.get(f"/admin/feedback/{rec.id}")
    assert "&lt;script&gt;" in r.text and "<script>alert" not in r.text
    assert "&lt;script&gt;" in logged_in_client.get("/admin/").text


def test_status_and_note_persist_after_reload(logged_in_client, records):  # AK-62
    rec = records[0]
    r = post(logged_in_client, f"/admin/feedback/{rec.id}/status", status="inProgress")
    assert r.status_code == 303 and r.headers["location"].startswith(f"/admin/feedback/{rec.id}")
    r = post(logged_in_client, f"/admin/feedback/{rec.id}/note", note="Notiz <b>eins</b>")
    assert r.status_code == 303
    page = logged_in_client.get(f"/admin/feedback/{rec.id}")
    assert 'value="inProgress" selected' in page.text
    assert "Notiz &lt;b&gt;eins&lt;/b&gt;" in page.text
    saved = logged_in_client.get(r.headers["location"])
    assert "Gespeichert" in saved.text and 'aria-live="polite"' in saved.text
    assert "In Arbeit" in logged_in_client.get("/admin/").text


def test_htmx_status_returns_partial(logged_in_client, records):
    rec = records[0]
    token = token_of(logged_in_client.get("/admin/").text)
    r = logged_in_client.post(
        f"/admin/feedback/{rec.id}/status",
        data={"status": "done"},
        headers={"HX-Request": "true", "X-CSRF-Token": token},
    )
    assert r.status_code == 200 and "<html" not in r.text and "Gespeichert" in r.text


def test_invalid_status_and_too_long_note_rejected(logged_in_client, records):
    rec = records[0]
    assert post(logged_in_client, f"/admin/feedback/{rec.id}/status", status="bogus").status_code == 400
    assert post(logged_in_client, f"/admin/feedback/{rec.id}/note", note="x" * 5001).status_code == 400


def test_post_without_csrf_is_403(logged_in_client, records):
    rec = records[0]
    assert logged_in_client.post(f"/admin/feedback/{rec.id}/delete").status_code == 403
    r = logged_in_client.post(f"/admin/feedback/{rec.id}/status", data={"status": "done"})
    assert r.status_code == 403
    assert logged_in_client.app.state.repository.get(rec.id) is not None


def test_delete_confirmation_page_and_delete(logged_in_client, records, settings):  # AK-62
    rec = records[2]
    folder = settings.data_dir / "attachments" / str(rec.id)
    assert folder.is_dir()
    confirm = logged_in_client.get(f"/admin/feedback/{rec.id}/delete")
    assert f"Rückmeldung {rec.reference} samt Bildern endgültig löschen?" in confirm.text
    assert logged_in_client.app.state.repository.get(rec.id) is not None  # GET löscht nie
    r = post(logged_in_client, f"/admin/feedback/{rec.id}/delete")
    assert r.status_code == 303 and r.headers["location"].startswith("/admin/")
    assert logged_in_client.app.state.repository.get(rec.id) is None
    assert not folder.exists()
    page = logged_in_client.get(r.headers["location"])
    assert "gelöscht" in page.text and "4 Rückmeldungen" in page.text
    assert logged_in_client.get(f"/admin/feedback/{rec.id}").status_code == 404


def test_attachment_requires_login_and_is_not_cached(client, logged_in_client, records):
    rec = records[2]
    url = f"/admin/attachments/{rec.id}/1"
    ok = logged_in_client.get(url)
    assert ok.headers["cache-control"] == "private, no-store"
    logged_in_client.cookies.clear()
    r = client.get(url)
    assert r.status_code == 303 and r.headers["location"].startswith("/admin/login")


def test_unknown_id_is_404(logged_in_client, records):
    unknown = uuid4()
    assert logged_in_client.get(f"/admin/feedback/{unknown}").status_code == 404
    assert logged_in_client.get("/admin/feedback/kein-uuid").status_code == 404
    assert logged_in_client.get(f"/admin/attachments/{unknown}/1").status_code == 404
    assert logged_in_client.get(f"/admin/attachments/{records[2].id}/9").status_code == 404
    assert logged_in_client.get(f"/admin/attachments/{records[2].id}/..%2F1").status_code == 404
    assert post(logged_in_client, f"/admin/feedback/{unknown}/delete").status_code == 404
    assert post(logged_in_client, f"/admin/feedback/{unknown}/status", status="done").status_code == 404
