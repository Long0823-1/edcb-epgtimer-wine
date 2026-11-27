#!/usr/bin/env bash
# EpgTimerNW (Wine) launcher.
#   ./start.sh          -> EpgTimerNW.exe (remote EpgTimerSrv front-end, NW mode)
# Creates a dedicated Wine prefix on first run and sets up Japanese fonts.
set -e
APP_DIR="$(cd "$(dirname "$0")" && pwd)"
BASE="${XDG_DATA_HOME:-$HOME/.local/share}/edcb-epgtimer-wine"
export WINEPREFIX="$BASE/prefix"
export WINEARCH=win64
EXE="EpgTimerNW.exe"
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
# --- HiDPI: ディスプレイのスケールに合わせて Wine の DPI (LogPixels) を設定する ---
# 優先順位: 環境変数 EPGTIMER_DPI_SCALE (例 1.5) / EPGTIMER_DPI (例 144) > 自動検出 > 1.0
# 自動検出 (KDE): kwinrc の Xwayland Scale -> kwinoutputconfig.json の先頭出力の scale
# EPGTIMER_DPI_SCALE=1 を指定すると 96 DPI (等倍) に戻る。
detect_scale() {
  local v=""
  if [ -n "${EPGTIMER_DPI_SCALE:-}" ]; then echo "$EPGTIMER_DPI_SCALE"; return; fi
  if command -v kreadconfig6 >/dev/null 2>&1; then
    v="$(kreadconfig6 --file kwinrc --group Xwayland --key Scale 2>/dev/null || true)"
  elif command -v kreadconfig5 >/dev/null 2>&1; then
    v="$(kreadconfig5 --file kwinrc --group Xwayland --key Scale 2>/dev/null || true)"
  fi
  if [ -z "$v" ] && [ -f "$HOME/.config/kwinoutputconfig.json" ]; then
    v="$(python3 -c 'import json,sys
try:
    d=json.load(open(sys.argv[1]))
    def walk(x):
        if isinstance(x,dict):
            if "scale" in x: return x["scale"]
            for vv in x.values():
                r=walk(vv)
                if r is not None: return r
        elif isinstance(x,list):
            for vv in x:
                r=walk(vv)
                if r is not None: return r
    r=walk(d)
    print(r if r else "")' "$HOME/.config/kwinoutputconfig.json" 2>/dev/null || true)"
  fi
  echo "${v:-1}"
}
SCALE="$(detect_scale)"
if [ -n "${EPGTIMER_DPI:-}" ]; then
  TARGET_DPI="$EPGTIMER_DPI"
else
  TARGET_DPI="$(awk -v s="$SCALE" 'BEGIN{ printf "%d", (96*s)+0.5 }')"
fi
if [ -n "${TARGET_DPI:-}" ] && [ -d "$WINEPREFIX/drive_c" ]; then
  CUR_DPI=""
  if [ -f "$WINEPREFIX/user.reg" ]; then
    CUR_HEX="$(grep -a '"LogPixels"=dword:' "$WINEPREFIX/user.reg" | head -1 | sed 's/.*dword:0*//')"
    [ -n "$CUR_HEX" ] && CUR_DPI="$(printf "%d" "0x$CUR_HEX" 2>/dev/null || echo "")"
  fi
  if [ "$CUR_DPI" != "$TARGET_DPI" ]; then
    echo "HiDPI: スケール ${SCALE} に合わせて Wine の DPI を ${TARGET_DPI} に設定します"
    wineserver -k 2>/dev/null || true
    WINEPREFIX="$WINEPREFIX" wine reg add 'HKCU\Control Panel\Desktop' /v LogPixels /t REG_DWORD /d "$TARGET_DPI" /f >/dev/null 2>&1 || true
    wineserver -w 2>/dev/null || true
  fi
fi

exec wine "$APP_DIR/app/$EXE" "$@"
