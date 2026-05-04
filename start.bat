@echo off
title espotifai
color 0A

echo.
echo  ==========================================
echo   espotifai - Iniciando servidor...
echo  ==========================================
echo.

cd /d "%~dp0server"

if not exist "node_modules" (
    echo  [!] Instalando dependencias...
    npm install
    echo.
)

if not exist ".env" (
    echo  [!] Creando .env desde .env.example...
    copy .env.example .env >nul
    echo  [!] IMPORTANTE: Edita server\.env y agrega tu YOUTUBE_API_KEY
    echo.
    pause
)

echo  [*] Servidor corriendo en http://localhost:3000
echo  [*] Presiona Ctrl+C para detener
echo.

start "" http://localhost:3000
npm run dev
