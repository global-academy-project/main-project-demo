# Docker Execution Guide

> [!NOTE]
> Korean version: [infra-manage-docker.README.kr.md](../../docs/localization/infra-manage-docker.README.kr.md)

## Compose Files

| File | Purpose |
|---|---|
| `docker-compose.yml` | Main application stack |
| `docker-compose.dev.yml` | Development database and related services |
| `mysql-migration.Dockerfile` | Flyway migration image for Kubernetes |
| `qdrant-init.Dockerfile` | Standalone Qdrant initialization image |

## Environment

Copy `docker/.env.example` to `docker/.env` and replace placeholders before running Compose.

```powershell
docker compose --env-file .\docker\.env -f .\docker\docker-compose.yml config --quiet
docker compose --env-file .\docker\.env -f .\docker\docker-compose.yml up -d --build
docker compose --env-file .\docker\.env -f .\docker\docker-compose.yml ps -a
```

Do not commit passwords, API keys, JWT secrets, or internal tokens.

## Build Contexts

Compose resolves sibling projects from `infra-manage/docker`:

- `../../vite-web`
- `../../spring-server`
- `../../ai-model`

## Korean Documentation

- [Korean Docker README](../../docs/localization/infra-manage-docker.README.kr.md)
