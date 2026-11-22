#!/bin/bash
set -euo pipefail
cd "$(dirname "$0")/.."

# 先编译，再为本机测试包补上签名。
xcodebuild \
  -project BLEUnlock.xcodeproj \
  -scheme BLEUnlock \
  -configuration Release \
  -destination 'generic/platform=macOS' \
  -derivedDataPath build \
  CODE_SIGNING_ALLOWED=NO \
  build

release_dir="$PWD/build/Build/Products/Release"
package_dir=$(mktemp -d "$release_dir/.dmg.XXXXXX")
trap 'rm -rf "$package_dir"' EXIT

mkdir "$package_dir/staging"
app_path="$package_dir/staging/BLEUnlock.app"
ditto "$release_dir/BLEUnlock.app" "$app_path"
ln -s /Applications "$package_dir/staging/Applications"

# 先签内嵌启动器，再签主 App，让 macOS 能识别本次构建的授权身份。
codesign --force --sign - "$app_path/Contents/Library/LoginItems/Launcher.app"
codesign --force --sign - --entitlements BLEUnlock/BLEUnlock.entitlements "$app_path"
codesign --verify --deep --strict "$app_path"

# 先校验临时镜像，打包失败时保留上次生成的 DMG。
hdiutil create -volname BLEUnlock -srcfolder "$package_dir/staging" \
  -format UDZO "$package_dir/BLEUnlock.dmg"
hdiutil verify "$package_dir/BLEUnlock.dmg"
mv -f "$package_dir/BLEUnlock.dmg" "$release_dir/BLEUnlock.dmg"
printf 'DMG: %s\n' "$release_dir/BLEUnlock.dmg"
