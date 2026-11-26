#!/usr/bin/env bash
set -euo pipefail

command=${1:?Specify build or archive}
if [[ "$XCODE_PROJECT" == *.xcodeproj ]]; then
  project_args=(-project "$XCODE_PROJECT")
elif [[ "$XCODE_PROJECT" == *.xcworkspace ]]; then
  project_args=(-workspace "$XCODE_PROJECT")
else
  echo "Provide an .xcodeproj or .xcworkspace path relative to the app repository." >&2
  exit 1
fi

if [[ ! -d "$XCODE_PROJECT" ]]; then
  echo "Xcode project or workspace does not exist: $XCODE_PROJECT" >&2
  exit 1
fi

build_args=("${project_args[@]}" -scheme "$XCODE_SCHEME" -configuration Release -destination 'generic/platform=iOS')
build_dir="$RUNNER_TEMP/ios-release-build"

case "$command" in
  build)
    xcodebuild "${build_args[@]}" -derivedDataPath "$build_dir" CODE_SIGNING_ALLOWED=NO build
    shopt -s nullglob
    apps=("$build_dir"/Build/Products/Release-iphoneos/*.app)
    ;;
  archive)
    archive="$RUNNER_TEMP/ios-release.xcarchive"
    xcodebuild "${build_args[@]}" -archivePath "$archive" \
      DEVELOPMENT_TEAM="$APPLE_TEAM_ID" -allowProvisioningUpdates -authenticationKeyPath "$ASC_KEY_PATH" \
      -authenticationKeyID "$ASC_KEY_ID" -authenticationKeyIssuerID "$ASC_ISSUER_ID" archive
    shopt -s nullglob
    apps=("$archive"/Products/Applications/*.app)
    ;;
  *)
    echo "Unknown build command: $command" >&2
    exit 1
    ;;
esac

if [[ "${#apps[@]}" -ne 1 ]]; then
  echo "Expected exactly one iOS app. Check the selected scheme and its Release product." >&2
  exit 1
fi

plist="${apps[0]}/Info.plist"
bundle_id=$(plutil -extract CFBundleIdentifier raw "$plist")
version=$(plutil -extract CFBundleShortVersionString raw "$plist")
build=$(plutil -extract CFBundleVersion raw "$plist")
sdk=$(plutil -extract DTSDKName raw "$plist")
printf 'Built %s %s (%s) with %s\n' "$bundle_id" "$version" "$build" "$sdk"

minimum_sdk_major=${MIN_IOS_SDK_MAJOR:-0}
if [[ "$minimum_sdk_major" != 0 ]]; then
  if [[ ! "$minimum_sdk_major" =~ ^[1-9][0-9]*$ ]]; then
    echo "minimum_ios_sdk_major must be a positive integer or 0." >&2
    exit 1
  fi
  if [[ ! "$sdk" =~ ^iphoneos([0-9]+)(\.[0-9]+)*$ ]] || (( BASH_REMATCH[1] < minimum_sdk_major )); then
    echo "The app was built with $sdk. Use iOS SDK $minimum_sdk_major or later." >&2
    exit 1
  fi
fi

if [[ "$bundle_id" != "$APP_BUNDLE_ID" ||
      ( -n "$APP_VERSION" && "$version" != "$APP_VERSION" ) ||
      ( -n "$APP_BUILD" && "$build" != "$APP_BUILD" ) ]]; then
  echo "The app bundle ID, version, or build number differs from the workflow inputs." >&2
  exit 1
fi
