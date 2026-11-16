"""Einstiegspunkt nur für Uvicorn; Tests importieren dieses Modul nie, sondern main.create_app."""

import os

from .main import create_app
from .settings import Settings

app = create_app(Settings.from_env(os.environ))
