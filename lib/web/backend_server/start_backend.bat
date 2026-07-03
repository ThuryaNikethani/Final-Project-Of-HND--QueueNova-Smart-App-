@echo off
title QueueNova Backend (port 3000)
cd /d "%~dp0"

echo Checking Node.js...
node --version >nul 2>&1
if errorlevel 1 (
    echo ERROR: Node.js not found. Install Node.js 18+ from https://nodejs.org
    pause
    exit /b 1
)

echo Installing / checking dependencies...
npm install -q

echo.
echo Starting QueueNova Backend on http://localhost:3000
echo Press Ctrl+C to stop.
echo.
npm start
pause
