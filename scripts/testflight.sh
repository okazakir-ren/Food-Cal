#!/bin/zsh
# 内部TestFlight向けにアーカイブして署名する。
#   scripts/testflight.sh <ビルド番号>          手元に書き出す（アップロードしない）
#   scripts/testflight.sh <ビルド番号> upload   App Store Connectへアップロードする
#
# チームに端末が無いと、通常のarchiveは開発用プロファイルを作れず失敗する。
# 署名なしでarchiveするとエンタイトルメントが消えるので、archiveの中身に
# エンタイトルメント付きのアドホック署名をかけてから、exportで配布用に署名し直す。
set -euo pipefail

build_number=${1:?ビルド番号を指定してください}
mode=${2:-export}
root=${0:A:h:h}
out="$root/build/testflight-$build_number"
archive="$out/AruiteGohan.xcarchive"

case "$mode" in
  export) destination=export ;;
  upload) destination=upload ;;
  *) echo "第2引数は upload か省略です: $mode" >&2; exit 2 ;;
esac

rm -rf "$out"
mkdir -p "$out"

xcodebuild archive \
  -project "$root/AruiteGohan.xcodeproj" \
  -scheme AruiteGohan \
  -configuration Release \
  -destination 'generic/platform=iOS' \
  -archivePath "$archive" \
  -derivedDataPath "$out/DerivedData" \
  CURRENT_PROJECT_VERSION="$build_number" \
  CODE_SIGNING_ALLOWED=NO \
  > "$out/archive.log" 2>&1 || { tail -20 "$out/archive.log"; exit 1; }

app="$archive/Products/Applications/AruiteGohan.app"
codesign -f -s - --entitlements "$root/Configurations/Widget.entitlements" "$app/PlugIns/AruiteGohanWidget.appex"
codesign -f -s - --entitlements "$root/Configurations/App.entitlements" "$app"

cat > "$out/ExportOptions.plist" <<EOF
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0"><dict>
<key>method</key><string>app-store-connect</string>
<key>destination</key><string>$destination</string>
<key>teamID</key><string>T9B78P93A3</string>
<key>signingStyle</key><string>automatic</string>
<key>uploadSymbols</key><true/>
<key>manageAppVersionAndBuildNumber</key><false/>
<key>testFlightInternalTestingOnly</key><true/>
</dict></plist>
EOF

xcodebuild -exportArchive \
  -archivePath "$archive" \
  -exportOptionsPlist "$out/ExportOptions.plist" \
  -exportPath "$out/export" \
  -allowProvisioningUpdates \
  > "$out/export.log" 2>&1 || { grep -E 'error|Error' "$out/export.log" | tail -20; exit 1; }

echo "完了: $mode（ビルド $build_number）"
echo "ログ: $out"
