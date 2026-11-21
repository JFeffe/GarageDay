@echo off
setlocal
pushd "%~dp0" || exit /b 1

set "GODOT_VERSIONED=Godot_v4.5.1-stable_win64.exe"
if defined GODOT_EXE if not exist "%GODOT_EXE%" set "GODOT_EXE="
if not defined GODOT_EXE if exist "tools\godot\%GODOT_VERSIONED%" set "GODOT_EXE=%CD%\tools\godot\%GODOT_VERSIONED%"
if not defined GODOT_EXE if exist "..\Jam House\tools\godot\%GODOT_VERSIONED%" set "GODOT_EXE=%CD%\..\Jam House\tools\godot\%GODOT_VERSIONED%"
if not defined GODOT_EXE for /f "delims=" %%G in ('where.exe godot.exe 2^>nul') do if not defined GODOT_EXE set "GODOT_EXE=%%G"
if not defined GODOT_EXE goto no_godot

if not exist ".godot\editor\filesystem_cache10" (
    echo Preparation de Garage Day pour le premier lancement...
    start "" /b /wait "%GODOT_EXE%" --headless --editor --import --path . --log-file "garage-day-import.log"
    if errorlevel 1 goto import_failed
)

start "" "%GODOT_EXE%" --path .
if errorlevel 1 goto launch_failed
popd
exit /b 0

:no_godot
echo Godot 4.5.1 est introuvable. Place %GODOT_VERSIONED% dans tools\godot.
goto failed

:import_failed
echo La preparation a echoue. Consulte garage-day-import.log dans le dossier du jeu.
goto failed

:launch_failed
echo Garage Day n'a pas pu demarrer.

:failed
pause
popd
exit /b 1
