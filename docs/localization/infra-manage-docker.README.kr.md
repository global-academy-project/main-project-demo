# Docker 실행 가이드

> [!NOTE]
> English version: [Docker Execution Guide](../../infra-manage/docker/README.md)

## 대상과 실행 위치

- [docker-compose.yml](./docker-compose.yml): 웹, API, AI 모델, 데이터베이스와 초기화 작업을 함께 실행합니다.
- [mysql-migration.Dockerfile](./mysql-migration.Dockerfile): **Kubernetes Job에서 실행할 DB 마이그레이션용 이미지**를 빌드합니다. Flyway와 SQL 파일을 포함하며, MySQL 서버 이미지나 Docker Compose용 Dockerfile이 아닙니다.

아래 PowerShell 명령은 모두 인프라 프로젝트 루트인 `infra-manage`에서 실행합니다.

```powershell
Set-Location C:\projects\main-project-demo\infra-manage
```

Docker Desktop과 Docker Compose v2가 필요합니다. Compose가 빌드하는 다른 프로젝트도 다음처럼 같은 상위 디렉터리에 준비해야 합니다.

```text
상위 디렉터리
├─ main-project-demo/
│  ├─ infra-manage/
│  ├─ vite-web/
│  ├─ spring-server/
│  └─ ai-model/
```

## Docker Compose

### 서비스와 접속 포트

| 서비스                    | 역할                          | 호스트에서 접속          | 컨테이너 간 주소                |
| ------------------------- | ----------------------------- | ------------------------ | ------------------------------- |
| `vite-web-application`    | Vite 웹 애플리케이션          | `http://localhost:50001` | `vite-web-application:50001`    |
| `spring-boot-application` | Spring Boot API               | 직접 노출하지 않음       | `spring-boot-application:60001` |
| `python-ai-model`         | AI API                        | 직접 노출하지 않음       | `python-ai-model:60100`         |
| `python-embedding-model`  | 임베딩 모델 API               | 직접 노출하지 않음       | `python-embedding-model:60110`  |
| `database-mysql-server`   | MySQL                         | 직접 노출하지 않음       | `database-mysql-server:3306`    |
| `kb-migrator`             | Flyway 스키마 마이그레이션    | 해당 없음                | MySQL에 접속하는 일회성 작업    |
| `qdrant-server`           | 벡터 데이터베이스             | 직접 노출하지 않음       | `qdrant-server:6333`            |
| `qdrant-init`             | Qdrant 컬렉션과 인덱스 초기화 | 해당 없음                | 일회성 작업                     |
| `kb-ingest`               | 지식 데이터 적재 API          | 직접 노출하지 않음       | `kb-ingest:8001`                |
| `prometheus`              | 메트릭 수집                   | `http://localhost:9090`  | `prometheus:9090`               |
| `grafana`                 | 모니터링 대시보드             | `http://localhost:3000`  | `grafana:3000`                  |

컨테이너끼리는 기본 bridge 네트워크에서 서비스 이름과 컨테이너 포트로 통신합니다. 예를 들어 다른 컨테이너에서 MySQL에 접속할 때는 `database-mysql-server:3306`을 사용합니다. MySQL과 AI API 등의 호스트 포트 매핑은 기본적으로 주석 처리되어 있습니다.

현재 포트 매핑에는 호스트 IP 제한이 없으므로 로컬 컴퓨터 외부에서도 접근할 수 있습니다. 개발 환경을 넘어 사용할 때는 방화벽과 바인딩 주소를 검토합니다.

### 환경변수 준비

로컬 전용 `docker/.env` 파일에 값을 준비합니다. 아래 명령은 이 파일을 `--env-file`로 명시해서 사용합니다. 실제 비밀번호와 토큰은 문서나 Git에 포함하지 않습니다.

| 구분            | 환경변수                                                                                      |
| --------------- | --------------------------------------------------------------------------------------------- |
| 업무 DB         | `MYSQL_DATABASE`, `MYSQL_USER`, `MYSQL_PASSWORD`, `MYSQL_ROOT_PASSWORD`                       |
| 지식 DB 계정    | `KB_OWNER_PASSWORD`, `KB_INGEST_PASSWORD`, `KB_READER_PASSWORD`                               |
| 내부 API와 인증 | `INTERNAL_API_TOKEN`, `JWT_SECRET`, `KB_INGEST_API_TOKEN`                                     |
| Qdrant          | `QDRANT_API_KEY`, `QDRANT_READ_ONLY_API_KEY`                                                  |
| 임베딩          | `EMBEDDING_API_KEY`                                                                           |
| 선택 설정       | `ADMIN_EMAIL`, `ADMIN_PASSWORD`, `LLM_ADAPTERS`, `CHECK_RULES_TOOL`, `KOSHA_MSDS_SERVICE_KEY` |

Compose의 `${변수:?오류 메시지}`는 값이 비어 있으면 실행을 차단합니다. 이런 검사가 없는 변수도 애플리케이션이나 DB 초기화에서 필요할 수 있습니다. 특히 MySQL 초기화 스크립트는 세 가지 `KB_*_PASSWORD` 값을 요구합니다.

### 실행과 확인

```powershell
# 환경변수 치환과 Compose 설정 검사
docker compose --env-file docker\.env -f docker\docker-compose.yml config --quiet

# 이미지 빌드 및 전체 서비스 시작
docker compose --env-file docker\.env -f docker\docker-compose.yml up -d --build

# 일회성 작업을 포함한 상태 확인
docker compose --env-file docker\.env -f docker\docker-compose.yml ps -a

# 마이그레이션 결과 확인
docker compose --env-file docker\.env -f docker\docker-compose.yml logs kb-migrator

# 서비스 중지 및 컨테이너/네트워크 제거
docker compose --env-file docker\.env -f docker\docker-compose.yml down
```

`kb-migrator`와 `qdrant-init`은 정상 완료 후 종료됩니다. 종료 코드가 `0`인지 로그와 상태를 함께 확인합니다.

첫 실행에서는 모델 다운로드와 DB 초기화로 준비 시간이 길어질 수 있습니다.

### AI POST 부하 확인

AI 서비스가 실행 중일 때 저장소 루트의 PowerShell에서 실행합니다.
요청은 AI 컨테이너 내부에서 전송되므로 AI 포트를 호스트에 공개할 필요가 없습니다.

```powershell
.\utils\ai-post-load.ps1 -RequestCount 100 -Concurrency 4 -TimeoutSeconds 300
```

실행 결과와 Docker 오류는 화면에 출력되는 동시에 `utils/logs`에 동시성과 실행
시각을 포함한 고유한 `.log` 파일로 저장됩니다. 시작 시각, 종료 시각과 종료 코드도
기록되며 로그 경로는 실행 시작 시 표시됩니다. `-LogPath .\my-test.log`로 파일을
직접 지정할 수 있습니다. 지정한 상위 디렉터리는 미리 존재해야 하며 기존 파일은
덮어쓰지 않습니다. 로그에는 요청 경로와 오류 메시지가 포함될 수 있으므로 공유 전에
내용을 확인하세요.

기본값은 총 10건, 동시 최대 2건, 요청당 제한 시간 300초입니다. 기본 요청은
아차사고 태깅과 규칙 입력 추출을 번갈아 호출합니다. 요청 수와 동시성을 점차
높여 처리량을 비교하세요. 높은 부하는 AI 서비스와 다른 사용자에게 영향을 줄 수
있으므로 테스트 환경에서 실행합니다.

다른 POST를 보내려면 요청 목록 JSON 파일을 작성하고 `-RequestFile`로 지정합니다.
각 항목은 AI 서비스 기준 경로와 JSON 요청 본문이며, 목록을 순서대로 반복합니다.

```json
[
	{"path": "/api/v1/extract/rule-input", "body": {"text": "Oxygen is 20.9 percent."}},
	{"path": "/api/v1/agent/near-miss-tag", "body": {"runId": 1, "siteId": 1, "nearMissId": 1, "title": "Near miss", "description": "A worker nearly slipped."}}
]
```

```powershell
.\utils\ai-post-load.ps1 -RequestCount 100 -Concurrency 4 -RequestFile .\requests.json
```

실행 결과에는 경로별 HTTP 상태와 평균 응답시간, 처리량이 표시됩니다. 실패한
요청이나 2xx 이외의 응답이 있으면 스크립트가 오류로 종료됩니다. Grafana의
`AI Model Prometheus` 대시보드와 `http://localhost:9090/targets`에서 확인할 수
있으며, Prometheus 수집 간격은 15초입니다. 2xx 여부만 검사하므로 응답 내용의
업무상 정확성은 별도 검증이 필요합니다.

#### 부하 테스트 결과

2026-11-23에 동시성 1·2·4·8로 각각 100건씩 실행한 결과와 해석은
[AI POST 부하 테스트 결과](./AI-POST-LOAD-RESULTS-2026-11-23.md)를 참고하세요.
모든 조건에서 HTTP 200을 받았으며, 동시성 2 이상에서는 처리량이 비슷한 반면
동시성이 높아질수록 평균·최대 지연시간이 증가했습니다. 테스트 환경 사양과
Grafana 원시 지표는 기록되지 않았으므로 절대 최대 처리량으로 해석해서는 안 됩니다.

### Terraform으로 로컬 Compose 실행

[lab.tf](../kubernetes/lab.tf)는 로컬 Docker Desktop에서 기존 `docker-compose.yml`을
실행하는 초안입니다. 서버나 Docker Desktop을 설치하지 않으며, 위의 Docker Compose
준비 사항과 Terraform 1.4 이상이 필요합니다. `docker/.env`는 미리 준비해야 합니다.

저장소 루트의 PowerShell에서 실행합니다.

```powershell
terraform -chdir=kubernetes init
terraform -chdir=kubernetes plan
terraform -chdir=kubernetes apply
```

`apply`는 `docker compose up -d --build`를 실행합니다. 기존 Compose 프로젝트를
사용하므로 실행 중인 컨테이너가 설정에 따라 재생성될 수 있습니다.
Terraform은 Compose 파일 변경을 감지하지만 컨테이너 상태, `.env`, SQL 및 다른
프로젝트의 소스 변경은 추적하지 않습니다. 이 변경을 반영하거나 수동으로 중지한
서비스를 다시 시작하려면 다음처럼 재실행합니다.

```powershell
terraform -chdir=kubernetes apply -replace=terraform_data.compose
```

Terraform 상태 파일은 로컬에 저장되므로 Git에 올리지 않습니다.
`terraform destroy`는 Terraform 상태만 정리하며 Compose 서비스를 중지하거나
볼륨을 삭제하지 않습니다. 서비스 중지는 위의 `docker compose ... down` 명령을
사용합니다.

### 시작 의존성

- Spring Boot는 MySQL과 Qdrant의 health check 통과를 기다립니다.
- Flyway는 MySQL의 health check 통과를 기다린 뒤 실행됩니다.
- Qdrant 초기화 작업은 Qdrant의 health check 통과를 기다립니다.
- AI API는 Qdrant 초기화 성공, Qdrant와 임베딩 API의 health check 통과를 기다립니다.
- 적재 API는 Qdrant 초기화 성공, Qdrant와 MySQL의 health check 통과를 기다립니다.

현재 Spring Boot와 적재 API는 Flyway 완료를 기다리도록 설정되어 있지 않습니다. 전체 서비스 시작이 곧 스키마 마이그레이션 완료를 의미하지는 않습니다. `depends_on`은 시작 조건이며, 운영 중 의존 서비스 장애에 대한 자동 복구를 보장하지 않습니다.

### 데이터와 SQL 파일

Compose의 상대 마운트 경로는 `docker-compose.yml`이 있는 디렉터리 기준입니다.

| 원본                                           | 컨테이너 경로                         | 용도                                                      |
| ---------------------------------------------- | ------------------------------------- | --------------------------------------------------------- |
| [docker/db/init](./db/init)                    | MySQL의 `/docker-entrypoint-initdb.d` | 초기 DB와 계정 생성, 읽기 전용                            |
| [docker/db/verify](./db/verify)                | MySQL의 `/opt/verify`                 | 검증 스크립트, 읽기 전용. 마운트만으로 자동 실행되지 않음 |
| [docker/db/report-dummy-data](./db/report-dummy-data) | MySQL의 `/tmp/report-dummy-data` | 보고서 더미 데이터, 읽기 전용                        |
| [docker/db/migration](./db/migration)          | Flyway의 `/flyway/sql`                | 버전별 스키마 마이그레이션                                |
| `database-data` 볼륨                           | MySQL의 `/var/lib/mysql`              | MySQL 데이터 영속 저장                                    |
| `qdrant-data` 볼륨                             | Qdrant의 `/qdrant/storage`            | 벡터 데이터 영속 저장                                     |
| `ai-model-cache`, `embedding-model-cache` 볼륨 | 각 서비스의 `/models/huggingface`     | 모델 캐시                                                 |

MySQL 초기화 스크립트는 데이터 디렉터리가 비어 있는 최초 실행에만 자동 실행됩니다. 기존 볼륨에서는 환경변수나 스크립트를 수정해도 초기화가 반복되지 않습니다.

Flyway는 `agent_kb` DB에 `kb_owner` 계정으로 접속하여 `V1__kb_init.sql`, `V2__eval.sql` 등을 적용합니다. 적용된 마이그레이션을 수정하기보다 새 버전 파일을 추가합니다.

기존 DB가 준비된 상태에서 마이그레이션을 다시 실행하려면:

```powershell
docker compose --env-file docker\.env -f docker\docker-compose.yml run --rm kb-migrator
```

일반적인 `down`은 named volume을 보존합니다. **`down -v`는 DB와 모델 캐시 등 Compose가 관리하는 named volume을 삭제하므로, 데이터 초기화가 목적이 아니라면 사용하지 않습니다.**

### Python AI 어댑터와 안전모델 파일

AI 이미지는 빌드 시 LoRA 어댑터를 `/models/adapters`, 비전 모델을
`/models/yolox`에 복사하고 음성 모델을 `/models/stt/whisper-small-ko`에
다운로드 및 변환합니다. 음성 모델 다운로드에는 빌드 환경의 인터넷 연결이
필요합니다. 모델 파일 변경 사항을 이미지에 반영하려면 다시 빌드해야 합니다.

`ai-model-cache`와 `embedding-model-cache`는 각 서비스의
`/models/huggingface`에 마운트되는 별도 캐시 볼륨입니다. 기존 볼륨은 이미지의
같은 경로를 가리며 이미지 재빌드만으로 기존 볼륨의 내용이 갱신되지는 않습니다.
AI 이미지의 어댑터, 비전 및 음성 모델 경로는 이 마운트 바깥에 있습니다.

## mysql-migration.Dockerfile — Kubernetes용 DB 마이그레이션 이미지

### 역할

`mysql-migration.Dockerfile`은 **Kubernetes Job에서 DB 스키마 마이그레이션을 실행하기 위한 Dockerfile**입니다. 로컬 디렉터리를 직접 마운트하는 대신 SQL을 이미지에 포함해 클러스터에 배포합니다.

Docker Compose의 `kb-migrator`는 이 Dockerfile을 사용하지 않습니다. Compose는 공식 Flyway 이미지에 호스트의 SQL 디렉터리를 마운트하는 기존 방식을 사용합니다.

| 설정                                                  | 의미                                               |
| ----------------------------------------------------- | -------------------------------------------------- |
| `FROM flyway/flyway:13.12-alpine`                     | Flyway 기반 이미지                                 |
| `USER 65003:65003`                                    | 이후 실행 시 사용할 UID/GID                        |
| `COPY --chown=65003:65003 db/migration/ /flyway/sql/` | SQL을 이미지에 복사하고 소유자 지정                |
| `CMD [...]`                                           | 기반 이미지의 Flyway ENTRYPOINT에 전달할 기본 인자 |

이미지 빌드 시에는 SQL을 복사할 뿐 DB에 접속하거나 마이그레이션을 실행하지 않습니다. 마이그레이션은 컨테이너 실행 시 수행됩니다.

### 빌드 컨텍스트와 빌드 명령

```powershell
docker build -f docker\mysql-migration.Dockerfile -t flyway-with-migrations:local .
```

- `-f`는 사용할 Dockerfile 위치입니다.
- 마지막 `.`은 현재 디렉터리, 즉 저장소 루트를 빌드 컨텍스트로 지정합니다.
- `COPY db/migration/`은 Dockerfile 위치가 아니라 빌드 컨텍스트를 기준으로 해석됩니다.
- Dockerfile과 SQL이 같은 디렉터리에 있을 필요는 없지만, SQL은 빌드 컨텍스트 안에 있어야 합니다.

`docker` 디렉터리를 컨텍스트로 사용하면 별도로 존재하는 `docker/db/migration`을 복사할 수 있어 루트의 SQL과 혼동될 수 있습니다. 위 빌드 명령은 저장소 루트의 `db/migration`을 사용하지만, Compose의 `kb-migrator`는 `docker/db/migration`을 마운트합니다. 두 디렉터리가 서로 다른 것을 확인하고 배포할 SQL을 선택하세요.

SQL을 변경한 경우 이미지를 다시 빌드해야 합니다.

### Kubernetes Job 실행 시 확인할 항목

현재 Dockerfile의 기본 접속 대상은 Kubernetes Service 이름인 `mysql-service:3306/agent_kb`이며, 사용자는 `kb_owner`입니다.

- Kubernetes에서는 해당 Service에 접근 가능한 네임스페이스/네트워크에서 실행하고, `FLYWAY_PASSWORD`를 Secret 등으로 주입해야 합니다.
- 로컬 Docker에서 단독 실행하면 Kubernetes의 Service 이름이 자동으로 해석되지는 않습니다.
- Job의 컨테이너 이미지에 빌드한 이미지를 지정하고, `/flyway/sql`에 별도 볼륨을 마운트하지 않아야 이미지에 포함된 SQL을 사용합니다. 해당 경로에 마운트하면 이미지의 SQL이 가려집니다.
- Kubernetes에서 Flyway 인자를 재정의할 때는 `args`를 사용합니다. `command`는 이미지의 ENTRYPOINT 자체를 대체합니다.
- 다른 클러스터/노드에서 실행하려면 이미지 레지스트리에 push하는 등 실행 환경에서 이미지를 가져올 수 있도록 준비해야 합니다.

DB와 계정은 마이그레이션 전에 준비되어 있어야 합니다. SQL을 이미지에 포함하는 것만으로 MySQL 초기화 스크립트나 영속 데이터까지 함께 제공되는 것은 아닙니다.