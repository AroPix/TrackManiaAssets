@echo off
setlocal EnableExtensions EnableDelayedExpansion

REM =========================
REM =       Variables       =
REM =========================
set "URL=https://github.com/AroPix/TrackManiaAssets/releases/download/1.0.0/TmNationsForever_UVME_v3.1.exe"
set "FILE=TmNationsForever_UVME_v3.1.exe"
set "BUSYBOX=C:\busybox.exe"

REM =========================
REM =       UI Loop         =
REM =========================
:MainMenu
cls
echo =========================================
echo   AroPix's TrackMania Script (Lutris)
echo =========================================
echo  1) Install UVME
echo  2) Uninstall UVME
echo  3) Update Script
echo  Q) Quit
echo.
set "opt="
set /p "opt=Select option (1/2/3/else to quit): "

if /i "%opt%"=="1" goto InstallUVME
if /i "%opt%"=="2" goto UninstallUVME
if /i "%opt%"=="3" goto UpdateScript

goto Quit

echo.
echo Invalid selection: "%opt%"
call :PauseReturn
goto MainMenu

REM =========================
REM =     Install UVME      =
REM =========================
:InstallUVME
echo.
echo === Installing UVME ===

REM --- Verify busybox/wget availability ---
if not exist "%BUSYBOX%" (
    echo ERROR: busybox not found at "%BUSYBOX%".
    echo Update the BUSYBOX path at the top of this script.
    call :PauseReturn
    goto MainMenu
)

REM --- Download ---
echo Downloading %URL% ...
"%BUSYBOX%" wget --no-check-certificate -O "%FILE%" "%URL%"
if errorlevel 1 (
    echo Download failed.
    call :PauseReturn
    goto MainMenu
)

REM --- Run the UVME Installer ---
echo Running "%FILE%" ...
start /wait "" "%FILE%"
if errorlevel 1 (
    echo The installer returned errorlevel %errorlevel%.
) else (
    echo Installer finished.
)

REM --- Delete the file ---
if exist "%FILE%" (
    echo Deleting "%FILE%" ...
    del "%FILE%" >nul 2>&1
    if exist "%FILE%" (
        echo WARNING: Could not delete "%FILE%". Close any processes using it.
    ) else (
        echo File removed.
    )
) else (
    echo Nothing to delete.
)

call :PauseReturn
goto MainMenu

REM =========================
REM =    Uninstall UVME     =
REM =========================
:UninstallUVME
echo.
echo === Uninstalling UVME ===
echo WIP!
call :PauseReturn
goto MainMenu

REM =========================
REM =    Update Script     =
REM =========================
:UpdateScript
echo.
echo === Updating Script ===
echo WIP!
call :PauseReturn
goto MainMenu

REM =========================
REM =   Helper Routines     =
REM =========================
:PauseReturn
echo.
echo Press Enter to continue...
set "tmp="
set /p tmp=
exit /b

:Quit
echo.
endlocal
exit /b 0
