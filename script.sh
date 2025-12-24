#!/usr/bin/env bash
set -euo pipefail

slug="${slug:-trackmania-united-forever}"

if command -v lutris >/dev/null 2>&1; then
  LUTRIS_CMD=(lutris)
elif command -v flatpak >/dev/null 2>&1 && flatpak info net.lutris.Lutris >/dev/null 2>&1; then
  LUTRIS_CMD=(flatpak run --no-sandbox net.lutris.Lutris)
else
  echo "Error: neither native lutris nor flatpak net.lutris.Lutris found." >&2
  exit 1
fi

get_prefix() {
  "${LUTRIS_CMD[@]}" --list-games --json 2>/dev/null \
    | jq -r --arg slug "$slug" '.[] | select(.slug==$slug) | .directory' \
    | head -n1
}

prefix="$(get_prefix)"
if [[ -z "$prefix" || "$prefix" == "null" ]]; then
  echo "Error: couldn't find prefix for slug: $slug" >&2
  exit 1
fi

tm_gamedata="$prefix/drive_c/Program Files (x86)/TmUnitedForever/GameData"

install_zip_gamedata() {
  local url="$1"
  local name="$2"
  local zip="/tmp/${name}.zip"

  mkdir -p "$tm_gamedata"
  echo "Downloading $name…"
  curl -L -o "$zip" "$url"

  echo "Installing $name…"
  unzip -o "$zip" 'GameData/*' -d /tmp
  cp -r /tmp/GameData/* "$tm_gamedata/"

  rm -f "$zip"
  rm -rf /tmp/GameData
  echo "$name installed into: $tm_gamedata"
}

install_newsnowcar() {
  install_zip_gamedata \
    "https://unlimiter.net/resources/NewSnowCar.zip" \
    "NewSnowCar"
}

install_tmhighlands() {
  install_zip_gamedata \
    "https://github.com/AroPix/TrackManiaAssets/releases/download/1.0.0/TmHighlands.zip" \
    "TmHighlands"
}

find_wine() {
  local cfg winever
  cfg="$(ls -1 "$HOME/.local/share/lutris/games/${slug}-"*.yml 2>/dev/null | head -n1 || true)"
  winever=""
  if [[ -n "$cfg" ]]; then
    winever="$(awk '
      $1=="wine:" {inwine=1}
      inwine && $1=="version:" {print $2; exit}
    ' "$cfg" 2>/dev/null || true)"
  fi

  if [[ -n "$winever" && -x "$HOME/.local/share/lutris/runners/wine/$winever/bin/wine" ]]; then
    echo "$HOME/.local/share/lutris/runners/wine/$winever/bin/wine"
    return 0
  fi

  command -v wine >/dev/null 2>&1 && command -v wine
}

run_uvme_installer() {
  local url="https://github.com/AroPix/TrackManiaAssets/releases/download/1.0.0/TmUnitedForever_UVME_v3.1.exe"
  local tmp="/tmp/TmUnitedForever_UVME_v3.1.exe"
  local exe="$prefix/drive_c/uvme_tmp.exe"

  curl -L -o "$tmp" "$url"
  cp -f "$tmp" "$exe"

  local winebin
  winebin="$(find_wine)" || {
    echo "Error: wine not found." >&2
    rm -f "$tmp" "$exe"
    exit 1
  }

  echo "Running UVME installer…"
  WINEPREFIX="$prefix" "$winebin" "$exe"

  rm -f "$tmp" "$exe"
  echo "UVME installer finished and cleaned up."
}

echo "Prefix: $prefix"
echo

PS3="Choose action: "
select action in \
  "Install NewSnowCar" \
  "Install TmHighlands" \
  "Install UVME" \
  "Quit"
do
  case "$REPLY" in
    1) install_newsnowcar; break ;;
    2) install_tmhighlands; break ;;
    3) run_uvme_installer; break ;;
    4) break ;;
    *) echo "Invalid choice." ;;
  esac
done
