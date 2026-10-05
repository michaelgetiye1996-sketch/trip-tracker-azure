# Small official Python base image (Debian slim)
FROM python:3.12-slim

# No .pyc files, unbuffered logs (so `kubectl logs` shows output immediately), lean pip
ENV PYTHONDONTWRITEBYTECODE=1 \
    PYTHONUNBUFFERED=1 \
    PIP_NO_CACHE_DIR=1 \
    PIP_DISABLE_PIP_VERSION_CHECK=1

WORKDIR /app

# Dependencies first: this layer is cached and only rebuilds when requirements.txt changes
COPY requirements.txt .
RUN pip install -r requirements.txt

# App code last: changes most often, so it's the cheapest layer to rebuild
COPY main.py .

# Run as a non-root user with a numeric UID (lets Kubernetes enforce runAsNonRoot)
RUN useradd --uid 10001 --no-create-home --shell /usr/sbin/nologin appuser
USER 10001

EXPOSE 8000

# Exec form: uvicorn runs as PID 1 and receives Kubernetes' SIGTERM for graceful shutdown
CMD ["uvicorn", "main:app", "--host", "0.0.0.0", "--port", "8000"]
