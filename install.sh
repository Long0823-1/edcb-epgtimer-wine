#!/usr/bin/env bash
# Installs Wine (Arch), this bundle into ~/.local/share/edcb-epgtimer-wine,
# and creates shortcuts in the application menu and on the desktop.
set -e
SRC="$(cd "$(dirname "$0")" && pwd)"
DEST="${XDG_DATA_HOME:-$HOME/.local/share}/edcb-epgtimer-wine"
APPS="${XDG_DATA_HOME:-$HOME/.local/share}/applications"
if ! command -v pacman >/dev/null 2>&1; then
  echo "error: この install.sh は Arch Linux (pacman) 用です。他の環境では wine 11 以降と wine-mono、日本語フォント (Noto Sans CJK) を手動で入れて start.sh を使ってください。" >&2
  exit 1
fi
sudo pacman -S --needed --noconfirm wine wine-mono noto-fonts-cjk
mkdir -p "$DEST" "$APPS"
rm -rf "$DEST/app"
cp -r "$SRC/app" "$DEST/"
for f in start.sh fonts.reg README.md edcb-wine-font.patch epgtimer.png TaskIconBlue.ico; do
  [ -f "$SRC/$f" ] && cp "$SRC/$f" "$DEST/"
done
chmod +x "$DEST/start.sh"

# --- shortcuts: application menu + desktop ---
DESKTOP_DIR="$(xdg-user-dir DESKTOP 2>/dev/null || echo "$HOME/Desktop")"
for d in EpgTimerNW; do
  sed -e "s|@START@|$DEST/start.sh|g" -e "s|@ICON@|$DEST/epgtimer.png|g" \
    "$SRC/$d.desktop" > "$APPS/$d.desktop"
  chmod +x "$APPS/$d.desktop"
  echo "ショートカット (メニュー): $APPS/$d.desktop"
  if [ -n "$DESKTOP_DIR" ]; then
    mkdir -p "$DESKTOP_DIR" 2>/dev/null || true
    if [ -d "$DESKTOP_DIR" ]; then
      cp "$APPS/$d.desktop" "$DESKTOP_DIR/$d.desktop"
      chmod +x "$DESKTOP_DIR/$d.desktop"
      # GNOME 等でダブルクリック起動を許可する信頼済みマーク (失敗しても続行)
      if command -v gio >/dev/null 2>&1; then
        gio set "$DESKTOP_DIR/$d.desktop" metadata::trusted true 2>/dev/null || true
      fi
      echo "ショートカット (デスクトップ): $DESKTOP_DIR/$d.desktop"
    else
      echo "warning: デスクトップディレクトリ ($DESKTOP_DIR) が無いため、デスクトップ用ショートカットをスキップしました。" >&2
    fi
  fi
done
command -v update-desktop-database >/dev/null 2>&1 && update-desktop-database "$APPS" 2>/dev/null || true
echo "インストール完了。アプリケーションメニューとデスクトップに「EpgTimerNW (Wine)」(リモート接続用) のショートカットを作成しました。$DEST/start.sh からも起動できます。"
