@echo off
title QueueNova Web Dashboard (staff/admin)
cd /d "%~dp0"

echo Starting the QueueNova staff/admin web dashboard (port 8081).
echo.
echo Once it says "Web development server available", open this URL
echo in your browser:
echo.
echo     http://localhost:8081
echo.
echo Reuse the same browser tab across restarts so your staff login
echo session persists instead of resetting each time.
echo.
echo Make sure the backend is running too (run_backend via
echo lib\web\backend_server\start_backend.bat), otherwise login/data
echo requests will fail.
echo.

flutter run -d web-server -t lib/web/web_main.dart --web-port=8081
pause
