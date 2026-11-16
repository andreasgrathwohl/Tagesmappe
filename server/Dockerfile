# Basis: python:3.12-slim. Für reproduzierbare Builds die Digest-Zeile festhalten:
#   docker buildx imagetools inspect python:3.12-slim   ->   FROM python:3.12-slim@sha256:<digest>
FROM python:3.12-slim AS build
COPY --from=ghcr.io/astral-sh/uv:0.13.8 /uv /usr/local/bin/uv
WORKDIR /app
ENV UV_COMPILE_BYTECODE=1 UV_LINK_MODE=copy UV_PYTHON_DOWNLOADS=never
COPY pyproject.toml uv.lock ./
COPY src ./src
# Nicht editierbar: die Laufzeit-Stufe kopiert nur .venv, eine editierbare Installation zeigte auf fehlende Quellen.
RUN uv sync --frozen --no-dev --no-editable

FROM python:3.12-slim
# Laufzeit ohne Build-Werkzeuge: nur .venv, Startseite und ein Nutzer ohne Rechte.
RUN useradd --system --uid 10001 --no-create-home --shell /usr/sbin/nologin frontstage \
    && mkdir /data && chown frontstage:frontstage /data
WORKDIR /app
COPY --from=build /app/.venv /app/.venv
COPY landing /app/landing
ENV PATH="/app/.venv/bin:$PATH" \
    PYTHONUNBUFFERED=1 \
    DATA_DIR=/data \
    LANDING_DIR=/app/landing \
    TRUSTED_PROXIES=127.0.0.1
# Eigentümer steht vor VOLUME: ein neues Volume übernimmt ihn aus dem Image, sonst könnte UID 10001 nicht schreiben.
VOLUME /data
USER frontstage
EXPOSE 8000
HEALTHCHECK --interval=15s --timeout=5s --start-period=10s --retries=3 \
    CMD ["python", "-c", "import urllib.request,sys; sys.exit(0 if urllib.request.urlopen('http://127.0.0.1:8000/healthz').status==200 else 1)"]
# sh -c, damit ${TRUSTED_PROXIES} aufgelöst wird; exec, damit uvicorn Signale erhält
CMD ["sh", "-c", "exec uvicorn frontstage_service.asgi:app --host 0.0.0.0 --port 8000 --proxy-headers --forwarded-allow-ips \"${TRUSTED_PROXIES}\" --no-access-log"]
