#!/usr/bin/env bash
set -euo pipefail

exec </dev/tty

slug="trackmania-united-forever"

if command -v lutris >/dev/null 2>&1; then
  LUTRIS_CMD=(lutris)
elif command -v flatpak >/dev/null 2>&1 && flatpak info net.lutris.Lutris >/dev/null 2>&1; then
  LUTRIS_CMD=(flatpak run --no-sandbox net.lutris.Lutris)
else
  exit 1
fi

prefix="$("${LUTRIS_CMD[@]}" --list-games --json 2>/dev/null \
  | jq -r --arg slug "$slug" '.[] | select(.slug==$slug) | .directory' \
  | head -n1)"

[ -n "$prefix" ] || exit 1

echo "Prefix: $prefix"
echo

tm_gamedata="$prefix/drive_c/Program Files (x86)/TmUnitedForever/GameData"

install_zip() {
  url="$1"
  name="$2"
  zip="/tmp/$name.zip"

  mkdir -p "$tm_gamedata"
  curl -L -o "$zip" "$url"
  unzip -o "$zip" 'GameData/*' -d /tmp
  rsync -a /tmp/GameData/ "$tm_gamedata/"
  rm -f "$zip"
  rm -rf /tmp/GameData
}

install_uvme() {
  exe_tmp="/tmp/uvme.exe"
  exe_prefix="$prefix/drive_c/uvme_tmp.exe"

  curl -L -o "$exe_tmp" "https://github.com/AroPix/TrackManiaAssets/releases/download/1.0.0/TmUnitedForever_UVME_v3.1.exe"
  cp "$exe_tmp" "$exe_prefix"

  if [ -x "$HOME/.local/share/lutris/runners/wine" ]; then
    winebin="$(find "$HOME/.local/share/lutris/runners/wine" -path '*/bin/wine' | head -n1)"
  else
    winebin="$(command -v wine)"
  fi

  WINEPREFIX="$prefix" "$winebin" "$exe_prefix"

  rm -f "$exe_tmp" "$exe_prefix"
}

PS3="Choose action: "
select _ in \
  "Install NewSnowCar" \
  "Install TmHighlands" \
  "Install UVME" \
  "Quit"
do
  case "$REPLY" in
    1) install_zip "https://unlimiter.net/resources/NewSnowCar.zip" "NewSnowCar"; break ;;
    2) install_zip "https://github.com/AroPix/TrackManiaAssets/releases/download/1.0.0/TmHighlands.zip" "TmHighlands"; break ;;
    3) install_uvme; break ;;
    4) break ;;
  esac
done
