"""Jinja2-Umgebung der Verwaltung (Autoescape für HTML ist aktiv)."""

from pathlib import Path

from fastapi.templating import Jinja2Templates

TEMPLATE_DIR = Path(__file__).resolve().parent.parent / "templates"
STATIC_DIR = Path(__file__).resolve().parent.parent / "static" / "admin"

templates = Jinja2Templates(directory=TEMPLATE_DIR)
