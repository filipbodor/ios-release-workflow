#!/usr/bin/env bash
set -euo pipefail

options="$RUNNER_TEMP/ios-release-export.plist"
cat > "$options" <<'PLIST'
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>destination</key>
    <string>upload</string>
    <key>method</key>
    <string>app-store-connect</string>
    <key>signingStyle</key>
    <string>automatic</string>
    <key>manageAppVersionAndBuildNumber</key>
    <false/>
</dict>
</plist>
PLIST
plutil -insert teamID -string "$APPLE_TEAM_ID" "$options"

xcodebuild -exportArchive -archivePath "$RUNNER_TEMP/ios-release.xcarchive" \
  -exportOptionsPlist "$options" -allowProvisioningUpdates \
  -authenticationKeyPath "$ASC_KEY_PATH" -authenticationKeyID "$ASC_KEY_ID" \
  -authenticationKeyIssuerID "$ASC_ISSUER_ID"
