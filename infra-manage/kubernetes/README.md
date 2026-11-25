# Kubernetes Configuration

> [!NOTE]
> Korean version: [infra-manage-kubernetes.README.kr.md](../../docs/localization/infra-manage-kubernetes.README.kr.md)

This directory contains a local Kubernetes deployment draft built from the Docker Compose stack.

## Structure

| Path | Purpose |
|---|---|
| `base/` | Shared ConfigMaps, Secrets, and storage |
| `vite/` | Vite deployment and service |
| `spring/` | Spring Boot deployment and service |
| `agent/` | Python AI deployment |
| `embedding/` | Embedding deployment |
| `ingest/` | Knowledge ingestion deployment |
| `qdrant/` | Qdrant StatefulSet and service |
| `mysql/` | MySQL StatefulSet, jobs, and storage |
| `prometheus/`, `grafana/` | Monitoring resources |

## Apply

```powershell
kubectl apply -k .\kubernetes
kubectl get pods,services,pvc,jobs
```

Create local Secret values before applying workloads. Never commit real secret values.

## Korean Documentation

- [Korean Kubernetes README](../../docs/localization/infra-manage-kubernetes.README.kr.md)
- [Korean MySQL README](../../docs/localization/infra-manage-kubernetes-mysql.README.kr.md)
