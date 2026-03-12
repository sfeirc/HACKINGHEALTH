# Build from repo root: docker build -f infra/docker/Dockerfile.ml .
FROM python:3.12-slim
WORKDIR /app
COPY services/ml/requirements.txt ./
RUN pip install --no-cache-dir -r requirements.txt
COPY services/ml/app ./app
COPY services/ml/run.py ./
EXPOSE 8000
CMD ["uvicorn", "app.main:app", "--host", "0.0.0.0", "--port", "8000"]
