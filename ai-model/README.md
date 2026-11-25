# AI Model Service

> [!NOTE]
> Korean version: [ai-model.README.kr.md](../docs/localization/ai-model.README.kr.md)

This service provides FastAPI applications for the safety management platform:

- AI agent API
- Near-miss tagging
- Rule input extraction
- Vision and speech processing
- RAG embedding and knowledge ingestion
- Qdrant initialization

## Local Development

Python 3.12 is required.

```powershell
py -3.12 -m venv .venv
.\.venv\Scripts\Activate.ps1
python -m pip install -r requirements.dev.txt
python -m pytest
```

Create a local environment file from the example:

```powershell
Copy-Item .env.example .env
python -m uvicorn app.main:app --host 0.0.0.0 --port 60100
```

Never commit real credentials or model artifacts.

## Docker Targets

```powershell
docker build --target ai -t ai-model:ai .
docker build --target embedding -t ai-model:embedding .
docker build --target ingest -t ai-model:ingest .
docker build --target qdrant-init -t ai-model:qdrant-init .
```

## Key Directories

| Path | Purpose |
|---|---|
| `app/agent/`, `app/llm/` | Agent scenarios and language model integration |
| `app/api/` | FastAPI routes |
| `app/rag/`, `app/chunking/` | RAG, embeddings, and chunk processing |
| `app/ingest/` | Knowledge ingestion routes |
| `scripts/` | Model, vector, ingestion, and evaluation tools |
| `tests/` | Automated tests |
| `eval/` | Retrieval, tagging, and extraction evaluation data |

## Korean Documentation

- [AI Model Korean README](../docs/localization/ai-model.README.kr.md)
- [Evaluation Korean README](../docs/localization/ai-model-eval.README.kr.md)
