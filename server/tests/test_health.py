def test_healthz_ok(client):
    r = client.get("/healthz")
    assert r.status_code == 200
    assert r.json() == {"status": "ok"}


def test_security_headers_on_every_response(client):
    for path in ("/healthz", "/gibt-es-nicht"):
        r = client.get(path)
        assert r.headers["X-Content-Type-Options"] == "nosniff"
        assert r.headers["Referrer-Policy"] == "no-referrer"
        assert r.headers["X-Frame-Options"] == "DENY"


def test_openapi_and_docs_disabled(client):
    for path in ("/docs", "/redoc", "/openapi.json"):
        assert client.get(path).status_code == 404
