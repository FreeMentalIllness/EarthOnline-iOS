#!/usr/bin/env bash
# 构建未签名 .ipa（供 SideStore / AltStore 自签名安装）
#
# 用法：
#   Scripts/build_unsigned_ipa.sh                       # 默认含小组件扩展
#   Scripts/build_unsigned_ipa.sh project.nowidget.yml  # 无扩展兜底变体
#
# 前置：brew install xcodegen
set -euo pipefail

SPEC="${1:-project.yml}"
CONFIGURATION="${CONFIGURATION:-Release}"
SCHEME="${SCHEME:-EarthOnline}"
PRODUCT="${PRODUCT:-EarthOnline}"
WORKDIR="$(cd "$(dirname "$0")/.." && pwd)"

cd "$WORKDIR"

echo "==> 生成 Xcode 工程：$SPEC"
if ! command -v xcodegen >/dev/null 2>&1; then
  if command -v brew >/dev/null 2>&1; then
    brew install xcodegen
  else
    echo "缺少 xcodegen，请先 brew install xcodegen" >&2
    exit 1
  fi
fi
xcodegen generate --spec "$SPEC" --project "EarthOnline.xcodeproj"

rm -rf build
mkdir -p build

DERIVED="build/DerivedData"

echo "==> 编译（关闭代码签名）"
xcodebuild \
  -project "EarthOnline.xcodeproj" \
  -scheme "$SCHEME" \
  -configuration "$CONFIGURATION" \
  -sdk iphoneos \
  -destination 'generic/platform=iOS' \
  -derivedDataPath "$DERIVED" \
  SYMROOT="$(pwd)/build/Products" \
  CODE_SIGNING_ALLOWED=NO \
  CODE_SIGNING_REQUIRED=NO \
  CODE_SIGN_IDENTITY="" \
  EXPANDED_CODE_SIGN_IDENTITY="" \
  ENABLE_BITCODE=NO \
  GCC_NO_COMMON_BLOCKS=YES \
  -quiet

APP_SRC="$(pwd)/build/Products/${CONFIGURATION}-iphoneos/${PRODUCT}.app"
if [[ ! -d "$APP_SRC" ]]; then
  echo "未找到产物：$APP_SRC" >&2
  exit 1
fi

# 清理可能残留的签名痕迹，保证 SideStore 签名链路干净
find "$APP_SRC" -name "_CodeSignature" -type d -prune -exec rm -rf {} + 2>/dev/null || true
find "$APP_SRC" -name "embedded.mobileprovision" -delete 2>/dev/null || true

VERSION="$(/usr/libexec/PlistBuddy -c 'Print CFBundleShortVersionString' "$APP_SRC/Info.plist" 2>/dev/null || echo 0.0.0)"
BUILD_ID="$(/usr/libexec/PlistBuddy -c 'Print CFBundleVersion' "$APP_SRC/Info.plist" 2>/dev/null || echo 0)"
IPA_NAME="${PRODUCT}-iOS-v${VERSION}-${BUILD_ID}-unsigned.ipa"

echo "==> 打包 $IPA_NAME"
rm -rf build/Payload build/*.ipa
mkdir -p build/Payload
cp -R "$APP_SRC" build/Payload/
cd build
zip -qry "$IPA_NAME" Payload
cd "$WORKDIR"

mv "build/$IPA_NAME" "$IPA_NAME" 2>/dev/null || true
echo "==> 产物：$WORKDIR/$IPA_NAME"

ls -lh "$IPA_NAME"
