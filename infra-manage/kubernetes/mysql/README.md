# MySQL Kubernetes Migration

> [!NOTE]
> Korean version: [infra-manage-kubernetes-mysql.README.kr.md](../../../docs/localization/infra-manage-kubernetes-mysql.README.kr.md)

This directory documents the MySQL and Flyway migration resources for Kubernetes.

## Scope

The current manifests are draft resources and require environment-specific review before deployment.

| Resource | Purpose |
|---|---|
| `configmap.yaml` | Non-sensitive database configuration |
| `secret-example.yaml` | Example secret template |
| `statefulset.yaml` | MySQL workload and persistent storage |
| `job.yaml`, `seed-job.yaml` | Flyway and seed execution |
| `service.yaml` | Cluster service configuration |

Keep credentials in Kubernetes Secrets and never commit real secret values.

## Korean Documentation

- [Korean MySQL README](../../../docs/localization/infra-manage-kubernetes-mysql.README.kr.md)
