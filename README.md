# Main Project

> [!NOTE]
> A version of the README in Korean can be found at [main-project-demo](./docs/localization/README.kr.md).

Top-level overview of the repositories that make up the field safety management
service. The service consists of a React web app, a Spring Boot API, Python AI
services, and an infrastructure repository that ties them together. Each
repository is developed and deployed independently, while local integration and
Kubernetes deployment are managed in the infrastructure repository.

## Architecture Overview

```text
[ main-vite-web ]  ──/api──▶  [ main-server ]  ──▶  [ main-ai-model ]
     React web                 Spring Boot API         FastAPI AI/RAG
                                     │                       │
                                     ▼                       ▼
                                  MySQL                Qdrant · Embedding
                                     └──────────┬──────────┘
                                        [ main-infra-manage ]
                               Docker Compose · Kubernetes · DB · Monitoring
```

- The web application forwards `/api` requests to the Spring Boot server.
- The Spring Boot server provides APIs for users/permissions, safety records,
  approvals, notifications, and audit reports, and calls the AI services when AI
  features are needed.
- The AI services provide agent, near-miss tagging, rule extraction, image
  recognition, and speech transcription features, along with RAG search
  (embedding + Qdrant).
- The infrastructure repository connects the four services via local Compose and
  Kubernetes, and manages database initialization/migration and monitoring
  configuration.

## Repositories

| Repository | Role | Tech stack |
|---|---|---|
| [main-vite-web](../main-vite-web) | React web app for field safety management | React 19, React Router 7, Vite 8, Node.js 24 |
| [main-server](../main-server) | Field safety management API server | Java 17, Spring Boot 4, MySQL, Flyway, JWT |
| [main-ai-model](../main-ai-model) | AI, embedding, and knowledge ingest services | Python 3.12, FastAPI, BGE-M3, Qdrant |
| [main-infra-manage](../main-infra-manage) | Integrated run and deployment infrastructure | Docker Compose, Kubernetes, MySQL, Grafana |

## Services and Ports

| Component | Local dev port | Docker port | Notes |
|---|---|---|---|
| Web (Vite) | 50001 | 50001 | Proxies `/api` requests to the server |
| API server (Spring Boot) | 8080 | 60001 | Swagger UI at `/swagger-ui/index.html` |
| AI API | 60100 | 60100 | Health check at `/health` |
| Embedding API | 60110 | 60110 | Readiness check at `/ready` |
| Knowledge ingest API | 8001 | 8001 | Readiness check at `/ready` |
| Qdrant init | — | one-off | Initializes collections and indexes |

## Quick Start

The simplest way to run everything together is with the infrastructure
repository's Docker Compose setup. All four repositories must live under the same
parent directory.

```text
main-infra-manage
main-vite-web
main-server
main-ai-model
```

Create `main-infra-manage/docker/.env` with the required variables and secrets,
then run Compose from the infrastructure repository root.

```powershell
docker compose --env-file .\docker\.env -f .\docker\docker-compose.yml up -d --build
```

For the required environment variables, inter-container connection addresses, and
initialization tasks, see the
[Docker execution guide in main-infra-manage](../main-infra-manage/docker/README.md).

## Per-Repository Development

To develop and test each repository individually, refer to its README.

- Web: [main-vite-web/README.md](../main-vite-web/README.md) — `npm ci`, then `npm run dev`
- Server: [main-server/README.md](../main-server/README.md) — `.\gradlew.bat bootRun`
- AI: [main-ai-model/README.md](../main-ai-model/README.md) — create `.venv`, then run `uvicorn`
- Infra: [main-infra-manage/README.md](../main-infra-manage/README.md) — Compose and Kubernetes

## Notes

- Manage passwords, JWT keys, internal API tokens, and mail/external service
  credentials via local environment variables or `.env` files, and never commit
  them to the repositories.
- Example values such as those in `.env.example` are not runnable credentials.
- Do not place real production secrets in Kubernetes manifest Secrets; decide on a
  cluster secret management approach before applying them.
