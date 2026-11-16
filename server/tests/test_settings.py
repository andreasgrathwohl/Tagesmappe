from pathlib import Path

import pytest

from frontstage_service.settings import Settings, SettingsError

BASE = {
    "APP_KEY": "k" * 32,
    "SESSION_SECRET": "s" * 32,
    "ADMIN_PASSWORD_HASH": "$argon2id$dummy",
}


def test_from_env_reads_all_values():
    s = Settings.from_env(
        {
            **BASE,
            "RETENTION_DAYS": "30",
            "DATA_DIR": "/srv/d",
            "PUBLIC_BASE_URL": "https://x.example.com",
            "COOKIE_SECURE": "false",
            "LANDING_DIR": "/srv/l",
        }
    )
    assert s.app_key == "k" * 32
    assert s.session_secret == "s" * 32
    assert s.admin_password_hash == "$argon2id$dummy"
    assert s.retention_days == 30
    assert s.data_dir == Path("/srv/d")
    assert s.public_base_url == "https://x.example.com"
    assert s.cookie_secure is False
    assert s.landing_dir == Path("/srv/l")


def test_defaults():
    s = Settings.from_env(BASE)
    assert s.retention_days == 365
    assert s.cookie_secure is True
    assert s.data_dir == Path("/data")
    assert s.landing_dir == Path("/app/landing")


def test_missing_app_key_fails_in_german():
    env = {k: v for k, v in BASE.items() if k != "APP_KEY"}
    with pytest.raises(SettingsError, match="APP_KEY fehlt"):
        Settings.from_env(env)


@pytest.mark.parametrize("name", ["APP_KEY", "SESSION_SECRET"])
def test_short_secrets_fail(name):
    with pytest.raises(SettingsError, match=name):
        Settings.from_env({**BASE, name: "kurz"})


@pytest.mark.parametrize("value", ["0", "-3", "abc"])
def test_retention_must_be_positive(value):
    with pytest.raises(SettingsError, match="RETENTION_DAYS"):
        Settings.from_env({**BASE, "RETENTION_DAYS": value})


def test_invalid_cookie_secure_fails():
    with pytest.raises(SettingsError, match="COOKIE_SECURE"):
        Settings.from_env({**BASE, "COOKIE_SECURE": "vielleicht"})


def test_noindex_setting():
    assert Settings.from_env(BASE).noindex is False
    assert Settings.from_env({**BASE, "NOINDEX": "true"}).noindex is True
    with pytest.raises(SettingsError, match="NOINDEX"):
        Settings.from_env({**BASE, "NOINDEX": "vielleicht"})
