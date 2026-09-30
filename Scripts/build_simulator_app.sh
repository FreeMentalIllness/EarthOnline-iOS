#!/usr/bin/env bash
# 构建 iOS 模拟器版 .app 并压缩成 .zip（供 Appetize.io 网页端做界面 / 功能验证）
#
# 用法：
#   Scripts/build_simulator_app.sh                       # 默认含小组件扩展（打包时会被剥离）
#   Scripts/build_simulator_app.sh project.nowidget.yml  # 无扩展兜底变体
#
# 与 .ipa 构建互不干扰：本脚本只消费 xcodegen 已生成的工程，写 build/SimProducts，
# 最终在仓库根目录产出 EarthOnline-iOS-Simulator.zip。
#
# 前置：已执行过 Scripts/build_unsigned_ipa.sh（或本机已 xcodegen generate）
set -euo pipefail

SPEC="${1:-project.yml}"
CONFIGURATION="${CONFIGURATION:-Release}"
SCHEME="${SCHEME:-EarthOnline}"
PRODUCT="${PRODUCT:-EarthOnline}"
WORKDIR="$(cd "$(dirname "$0")/.." && pwd)"

cd "$WORKDIR"

PRODUCT_XCODEPROJ="$PRODUCT.xcodeproj"
if [[ ! -d "$PRODUCT_XCODEPROJ" ]]; then
  echo "==> 工程不存在，先生成：$SPEC"
  if ! command -v xcodegen >/dev/null 2>&1; then
    if command -v brew >/dev/null 2>&1; then
      brew install xcodegen
    else
      echo "缺少 xcodegen，请先 brew install xcodegen" >&2
      exit 1
    fi
  fi
  # 注意：--project 接收的是「目录」而不是 .xcodeproj 路径
  xcodegen generate --spec "$SPEC" --project .
fi

if [[ ! -d "$PRODUCT_XCODEPROJ" ]]; then
  FOUND="$(ls -1d ./*.xcodeproj 2>/dev/null | awk 'NR==1' || true)"
  if [[ -z "$FOUND" ]]; then
    echo "未找到 Xcode 工程：$PRODUCT_XCODEPROJ" >&2
    exit 1
  fi
  echo "==> 检测到工程：$FOUND"
  PRODUCT_XCODEPROJ="${FOUND#./}"
fi

mkdir -p build

# 版本信息：与 .ipa 同源，统一从 xcconfig 读取
# 注意：本脚本开了 set -o pipefail，`cmd | head -1` 会让上游收到 SIGPIPE 而整段失败，
# 所以一律用单条 awk 取值，不用管道。
MARKETING_VERSION="$(awk -F' *= *' '/^MARKETING_VERSION/ {print $2; exit}' xcconfig/Common.xcconfig)"
CURRENT_PROJECT_VERSION="$(awk -F' *= *' '/^CURRENT_PROJECT_VERSION/ {print $2; exit}' xcconfig/Common.xcconfig)"
EO_MAP_BACKEND="$(awk -F' *= *' '/^EO_MAP_BACKEND/ {print $2; exit}' xcconfig/Common.xcconfig)"
AMAP_KEY=""
if [[ -f xcconfig/Secrets.local.xcconfig ]]; then
  AMAP_KEY="$(awk -F' *= *' '/^AMAP_KEY/ {print $2; exit}' xcconfig/Secrets.local.xcconfig)"
fi
MARKETING_VERSION="${MARKETING_VERSION:-1.0.4}"
CURRENT_PROJECT_VERSION="${CURRENT_PROJECT_VERSION:-1}"
EO_MAP_BACKEND="${EO_MAP_BACKEND:-mapkit}"
echo "==> 版本：${MARKETING_VERSION} (build ${CURRENT_PROJECT_VERSION})，地图后端：${EO_MAP_BACKEND}"

DERIVED="$(pwd)/build/DerivedDataSim"
SYMROOT="$(pwd)/build/SimProducts"
APP_SRC="$SYMROOT/${CONFIGURATION}-iphonesimulator/${PRODUCT}.app"

echo "==> 编译模拟器版本（arm64 + x86_64 双架构，兼顾 Appetize 两种运行节点）"
set +e
xcodebuild \
  -project "$PRODUCT_XCODEPROJ" \
  -scheme "$SCHEME" \
  -configuration "$CONFIGURATION" \
  -sdk iphonesimulator \
  -destination 'generic/platform=iOS Simulator' \
  -derivedDataPath "$DERIVED" \
  SYMROOT="$SYMROOT" \
  ARCHS="x86_64 arm64" \
  ONLY_ACTIVE_ARCH=NO \
  CODE_SIGNING_ALLOWED=NO \
  CODE_SIGNING_REQUIRED=NO \
  CODE_SIGN_IDENTITY="" \
  EXPANDED_CODE_SIGN_IDENTITY="" \
  ENABLE_BITCODE=NO \
  -quiet
BUILD_RC=$?
set -e

if [[ $BUILD_RC -ne 0 ]]; then
  echo "!! 双架构构建失败（rc=$BUILD_RC），回退为默认单架构"
  xcodebuild \
    -project "$PRODUCT_XCODEPROJ" \
    -scheme "$SCHEME" \
    -configuration "$CONFIGURATION" \
    -sdk iphonesimulator \
    -destination 'generic/platform=iOS Simulator' \
    -derivedDataPath "$DERIVED" \
    SYMROOT="$SYMROOT" \
    CODE_SIGNING_ALLOWED=NO \
    CODE_SIGNING_REQUIRED=NO \
    CODE_SIGN_IDENTITY="" \
    EXPANDED_CODE_SIGN_IDENTITY="" \
    ENABLE_BITCODE=NO \
    -quiet
fi

if [[ ! -d "$APP_SRC" ]]; then
  echo "未找到模拟器产物：$APP_SRC" >&2
  exit 1
fi

echo "==> 架构信息"
if command -v lipo >/dev/null 2>&1; then
  lipo -info "$APP_SRC/$PRODUCT" 2>/dev/null || true
fi

# 与 .ipa 同样的兜底：Xcode 26 会忽略 INFOPLIST_FILE 而用自动生成的精简 plist，
# 导致 App 名 / 版本号 / 权限文案 / ATS / 灵动岛开关全部丢失。这里用 python3 读取
# Resources/Info.template.json 重写二进制 plist。
echo "==> 写入自定义 Info.plist"
TPL="$WORKDIR/Resources/Info.template.json"
PY_BIN=""
for cand in "/usr/bin/python3" "/usr/local/bin/python3" "/opt/homebrew/bin/python3" "python3"; do
  if command -v "$cand" >/dev/null 2>&1; then PY_BIN="$cand"; break; fi
done
if [[ -z "$PY_BIN" ]]; then
  echo "!! 未找到 python3，跳过 Info.plist 注入（产物仍可运行，但 App 名/版本可能回落）"
else
  "$PY_BIN" - "$TPL" "$APP_SRC/Info.plist" \
    "$MARKETING_VERSION" "$CURRENT_PROJECT_VERSION" "$AMAP_KEY" "$EO_MAP_BACKEND" <<'PYEOF'
import json, plistlib, sys
tpl, dst, ver, build, amap_key, backend = sys.argv[1:7]
data = json.load(open(tpl, encoding="utf-8"))
data["CFBundleExecutable"] = "EarthOnline"
data["CFBundleName"] = "EarthOnline"
data["CFBundleDisplayName"] = "\u5730\u7403Online"
data["CFBundleIdentifier"] = "com.example.earthonline"
data["CFBundlePackageType"] = "APPL"
data["CFBundleInfoDictionaryVersion"] = "6.0"
data["CFBundleShortVersionString"] = ver
data["CFBundleVersion"] = build
data["AMapKey"] = amap_key
data["EO_MAP_BACKEND"] = backend
data["MinimumOSVersion"] = "17.0"
with open(dst, "wb") as f:
    plistlib.dump(data, f, fmt=plistlib.FMT_BINARY)
print("注入完成，键数：", len(data))
PYEOF
fi

# 模拟器产物不需要签名信息；Appetize 也不加载 App 扩展（保留会在其沙箱里引入不必要的校验），
# 因此这里把签名痕迹与 PlugIns 一并剥离，保持包体干净。
find "$APP_SRC" -name "_CodeSignature" -type d -prune -exec rm -rf {} + 2>/dev/null || true
find "$APP_SRC" -name "embedded.mobileprovision" -delete 2>/dev/null || true
if [[ -d "$APP_SRC/PlugIns" ]]; then
  echo "==> 剥离 App 扩展（Appetize 不加载 PlugIns）"
  rm -rf "$APP_SRC/PlugIns"
fi

ZIP_NAME="EarthOnline-iOS-Simulator.zip"
rm -f "$ZIP_NAME"

echo "==> 打包 $ZIP_NAME"
ditto -c -k --sequesterRsrc --keepParent "$APP_SRC" "$ZIP_NAME"

echo "==> zip 内容顶层结构"
unzip -Z1 "$ZIP_NAME" 2>/dev/null | awk 'NR<=3' || true

ls -lh "$ZIP_NAME"
echo "==> 产物：$WORKDIR/$ZIP_NAME"
