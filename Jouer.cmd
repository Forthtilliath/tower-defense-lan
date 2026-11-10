@echo off
rem Double-clic : lance le jeu. En ligne de commande : Jouer.cmd -Joueurs 2 (ou -Editeur).
rem PowerShell 7 de preference (accents du script bien lus), sinon Windows PowerShell.
where pwsh >nul 2>nul
if %errorlevel%==0 (
    pwsh -NoProfile -ExecutionPolicy Bypass -File "%~dp0tools\play.ps1" %*
) else (
    powershell -NoProfile -ExecutionPolicy Bypass -File "%~dp0tools\play.ps1" %*
)
