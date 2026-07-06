@echo off
title QueueNova (persistent web session)
cd /d "%~dp0"

echo Starting QueueNova as a plain web server (port 8080).
echo.
echo Once it says "Web development server available", open this URL
echo in your NORMAL Chrome/Edge window (not a new one Flutter opens for
echo you - it doesn't open one in this mode):
echo.
echo     http://localhost:8080
echo.
echo Keep using that same browser tab across restarts. Because it's your
echo everyday browser profile instead of a throwaway one, your login,
echo personal details, and profile photo will persist normally.
echo.

flutter run -d web-server --web-port=8080
pause
