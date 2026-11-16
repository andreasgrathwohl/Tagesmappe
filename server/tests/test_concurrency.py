"""Nebenläufigkeit: eigene Verbindung je Anfrage, Speicherarbeit außerhalb der Ereignisschleife."""

import asyncio
import threading
import time

from test_admin_feedback import PASSWORD, post, seed
from test_api_feedback import make_png, post_feedback

from frontstage_service.attachments import AttachmentStore
from frontstage_service.models import FeedbackStatus


def login(client) -> None:
    from test_admin_feedback import token_of

    token = token_of(client.get("/admin/login").text)
    r = client.post("/admin/login", data={"csrf_token": token, "password": PASSWORD, "next": "/admin/"})
    assert r.status_code == 303


def test_admin_write_survives_rollback_of_a_foreign_transaction(client, clock):
    """Eine fremde Transaktion, die zurückrollt, darf eine bestätigte Änderung nicht mitnehmen."""
    login(client)
    record = seed(client.app, clock, "issue", "Etwas klemmt.")
    begun = threading.Event()

    def failing_writer() -> None:
        try:
            with client.app.state.repository.transaction():
                begun.set()
                time.sleep(0.3)
                raise OSError("Platte voll")
        except OSError:
            pass

    worker = threading.Thread(target=failing_writer)
    worker.start()
    assert begun.wait(5)
    r = post(client, f"/admin/feedback/{record.id}/status", status="done")
    worker.join()
    assert r.status_code == 303
    assert client.app.state.repository.get(record.id).status == FeedbackStatus.done


def test_request_connection_is_closed_after_request(client, monkeypatch):
    import frontstage_service.deps as deps

    opened = []
    original = deps.open_connection

    def recording(data_dir):
        connection = original(data_dir)
        opened.append(connection)
        return connection

    monkeypatch.setattr(deps, "open_connection", recording)
    assert post_feedback(client).status_code == 201
    assert len(opened) == 1
    assert opened[0] is not client.app.state.connection
    try:
        opened[0].execute("SELECT 1")
    except Exception as exc:  # noqa: BLE001
        assert "closed" in str(exc)
    else:
        raise AssertionError("Verbindung ist noch offen")


def test_intake_storage_runs_outside_the_event_loop(client, monkeypatch):
    seen: list[bool] = []
    original = AttachmentStore.save

    def recording(self, *args, **kwargs):
        try:
            asyncio.get_running_loop()
            seen.append(True)
        except RuntimeError:
            seen.append(False)
        return original(self, *args, **kwargs)

    monkeypatch.setattr(AttachmentStore, "save", recording)
    assert post_feedback(client, images=[make_png()]).status_code == 201
    assert seen == [False]
