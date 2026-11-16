import re
from datetime import timedelta

import pytest

from frontstage_service import hash_password

PASSWORD = "richtiges-passwort"


def login_token(client, next_path: str | None = None) -> str:
    """Holt die Anmeldeseite und liest das Vor-Anmelde-Token."""
    r = client.get("/admin/login", params={"next": next_path} if next_path else None)
    assert r.status_code == 200
    match = re.search(r'name="csrf_token" value="([^"]+)"', r.text)
    assert match
    return match.group(1)


def do_login(client, password: str = PASSWORD, next_path: str | None = None):
    token = login_token(client)
    data = {"password": password, "csrf_token": token}
    if next_path is not None:
        data["next"] = next_path
    return client.post("/admin/login", data=data)


def test_admin_requires_login_redirects(client):
    r = client.get("/admin/")
    assert r.status_code == 303
    assert r.headers["location"] == "/admin/login?next=%2Fadmin%2F"


def test_wrong_password_rejected(client):
    r = do_login(client, "falsch")
    assert r.status_code == 200
    assert "Passwort stimmt nicht." in r.text
    assert 'role="alert"' in r.text
    assert client.get("/admin/").status_code == 303  # keine Sitzung


def test_correct_password_logs_in_and_rotates_session(client):
    token_before = login_token(client)
    r = client.post("/admin/login", data={"password": PASSWORD, "csrf_token": token_before})
    assert r.status_code == 303
    assert r.headers["location"] == "/admin/"
    page = client.get("/admin/")
    assert page.status_code == 200
    # Das Token der Sitzung wurde erneuert: das alte gilt nicht mehr
    new_token = re.search(r'"X-CSRF-Token":\s*"([^"]+)"', page.text).group(1)
    assert new_token != token_before
    r = client.post("/admin/logout", data={"csrf_token": token_before})
    assert r.status_code == 403


def test_session_cookie_flags(client):
    r = do_login(client)
    cookie = r.headers["set-cookie"].lower()
    assert "frontstage_admin=" in cookie
    assert "secure" in cookie
    assert "httponly" in cookie
    assert "samesite=strict" in cookie
    assert "max-age=28800" in cookie


def test_post_without_csrf_is_403(client):
    login_token(client)
    r = client.post("/admin/login", data={"password": PASSWORD})
    assert r.status_code == 403
    r = client.post("/admin/login", data={"password": PASSWORD, "csrf_token": "falsch"})
    assert r.status_code == 403
    do_login(client)
    assert client.post("/admin/logout").status_code == 403
    assert client.get("/admin/").status_code == 200  # Sitzung blieb bestehen


def test_csrf_header_is_accepted(client):
    do_login(client)
    page = client.get("/admin/")
    token = re.search(r'"X-CSRF-Token":\s*"([^"]+)"', page.text).group(1)
    r = client.post("/admin/logout", headers={"X-CSRF-Token": token})
    assert r.status_code == 303


def test_login_locks_after_five_failures(client, clock):
    for _ in range(5):
        assert "Passwort stimmt nicht." in do_login(client, "falsch").text
    r = do_login(client, PASSWORD)
    assert r.status_code == 429
    assert "Zu viele Versuche. Versuch es in 10 Minuten erneut." in r.text
    assert client.get("/admin/").status_code == 303
    clock.now += timedelta(minutes=11)
    assert do_login(client, PASSWORD).status_code == 303


def test_successful_logins_do_not_count(client):
    for _ in range(7):
        assert do_login(client).status_code == 303
        client.post("/admin/logout", headers={"X-CSRF-Token": "x"})
        client.cookies.clear()


def test_logout_clears_session(client):
    do_login(client)
    token = re.search(r'"X-CSRF-Token":\s*"([^"]+)"', client.get("/admin/").text).group(1)
    r = client.post("/admin/logout", data={"csrf_token": token})
    assert r.status_code == 303
    assert r.headers["location"] == "/admin/login"
    assert client.get("/admin/").status_code == 303


@pytest.mark.parametrize(
    "bad",
    ["https://evil.example.com", "//evil.example.com", "/admin/../x", "/administrator", "/\\evil", "/other"],
)
def test_next_parameter_rejects_external_urls(client, bad):
    r = do_login(client, next_path=bad)
    assert r.status_code == 303
    assert r.headers["location"] == "/admin/"


def test_next_parameter_keeps_admin_path(client):
    r = do_login(client, next_path="/admin/feedback?status=new")
    assert r.headers["location"] == "/admin/feedback?status=new"


def test_htmx_request_without_session_gets_hx_redirect(client):
    r = client.get("/admin/", headers={"HX-Request": "true"})
    assert r.status_code == 401
    assert r.headers["hx-redirect"].startswith("/admin/login")


def test_csp_header_on_admin(client):
    expected = (
        "default-src 'self'; img-src 'self' data:; style-src 'self'; script-src 'self'; "
        "frame-ancestors 'none'; base-uri 'none'; form-action 'self'"
    )
    assert client.get("/admin/login").headers["content-security-policy"] == expected
    assert client.get("/admin/").headers["content-security-policy"] == expected
    assert "content-security-policy" not in client.get("/healthz").headers


def test_static_assets_are_served_without_login(client):
    assert client.get("/admin/static/admin.css").status_code == 200
    assert client.get("/admin/static/htmx.min.js").status_code == 200


def test_login_page_is_escaped(client):
    r = client.get("/admin/login", params={"next": '/admin/"><script>x</script>'})
    assert "<script>x" not in r.text


def test_hash_password_cli_outputs_argon2_hash(monkeypatch, capsys):
    answers = iter(["geheim-geheim-1", "geheim-geheim-1"])
    monkeypatch.setattr(hash_password.getpass, "getpass", lambda prompt="": next(answers))
    assert hash_password.main() == 0
    out = capsys.readouterr().out.strip()
    assert out.startswith("$argon2id$")
    assert hash_password.verify_password(out, "geheim-geheim-1")


def test_hash_password_cli_rejects_mismatch(monkeypatch, capsys):
    answers = iter(["geheim-geheim-1", "anders-anders-2"])
    monkeypatch.setattr(hash_password.getpass, "getpass", lambda prompt="": next(answers))
    assert hash_password.main() == 1
    assert "$argon2" not in capsys.readouterr().out


def test_non_ascii_csrf_token_is_403_not_500(client):
    login_token(client)
    r = client.post("/admin/login", data={"password": PASSWORD, "csrf_token": "ä"})
    assert r.status_code == 403
    r = client.post("/admin/login", data={"password": PASSWORD}, headers={"X-CSRF-Token": "ä".encode("utf-8")})
    assert r.status_code == 403


def test_login_page_disables_htmx_inline_style_and_eval(client):
    page = client.get("/admin/login")
    assert 'name="htmx-config"' in page.text
    assert '"includeIndicatorStyles":false' in page.text
    assert '"allowEval":false' in page.text
    assert ".htmx-indicator" in client.get("/admin/static/admin.css").text
