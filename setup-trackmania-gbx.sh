#!/bin/bash
set -euo pipefail

# ─────────────────────────────────────────────────────────────────────────────
# TrackMania .gbx file association setup
#
# Reads a Lutris game YAML to discover:
#   - the wine prefix
#   - the game executable
#   - the runner version (Proton vs Wine)
#   - system env vars and DLL overrides
#
# Then generates a wrapper script + .desktop entry that opens .gbx files
# through the correct runner:
#   - Proton  → umu-run  (with PROTONPATH + WINEPREFIX)
#   - Wine    → the configured wine binary (with WINEPREFIX)
#
# Usage:
#   ./setup-trackmania-gbx.sh [path/to/trackmania-*.yml]
#
# If no YAML path is given, auto-detects the first TrackMania game YAML.
# ─────────────────────────────────────────────────────────────────────────────

LUTRIS_GAMES_DIR="$HOME/.local/share/lutris/games"
WRAPPER_DIR="$HOME/bin"
DESKTOP_DIR="$HOME/.local/share/applications"
MIME_DIR="$HOME/.local/share/mime/packages"

# ─── Helpers ─────────────────────────────────────────────────────────────────

die() { echo "Error: $*" >&2; exit 1; }

# Yaml parsing via python3 (PyYAML). Falls back to a minimal grep-based parser
# if PyYAML is not installed.
parse_yaml() {
    local yml="$1"
    python3 - "$yml" <<'PYEOF'
import sys, json
try:
    import yaml
    with open(sys.argv[1]) as f:
        data = yaml.safe_load(f)
except ImportError:
    print("NOPYYAML")
    sys.exit(0)
except Exception as e:
    print(f"ERROR: {e}", file=sys.stderr)
    sys.exit(1)

game = data.get("game", {})
wine = data.get("wine", {})
system = data.get("system", {})

out = {
    "name": data.get("name", "TrackMania"),
    "prefix": game.get("prefix", ""),
    "exe": game.get("exe", ""),
    "wine_version": wine.get("version", "system"),
    "overrides": wine.get("overrides", {}),
    "show_debug": wine.get("show_debug", ""),
    "env": system.get("env", {}),
    "mangohud": system.get("mangohud", False),
}
print(json.dumps(out))
PYEOF
}

# Fallback YAML parser (grep-based) for when PyYAML is unavailable.
# Only extracts the fields we care about.
parse_yaml_fallback() {
    local yml="$1"
    # Extract prefix, exe, wine.version using sed/awk
    local prefix exe wine_ver
    prefix=$(sed -n '/^game:/,/^[a-z]/p' "$yml" | grep -m1 '^\s*prefix:' | sed 's/.*prefix:\s*//' | tr -d "'\"")
    exe=$(sed -n '/^game:/,/^[a-z]/p' "$yml" | grep -m1 '^\s*exe:' | sed 's/.*exe:\s*//' | tr -d "'\"")
    wine_ver=$(sed -n '/^wine:/,/^[a-z]/p' "$yml" | grep -m1 '^\s*version:' | sed 's/.*version:\s*//' | tr -d "'\"")
    [ -z "$prefix" ] && die "Could not parse prefix from $yml"
    [ -z "$exe" ] && die "Could not parse exe from $yml"
    [ -z "$wine_ver" ] && wine_ver="system"
    echo "{\"name\":\"TrackMania\",\"prefix\":\"$prefix\",\"exe\":\"$exe\",\"wine_version\":\"$wine_ver\",\"overrides\":{},\"show_debug\":\"\",\"env\":{},\"mangohud\":false}"
}

# ─── Detect the Lutris YAML ──────────────────────────────────────────────────

YML_PATH="${1:-}"
if [ -z "$YML_PATH" ]; then
    # Auto-detect: find the newest trackmania game YAML
    YML_PATH=$(ls -t "$LUTRIS_GAMES_DIR"/trackmania-*.yml 2>/dev/null | head -1)
    [ -z "$YML_PATH" ] && die "No TrackMania game YAML found in $LUTRIS_GAMES_DIR"
fi
[ -f "$YML_PATH" ] || die "YAML not found: $YML_PATH"

echo "=== TrackMania .gbx file association setup ==="
echo "  Lutris YAML: $YML_PATH"
echo

# ─── Parse the YAML ──────────────────────────────────────────────────────────

RAW=$(parse_yaml "$YML_PATH")
if [ "$RAW" = "NOPYYAML" ]; then
    echo "  (PyYAML not available, using fallback parser)"
    RAW=$(parse_yaml_fallback "$YML_PATH")
fi

# Extract fields with python json parsing (avoids jq dependency)
PREFIX=$(echo "$RAW" | python3 -c "import sys,json; print(json.load(sys.stdin)['prefix'])")
EXE_LINUX=$(echo "$RAW" | python3 -c "import sys,json; print(json.load(sys.stdin)['exe'])")
WINE_VERSION=$(echo "$RAW" | python3 -c "import sys,json; print(json.load(sys.stdin)['wine_version'])")
GAME_NAME=$(echo "$RAW" | python3 -c "import sys,json; print(json.load(sys.stdin)['name'])")
OVERRIDES=$(echo "$RAW" | python3 -c "import sys,json; d=json.load(sys.stdin)['overrides']; print(','.join(f'{k}={v}' for k,v in d.items())) if d else print('')")
SHOW_DEBUG=$(echo "$RAW" | python3 -c "import sys,json; print(json.load(sys.stdin)['show_debug'])")
ENV_JSON=$(echo "$RAW" | python3 -c "import sys,json; print(json.dumps(json.load(sys.stdin)['env']))")
MANGOHUD=$(echo "$RAW" | python3 -c "import sys,json; print(json.load(sys.stdin)['mangohud'])")

# Convert exe to a Windows path (C:\... not Z:\...)
# The exe is already a Linux path like /home/.../drive_c/Program Files (x86)/TmUnitedForever/TmForever.exe
# Convert to C:\Program Files (x86)\TmUnitedForever\TmForever.exe
exe_to_windows() {
    local linux_path="$1"
    local prefix="$2"
    local drive_c="$prefix/drive_c"
    # Strip the drive_c prefix and build a Windows path
    local rel="${linux_path#$drive_c/}"
    if [ "$rel" = "$linux_path" ]; then
        # Not under drive_c, use Z: mapping
        echo "Z:$(echo "$linux_path" | sed 's|/|\\|g')"
    else
        echo "C:\\$(echo "$rel" | sed 's|/|\\|g')"
    fi
}

EXE_WIN=$(exe_to_windows "$EXE_LINUX" "$PREFIX")

echo "  Game:         $GAME_NAME"
echo "  Prefix:        $PREFIX"
echo "  Executable:    $EXE_WIN"
echo "  Runner:        $WINE_VERSION"
echo "  DLL overrides: ${OVERRIDES:-(none)}"
[ -n "$SHOW_DEBUG" ] && echo "  Wine debug:    $SHOW_DEBUG"
echo

# ─── Validate ────────────────────────────────────────────────────────────────

[ -d "$PREFIX/drive_c" ] || die "Wine prefix not found at $PREFIX"
[ -f "$EXE_LINUX" ] || die "Executable not found: $EXE_LINUX"

# ─── Detect Proton vs Wine and resolve runner paths ──────────────────────────
#
# Lutris wine.version can be:
#   "system"                    → use /usr/bin/wine (system wine)
#   "wine-ge-8-26-x86_64"       → Lutris wine runner: ~/.local/share/lutris/runners/wine/<version>/bin/wine
#   "wine-staging-11.2-x86_64"  → same as above
#   "proton-cachyos-native"     → Proton installed in /usr/share/steam/compatibilitytools.d/<version>/
#   "ge-proton"                 → Lutris proton runner: ~/.local/share/lutris/runners/wine/ge-proton/
#   "GE-Proton10-32"            → Steam compatibilitytools.d: ~/.local/share/Steam/compatibilitytools.d/<version>/
#
# Proton detection: version string contains "proton" (case-insensitive)

LUTRIS_WINE_RUNNERS="$HOME/.local/share/lutris/runners/wine"
STEAM_COMPATTOOLS="$HOME/.local/share/Steam/compatibilitytools.d"
SYSTEM_COMPATTOOLS="/usr/share/steam/compatibilitytools.d"

is_proton=false
PROTONPATH=""
WINE_BIN=""
WINEPATH_BIN=""

resolve_runner() {
    local ver="$1"
    local lower=$(echo "$ver" | tr '[:upper:]' '[:lower:]')

    if [[ "$lower" == "system" ]]; then
        # System wine
        is_proton=false
        WINE_BIN=$(command -v wine || true)
        WINEPATH_BIN=$(command -v winepath || echo "$WINE_BIN")
        [ -z "$WINE_BIN" ] && die "System wine not found"
        echo "  → System wine: $WINE_BIN"
        return
    fi

    if [[ "$lower" == proton* ]]; then
        # Proton variant — could be in system compattools or lutris runners
        is_proton=true
        # Try system-wide: /usr/share/steam/compatibilitytools.d/<ver>/
        if [ -d "$SYSTEM_COMPATTOOLS/$ver" ]; then
            PROTONPATH="$SYSTEM_COMPATTOOLS/$ver"
        # Try Steam compatibilitytools.d: ~/.local/share/Steam/compatibilitytools.d/<ver>/
        elif [ -d "$STEAM_COMPATTOOLS/$ver" ]; then
            PROTONPATH="$STEAM_COMPATTOOLS/$ver"
        # Try Lutris wine runner ge-proton: ~/.local/share/lutris/runners/wine/ge-proton/
        elif [ -d "$LUTRIS_WINE_RUNNERS/ge-proton" ]; then
            PROTONPATH="$LUTRIS_WINE_RUNNERS/ge-proton"
        else
            die "Proton version '$ver' not found in known locations"
        fi
        # Proton's wine binary lives in files/bin/wine
        WINE_BIN="$PROTONPATH/files/bin/wine"
        [ -f "$WINE_BIN" ] || WINE_BIN="$PROTONPATH/files/bin/wine64"
        echo "  → Proton: $PROTONPATH"
        return
    fi

    if [[ "$lower" == ge-proton* ]]; then
        # Lutris "ge-proton" runner
        is_proton=true
        if [ -d "$LUTRIS_WINE_RUNNERS/ge-proton" ]; then
            PROTONPATH="$LUTRIS_WINE_RUNNERS/ge-proton"
        else
            die "Lutris ge-proton runner not found"
        fi
        WINE_BIN="$PROTONPATH/files/bin/wine"
        [ -f "$WINE_BIN" ] || WINE_BIN="$PROTONPATH/files/bin/wine64"
        echo "  → Proton (Lutris ge-proton): $PROTONPATH"
        return
    fi

    # Check for GE-Proton in Steam compattools.d (version name like "GE-Proton10-32")
    if [[ "$ver" == GE-Proton* ]] && [ -d "$STEAM_COMPATTOOLS/$ver" ]; then
        is_proton=true
        PROTONPATH="$STEAM_COMPATTOOLS/$ver"
        WINE_BIN="$PROTONPATH/files/bin/wine"
        [ -f "$WINE_BIN" ] || WINE_BIN="$PROTONPATH/files/bin/wine64"
        echo "  → Proton (Steam compattools): $PROTONPATH"
        return
    fi

    # Otherwise it's a Lutris wine runner like wine-ge-8-26-x86_64
    is_proton=false
    if [ -d "$LUTRIS_WINE_RUNNERS/$ver" ]; then
        WINE_BIN="$LUTRIS_WINE_RUNNERS/$ver/bin/wine"
        WINEPATH_BIN="$LUTRIS_WINE_RUNNERS/$ver/bin/winepath"
    else
        die "Wine runner '$ver' not found in $LUTRIS_WINE_RUNNERS"
    fi
    [ -f "$WINE_BIN" ] || die "Wine binary not found: $WINE_BIN"
    echo "  → Wine runner: $WINE_BIN"
}

resolve_runner "$WINE_VERSION"

# Verify winepath availability (for converting .gbx file paths)
if [ "$is_proton" = true ]; then
    # Proton: winepath is inside files/lib/wine/*/winepath.exe (Windows-side)
    # We can use the Proton wine binary to invoke it, or use a manual path conversion
    # umu-run handles this via the proton script, so we let umu do the conversion
    WINEPATH_BIN=""
else
    if [ -z "$WINEPATH_BIN" ] || [ ! -f "$WINEPATH_BIN" ]; then
        WINEPATH_BIN="$WINE_BIN"
    fi
fi

# Check umu-run for Proton
if [ "$is_proton" = true ]; then
    command -v umu-run >/dev/null || die "umu-run not found. Install 'umu-launcher' for Proton support."
fi

echo

# ─── Generate the wrapper script ─────────────────────────────────────────────

WRAPPER_NAME="tmforever-open.sh"
WRAPPER="$WRAPPER_DIR/$WRAPPER_NAME"

mkdir -p "$WRAPPER_DIR"

# Build the env var exports from system.env
ENV_EXPORTS=""
if [ -n "$ENV_JSON" ] && [ "$ENV_JSON" != "{}" ]; then
    ENV_EXPORTS=$(echo "$ENV_JSON" | python3 -c "
import sys, json
env = json.load(sys.stdin)
for k, v in env.items():
    print(f'export {k}={repr(v)}')
")
fi

# Build WINEDLLOVERRIDES
DLL_OVERRIDE_EXPORT=""
if [ -n "$OVERRIDES" ]; then
    # Convert "dinput8=n,b" to WINEDLLOVERRIDES format "dinput8=n,b"
    DLL_OVERRIDE_EXPORT="export WINEDLLOVERRIDES=\"$OVERRIDES\""
fi

# Build WINEDEBUG
WINEDEBUG_EXPORT=""
if [ -n "$SHOW_DEBUG" ]; then
    WINEDEBUG_EXPORT="export WINEDEBUG=\"$SHOW_DEBUG\""
fi

# MangoHud
MANGOHUD_EXPORT=""
if [ "$MANGOHUD" = "True" ]; then
    MANGOHUD_EXPORT="export MANGOHUD=1"
fi

cat > "$WRAPPER" << EOF
#!/bin/bash
# Auto-generated by setup-trackmania-gbx.sh
# Opens .gbx files in $GAME_NAME via Lutris config
# Runner: $WINE_VERSION

export WINEPREFIX="$PREFIX"
$ENV_EXPORTS
$DLL_OVERRIDE_EXPORT
$WINEDEBUG_EXPORT
$MANGOHUD_EXPORT

EOF

if [ "$is_proton" = true ]; then
    # Proton path: use umu-run with PROTONPATH
    cat >> "$WRAPPER" << 'EOF'
# Convert the .gbx file path (Linux) to a Windows path (Z:\...)
# umu-run/Proton maps the Linux filesystem under Z:
gbx_file="$1"
if [ -z "$gbx_file" ]; then
    echo "Usage: $0 <file.gbx>" >&2
    exit 1
fi

# Convert /home/user/file.gbx → Z:\home\user\file.gbx
win_path="Z:$(echo "$gbx_file" | sed 's|/|\\|g')"

EOF
    cat >> "$WRAPPER" << EOF
export PROTONPATH="$PROTONPATH"
export WINEPREFIX="$PREFIX"
exec umu-run "$EXE_WIN" /useexedir /singleinst /file="\$win_path"
EOF
else
    # Wine path: use wine binary directly, winepath for conversion
    cat >> "$WRAPPER" << 'EOF'
gbx_file="$1"
if [ -z "$gbx_file" ]; then
    echo "Usage: $0 <file.gbx>" >&2
    exit 1
fi

EOF
    if [ -n "$WINEPATH_BIN" ] && [ -f "$WINEPATH_BIN" ]; then
        cat >> "$WRAPPER" << EOF
win_path="\$("$WINEPATH_BIN" -w "\$gbx_file")"
exec "$WINE_BIN" "$EXE_WIN" /useexedir /singleinst /file="\$win_path"
EOF
    else
        # Fallback: manual Z: conversion
        cat >> "$WRAPPER" << 'EOF'
win_path="Z:$(echo "$gbx_file" | sed 's|/|\\|g')"
EOF
        cat >> "$WRAPPER" << EOF
exec "$WINE_BIN" "$EXE_WIN" /useexedir /singleinst /file="\$win_path"
EOF
    fi
fi

chmod +x "$WRAPPER"
echo "[1/4] Wrapper script created -> $WRAPPER"

# ─── Generate the .desktop entry ─────────────────────────────────────────────

# Determine icon path
ICON_PATH="$PREFIX/drive_c/Program Files (x86)/TmUnitedForever/Gbx.ico"
[ ! -f "$ICON_PATH" ] && ICON_PATH=""

DESKTOP_FILE="trackmania-gbx.desktop"
DESKTOP="$DESKTOP_DIR/$DESKTOP_FILE"

mkdir -p "$DESKTOP_DIR"
{
    echo "[Desktop Entry]"
    echo "Type=Application"
    echo "Name=$GAME_NAME"
    echo "Exec=$WRAPPER %f"
    [ -n "$ICON_PATH" ] && echo "Icon=$ICON_PATH"
    echo "MimeType=application/x-gbx;"
    echo "Terminal=false"
    echo "NoDisplay=true"
} > "$DESKTOP"
echo "[2/4] Desktop entry created -> $DESKTOP"

# ─── Register the MIME type ───────────────────────────────────────────────────

MIME_XML="$MIME_DIR/x-gbx.xml"
mkdir -p "$MIME_DIR"
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

# ─── Update databases ────────────────────────────────────────────────────────

if command -v update-mime-database >/dev/null 2>&1; then
    update-mime-database "$HOME/.local/share/mime" >/dev/null
fi
if command -v update-desktop-database >/dev/null 2>&1; then
    update-desktop-database "$DESKTOP_DIR" >/dev/null
fi
echo "[4/4] Databases updated"
echo

# ─── Ask to set as default ────────────────────────────────────────────────────
# We write mimeapps.list directly instead of calling `xdg-mime default`, because
# xdg-mime calls `qtpaths` on KDE which was removed in Qt6 / Plasma 6, causing a
# spurious error even though the association succeeds.

set_default_app() {
    local desktop_file="$1"
    local mime_type="$2"
    local mimeapps="$HOME/.config/mimeapps.list"

    mkdir -p "$(dirname "$mimeapps")"
    touch "$mimeapps"

    # Remove any existing entry for this mime type in [Default Applications]
    python3 - "$mimeapps" "$mime_type" "$desktop_file" <<'PYEOF'
import sys, configparser, os
path, mime, desktop = sys.argv[1], sys.argv[2], sys.argv[3]
cp = configparser.ConfigParser()
cp.optionxform = str  # preserve case
cp.read(path)
if "Default Applications" not in cp:
    cp["Default Applications"] = {}
cp["Default Applications"][mime] = desktop
with open(path, "w") as f:
    cp.write(f)
PYEOF
}

read -r -p "Associate .gbx files with $GAME_NAME as the default app? [y/N] " ans
case "$ans" in
    [yY]|[yY][eE][sS])
        set_default_app "$DESKTOP_FILE" "application/x-gbx"
        # Refresh KDE's file association cache if running KDE
        if [ -n "${KDE_SESSION_VERSION:-}" ]; then
            kbuildsycoca6 2>/dev/null || kbuildsycoca5 2>/dev/null || true
        fi
        echo
        echo "Done. .gbx files will now open in $GAME_NAME."
        echo "Verify with: xdg-mime query default application/x-gbx"
        ;;
    *)
        echo
        echo "Skipped. The wrapper/desktop entry are installed but not set as default."
        echo "To set it later: xdg-mime default $DESKTOP_FILE application/x-gbx"
        ;;
esac
