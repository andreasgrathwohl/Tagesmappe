import csv
import io
import json
from datetime import UTC, datetime
from uuid import uuid4

from test_admin_feedback import logged_in_client, records  # noqa: F401  (Fixtures)

from frontstage_service.admin.export import to_csv, to_json
from frontstage_service.models import FeedbackKind, FeedbackRecord, FeedbackStatus


def make(text="Text", note="", reference="FS-1", device=None) -> FeedbackRecord:
    return FeedbackRecord(
        id=uuid4(),
        client_draft_id=uuid4(),
        reference=reference,
        received_at=datetime(2026, 11, 10, 8, 30, tzinfo=UTC),
        kind=FeedbackKind.issue,
        text=text,
        topic=None,
        app_version="0.1.0 (1)",
        device_info=device,
        status=FeedbackStatus.new,
        note=note,
        attachment_count=0,
        updated_at=datetime(2026, 11, 10, 8, 30, tzinfo=UTC),
    )


def parse(data: bytes) -> list[list[str]]:
    return list(csv.reader(io.StringIO(data.decode("utf-8-sig"), newline=""), delimiter=";"))


def test_csv_has_bom_header_and_rows(logged_in_client, records):  # noqa: F811  # AK-62
    r = logged_in_client.get("/admin/export.csv")
    assert r.status_code == 200
    assert r.content.startswith(b"\xef\xbb\xbf")
    rows = parse(r.content)
    assert rows[0] == [
        "reference", "received_at", "kind", "status", "topic",
        "app_version", "attachment_count", "text", "note",
    ]
    assert len(rows) == 6


def test_csv_neutralises_formulas():  # Review 3
    link = '=HYPERLINK("http://example.com")'
    rows = parse(to_csv([make(link, note="@SUM(1)"), make("+1", "-2"), make("	x")]))
    assert rows[1][7] == "'" + link
    assert rows[1][8] == "'@SUM(1)"
    assert rows[2][7] == "'+1" and rows[2][8] == "'-2"
    assert rows[3][7] == "'\tx"
    assert parse(to_csv([make("normal")]))[1][7] == "normal"


def test_csv_keeps_semicolons_and_newlines_quoted():
    rows = parse(to_csv([make("a;b\nzweite \"Zeile\"")]))
    assert rows[1][7] == "a;b\nzweite \"Zeile\""
    assert len(rows[1]) == 9


def test_json_contains_device_info():
    items = json.loads(to_json([make(device={"appVersion": "0.1.0"}), make()]))
    assert items[0]["device_info"] == {"appVersion": "0.1.0"}
    assert items[1]["device_info"] is None
    assert items[0]["reference"] == "FS-1" and items[0]["status"] == "new"
    assert items[0]["received_at"] == "2026-11-10T08:30:00Z"


def test_export_follows_filters(logged_in_client, records):  # noqa: F811
    r = logged_in_client.get("/admin/export.csv", params={"kind": "idea"})
    assert len(parse(r.content)) == 3
    assert "frontstage-rueckmeldungen-2026-11-14.csv" in r.headers["content-disposition"]
    r = logged_in_client.get("/admin/export.json", params={"since": "2026-11-12", "until": "2026-11-13"})
    assert len(json.loads(r.content)) == 2
    assert r.headers["content-type"].startswith("application/json")
    assert "frontstage-rueckmeldungen-2026-11-14.json" in r.headers["content-disposition"]
    assert r.headers["cache-control"] == "no-store"


def test_export_links_in_list_carry_filters(logged_in_client, records):  # noqa: F811
    r = logged_in_client.get("/admin/", params={"kind": "idea"})
    assert "/admin/export.csv?kind=idea" in r.text
    assert "/admin/export.json?kind=idea" in r.text


def test_export_requires_login(client):
    for path in ("/admin/export.csv", "/admin/export.json"):
        r = client.get(path)
        assert r.status_code in (303, 401)
        assert "location" in r.headers or r.status_code == 401
