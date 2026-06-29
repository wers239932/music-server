#!/usr/bin/env bash
# ==========================================================================
# metube-organize.sh — Перемещает скачанные MeTube файлы в _Unsorted
# ==========================================================================
# MeTube сохраняет файлы без ID3-тегов и структуры папок.
# Этот скрипт перемещает их в /data/music/_Unsorted/,
# чтобы Navidrome мог их увидеть.
#
# Использование:
#   ./metube-organize.sh          # разовый запуск
#   */5 * * * * /path/to/metube-organize.sh  # через cron каждые 5 мин
# ==========================================================================

set -euo pipefail

METUBE_DIR="$(cd "$(dirname "$0")/../../data/downloads/metube" && pwd)"
TARGET_DIR="$(cd "$(dirname "$0")/../../data/music/_Unsorted" && pwd)"

mkdir -p "$TARGET_DIR"

shopt -s nullglob
found=0

for f in "$METUBE_DIR"/*.{mp3,m4a,opus,flac,wav,ogg,webm} 2>/dev/null; do
    [ -f "$f" ] || continue
    mv -n "$f" "$TARGET_DIR/"
    echo "[+] Moved: $(basename "$f")"
    ((found++)) || true
done

if [ "$found" -eq 0 ]; then
    echo "[i] No new files to organize."
fi
