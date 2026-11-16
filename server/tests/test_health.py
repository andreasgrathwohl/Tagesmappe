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


def test_noindex_off_by_default(client):
    r = client.get("/healthz")
    assert "X-Robots-Tag" not in r.headers


def test_noindex_header_and_robots_txt(settings):
    from dataclasses import replace

    from fastapi.testclient import TestClient

    from frontstage_service.main import create_app

    with TestClient(create_app(replace(settings, noindex=True)), base_url="https://testserver") as c:
        r = c.get("/healthz")
        assert r.headers["X-Robots-Tag"] == "noindex, nofollow"
        robots = c.get("/robots.txt")
        assert robots.status_code == 200
        assert robots.headers["X-Robots-Tag"] == "noindex, nofollow"
        assert "Disallow: /" in robots.text
