#!/bin/bash
set -euo pipefail

PREFIX="/home/florian/Games/trackmania-united-forever"
EXE_REL="C:\\Program Files (x86)\\TmUnitedForever\\TmForever.exe"
WRAPPER="$HOME/bin/tmforever-open.sh"
DESKTOP="$HOME/.local/share/applications/trackmania-gbx.desktop"
MIME_XML="$HOME/.local/share/mime/packages/x-gbx.xml"

echo "=== TrackMania .gbx file association setup ==="
echo

# Sanity checks
if [ ! -d "$PREFIX/drive_c" ]; then
    echo "Error: wine prefix not found at $PREFIX" >&2
    exit 1
fi
if ! command -v wine >/dev/null; then
    echo "Error: 'wine' not found in PATH" >&2
    exit 1
fi
if ! command -v winepath >/dev/null; then
    echo "Error: 'winepath' not found in PATH" >&2
    exit 1
fi

# 1. Wrapper script
mkdir -p "$(dirname "$WRAPPER")"
cat > "$WRAPPER" << EOF
#!/bin/bash
export WINEPREFIX="$PREFIX"
exec wine "$EXE_REL" /useexedir /singleinst /file="\$(winepath -w "\$1")" "\$@"
EOF
chmod +x "$WRAPPER"
echo "[1/4] Wrapper script created -> $WRAPPER"

# 2. .desktop entry
mkdir -p "$(dirname "$DESKTOP")"
cat > "$DESKTOP" << EOF
[Desktop Entry]
Type=Application
Name=TrackMania Forever
Exec=$WRAPPER %f
Icon=$PREFIX/drive_c/Program Files (x86)/TmUnitedForever/Gbx.ico
MimeType=application/x-gbx;
Terminal=false
NoDisplay=true
EOF
echo "[2/4] Desktop entry created -> $DESKTOP"

# 3. MIME type definition
mkdir -p "$(dirname "$MIME_XML")"
cat > "$MIME_XML" << 'EOF'
<?xml version="1.0"?>
<mime-info xmlns="http://www.freedesktop.org/standards/shared-mime-info">
  <mime-type type="application/x-gbx">
    <comment>TrackMania file</comment>
    <glob pattern="*.gbx"/>
  </mime-type>
</mime-info>
EOF
echo "[3/4] MIME type registered -> $MIME_XML"

# 4. Update databases
if command -v update-mime-database >/dev/null; then
    update-mime-database "$HOME/.local/share/mime" >/dev/null
fi
if command -v update-desktop-database >/dev/null; then
    update-desktop-database "$HOME/.local/share/applications" >/dev/null
fi
echo "[4/4] Databases updated"
echo

# Ask whether to set as default
read -r -p "Associate .gbx files with TrackMania Forever as the default app? [y/N] " ans
case "$ans" in
    [yY]|[yY][eE][sS])
        xdg-mime default "$(basename "$DESKTOP")" application/x-gbx
        echo "Done. .gbx files will now open in TrackMania."
        echo "Verify with: xdg-mime query default application/x-gbx"
        ;;
    *)
        echo "Skipped. The wrapper/desktop entry are installed but not set as default."
        echo "To set it later: xdg-mime default $(basename "$DESKTOP") application/x-gbx"
        ;;
esac