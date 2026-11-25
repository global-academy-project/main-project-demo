# Metrix Service

> [!NOTE]
> Korean version: [ai-model-metrix.README.kr.md](../../docs/localization/ai-model-metrix.README.kr.md)

The Metrix FastAPI service exposes AI metrics and monitoring endpoints.

## Local Run

```powershell
python metrix/main.py
```

Run the service with dependencies from `metrix/requirements.txt`.

## Docker

The infrastructure Compose configuration builds the AI service using `metrix/Dockerfile` or the root multi-stage `ai-model/Dockerfile` target.

Rebuild and restart from `infra-manage/docker` after changing infrastructure configuration.

## Korean Documentation

- [Korean Metrix README](../../docs/localization/ai-model-metrix.README.kr.md)
