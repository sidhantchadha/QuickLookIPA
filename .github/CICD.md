# CI/CD Documentation

QuickLookIPA uses GitHub Actions for continuous integration and automated releases.

## Workflows

### 1. CI Workflow (`ci.yml`)

**Triggers:**
- Push to `main` or `develop` branches
- Pull requests to `main` or `develop`
- Manual dispatch from Actions tab

**What it does:**
- Builds both Debug and Release configurations
- Verifies app bundle integrity
- Checks for Info.plist and binary
- Reports version, build number, and bundle ID
- Optionally runs SwiftLint (if available)
- Uses build caching for faster builds

**View results:**
- Go to: https://github.com/sidhantchadha/QuickLookIPA/actions
- Click on the latest CI run to see build details

### 2. Build & Release Workflow (`build-release.yml`)

**Triggers:**
- Push tags matching `v*.*.*` (e.g., `v1.1.0`, `v1.2.1`)
- Manual dispatch from Actions tab (choose release type)

**What it does:**
- Builds Release configuration (unsigned)
- Creates DMG installer with Applications symlink
- Creates ZIP archive
- Generates SHA-256 checksums
- Uploads artifacts to GitHub
- Creates GitHub release with notes

**Output artifacts:**
- `QuickLookIPA-vX.X.X-macOS.dmg` - DMG installer
- `QuickLookIPA-vX.X.X-macOS.zip` - ZIP archive
- `*.sha256` - Checksum files for verification

## Creating a Release

### Method 1: Using Git Tags (Recommended)

```bash
# Ensure you're on main branch with latest code
git checkout main
git pull origin main

# Create and push a new tag
git tag -a v1.1.1 -m "Release v1.1.1: Description of changes"
git push origin v1.1.1
```

This will automatically:
1. Trigger the build-release workflow
2. Build the app
3. Create DMG and ZIP files
4. Create a draft release on GitHub

### Method 2: Manual Dispatch

1. Go to: https://github.com/sidhantchadha/QuickLookIPA/actions
2. Click on "Build and Release" workflow
3. Click "Run workflow"
4. Select branch (usually `main`)
5. Choose release type:
   - **draft** - Creates a draft release (not visible to public)
   - **prerelease** - Creates a pre-release (marked as not production-ready)
   - **release** - Creates a public release
6. Click "Run workflow"

## Publishing a Release

After the workflow completes:

1. Go to: https://github.com/sidhantchadha/QuickLookIPA/releases
2. Find the draft release
3. Review the release notes
4. Edit if needed
5. Click "Publish release"

The release will now be public and users can download the DMG/ZIP files.

## Installing from Release

### For Users - DMG Method (Recommended)

1. Download `QuickLookIPA-vX.X.X-macOS.dmg`
2. Double-click to open the DMG
3. Drag QuickLookIPA.app to Applications folder
4. Launch from Applications
5. If blocked by macOS Gatekeeper:
   - Go to System Settings → Privacy & Security
   - Click "Open Anyway" next to QuickLookIPA
   - Click "Open" in confirmation dialog

### For Users - ZIP Method

1. Download `QuickLookIPA-vX.X.X-macOS.zip`
2. Extract the ZIP file
3. Move QuickLookIPA.app to Applications folder
4. Follow same Gatekeeper steps if blocked

### Verifying Downloads

```bash
# Verify DMG integrity
shasum -a 256 -c QuickLookIPA-v1.1.0-macOS.dmg.sha256

# Verify ZIP integrity
shasum -a 256 -c QuickLookIPA-v1.1.0-macOS.zip.sha256
```

## Technical Details

### Build Environment

- **Runner:** macOS 14 (Sonoma)
- **Xcode:** 15.2
- **Swift:** 5.9+
- **Architecture:** Universal (Apple Silicon + Intel)

### Build Configuration

```bash
xcodebuild clean build \
  -project QuickLookIPA.xcodeproj \
  -scheme QuickLookIPA \
  -configuration Release \
  CODE_SIGN_IDENTITY="" \
  CODE_SIGNING_REQUIRED=NO \
  CODE_SIGNING_ALLOWED=NO
```

**Note:** Builds are **unsigned** to work on free GitHub Actions runners. Users will need to approve the app via Gatekeeper on first launch.

### Caching

The workflows use caching to speed up builds:
- Derived data is cached between runs
- Cache key based on project file hash
- Cache automatically invalidates when project changes

### Artifact Retention

- Artifacts are kept for **30 days**
- Releases are permanent until manually deleted
- Download artifacts from the Actions tab or Releases page

## Troubleshooting

### CI Build Fails

1. Check the workflow logs in Actions tab
2. Look for specific errors in xcodebuild output
3. Common issues:
   - Missing dependencies
   - Xcode version mismatch
   - Code signing issues (should be disabled)

### Release Not Created

1. Verify tag format matches `v*.*.*`
2. Check workflow logs for errors
3. Ensure GITHUB_TOKEN has proper permissions
4. Check if release already exists for that tag

### App Won't Launch After Download

This is expected for unsigned apps:
1. Right-click the app → Open (first time only)
2. Or use System Settings → Privacy & Security → Open Anyway
3. This is a one-time approval

### Checksums Don't Match

1. Re-download the files
2. Ensure you downloaded the correct version
3. Check for download interruptions
4. Try a different browser or download method

## CI/CD Best Practices

### Version Numbering

Follow semantic versioning:
- `v1.0.0` - Major release (breaking changes)
- `v1.1.0` - Minor release (new features)
- `v1.1.1` - Patch release (bug fixes)

### Release Process

1. Develop features on feature branches
2. Merge to `develop` for testing
3. CI runs automatically
4. When ready for release:
   - Merge `develop` to `main`
   - Create version tag
   - Workflow builds and creates release
   - Review and publish

### Testing Before Release

1. Let CI run on main branch
2. Verify build succeeds
3. Download build artifacts
4. Test locally
5. Then create release tag

## GitHub Actions Costs

- **Public repositories:** Free unlimited minutes
- **Private repositories:** 2,000 free minutes/month
- **macOS runners:** 10x multiplier
  - 1 minute = 10 minutes toward quota
  - ~200 minutes of macOS builds on free tier

**Current usage:**
- CI builds: ~5 minutes per run
- Release builds: ~8 minutes per run
- Average: ~50 macOS minutes/month (well within free tier)

## Monitoring

View all workflows:
- https://github.com/sidhantchadha/QuickLookIPA/actions

View releases:
- https://github.com/sidhantchadha/QuickLookIPA/releases

Check Action quota (for private repos):
- https://github.com/settings/billing

---

**Questions or Issues?**

Open an issue: https://github.com/sidhantchadha/QuickLookIPA/issues
