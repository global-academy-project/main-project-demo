# Main Project for Infra Manager

> [!NOTE]
> English version: [Infrastructure Management README](../../infra-manage/README.md)

웹, Spring Boot API, Python AI 서비스를 로컬 통합 환경과 Kubernetes 리소스로
연결하는 인프라 저장소입니다. 서비스 코드는 각 프로젝트 저장소에서 관리하고,
이 저장소에서는 Compose 구성, 데이터베이스 초기화 및 마이그레이션, 모니터링,
Kubernetes 초안을 관리합니다.

## 빠른 시작: Docker Compose

Docker Desktop과 Docker Compose v2를 준비하고, 다음 저장소들이 같은 상위
디렉터리에 있는지 확인합니다.

```text
main-project-demo/
├── infra-manage/
├── vite-web/
├── spring-server/
└── ai-model/
```

`docker/.env`를 로컬에서 만들고 필요한 변수와 비밀 값을 입력합니다.
필수 변수 목록과 서비스별 동작은 [Docker 실행 가이드](docker/README.md)에
정리되어 있습니다. 저장소에 실제 비밀번호, 토큰 또는 API 키를 커밋하지 마세요.

저장소 루트에서 Compose 설정을 검증하고 서비스를 실행합니다.

```powershell
docker compose --env-file .\docker\.env -f .\docker\docker-compose.yml config --quiet
docker compose --env-file .\docker\.env -f .\docker\docker-compose.yml up -d --build
docker compose --env-file .\docker\.env -f .\docker\docker-compose.yml ps -a
```

컨테이너 간 연결 주소와 호스트 공개 포트, 초기화 작업, 로그 확인 절차는
[Docker 실행 가이드](docker/README.md)를 참고하세요. 개발용 데이터베이스만
실행하는 `docker-compose.dev.yml` 구성은 아래의 개발 DB 보관 안내를 따릅니다.

## Kubernetes

`kubernetes/`에는 Compose 구성을 옮기기 위한 로컬 배포 초안이 있습니다.
Docker Desktop Kubernetes 등의 클러스터와 `kubectl`을 준비하고
[Kubernetes 가이드](kubernetes/README.md)의 이미지, Secret, 스토리지 요구사항을
확인하세요. 실제 비밀은 로컬에서 안전하게 관리하고 Git에 커밋하지 않습니다.

### 로컬 빌드와 배포

위 Compose 빠른 시작에 나열된 프로젝트가 `main-project-demo` 아래에 있어야 합니다.
`kubernetes\base\common-secret.yaml`은
[Secret 예시](kubernetes/common-secret-example.yaml)를 참고해 로컬에서
준비합니다. 예시 문자열을 실제 Base64 값으로 바꿔야 하며, Base64는 암호화가
아닙니다.

저장소 루트에서 이미지를 빌드하고 매니페스트의 태그를 갱신합니다.

```powershell
.\utils\image-tag-manage.ps1
```

스크립트는 모든 빌드가 성공한 후 이미지 태그를 매니페스트에 반영하지만
클러스터에 적용하거나 노드에 이미지를 로드하지는 않습니다. 이미지가 각 노드에서
사용 가능한지 확인한 뒤 배포합니다. 기존 `qdrant-init` Job은 이미지가 바뀌면
Pod 템플릿을 수정할 수 없어 해당 Job을 별도로 재생성해야 합니다.

```powershell
kubectl apply -k .\kubernetes
kubectl get pods,services,pvc,jobs
```

MySQL만 시험할 때는 `kubectl apply -k .\kubernetes\standalone\mysql`을
사용할 수 있습니다. 단독 구성도 공통 리소스를 포함합니다.
`kubectl delete -k`는 공통 Secret과 PVC까지 삭제할 수 있으며, 스토리지
정책에 따라 데이터가 삭제될 수 있으므로 실행 전에 대상을 확인하세요.

MySQL 초기화와 Flyway Job은 DB·계정 및 스키마를 준비합니다. 임베딩 생성과
데이터 적재는 별도 서비스와 ingest 과정이 필요하며, 빈 PVC에 Compose 호스트의
데이터가 자동으로 복사되지는 않습니다.

### 웹 접속과 관리자 계정

로컬 포트 포워딩을 실행하고 브라우저에서
[http://localhost:19001](http://localhost:19001)을 엽니다.

```powershell
kubectl port-forward service/vite-service 19001:50001
```

터미널을 열어둬야 하며 `Ctrl+C`로 종료합니다. 포트가 이미 사용 중이면
`19002:50001`처럼 앞쪽 로컬 포트를 변경합니다.

Spring은 관리자 계정이 없고 `ADMIN_EMAIL`과 `ADMIN_PASSWORD`가 설정된 경우에만
첫 관리자 계정을 생성합니다. Kubernetes에서는 `common-spring-secret`에서
값을 주입하며, 생성 시 첫 로그인에서 비밀번호를 변경해야 합니다.

```powershell
kubectl logs deployment/spring-server | Select-String "admin"
```

관리자가 이미 있거나 Pod가 재시작됐다면 생성 로그가 없을 수 있습니다. Secret
변경만으로 기존 관리자 비밀번호는 바뀌지 않습니다.

배포 문제와 진단 명령은 [로컬 Kubernetes 문제 기록](kubernetes/TROUBLESHOOTING.md)을
참고하세요. Secret 값이나 민감한 로그는 공유하지 않습니다.

### Kubernetes CPU와 메모리 산정

컨테이너의 `resources`는 측정한 사용량을 기준으로 설정합니다.
`requests`는 스케줄러가 노드 배치 시 고려하는 요청량이고, `limits`는
컨테이너에 적용되는 상한입니다. CPU가 제한을 넘으면 실행이 제한되고,
메모리가 제한을 넘으면 컨테이너가 OOM으로 종료될 수 있습니다.

- CPU `1000m`은 CPU 1개에 해당하므로 `250m`은 0.25 CPU입니다.
- 메모리 `1Mi`는 1,048,576바이트입니다. `64Mi`는 약 67MB입니다.
- 리소스 값은 컨테이너 하나 기준입니다. Pod에 컨테이너가 여러 개면
  일반적으로 각 컨테이너의 요청량과 제한량을 더해 계산합니다.

예를 들어 현재 Vite 매니페스트는 컨테이너 하나에 CPU `250m`, 메모리
`64Mi`를 요청하고, CPU `500m`, 메모리 `128Mi`로 제한합니다. 복제본이
2개이므로 정상 상태의 합계는 다음과 같습니다.

| 구분 | 계산 | 합계 |
|---|---|---|
| CPU requests | `250m × 2` | `500m` (0.5 CPU) |
| 메모리 requests | `64Mi × 2` | `128Mi` |
| CPU limits | `500m × 2` | `1000m` (1 CPU) |
| 메모리 limits | `128Mi × 2` | `256Mi` |

롤링 업데이트 중에는 새 Pod가 추가로 생성될 수 있습니다. 현재 Vite 설정의
기본 롤링 업데이트 전략에서는 복제본 2개에 최대 1개가 추가되어, 일시적으로
요청량 합계가 CPU `750m`, 메모리 `192Mi`까지 늘어날 수 있습니다. 실제
노드 용량을 계획할 때는 다른 워크로드, 시스템 사용량, Pod 오버헤드와
종료 중인 Pod도 고려하고 노드별 할당 가능 용량을 확인합니다.

초깃값을 정한 후에는 대표적인 부하와 피크 상황에서 CPU와 메모리를
관찰해 조정합니다. 다음 명령은 현재 사용량 확인용이며 Metrics Server가
필요합니다. 순간값만으로 피크를 판단하지 말고 모니터링 지표를 일정 기간
수집하세요.

```powershell
kubectl top pods
kubectl top nodes
kubectl describe nodes
```

측정한 사용량과 변동 폭을 바탕으로 requests를 조정하고, limits는 부하
급증에 필요한 여유를 고려해 설정합니다. 특히 메모리 제한은 정상적인
피크 사용량보다 충분히 높게 잡고 OOM 발생 여부를 확인합니다. 위 Vite
수치는 현재 매니페스트의 예시이지 검증된 권장값은 아닙니다.

## 저장소 구성

| 경로 | 내용 |
|---|---|
| `docker/` | Compose 구성, 실행 가이드, 모니터링 설정 |
| `db/init/` | MySQL 최초 데이터 디렉터리 초기화 스크립트 |
| `db/migration/` | Flyway 데이터베이스 마이그레이션 |
| `db/verify/` | 수동 검증용 스크립트 |
| `kubernetes/` | Kubernetes 리소스 및 Kustomize 초안 |
| `utils/` | 인프라 관리 유틸리티 |

## Development web proxy

The web container forwards `/api` requests to
`http://spring-boot-application:60001` through `VITE_API_PROXY_TARGET`.
Inside the web container, `localhost` refers to the web container itself, not
Spring. Spring does not need a published host port for this connection.

## Development database storage

In [the development Compose configuration](docker/docker-compose.dev.yml), MySQL
uses `database-data`, while Qdrant retains the existing `default` volume.
Never mount the same data volume into both database services.

Spring waits for an authenticated MySQL health check before starting.
Initialization scripts run only when MySQL initializes an empty data directory.

When separating an existing shared volume, inspect and back up its contents first.
The new MySQL volume does not automatically migrate old MySQL data.
Do not use `docker compose down --volumes` when preserving database data.

From the repository root, validate and start the database with:

```powershell
docker compose --env-file .\docker\.env -f .\docker\docker-compose.dev.yml config --quiet
docker compose --env-file .\docker\.env -f .\docker\docker-compose.dev.yml up -d --wait database-mysql-server
```

## Docker Compose configuration

For the main Compose stack's image, healthcheck, volume, and environment variable
notes, see the [Docker execution guide](docker/README.md).
