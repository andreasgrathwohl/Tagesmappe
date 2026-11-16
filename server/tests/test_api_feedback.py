"""Annahme von Rückmeldungen (FR-18, AK-61)."""

import io
import json
import sqlite3
from datetime import timedelta
from uuid import UUID, uuid4

from fastapi.testclient import TestClient
from PIL import Image

from frontstage_service.attachments import AttachmentStore
from frontstage_service.main import create_app
from frontstage_service.repository import FeedbackRepository

KEY = "test-app-key-" + "x" * 20
MIB = 1024 * 1024


def make_png(size: tuple[int, int] = (8, 8)) -> bytes:
    buffer = io.BytesIO()
    Image.new("RGB", size, (200, 120, 40)).save(buffer, format="PNG")
    return buffer.getvalue()


def feedback_json(**overrides) -> dict:
    data = {
        "clientDraftId": str(uuid4()),
        "kind": "idea",
        "text": "Eine Idee zum Tagesplan.",
        "topic": "dayView",
        "appVersion": "1.0",
        "deviceInfo": None,
    }
    data.update(overrides)
    return data


def post_feedback(client, json_body=None, images=(), key=KEY, raw_json=None):
    """Sendet Multipart wie die App: ``feedback`` ohne Dateinamen, ``attachment`` mit Dateiname."""
    body = json_body if json_body is not None else feedback_json()
    payload = raw_json if raw_json is not None else json.dumps(body)
    files = [("feedback", (None, payload, "application/json"))]
    for index, data in enumerate(images):
        files.append(("attachment", (f"bild{index}.png", data, "image/png")))
    headers = {"X-Frontstage-App-Key": key} if key is not None else {}
    return client.post("/api/v1/feedback", files=files, headers=headers)


def count_rows(settings) -> int:
    with sqlite3.connect(settings.data_dir / "frontstage.db") as db:
        return db.execute("SELECT COUNT(*) FROM feedback").fetchone()[0]


def test_valid_feedback_with_two_images_returns_201_and_receipt(client, settings):
    r = post_feedback(client, images=[make_png(), make_png((4, 4))])
    assert r.status_code == 201
    body = r.json()
    assert set(body) == {"id", "reference"}
    assert len(body["reference"]) == 8
    folder = settings.data_dir / "attachments" / body["id"]
    assert sorted(p.name for p in folder.iterdir()) == ["0.png", "1.png"]
    assert not (settings.data_dir / "attachments" / ".staging" / body["id"]).exists()


def test_missing_or_wrong_key_is_401(client):
    assert post_feedback(client, key=None).status_code == 401
    assert post_feedback(client, key="falsch").status_code == 401
    assert post_feedback(client, key=KEY + "x").status_code == 401


def test_six_images_is_413(client):
    assert post_feedback(client, images=[make_png()] * 6).status_code == 413


def test_nine_mib_image_is_413(client):
    assert post_feedback(client, images=[b"\x89PNG" + b"0" * (9 * MIB)]).status_code == 413


def test_missing_content_length_is_rejected(client):
    # Chunked-Upload ohne Content-Length darf die Größengrenze nicht umgehen
    def chunks():
        yield b"--x--"

    r = client.post(
        "/api/v1/feedback",
        content=chunks(),
        headers={
            "X-Frontstage-App-Key": KEY,
            "Content-Type": "multipart/form-data; boundary=x",
        },
    )
    assert r.status_code == 411


def test_content_length_over_26_mib_is_413_without_reading(client):
    r = client.post(
        "/api/v1/feedback",
        content=b"x",
        headers={
            "X-Frontstage-App-Key": KEY,
            "Content-Type": "multipart/form-data; boundary=abc",
            "Content-Length": str(26 * MIB + 1),
        },
    )
    assert r.status_code == 413


def test_gif_is_415(client):
    buffer = io.BytesIO()
    Image.new("P", (4, 4)).save(buffer, format="GIF")
    assert post_feedback(client, images=[buffer.getvalue()]).status_code == 415


def test_unknown_topic_or_extra_field_is_422(client):
    assert post_feedback(client, feedback_json(topic="gibtEsNicht")).status_code == 422
    assert post_feedback(client, feedback_json(extra="x")).status_code == 422
    assert post_feedback(client, raw_json="kein json").status_code == 422


def test_missing_feedback_part_is_422(client):
    r = client.post(
        "/api/v1/feedback",
        files=[("attachment", ("a.png", make_png(), "image/png"))],
        headers={"X-Frontstage-App-Key": KEY},
    )
    assert r.status_code == 422


def test_empty_text_is_422(client):
    assert post_feedback(client, feedback_json(text="")).status_code == 422


def test_11th_request_in_a_minute_is_429_with_retry_after(client):
    for _ in range(10):
        assert post_feedback(client).status_code == 201
    r = post_feedback(client)
    assert r.status_code == 429
    assert int(r.headers["Retry-After"]) >= 1


def test_wrong_key_does_not_consume_the_limit(client):
    for _ in range(12):
        assert post_feedback(client, key="falsch").status_code == 401
    assert post_feedback(client).status_code == 201


def test_31st_request_in_an_hour_is_429(client, clock):
    for _ in range(3):
        for _ in range(10):
            assert post_feedback(client).status_code == 201
        clock.now += timedelta(minutes=2)
    r = post_feedback(client)
    assert r.status_code == 429
    assert int(r.headers["Retry-After"]) > 60


def test_same_client_draft_id_returns_existing(client, settings):
    body = feedback_json()
    first = post_feedback(client, body, images=[make_png()])
    second = post_feedback(client, body, images=[make_png(), make_png()])
    assert first.status_code == 201
    assert second.status_code == 200
    assert second.json() == first.json()
    assert count_rows(settings) == 1
    folder = settings.data_dir / "attachments" / first.json()["id"]
    assert [p.name for p in folder.iterdir()] == ["0.png"]


def test_concurrent_duplicate_draft_id_returns_existing(client, settings, monkeypatch):
    """Die Vorabprüfung übersieht die Wiederholung (Wettlauf); der UNIQUE-Fall liefert trotzdem 200."""
    body = feedback_json()
    first = post_feedback(client, body)
    original = FeedbackRepository.find_by_client_draft_id
    calls = {"n": 0}

    def late_lookup(self, draft_id):
        calls["n"] += 1
        return None if calls["n"] == 1 else original(self, draft_id)

    # Am Typ, nicht an einer Instanz: Jede Anfrage hat ihr eigenes Repository
    monkeypatch.setattr(FeedbackRepository, "find_by_client_draft_id", late_lookup)
    second = post_feedback(client, body, images=[make_png()])
    assert calls["n"] == 2  # Vorabprüfung übersehen, nach dem UNIQUE-Fehler gefunden
    assert second.status_code == 200
    assert second.json() == first.json()
    assert count_rows(settings) == 1
    staging = settings.data_dir / "attachments" / ".staging"
    assert not staging.exists() or not any(staging.iterdir())


def test_storage_failure_leaves_no_partial_record(client, settings, monkeypatch):
    def boom(self, *args, **kwargs):
        raise OSError("Platte voll")

    monkeypatch.setattr(AttachmentStore, "save", boom)
    r = post_feedback(client, images=[make_png()])
    assert r.status_code == 503
    assert count_rows(settings) == 0
    attachments = settings.data_dir / "attachments"
    assert not attachments.exists() or not any(attachments.rglob("*.png"))
    staging = attachments / ".staging"
    assert not staging.exists() or not any(staging.iterdir())


def test_no_ip_address_persisted(client, settings):
    assert post_feedback(client, images=[make_png()]).status_code == 201
    with sqlite3.connect(settings.data_dir / "frontstage.db") as db:
        db.row_factory = sqlite3.Row
        for row in db.execute("SELECT * FROM feedback"):
            for value in dict(row).values():
                assert "testclient" not in str(value)
                assert "127.0.0.1" not in str(value)


def test_log_line_has_only_reference_and_count(client, caplog):
    caplog.set_level("INFO")
    r = post_feedback(client, images=[make_png()])
    reference = r.json()["reference"]
    messages = [m for m in caplog.messages if "feedback received" in m]
    assert messages == [f"feedback received reference={reference} attachments=1"]


def test_record_survives_app_restart(settings, clock):
    with TestClient(create_app(settings, clock=clock), base_url="https://testserver") as first:
        receipt = post_feedback(first, images=[make_png()]).json()
    with TestClient(create_app(settings, clock=clock), base_url="https://testserver") as second:
        record = second.app.state.repository.get(UUID(receipt["id"]))
    assert record is not None
    assert record.reference == receipt["reference"]


def test_healthz_returns_503_when_database_unreadable(client, monkeypatch):
    import frontstage_service.main as main

    def unreadable(data_dir):
        raise sqlite3.OperationalError("unable to open database file")

    monkeypatch.setattr(main, "open_connection", unreadable)
    assert client.get("/healthz").status_code == 503


def test_get_not_allowed(client):
    assert client.get("/api/v1/feedback").status_code == 405
