@echo off
title QueueNova ML Server (port 5001)
cd /d "%~dp0"

echo Checking Python...
python --version >nul 2>&1
if errorlevel 1 (
    echo ERROR: Python not found. Install Python 3.9+ and add it to PATH.
    pause
    exit /b 1
)

echo Installing / checking dependencies...
pip install -r requirements.txt -q

echo.
echo Starting QueueNova ML Inference Server on http://localhost:5001
echo Press Ctrl+C to stop.
echo.
python inference.py
pause
