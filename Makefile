PYTHON = backend/.venv/Scripts/python.exe
ifeq ($(OS), Windows_NT)
    PYTHON = backend/.venv/Scripts/python.exe
else
    PYTHON = backend/.venv/bin/python
endif

.PHONY: help venv install lint format test run ingest up down logs clean

help: ## Show available targets
	@grep -E '^[a-zA-Z_-]+:.*?## .*$$' $(MAKEFILE_LIST) | awk 'BEGIN {FS = ":.*?## "}; {printf "  %-12s %s\n", $$1, $$2}'

venv: ## Create the backend virtualenv
	python -m venv backend/.venv

install: ## Install dev dependencies into the venv
	$(PYTHON) -m pip install -r backend/requirements-dev.txt

lint: ## Run ruff checks
	cd backend && .venv/Scripts/python.exe -m ruff check app tests

format: ## Auto-fix lint issues
	cd backend && .venv/Scripts/python.exe -m ruff check app tests --fix

test: ## Run the pytest suite
	cd backend && .venv/Scripts/python.exe -m pytest tests -v

run: ## Start the API locally (uvicorn, auto-reload)
	cd backend && .venv/Scripts/python.exe -m uvicorn app.main:app --reload --port 8000

samples: ## Generate sample PDFs into data/documents
	cd backend && .venv/Scripts/python.exe scripts/generate_sample_pdfs.py

ingest: ## Bulk-ingest data/documents (requires docker compose up)
	cd backend && .venv/Scripts/python.exe scripts/ingest.py ../data/documents --recursive

up: ## Start the full stack (Postgres + Ollama + API + Phoenix)
	docker compose up -d --build

down: ## Stop the full stack
	docker compose down

logs: ## Tail backend logs
	docker compose logs -f backend

clean: ## Remove caches and logs
	cd backend && .venv/Scripts/python.exe -m ruff clean 2>/dev/null || true
	rm -f backend/pytest.log backend/ruff.log
