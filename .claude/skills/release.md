---
name: release
description: Build Arbor in Release configuration and publish to GitHub Releases
---

You are releasing a new version of the Arbor macOS app to GitHub.

## Steps

1. Ask the user for the version number (e.g. `1.1`) if not provided as an argument.

2. Build in Release configuration:
```bash
xcodebuild -scheme Arbor -configuration Release \
  -destination "platform=macOS" \
  CONFIGURATION_BUILD_DIR=./build/Release \
  build
```

3. Zip the .app bundle using `ditto` (preserves macOS metadata):
```bash
cd build/Release
ditto -c -k --keepParent Arbor.app Arbor-v{VERSION}.zip
```

4. Create the GitHub Release and upload the zip:
```bash
gh release create v{VERSION} \
  --repo k-k4w4/Arbor \
  --title "v{VERSION}" \
  --notes "Release v{VERSION}" \
  build/Release/Arbor-v{VERSION}.zip
```

5. Report the release URL to the user.

## Notes

- The app is not notarized (CODE_SIGN_IDENTITY = "-"). Users must right-click → Open on first launch to bypass Gatekeeper.
- GitHub repo: `k-k4w4/Arbor`
- Build output: `./build/Release/Arbor.app`
