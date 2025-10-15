@echo off
echo.
echo ========================================
echo   GitHub Webhook Auto-Setup
echo ========================================
echo.

echo 🔑 You need a GitHub Personal Access Token
echo.
echo 📝 Quick Setup:
echo 1. Go to: https://github.com/settings/tokens
echo 2. Click "Generate new token (classic)"
echo 3. Select "repo" scope
echo 4. Copy the token
echo.

set /p token="Enter your GitHub token: "

if "%token%"=="" (
    echo ❌ No token provided. Exiting...
    pause
    exit /b 1
)

echo.
echo 🚀 Setting up webhook...
echo.

powershell -ExecutionPolicy Bypass -File "setup-github-webhook-automatic.ps1" -GitHubToken "%token%"

echo.
echo 📋 Setup completed!
echo.
pause