@echo off
title QueueNova — Start All Servers
cd /d "%~dp0"

echo =========================================================
echo  QueueNova — Starting all servers
echo =========================================================
echo.

REM ── 1. Check prerequisites ─────────────────────────────────
python --version >nul 2>&1
if errorlevel 1 (
    echo ERROR: Python not found. Install Python 3.9+ and add it to PATH.
    pause & exit /b 1
)
node --version >nul 2>&1
if errorlevel 1 (
    echo ERROR: Node.js not found. Install Node.js 18+ from https://nodejs.org
    pause & exit /b 1
)

REM ── 2. ML server in a separate window ──────────────────────
echo [1/2] Starting ML Inference Server (port 5001)...
start "QueueNova ML Server" cmd /k "cd /d %~dp0ml && pip install -r requirements.txt -q && python inference.py"

REM Give Flask a moment to load before Node tries to connect
timeout /t 3 /nobreak >nul

REM ── 3. Node.js backend in a separate window ─────────────────
echo [2/2] Starting Node.js Backend (port 3000)...
start "QueueNova Backend" cmd /k "cd /d %~dp0 && npm install -q && npm start"

echo.
echo Both servers are starting in their own windows.
echo   ML server  → http://localhost:5001/health
echo   Backend    → http://localhost:3000/api/web/system/health
echo.
echo Close those windows to stop the servers.
pause
