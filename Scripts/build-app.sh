#!/bin/bash
# 打包成 macOS .app → build/AI-Remotty.app
set -euo pipefail
cd "$(dirname "$0")/.."

APP_NAME="AI-Remotty"
BIN="Remotty"
APP_DIR="build/${APP_NAME}.app"
CONTENTS="${APP_DIR}/Contents"
MACOS_DIR="${CONTENTS}/MacOS"
RES_DIR="${CONTENTS}/Resources"

echo "→ swift build (release)"
swift build -c release

echo "→ assembling ${APP_DIR}"
rm -rf "${APP_DIR}"
mkdir -p "${MACOS_DIR}" "${RES_DIR}"
cp ".build/release/${BIN}" "${MACOS_DIR}/${BIN}"
cp "Resources/Info.plist" "${CONTENTS}/Info.plist"
[[ -f "Resources/AppIcon.icns" ]] && cp "Resources/AppIcon.icns" "${RES_DIR}/AppIcon.icns"
printf 'APPL????' > "${CONTENTS}/PkgInfo"

# 穩定自簽身分讓權限授權（Bluetooth/Accessibility）跨重建保留；沒有就 ad-hoc。
SIGN_IDENTITY=""
for cand in "Remotty Self-Signed" "Configgy Self-Signed" "Findly Self-Signed"; do
  if security find-identity -p codesigning 2>/dev/null | grep -q "${cand}"; then SIGN_IDENTITY="${cand}"; break; fi
done
if [[ -n "${SIGN_IDENTITY}" ]]; then
  echo "→ codesign with ${SIGN_IDENTITY}"
  codesign --force --deep --sign "${SIGN_IDENTITY}" --timestamp=none "${APP_DIR}"
else
  echo "→ ad-hoc codesign（建議建穩定自簽身分，否則每次重建後要重設 Bluetooth/Accessibility 權限）"
  codesign --force --deep --sign - "${APP_DIR}"
fi

echo
echo "Done →  open ${APP_DIR}    或安裝：cp -R ${APP_DIR} /Applications/"
