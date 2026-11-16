"""Startseite, Impressum und Datenschutz werden vom selben Prozess ausgeliefert (Entscheidung 13)."""


def test_landing_index_served(client):
    response = client.get("/")
    assert response.status_code == 200
    assert response.headers["content-type"].startswith("text/html")
    assert "Frontstage" in response.text


def test_impressum_and_datenschutz_redirect_and_serve(client):
    for path in ("/impressum", "/datenschutz"):
        redirect = client.get(path)
        assert redirect.status_code == 308
        assert redirect.headers["location"].endswith(path + "/")
        page = client.get(path + "/")
        assert page.status_code == 200
        assert page.headers["content-type"].startswith("text/html")


def test_api_and_admin_take_precedence(client):
    response = client.post("/api/v1/feedback", data={"message": "x"})
    assert response.status_code == 401
    assert client.get("/healthz").json() == {"status": "ok"}
    assert client.get("/admin/login").status_code == 200


def test_landing_csp_allows_only_self(client):
    csp = client.get("/").headers["content-security-policy"]
    assert "font-src 'self'" in csp
    assert "default-src 'self'" in csp
    assert "http:" not in csp and "https:" not in csp
    assert "unsafe-inline" not in csp


def test_landing_sets_no_cookie(client):
    assert "set-cookie" not in client.get("/").headers
    assert "set-cookie" not in client.get("/impressum/").headers


def test_unknown_landing_path_is_404(client):
    assert client.get("/gibt-es-nicht").status_code == 404
