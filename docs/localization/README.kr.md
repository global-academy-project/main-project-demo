# Main Project

> [!NOTE]
> 영문으로 작성된 README는 [main-project-demo](../../README.md)에서 확인하실 수 있습니다.

현장 안전관리 서비스를 구성하는 전체 저장소를 소개하는 상위 프로젝트 문서입니다.
이 **현장 안전관리 서비스**는 현장 작업자·관리자가 안전 사고를 기록·검토·조치할 수
있도록 돕는 플랫폼으로, 아차사고 탐지·문서 검색·이미지 인식·음성 입력에 AI를
활용합니다.

이 서비스는 React 웹, Spring Boot API, Python AI 서비스, 그리고 이들을 연결하는
인프라 저장소로 구성됩니다. 각 저장소는 독립적으로 개발·배포되며, 로컬 통합과
Kubernetes 배포는 인프라 저장소에서 함께 관리합니다.

## 핵심 기능

- **안전 운영** — 사용자·권한 관리, 안전·작업 기록, 승인 워크플로, 알림, 감사
  리포트 (Spring Boot API).
- **AI 지원** — 로컬 LLM(Qwen 계열) 기반의 AI 에이전트, 아차사고 태깅, 안전 규칙
  추출.
- **비전·음성** — 현장 사진 분석(YOLOX-Nano)과 음성 인식(Whisper)으로 손이 자유로운
  현장 보고 지원.
- **지식 검색 (RAG)** — 문서 적재·임베딩(BGE-M3)과 Qdrant 기반 벡터 검색.
- **통합 운영** — Docker Compose 원커맨드 로컬 실행, Kubernetes/Kustomize 배포,
  Prometheus·Grafana 모니터링.

## 아키텍처 개요

![시스템 아키텍처](../images/system-architecture.kr.png)

```text
[ vite-web ]  ──/api──▶  [ spring-server ]  ──▶  [ ai-model ]
     React 웹                  Spring Boot API         FastAPI AI/RAG
                                     │                       │
                                     ▼                       ▼
                                  MySQL                Qdrant · 임베딩
                                     └──────────┬──────────┘
                                        [ infra-manage ]
                               Docker Compose · Kubernetes · DB · 모니터링
```

- 웹 애플리케이션은 `/api` 요청을 Spring Boot 서버로 전달합니다.
- Spring Boot 서버는 사용자/권한, 안전 기록, 결재, 알림, 감사 보고서 API를 제공하며
  AI 기능이 필요할 때 AI 서비스를 호출합니다.
- AI 서비스는 에이전트, 아차사고 태깅, 규칙 추출, 사진 인식, 음성 전사 기능과
  RAG 검색(임베딩 + Qdrant)을 제공합니다.
- 인프라 저장소는 네 서비스를 로컬 Compose와 Kubernetes로 연결하고, 데이터베이스
  초기화·마이그레이션과 모니터링 구성을 관리합니다.

## 저장소 구성

| 저장소 | 역할 | 기술 스택 |
|---|---|---|
| [vite-web](../../vite-web) | 현장 안전관리 React 웹 애플리케이션 | React 19, React Router 7, Vite 8, Node.js 24 |
| [spring-server](../../spring-server) | 현장 안전관리 API 서버 | Java 17, Spring Boot 4, MySQL, Flyway, JWT |
| [ai-model](../../ai-model) | AI·임베딩·지식 적재 서비스 | Python 3.12, FastAPI, BGE-M3, Qdrant |
| [infra-manage](../../infra-manage) | 통합 실행 및 배포 인프라 | Docker Compose, Kubernetes, MySQL, Grafana |

## 서비스와 포트

| 구성 | 로컬 개발 포트 | Docker 포트 | 비고 |
|---|---|---|---|
| 웹 (Vite) | 50001 | 50001 | `/api` 요청을 서버로 프록시 |
| API 서버 (Spring Boot) | 8080 | 60001 | Swagger UI `/swagger-ui/index.html` |
| AI API | 60100 | 60100 | 상태 확인 `/health` |
| 임베딩 API | 60110 | 60110 | 상태 확인 `/ready` |
| 지식 적재 API | 8001 | 8001 | 상태 확인 `/ready` |
| Qdrant 초기화 | — | 일회성 | 컬렉션·인덱스 초기화 |

## 빠른 시작

가장 간단한 통합 실행은 인프라 저장소의 Docker Compose를 사용하는 방식입니다.
네 저장소가 같은 상위 디렉터리에 있어야 합니다.

```text
main-project-demo/
├── vite-web/
├── spring-server/
├── ai-model/
└── infra-manage/
```

`infra-manage/docker/.env`를 만들고 필요한 변수와 비밀 값을 입력한 뒤,
인프라 프로젝트 루트에서 Compose를 실행합니다.

```powershell
docker compose --env-file .\docker\.env -f .\docker\docker-compose.yml up -d --build
```

필수 환경 변수, 컨테이너 간 연결 주소, 초기화 작업은
[infra-manage의 Docker 실행 가이드](../../infra-manage/docker/README.md)를
참고하세요.

## 배포·운영

`infra-manage` 저장소는 애플리케이션·데이터 계층을 Docker Compose와
Kubernetes/Kustomize로 배포하며, API 서버와 AI 컴포넌트의 메트릭·헬스체크를
Prometheus와 Grafana로 수집합니다.

### 배포·모니터링 개요

![배포·운영 구성](../images/deploy-monitoring.kr.png)

### Docker Compose 구성

![컨테이너 플랫폼 · Docker Compose](../images/docker-compose.kr.png)

### Kubernetes 구성

![컨테이너 플랫폼 · Kubernetes](../images/kubernetes.kr.png)

## 저장소별 개발 안내

각 저장소를 개별적으로 개발·테스트하려면 해당 저장소의 README를 참고하세요.

- 웹: [vite-web/README.md](../../vite-web/README.md) — `npm ci` 후 `npm run dev`
- 서버: [spring-server/README.md](../../spring-server/README.md) — `\.\gradlew.bat bootRun`
- AI: [ai-model/README.md](../../ai-model/README.md) — `.venv` 생성 후 `uvicorn`
- 인프라: [infra-manage/README.md](../../infra-manage/README.md) — Compose·Kubernetes

## 협업 인원

| 이름 | 역할 | GitHub |
|---|---|---|
| GEONWOO CHOI | 메인테이너 | [@geonwoo8873](https://github.com/geonwoo8873) |
| Mingi Choi | 기여자 | [@GreyColor10](https://github.com/GreyColor10) |
| tmdwls1226 | 기여자 | [@tmdwls1226](https://github.com/tmdwls1226) |
| 김영민 | 기여자 | [@kymin9118](https://github.com/kymin9118) |

## 주의 사항

- 비밀번호, JWT 키, 내부 API 토큰, 메일·외부 서비스 자격 증명은 로컬 환경 변수나
  `.env`로 관리하고 저장소에 커밋하지 마세요.
- `.env.example` 등 예시 값은 그대로 실행 가능한 자격 증명이 아닙니다.
- Kubernetes 매니페스트의 Secret에는 실제 운영 비밀 값을 두지 말고, 클러스터의
  Secret 관리 방식을 정한 뒤 적용하세요.
