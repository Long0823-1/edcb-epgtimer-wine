#!/usr/bin/env bash
# EpgTimer / EpgTimerNW (Wine) launcher.
#   ./start.sh          -> EpgTimerNW.exe (default: remote EpgTimerSrv front-end)
#   ./start.sh timer    -> EpgTimer.exe   (normal mode)
# Creates a dedicated Wine prefix on first run and sets up Japanese fonts.
set -e
APP_DIR="$(cd "$(dirname "$0")" && pwd)"
BASE="${XDG_DATA_HOME:-$HOME/.local/share}/edcb-epgtimer-wine"
export WINEPREFIX="$BASE/prefix"
export WINEARCH=win64
EXE="EpgTimerNW.exe"
if [ "${1:-}" = "timer" ]; then
  EXE="EpgTimer.exe"
  shift
fi
if ! command -v wine >/dev/null 2>&1; then
  echo "error: wine が見つかりません。先に ./install.sh を実行してください。" >&2
  exit 1
fi
if [ ! -d "$WINEPREFIX/drive_c" ]; then
  echo "初回起動: Wine プレフィックスを作成します ($WINEPREFIX)"
  mkdir -p "$BASE"
  wineboot --init
  wineserver -w
  # 日本語フォント設定: ホストの Noto CJK をプレフィックスへ取り込み、フォント代替を登録する
  FONT_SRC=/usr/share/fonts/noto-cjk
  if [ -d "$FONT_SRC" ]; then
    for f in NotoSansCJK-Regular.ttc NotoSansCJK-Bold.ttc NotoSerifCJK-Regular.ttc NotoSerifCJK-Bold.ttc; do
      [ -f "$FONT_SRC/$f" ] && cp "$FONT_SRC/$f" "$WINEPREFIX/drive_c/windows/Fonts/"
    done
    wine regedit "$APP_DIR/fonts.reg" >/dev/null 2>&1 || true
    wineserver -w
    echo "日本語フォント (Noto CJK) を設定しました。"
  else
    echo "warning: $FONT_SRC が無いため日本語フォント設定をスキップしました。noto-fonts-cjk を導入してください。" >&2
  fi
fi
exec wine "$APP_DIR/app/$EXE" "$@"
