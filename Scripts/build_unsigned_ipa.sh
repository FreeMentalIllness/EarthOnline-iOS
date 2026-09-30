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
  FOUND="$(ls -1d ./*.xcodeproj 2>/dev/null | head -n 1 || true)"
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
# 注意：本脚本开了 set -o pipefail，`cmd | head -1` 会让上游收到 SIGPIPE 而整段失败，
# 所以一律用单条 awk 取值，不用管道。
MARKETING_VERSION="$(awk -F' *= *' '/^MARKETING_VERSION/ {print $2; exit}' xcconfig/Common.xcconfig)"
CURRENT_PROJECT_VERSION="$(awk -F' *= *' '/^CURRENT_PROJECT_VERSION/ {print $2; exit}' xcconfig/Common.xcconfig)"
EO_MAP_BACKEND="$(awk -F' *= *' '/^EO_MAP_BACKEND/ {print $2; exit}' xcconfig/Common.xcconfig)"
AMAP_KEY=""
if [[ -f xcconfig/Secrets.local.xcconfig ]]; then
  AMAP_KEY="$(awk -F' *= *' '/^AMAP_KEY/ {print $2; exit}' xcconfig/Secrets.local.xcconfig)"
fi
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

# 兜底：部分 Xcode 版本会让 GENERATE_INFOPLIST_FILE/INFOPLIST_FILE 的组合失效，导致
# 自定义条目（App 名、权限文案、ATS、灵动岛开关）全部丢失。这里以仓库内的 Info.plist 为
# 基准重写产物 plist，用 plutil 展开构建变量并补齐安装必需元数据，最后转二进制去掉注释。
# 说明：PlistBuddy 遇到空值会直接 abort，所以统一用 plutil（对空值与复杂类型都稳定）。
echo "==> 写入自定义 Info.plist"
INF="$APP_SRC/Info.plist"
cp "$WORKDIR/Resources/Info.plist" "$INF"

replace_str() { plutil -replace "$1" -string "$2" "$INF"; }
replace_str CFBundleExecutable "$PRODUCT"
replace_str CFBundleName "$PRODUCT"
replace_str CFBundleDisplayName "地球Online"
replace_str CFBundleIdentifier "$BUNDLE_ID"
replace_str CFBundlePackageType "APPL"
replace_str CFBundleInfoDictionaryVersion "6.0"
replace_str CFBundleDevelopmentRegion "zh_CN"
replace_str CFBundleShortVersionString "$MARKETING_VERSION"
replace_str CFBundleVersion "$CURRENT_PROJECT_VERSION"
replace_str AMapKey "$AMAP_KEY"
replace_str EO_MAP_BACKEND "$EO_MAP_BACKEND"

insert_or_replace_str() { plutil -insert "$1" -string "$2" "$INF" 2>/dev/null || plutil -replace "$1" -string "$2" "$INF"; }
insert_or_replace_json() { plutil -insert "$1" -json "$2" "$INF" 2>/dev/null || plutil -replace "$1" -json "$2" "$INF"; }
insert_or_replace_str MinimumOSVersion "17.0"
insert_or_replace_json CFBundleSupportedPlatforms '["iPhoneOS"]'
insert_or_replace_json UIDeviceFamily '[1,2]'

# 转成二进制 plist：剥离 XML 注释，也是安装器期望的标准形态
plutil -convert binary1 "$INF"

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
