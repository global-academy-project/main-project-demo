# Kubernetes 초안

이 디렉터리는 Docker Compose 구성을 Kubernetes 리소스로 이관하기 위한 초안이다.

현재 상태는 설계와 검증이 진행 중이며, 파일과 매니페스트 구조가 변경될 수 있다.

## 디렉터리 구조

| 경로 | 역할 |
|---|---|
| `base/` | 공통 ConfigMap, Secret 및 PVC |
| `kustomization.yaml` | 전체 리소스를 연결하는 루트 Kustomization |
| `standalone/` | 공통 리소스와 단일 서비스를 조합한 로컬 테스트 구성 |
| `vite/` | Vite 웹 Deployment와 Service |
| `spring/` | Spring Boot 애플리케이션 리소스 |
| `agent/` | Python AI 모델 리소스 |
| `embedding/` | 임베딩 모델 리소스 |
| `ingest/` | KB ingest 작업 리소스 |
| `mysql/` | MySQL StatefulSet, Job, Secret, Volume 리소스 |
| `qdrant/` | Qdrant StatefulSet, Job, ConfigMap, Secret 리소스 |
| `prometheus/`, `grafana/` | 로컬 모니터링 리소스 |

상세 환경 변수 분석서는 [docs/environment-variable-audit.md](../docs/environment-variable-audit.md)를 참고한다.

## 설정 분리 원칙

### ConfigMap

- 비밀번호나 토큰을 포함하지 않는다.
- 여러 독립 서비스가 실제로 소비하는 값만 공통 리소스에 둔다.
- 도메인별 설정은 해당 도메인의 ConfigMap으로 분리한다.
- Pod 내부 주소는 실제 Kubernetes Service 이름과 포트로 작성한다.

예를 들어 `TZ`, `LANG`, `LC_ALL`은 내부 시스템에서 공통으로 사용될 수 있으므로
`common-system-config`에 둔다.

반면 임베딩 모델, 차원, 배치 크기와 같은 설정은 임베딩 관련 리소스에만
주입되도록 `common-embedding-config`로 분리한다.

### Secret

- 비밀번호, API 키, 토큰은 ConfigMap이 아니라 Secret에 둔다.
- 실제 Secret 값은 Git에 커밋하지 않는다.
- 저장소에는 `secret-example.yaml` 또는 운영 환경에서 생성할 Secret 템플릿만 둔다.
- 공통 Secret은 실제로 여러 컴포넌트가 동일한 값을 사용하는 경우에만 사용한다.

## 환경 변수 주입 방식

키가 여러 개이고 동일 도메인의 설정을 함께 소비하는 경우 `envFrom`을 사용한다.

```yaml
envFrom:
  - configMapRef:
      name: common-system-config
  - configMapRef:
      name: common-embedding-config
  - secretRef:
      name: common-embedding-secret
```

`envFrom`은 해당 ConfigMap 또는 Secret의 모든 키를 주입한다.
반드시 필요한 설정만 포함된 리소스인지 확인해야 한다.

키가 1~2개이고 사용 대상을 제한해야 하는 경우 `configMapKeyRef` 또는
`secretKeyRef`를 사용한다.

```yaml
env:
  - name: EMBEDDING_MODEL
    valueFrom:
      configMapKeyRef:
        name: common-embedding-config
        key: EMBEDDING_MODEL
```

## 권장 리소스 초안

| 리소스 | 포함할 설정 |
|---|---|
| `common-system-config` | `TZ`, `LANG`, `LC_ALL` |
| `common-spring-config` | Spring과 Java 공개 설정 |
| `common-python-config` | Python AI 서비스 공개 설정 |
| `common-embedding-config` | 임베딩 모델명, 차원, URL, 배치 설정 |
| `common-model-config` | 모델 클라이언트와 모델 경로 설정 |
| `common-mysql-config` | MySQL 호스트, 포트, 데이터베이스명과 문자셋 |
| `common-kb-config` | Knowledge Base 데이터베이스명과 계정 |
| `common-qdrant-config` | Qdrant 호스트와 공개 설정 |

| Secret | 포함할 값 |
|---|---|
| `common-spring-secret` | JWT, 내부 API 토큰, 관리자 계정 |
| `common-mysql-secret` | MySQL 사용자와 root 비밀번호 |
| `common-kb-secret` | KB 계정 비밀번호와 ingest 토큰 |
| `common-embedding-secret` | 임베딩 API 키 |
| `common-qdrant-secret` | Qdrant API 키 |
| `common-kosha-secret` | KOSHA 서비스 키 |

## Compose와 Kubernetes 주소 매핑

| 역할 | Compose 주소 예시 | Kubernetes 주소 예시 |
|---|---|---|
| Spring | `spring-boot-application:60001` | `spring-service:60001` |
| AI 모델 | `python-ai-model:60100` | `ai-model-service:60100` |
| 임베딩 | `python-embedding-model:60110` | `embedding-service:60110` |
| MySQL | `database-mysql-server:3306` | `mysql-service:3306` |
| Qdrant | `qdrant-server:6333` | `qdrant-service:6333` |

실제 포트와 Service 이름은 각 도메인 디렉터리의 `service.yaml`에서 확인하고,
주소가 여러 설정에 반복될 경우 단일 ConfigMap 키로 통일한다.

## 로컬 배포 초안

서비스별 Kustomization은 해당 서비스만 포함한다. 루트 구성은 `base/`와 모든
서비스를 한 번씩 포함한다. `standalone/mysql/` 같은 구성은 `base/`와 해당
서비스만 조합한다. 단독 구성이라고 다른 서비스가 필요 없다는 뜻은 아니다.
예를 들어 ingest에는 MySQL, Qdrant와 embedding이 필요하다.

`base/common-secret.yaml`은 [Secret 예시](common-secret-example.yaml)를 참고해
로컬에서 준비하고 예시 값을 실제 Base64 값으로 바꾼다. 실제 값은 Git에 커밋하지 않는다.
MySQL의 KB 계정 비밀번호와 Flyway Job의 `KB_OWNER_PASSWORD`는 같아야 한다.

저장소 루트 기준으로 로컬 이미지를 빌드한다.

```powershell
docker build -f ..\main-vite-web\orchestration.Dockerfile -t vite-web:local ..\main-vite-web
docker build -t spring-server:local ..\main-server
docker build --target ai -t ai-model:local ..\main-ai-model
docker build --target embedding -t embedding:local ..\main-ai-model
docker build --target ingest -t kb-ingest:local ..\main-ai-model
docker build --target qdrant-init -t qdrant-init:local ..\main-ai-model
```

또는 `.\utils\image-tag-manage.ps1`을 실행하면 각 이미지에 같은 시간 기반
태그를 붙여 빌드하고 모든 빌드가 성공한 후 해당 매니페스트를 갱신한다.
빌드 실패 시 매니페스트는 갱신하지 않는다. 클러스터에 자동으로 적용하거나
노드에 이미지를 로드하지는 않는다. 기존 `qdrant-init` Job은 Pod 템플릿을
수정할 수 없으므로 이미지가 바뀌면 Job만 별도로 재생성해야 한다.

이미지는 각 Kubernetes 노드에서 사용할 수 있어야 한다. kind와 minikube 등은
별도의 이미지 로드가 필요할 수 있다. `:local`을 다시 빌드해도 실행 중인 Pod는
자동 갱신되지 않으며 `IfNotPresent`는 기존 이미지를 재사용할 수 있다. 새 빌드마다
고유 태그를 사용하고 매니페스트를 갱신하는 방식을 권장한다.

먼저 렌더링을 확인한다. 출력에 Secret이 포함되므로 공유하지 않는다.

```powershell
kubectl kustomize .\kubernetes
kubectl kustomize .\kubernetes\standalone\mysql
```

배포 환경과 Secret, 스토리지를 확인한 다음 전체 구성 또는 단독 구성을 적용한다.

```powershell
kubectl apply -k .\kubernetes
# 또는 MySQL 관련 구성만 적용
kubectl apply -k .\kubernetes\standalone\mysql
kubectl get pods,services,pvc,jobs
```

`kubectl delete -k`는 해당 구성에 포함된 공통 Secret과 PVC까지 삭제한다.
PVC 삭제는 스토리지 정책에 따라 실제 데이터 삭제로 이어질 수 있으므로,
테스트 종료 시에도 삭제 대상을 먼저 확인한다.

`ReadWriteOnce` 모델 캐시는 Spring과 AI Pod가 같은 노드에서 사용해야 할 수
있다. embedding은 별도 PVC를 사용한다. ingest의 `shared-data-volume`은 빈
볼륨이며 Compose 호스트의 `out` 파일을 자동으로 가져오지 않는다. 필요한 입력을
PVC의 `out` 디렉터리에 별도로 준비해야 한다. `vectors` 디렉터리는 쓰기용이다.

MySQL과 Qdrant 준비 및 초기화 Job 완료는 다른 서비스의 배포 순서로 보장되지
않는다. Flyway는 연결을 재시도하며 Qdrant 초기화 Job도 실패 시 재시도하지만,
Job 결과와 각 서비스의 준비 상태를 확인해야 한다. 완료된 Job은 매니페스트를
재적용해도 자동으로 다시 실행되지 않는다.

Prometheus는 현재 AI 서비스와 자체 메트릭을 수집한다. embedding과 ingest는
현재 `/metrics` 엔드포인트가 없으며, Qdrant 메트릭은 인증 연동이 필요하다.
Grafana와 Prometheus는 ClusterIP로 제공되므로 로컬 접근에는 포트 포워딩을 쓴다.
각 명령은 별도의 터미널에서 실행한다.

```powershell
kubectl port-forward service/grafana 3000:3000
kubectl port-forward service/prometheus 9090:9090
```

## 이후 작업

- Compose 환경 변수를 실제 Kubernetes 환경 변수로 매핑한다.
- Docker 컨테이너 이름을 Kubernetes Service 이름과 포트로 교체한다.
- 공통 Secret의 실제 운영 주입 방식을 정한다.
- 각 도메인 ConfigMap이 필요한 키만 포함하는지 검토한다.
- 공통 설정과 도메인 설정의 중복을 재검토한다.
- StatefulSet, Deployment, Job의 환경 변수 주입 방식과 순서를 문서화한다.
- 매니페스트 검증 후 이 초안을 각 도메인 `README.md`와 동기화한다.
