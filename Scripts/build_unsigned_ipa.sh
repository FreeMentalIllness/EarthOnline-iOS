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
# 注意：--project 接收的是「目录」而不是 .xcodeproj 路径，传文件名会导致
# XcodeGen 尝试生成 EarthOnline.xcodeproj/EarthOnline.xcodeproj 并在拷贝临时产物时失败。
xcodegen generate --spec "$SPEC" --project .

echo "== 工程校验：版本与 Info.plist 设置 =="
grep -aE "INFOPLIST_FILE|GENERATE_INFOPLIST_FILE|MARKETING_VERSION|CURRENT_PROJECT_VERSION" \
  "$PRODUCT.xcodeproj/project.pbxproj" | head -20 || echo "(未匹配到任何设置)"

if [[ ! -d "$PRODUCT.xcodeproj" ]]; then
  FOUND="$(ls -1d ./*.xcodeproj 2>/dev/null | head -n 1)"
  if [[ -z "$FOUND" ]]; then
    echo "未找到生成的 Xcode 工程：$PRODUCT.xcodeproj" >&2
    exit 1
  fi
  echo "==> 检测到工程：$FOUND"
  PRODUCT_XCODEPROJ="${FOUND#./}"
else
  PRODUCT_XCODEPROJ="$PRODUCT.xcodeproj"
fi

rm -rf build
mkdir -p build

# 版本 / Bundle ID / 地图后端：统一从 xcconfig 读取，避免与 App 设置分叉
MARKETING_VERSION="$(sed -n 's/^MARKETING_VERSION *= *//p' xcconfig/Common.xcconfig | head -n 1)"
CURRENT_PROJECT_VERSION="$(sed -n 's/^CURRENT_PROJECT_VERSION *= *//p' xcconfig/Common.xcconfig | head -n 1)"
EO_MAP_BACKEND="$(sed -n 's/^EO_MAP_BACKEND *= *//p' xcconfig/Common.xcconfig | head -n 1)"
AMAP_KEY="$(sed -n 's/^AMAP_KEY *= *//p' xcconfig/Secrets.local.xcconfig 2>/dev/null | head -n 1)"
BUNDLE_ID="com.example.earthonline"
MARKETING_VERSION="${MARKETING_VERSION:-1.0.4}"
CURRENT_PROJECT_VERSION="${CURRENT_PROJECT_VERSION:-1}"
EO_MAP_BACKEND="${EO_MAP_BACKEND:-mapkit}"
echo "==> 版本：${MARKETING_VERSION} (build ${CURRENT_PROJECT_VERSION})，地图后端：${EO_MAP_BACKEND}"

DERIVED="build/DerivedData"

echo "== 已解析构建设置 =="
xcodebuild -project "$PRODUCT_XCODEPROJ" -target EarthOnline \
  -configuration "$CONFIGURATION" -sdk iphoneos -showBuildSettings 2>&1 \
  | grep -E "INFOPLIST_FILE|GENERATE_INFOPLIST_FILE|MARKETING_VERSION|CURRENT_PROJECT_VERSION|WRAPPER_NAME|PRODUCT_NAME" || true

echo "==> 编译（关闭代码签名）"
xcodebuild \
  -project "$PRODUCT_XCODEPROJ" \
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

# 兜底：若 Xcode 走了自动生成 Info.plist 的分支，自定义条目（App 名、权限描述、地图配置、
# 版本号）会全部丢失。这里统一把仓库里的 Info.plist 合并进产物，再显式展开构建变量，
# 保证无论 Xcode 版本如何变化，安装的 App 名称/版本/权限文案都是对的。
echo "==> 合并自定义 Info.plist"
/usr/libexec/PlistBuddy -c "Merge $WORKDIR/Resources/Info.plist" "$APP_SRC/Info.plist" >/dev/null 2>&1 || true
/usr/libexec/PlistBuddy \
  -c "Set :CFBundleExecutable $PRODUCT" \
  -c "Set :CFBundleName $PRODUCT" \
  -c "Set :CFBundleDisplayName 地球Online" \
  -c "Set :CFBundleIdentifier ${BUNDLE_ID:-com.example.earthonline}" \
  -c "Set :CFBundlePackageType APPL" \
  -c "Set :CFBundleInfoDictionaryVersion 6.0" \
  -c "Set :CFBundleShortVersionString ${MARKETING_VERSION:-1.0.4}" \
  -c "Set :CFBundleVersion ${CURRENT_PROJECT_VERSION:-1}" \
  -c "Set :MinimumOSVersion 17.0" \
  -c "Set :AMapKey ${AMAP_KEY:-}" \
  -c "Set :EO_MAP_BACKEND ${EO_MAP_BACKEND:-mapkit}" \
  "$APP_SRC/Info.plist" >/dev/null 2>&1 || true

echo "== app bundle 内 Info.plist 摘要 =="
head -n 24 "$APP_SRC/Info.plist" || true
ls -l "$APP_SRC" | head -20

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
