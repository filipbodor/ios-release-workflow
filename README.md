# iOS Release Workflow

A reusable GitHub Actions workflow for shipping an existing iOS app to the App Store. It runs on GitHub-hosted macOS with Xcode automatic signing and uses Fastlane to submit a specific build for Apple review.

| Mode | What it does |
| --- | --- |
| `check` | Builds the Release configuration unsigned, checks the app bundle ID and compares the version and build if supplied. Requires no Apple credentials. |
| `upload` | Archives, signs, checks the version and build, and uploads to App Store Connect. |
| `release` | Uploads and waits for the specified build to process, sets the supplied release notes, and submits it for review. |
| `submit-existing` | Submits a specified version and build already uploaded to App Store Connect. Use this after an upload succeeded but the submission step needs retrying. |

## App setup

- Use a shared iOS scheme and enable automatic signing for the app and its embedded targets. Commit the intended marketing version and build number before release. The workflow preserves those values and checks them before uploading.
- Have an existing App Store Connect app with an approved initial version and complete store metadata, including the screenshots and the localization used for release notes. Provide the app’s export-compliance declaration when applicable. The workflow updates the release notes for one existing locale on the version.
- Use a team App Store Connect API key whose role permits Xcode provisioning and distribution signing and, for submission, App Review submission. The key ID, issuer ID, and complete raw `.p8` contents go in the caller’s `ASC_KEY_ID`, `ASC_ISSUER_ID`, and `ASC_PRIVATE_KEY` secrets. A team key reaches all apps the role can access. Protect it accordingly. [Apple API keys](https://developer.apple.com/documentation/appstoreconnectapi/creating-api-keys-for-app-store-connect-api) · [Signing permissions](https://developer.apple.com/help/account/access/roles/)
- Prefer secrets in an `app-store` environment in the calling repo. Restrict deployments to a trusted branch and use reviewers if your GitHub plan supports them. If a plan lacks private-repo environment secrets, the example also maps explicitly named repository secrets. Keep the live caller restricted to your trusted branch in either case. [GitHub environments and plan limits](https://docs.github.com/en/actions/how-tos/deploy/configure-and-manage-deployments/manage-environments)

## Caller example

Put this in `.github/workflows/release-ios.yml` in the app repo. Resolve the release tag to its full commit SHA and use that SHA in the `uses` reference. Use a commit you have reviewed before passing credentials.

```yaml
name: Release iOS
on:
  workflow_dispatch:
    inputs:
      mode:
        type: choice
        options: [check, upload, release, submit-existing]
        default: check
      version:
        type: string
      build:
        type: string
      notes:
        type: string
      automatic_release:
        type: boolean
        default: false

permissions:
  contents: read

jobs:
  release:
    if: inputs.mode == 'check' || github.ref == 'refs/heads/main'
    uses: filipbodor/ios-release-workflow/.github/workflows/release-ios.yml@REVIEWED_COMMIT_SHA
    with:
      project: Example.xcodeproj
      scheme: Example
      bundle_id: com.example.ios
      team_id: ABCDE12345
      runner: xcode-27
      minimum_ios_sdk_major: 27
      mode: ${{ inputs.mode }}
      version: ${{ inputs.version }}
      build: ${{ inputs.build }}
      release_notes: ${{ inputs.notes }}
      automatic_release: ${{ inputs.automatic_release }}
    secrets:
      ASC_KEY_ID: ${{ inputs.mode != 'check' && secrets.ASC_KEY_ID || '' }}
      ASC_ISSUER_ID: ${{ inputs.mode != 'check' && secrets.ASC_ISSUER_ID || '' }}
      ASC_PRIVATE_KEY: ${{ inputs.mode != 'check' && secrets.ASC_PRIVATE_KEY || '' }}
```

Set `runner` to select a GitHub-hosted macOS image. Set `minimum_ios_sdk_major` to check the SDK recorded in the built app before uploading it. These inputs default to `macos-26` and `0`, respectively.

Run an unsigned check or explicitly start a release from GitHub CLI.

```sh
gh workflow run release-ios.yml --ref main -f mode=check
gh workflow run release-ios.yml --ref main -f mode=release \
  -f version=1.2.0 -f build=12 -f notes='Improves reminders.' -f automatic_release=true
```

Apple reviews each submission. With automatic release enabled, Apple publishes it after approval. A release run stops after successful submission. If the build was already uploaded, run `submit-existing` with its exact version and build instead of uploading it again. If a version is already in review, use App Store Connect to see its status. [Apple App Review](https://developer.apple.com/help/app-store-connect/manage-submissions-to-app-review/submit-an-app/)

MIT licensed.
