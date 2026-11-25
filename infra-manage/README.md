# Infrastructure Management

> [!NOTE]
> Korean version: [infra-manage.README.kr.md](../docs/localization/infra-manage.README.kr.md)

This repository connects the web, Spring Boot API, Python AI services, database, monitoring, and Kubernetes resources.

## Docker Compose

The expected sibling directories are:

```text
main-project-demo/
├── vite-web/
├── spring-server/
├── ai-model/
└── infra-manage/
```

Create `docker/.env` from `docker/.env.example`, then run:

```powershell
docker compose --env-file .\docker\.env -f .\docker\docker-compose.yml config --quiet
docker compose --env-file .\docker\.env -f .\docker\docker-compose.yml up -d --build
```

See [Docker execution guide](docker/README.md) for variables, ports, initialization, and troubleshooting.

## Kubernetes

Use the manifests under `kubernetes/` with Docker Desktop Kubernetes or another Kubernetes cluster.

```powershell
kubectl apply -k .\kubernetes
kubectl get pods,services,pvc,jobs
```

See [Kubernetes guide](kubernetes/README.md) before deploying.

## Directory Layout

| Path | Purpose |
|---|---|
| `docker/` | Compose and monitoring configuration |
| `db/` | MySQL initialization, migrations, and verification |
| `kubernetes/` | Kubernetes resources and Kustomize configuration |
| `utils/` | Infrastructure automation scripts |

## Korean Documentation

- [Infrastructure Korean README](../docs/localization/infra-manage.README.kr.md)
- [Docker Korean README](../docs/localization/infra-manage-docker.README.kr.md)
- [Kubernetes Korean README](../docs/localization/infra-manage-kubernetes.README.kr.md)
