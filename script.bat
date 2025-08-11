:: --- Relaunch in cmd.exe exactly once ---
if "%~1"=="__in_cmd__" goto :SkipRelaunch
start "" "%ComSpec%" /k "%~f0" __in_cmd__
exit /b
:SkipRelaunch

@echo off
setlocal EnableExtensions EnableDelayedExpansion

REM =========================
REM =       Variables       =
REM =========================
set "URL=https://github.com/AroPix/TrackManiaAssets/releases/download/1.0.0/TmNationsForever_UVME_v3.1.exe"
set "FILE=TmNationsForever_UVME_v3.1.exe"
set "BUSYBOX=C:\busybox.exe"
set "SCRIPT=https://github.com/AroPix/TrackManiaAssets/raw/refs/heads/main/script.bat"

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
echo  4) Download Car Skin
echo  Q) Quit
echo.
set "opt="
set /p "opt=Select option (1/2/3/4/else to quit): "

if /i "%opt%"=="1" goto InstallUVME
if /i "%opt%"=="2" goto UninstallUVME
if /i "%opt%"=="3" goto UpdateScript
if /i "%opt%"=="4" goto DownloadCarSkin

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
echo Press anything after console looks empty!
"C:\Program Files (x86)\TmNationsForever\uvme\unins000.exe"
call :PauseReturn
goto MainMenu

REM =========================
REM =    Update Script     =
REM =========================
:UpdateScript
echo.
echo === Updating Script ===

REM --- Verify busybox/wget availability ---
if not exist "%BUSYBOX%" (
    echo ERROR: busybox not found at "%BUSYBOX%".
    call :PauseReturn
    goto MainMenu
)

REM Figure out names/paths
set "CURRENT_FULL=%~f0"
set "CURRENT_NAME=%~nx0"
set "TARGET=C:\%CURRENT_NAME%"
set "TEMPNEW=C:\%CURRENT_NAME%.new"

echo Downloading latest script to "%TEMPNEW%" ...
"%BUSYBOX%" wget --no-check-certificate -O "%TEMPNEW%" "%SCRIPT%"
if errorlevel 1 (
    echo Download failed.
    if exist "%TEMPNEW%" del "%TEMPNEW%" >nul 2>&1
    call :PauseReturn
    goto MainMenu
)

REM Basic sanity check (non-empty file)
for %%A in ("%TEMPNEW%") do set "NEWSIZE=%%~zA"
if not defined NEWSIZE set "NEWSIZE=0"
if %NEWSIZE% LSS 10 (
    echo Downloaded file looks too small (%NEWSIZE% bytes). Aborting.
    del "%TEMPNEW%" >nul 2>&1
    call :PauseReturn
    goto MainMenu
)

echo.
echo Applying update...

REM Always ensure C:\ has the updated copy
copy /y "%TEMPNEW%" "%TARGET%" >nul
if errorlevel 1 (
    echo WARNING: Could not write to "%TARGET%".
) else (
    echo Wrote updated script to "%TARGET%".
)

REM Try to overwrite the running script directly
copy /y "%TEMPNEW%" "%CURRENT_FULL%" >nul
if errorlevel 1 (
    echo The running script is locked; scheduling a deferred swap...
    REM Defer replacement after this process exits (short delay)
    set "SWAPCMD=ping -n 2 127.0.0.1 >nul ^&^& copy /y \"%TEMPNEW%\" \"%CURRENT_FULL%\" >nul ^&^& del \"%TEMPNEW%\""
    start "" cmd /c %SWAPCMD%
    echo Update will finalize after you close this window.
) else (
    echo Running script overwritten successfully.
    del "%TEMPNEW%" >nul 2>&1
)

call :PauseReturn
goto MainMenu


REM =========================
REM =   Download Car Skin   =
REM =========================
:DownloadCarSkin
echo.
echo === Download Car Skin ===

REM --- Verify busybox/wget availability ---
if not exist "%BUSYBOX%" (
    echo ERROR: busybox not found at "%BUSYBOX%".
    call :PauseReturn
    goto MainMenu
)

REM Target: C:\users\steamuser\Documents\TmForever\Skins\Vehicles\CarCommon
set "SKINS_BASE=C:\users\steamuser\Documents\TmForever\Skins"
if not exist "%SKINS_BASE%" mkdir "%SKINS_BASE%"
set "VEH_PARENT=%SKINS_BASE%\Vehicles"
if not exist "%VEH_PARENT%" mkdir "%VEH_PARENT%"
set "VEH_DIR=%VEH_PARENT%\CarCommon"
if not exist "%VEH_DIR%" mkdir "%VEH_DIR%"

REM Ask for a DIRECT download URL
set "DLURL="
set "TMPVBS=%TEMP%\ask_skin.vbs"
> "%TMPVBS%" echo Dim s : s = InputBox("Click on the copy link button on Maniapark for any skin:", "Download Car Skin", "")
>> "%TMPVBS%" echo If IsEmpty(s) Then s = ""
>> "%TMPVBS%" echo WScript.StdOut.Write s
for /f "usebackq delims=" %%A in (cscript //nologo "%TMPVBS%") do set "DLURL=%%A"
del "%TMPVBS%" >nul 2>&1

if not defined DLURL (
    echo No URL entered. Aborting.
    call :PauseReturn
    goto MainMenu
)

echo URL: %DLURL%

REM --- Derive filename from URL ---
set "FNAME=%DLURL%"
for /f "tokens=1* delims=?" %%a in ("%FNAME%") do (
    if "%%b" neq "" (set "FNAME=%%b") else (set "FNAME=%%a")
)

REM If still a path, take the last segment
set "TMPSEG=%FNAME%"
:__slashloop
for /f "tokens=1* delims=/" %%a in ("%TMPSEG%") do (
    if "%%b"=="" (set "FNAME=%%a") else (set "TMPSEG=%%b" & goto __slashloop)
)

REM Ensure .zip extension
if /i not "%FNAME:~-4%"==".zip" set "FNAME=%FNAME%.zip"

REM Final paths
set "OUTFILE=%VEH_DIR%\%FNAME%"
set "OUTTMP=%OUTFILE%.new"

echo.
echo Saving to: "%OUTFILE%"
echo Downloading...
"%BUSYBOX%" wget --no-check-certificate -O "%OUTTMP%" "%DLURL%"
if errorlevel 1 (
    echo Download failed. Check the URL and try again.
    if exist "%OUTTMP%" del "%OUTTMP%" >nul 2>&1
    call :PauseReturn
    goto MainMenu
)

REM Basic sanity check (non-empty file)
set "NEWSIZE="
for %%A in ("%OUTTMP%") do set "NEWSIZE=%%~zA"
if not defined NEWSIZE set "NEWSIZE=0"

if %NEWSIZE% LSS 10 (
    echo Downloaded file looks too small (%NEWSIZE% bytes). Aborting.
    del "%OUTTMP%" >nul 2>&1
    call :PauseReturn
    goto MainMenu
)

REM Move into place
move /y "%OUTTMP%" "%OUTFILE%" >nul
if errorlevel 1 (
    echo Could not finalize download.
) else (
    echo Done. Saved skin to: "%OUTFILE%"
    echo ^(ZIPs in CarCommon are picked up by TrackMania.^)
)

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
