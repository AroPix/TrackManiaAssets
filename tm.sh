#!/usr/bin/env bash
set -euo pipefail

exec </dev/tty

slug="maniaplanet"

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

tm_gamedata="$prefix/drive_c/Program Files (x86)/ManiaPlanet/GameData"

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

install_openplanet() {
  exe_tmp="/tmp/openplanet.exe"
  exe_prefix="$prefix/drive_c/openplanet_tmp.exe"

  curl -L -o "$exe_tmp" "https://cdn.openplanet.dev/builds/v4/OpenplanetV4_1.29.5.exe"
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
  "Install Openplanet" \
  "Quit"
do
  case "$REPLY" in
    3) install_openplanet; break ;;
    4) break ;;
  esac
done
