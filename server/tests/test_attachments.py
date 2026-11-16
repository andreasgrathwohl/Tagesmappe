from uuid import uuid4

from frontstage_service.attachments import AttachmentStore


def test_attachment_paths_sorted_and_deleted(tmp_path):
    store = AttachmentStore(tmp_path / "attachments")
    fid = uuid4()
    store.save(fid, 10, b"c", "jpg")
    store.save(fid, 2, b"b", "png")
    store.save(fid, 1, b"a", "png")
    assert store.paths(fid) == []  # noch nicht veröffentlicht
    store.publish(fid)
    assert not (tmp_path / "attachments" / ".staging" / str(fid)).exists()
    assert [p.name for p in store.paths(fid)] == ["1.png", "2.png", "10.jpg"]
    assert store.path(fid, 2).read_bytes() == b"b"
    assert store.path(fid, 3) is None
    store.delete_all(fid)
    assert store.paths(fid) == [] and not (tmp_path / "attachments" / str(fid)).exists()


def test_attachment_discard_removes_staging(tmp_path):
    store = AttachmentStore(tmp_path / "attachments")
    fid = uuid4()
    store.save(fid, 1, b"a", "png")
    store.discard(fid)
    assert not (tmp_path / "attachments" / ".staging" / str(fid)).exists()
    assert store.paths(fid) == []


def test_publish_without_images_and_unknown_id_are_harmless(tmp_path):
    store = AttachmentStore(tmp_path / "attachments")
    fid = uuid4()
    store.publish(fid)
    store.discard(fid)
    store.delete_all(fid)
    assert store.paths(fid) == [] and store.path(fid, 1) is None
