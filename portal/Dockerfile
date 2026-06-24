# Container image for the FastAPI portal.
#
# Built and pushed to Azure Container Registry by .github/workflows/portal.yml,
# then run on Azure Container Apps. Kept deliberately simple and readable.

FROM python:3.13-slim

# PYTHONDONTWRITEBYTECODE: don't litter .pyc files in the container.
# PYTHONUNBUFFERED: send stdout/stderr straight through (unbuffered), so
# log lines reach Container Apps / Log Analytics immediately.
ENV PYTHONDONTWRITEBYTECODE=1 \
    PYTHONUNBUFFERED=1

WORKDIR /app

# Install dependencies FIRST, in their own layer. Docker caches layers,
# and requirements.txt changes far less often than the app code — so most
# rebuilds skip the (slow) pip install and reuse the cached layer.
COPY requirements.txt .
RUN pip install --no-cache-dir -r requirements.txt

# Then copy the application package.
COPY app ./app

# Run as a non-root user — if the app is ever compromised, the attacker
# isn't root inside the container. Create a fixed-uid user and switch to it.
RUN useradd --create-home --uid 10001 appuser
USER appuser

# Document the port the app listens on (Container Apps routes to it).
EXPOSE 8000

# Start uvicorn. --host 0.0.0.0 binds all interfaces so traffic from
# outside the container reaches the app (127.0.0.1 would only be reachable
# from inside). No --reload here: that's a development-only convenience.
CMD ["uvicorn", "app.main:app", "--host", "0.0.0.0", "--port", "8000"]
