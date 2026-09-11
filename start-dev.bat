@echo off
title Document Search Platform (muni)
cd /d "%~dp0backend"

if not exist .venv\Scripts\python.exe (
    echo [ERROR] Virtualenv not found.
    echo Run these first in a terminal:
    echo   cd backend
    echo   python -m venv .venv
    echo   .venv\Scripts\python -m pip install -r requirements-dev.txt
    pause
    exit /b 1
)

echo ============================================================
echo  Document Search Platform  -  starting API server
echo  Interactive UI : http://127.0.0.1:8000/docs
echo  Health check   : http://127.0.0.1:8000/api/v1/health
echo  Press Ctrl+C to stop the server.
echo ============================================================
echo.

start "" "http://127.0.0.1:8000/docs"
.venv\Scripts\python.exe -m uvicorn app.main:app --host 127.0.0.1 --port 8000

echo.
echo Server stopped.
pause
