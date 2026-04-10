---
name: release
description: Build Arbor in Release configuration and publish to GitHub Releases
---

You are releasing a new version of the Arbor macOS app to GitHub.

## Steps

1. Ask the user for the version number (e.g. `1.1`) if not provided as an argument.

2. Update version numbers in both files:
   - `project.yml`: `MARKETING_VERSION` and `CURRENT_PROJECT_VERSION`
   - `Arbor.xcodeproj/project.pbxproj`: same fields (replace all occurrences)

3. Commit the version bump (and any doc updates like README.md).

4. Build in Release configuration. Do NOT use `CONFIGURATION_BUILD_DIR` — it breaks SPM resource bundle resolution. Build to DerivedData instead:
```bash
xcodebuild -scheme Arbor -configuration Release -destination "platform=macOS" build
```

5. Find and copy the built app, then zip with `ditto`:
```bash
BUILD_DIR=$(xcodebuild -scheme Arbor -configuration Release -showBuildSettings 2>/dev/null | grep ' BUILT_PRODUCTS_DIR' | awk '{print $3}')
mkdir -p build/Release
cp -R "$BUILD_DIR/Arbor.app" build/Release/
cd build/Release
ditto -c -k --keepParent Arbor.app Arbor-v{VERSION}.zip
```

6. Push to remote:
```bash
git push origin main
```

7. Create the GitHub Release and upload the zip:
```bash
gh release create v{VERSION} \
  --repo k-k4w4/Arbor \
  --title "v{VERSION}" \
  --notes "Release notes here" \
  build/Release/Arbor-v{VERSION}.zip
```

8. Report the release URL to the user.

## Notes

- The app is not notarized (CODE_SIGN_IDENTITY = "-"). Users must right-click -> Open on first launch to bypass Gatekeeper.
- GitHub repo: `k-k4w4/Arbor`
- Build output: DerivedData -> copied to `./build/Release/Arbor.app`
- `CONFIGURATION_BUILD_DIR` must NOT be used — SPM resource bundles (e.g. HighlightSwift) fail to resolve with custom build dirs.
