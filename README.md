# Document Search Platform (`muni`)

Production-grade **agentic RAG** document search: FastAPI + LlamaIndex +
CrewAI agents, local **Ollama** models (`llama3.1` for generation,
`nomic-embed-text` for embeddings), **PostgreSQL/pgvector** storage, and
**Arize Phoenix** (OpenTelemetry) observability.

```
┌──────────┐   HTTP    ┌─────────────────── FastAPI (backend) ──────────────┐
│  Client  │ ────────► │ ingest │ query │ documents │ health               │
└──────────┘           │   │                                                │
                       │   ▼                                                │
                       │ DocumentLoader → Chunker → OllamaEmbed             │
                       │        │                │                          │
                       │        ▼                ▼                          │
                       │  MetadataStore ──► PGVectorStore (pgvector)        │
                       │                                                    │
                       │  Query: Retriever → [LLM rerank] → Prompt → LLM    │
                       │       (agentic: CrewAI researcher + synthesiser)   │
                       │                                                    │
                       │  Traces ──► Arize Phoenix (OTLP)                   │
                       └────────────────────────────────────────────────────┘
```

## Repository layout

| Path | Purpose |
|---|---|
| `backend/app/main.py` | FastAPI factory (CORS, request-id middleware, lifespan) |
| `backend/app/api/` | Routes (`health`, `documents`, `ingest`, `query`) + DI |
| `backend/app/core/config.py` | Typed pydantic-settings (12-factor) |
| `backend/app/core/ingestion/` | Loader (Docling), chunker, embedder, pgvector, pipeline |
| `backend/app/core/rag/` | Retriever, LLM factory, grounded answer engine |
| `backend/app/core/agents/` | CrewAI orchestrator (researcher + synthesiser) |
| `backend/app/core/tracing/` | OpenTelemetry → Arize Phoenix |
| `backend/app/prompts/` | Versioned prompt templates |
| `backend/tests/` | Pytest suite (24 tests, run without Ollama/Postgres) |
| `backend/evaluation/` | Ragas offline-eval harness + golden QA set |
| `backend/scripts/` | Sample-PDF generator, ingest CLI |
| `docker-compose.yml` | Postgres/pgvector + Ollama + backend + Phoenix |
| `.github/workflows/ci.yml` | Lint → test → Docker build |

## Quick start (Docker)

```bash
docker compose up -d --build          # Postgres, Ollama, Phoenix, API
# wait for ollama-init to pull models, then optionally:
docker compose exec backend python scripts/ingest.py /app/data/documents --recursive
```

- API docs: http://localhost:8000/docs
- Phoenix traces: http://localhost:6006

## Quick start (local, no Docker)

```bash
# 1. Python venv
cd backend
python -m venv .venv
.venv/Scripts/python -m pip install -r requirements-dev.txt   # Windows
# .venv/bin/python -m pip install -r requirements-dev.txt     # Linux/macOS

# 2. Lint + tests (no external services needed)
.venv/Scripts/python -m ruff check app tests
.venv/Scripts/python -m pytest tests -v

# 3. Full stack (needs Postgres/pgvector + Ollama running)
copy .env.example .env      # then edit as needed
.venv/Scripts/python -m uvicorn app.main:app --reload --port 8000
```

A `Makefile` wraps all of this: `make install`, `make test`, `make lint`,
`make run`, `make up`, `make ingest`.

## API

| Method | Path | Description |
|---|---|---|
| `GET` | `/api/v1/health`, `/health/live`, `/health/ready` | Dependency probes |
| `POST` | `/api/v1/ingest/upload` | Ingest an uploaded document (201) |
| `POST` | `/api/v1/ingest/directory` | Bulk-ingest the ingest directory |
| `GET` | `/api/v1/documents` | Paginated metadata listing |
| `GET`/`DELETE` | `/api/v1/documents/{id}` | Fetch / remove a document |
| `POST` | `/api/v1/query` | Ask a grounded question |

Query body: `{"question": "...", "mode": "auto|basic|agentic", "top_k": 6, "temperature": 0.1}`.
Responses always include `answer`, `sources` (with citations + scores),
`mode`, `model`, and `latency_ms`; errors use a uniform
`{"error": {"code", "detail"}}` envelope.

## Observability

Every span (LLM calls, embeddings, retrieval, crew steps) is exported via
OTLP to Phoenix — set `TRACING_ENABLED=false` to disable. The `X-Request-ID`
response header correlates logs with traces.

## Evaluation

```bash
cd backend
.venv/Scripts/python evaluation/run_evaluation.py
```

Runs the golden QA set through the pipeline and reports Ragas
faithfulness / answer-relevancy / context precision & recall (exits 1 below
`--threshold` — wire it into CI once the stack is reachable).

## CI

GitHub Actions: ruff → pytest → Docker image build → `docker compose config`
validation. See `.github/workflows/ci.yml`.
