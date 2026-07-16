#!/bin/bash
# 把 build/AI-Remotty.app 打包成可拖曳安裝的 dmg → dist/AI-Remotty-<version>.dmg
# 用法：./Scripts/make-dmg.sh 0.1.0
set -euo pipefail
cd "$(dirname "$0")/.."

VERSION="${1:-}"
if [[ -z "${VERSION}" ]]; then
  echo "用法：$0 <version>   例：$0 0.1.0" >&2
  exit 1
fi

APP="build/AI-Remotty.app"
[[ -d "${APP}" ]] || { echo "找不到 ${APP} —— 先跑 ./Scripts/build-app.sh" >&2; exit 1; }

DMG="dist/AI-Remotty-${VERSION}.dmg"
STAGE="$(mktemp -d)"
trap 'rm -rf "${STAGE}"' EXIT

echo "→ staging"
mkdir -p dist
cp -R "${APP}" "${STAGE}/"
ln -s /Applications "${STAGE}/Applications"   # 拖曳安裝的目標

echo "→ hdiutil create ${DMG}"
rm -f "${DMG}"
hdiutil create -volname "AI-Remotty" -srcfolder "${STAGE}" -ov -format UDZO "${DMG}" >/dev/null

echo "Done: ${DMG}"
