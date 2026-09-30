#!/usr/bin/env bash
# 校验 ipa 是否会被 SideStore 签名卡住：检查是否残留限制性 Entitlements / 描述文件
#
# 用法：Scripts/verify_ipa.sh build/EarthOnline-iOS-v1.0.4-1-unsigned.ipa
set -euo pipefail

IPA="${1:-}"
if [[ -z "$IPA" || ! -f "$IPA" ]]; then
  echo "用法：verify_ipa.sh <xxx.ipa>" >&2
  exit 1
fi

TMP="$(mktemp -d)"
trap 'rm -rf "$TMP"' EXIT

echo "==> 解包 $IPA"
unzip -q "$IPA" -d "$TMP"

APP_PATH="$(find "$TMP/Payload" -maxdepth 1 -name "*.app" -type d | head -n 1)"
if [[ -z "$APP_PATH" ]]; then
  echo "Payload 里没有 .app，产物结构异常" >&2
  exit 1
fi
echo "App: $(basename "$APP_PATH")"

# 1. 不能带描述文件
if [[ -f "$APP_PATH/embedded.mobileprovision" ]]; then
  echo "❌ 发现 embedded.mobileprovision（未签名 ipa 不应包含）"
  exit 1
fi

# 2. 不能有签名痕迹
if [[ -d "$APP_PATH/_CodeSignature" ]]; then
  echo "❌ 发现 _CodeSignature（未签名 ipa 不应包含）"
  exit 1
fi

# 3. 二进制里不能有限制性 Entitlement 字符串
BINARY="$APP_PATH/$(basename "$APP_PATH" .app)"
RESTRICTED=(
  "com.apple.security.application-groups"
  "com.apple.developer.healthkit"
  "com.apple.developer.networking.vpn.api"
  "aps-environment"
  "com.apple.developer.associated-domains"
  "com.apple.developer.default-data-protection"
  "com.apple.developer.icloud-container-identifiers"
  "com.apple.private"
)

status=0
for key in "${RESTRICTED[@]}"; do
  if strings "$BINARY" 2>/dev/null | grep -q "$key"; then
    echo "⚠️  二进制中发现限制性 Entitlement：$key"
    status=1
  fi
done

# 4. 扩展清单
echo "==> 扩展目录："
if [[ -d "$APP_PATH/PlugIns" ]]; then
  ls -1 "$APP_PATH/PlugIns" 2>/dev/null || echo "  （无）"
else
  echo "  （无 PlugIns 目录）"
fi

if [[ $status -eq 0 ]]; then
  echo "✅ 通过：无限制性 Entitlements，可交给 SideStore 自签名"
else
  echo "❌ 存在风险项，请检查上面的输出"
fi
exit $status
