# QuickLookIPA

<p align="center">
  <img src="https://img.shields.io/badge/macOS-14.0+-blue.svg" alt="macOS 14.0+">
  <img src="https://img.shields.io/badge/Swift-5.9-orange.svg" alt="Swift 5.9">
  <img src="https://img.shields.io/badge/Xcode-15.0+-blue.svg" alt="Xcode 15.0+">
  <img src="https://img.shields.io/badge/version-1.1.0-green.svg" alt="Version 1.1.0">
  <img src="https://img.shields.io/badge/license-MIT-lightgrey.svg" alt="MIT License">
</p>

A comprehensive macOS application for inspecting, analyzing, and resigning iOS IPA files. Built with SwiftUI, QuickLookIPA provides developers and testers with deep insights into app packages including provisioning profiles, entitlements, code signatures, security analysis, and more.

## Features

### 🔍 Deep IPA Inspection
- **Complete metadata extraction**: App name, bundle ID, version, build number, minimum iOS version
- **Binary analysis**: File sizes, architectures (arm64, x86_64), and binary information
- **App icon extraction**: View and export the app icon in full resolution
- **Frameworks analysis**: List all embedded frameworks with sizes
- **Extensions analysis**: Detect and analyze app extensions (widgets, watch apps, etc.)
- **Localization support**: View all supported languages

### 🔐 Security & Code Signing
- **Provisioning profile parsing**: Extract profile name, team, UUID, type, creation/expiration dates
- **Entitlements inspection**: Comprehensive list of app capabilities with descriptions
- **Code signature verification**: Validate signing status and certificate information
- **Bundle ID validation**: Detect mismatches between Info.plist and provisioning profile
- **Certificate details**: View distribution certificate information and validity

### ✍️ IPA Resigning
- **Replace provisioning profiles**: Select new .mobileprovision files
- **Certificate selection**: Choose from installed code signing certificates
- **Bundle ID modification**: Optionally change the app's bundle identifier
- **Automatic signing**: Signs app bundle, frameworks, and extensions
- **Progress tracking**: Real-time progress updates during resign process
- **Error handling**: Comprehensive error messages for troubleshooting

### 📊 Export & Reporting
- **Multiple export formats**: JSON, Markdown, Plain Text, PDF
- **Formatted reports**: Professional reports with sections and formatting
- **Full data export**: All inspection data included in exports
- **Custom naming**: Auto-generated filenames based on app name

### 📜 Inspection History
- **Persistent storage**: Automatic history of all inspected IPAs
- **Quick re-inspection**: Click any history item to view details again
- **Search & filter**: Find previous inspections quickly
- **Clear history**: Remove all or individual history entries
- **Inspection metadata**: Timestamps and file information

### 🔄 IPA Comparison
- **Side-by-side comparison**: Compare two IPA files in detail
- **Diff visualization**: Highlights differences in versions, certificates, entitlements
- **Version tracking**: Compare different builds of the same app
- **Quick access**: Compare from history or select new files

### 🎨 Modern UI/UX
- **Native macOS design**: Built with SwiftUI for a native feel
- **Dark mode support**: Automatically adapts to system appearance
- **Drag & drop**: Simply drag IPA files onto the window
- **File picker**: Alternative file selection with keyboard shortcut (⌘O)
- **Keyboard shortcuts**: Export (⌘E), History (⌘H), Debug logging (⇧⌘D)
- **Responsive layout**: Adapts to different window sizes

### 🛠 Developer Tools
- **Debug logging**: Toggle detailed logging for troubleshooting
- **Security-scoped resources**: Proper handling of sandboxed file access
- **Background processing**: Non-blocking UI during inspection
- **Error recovery**: Graceful error handling with user-friendly messages
- **Memory efficient**: Handles large IPA files (up to 500MB)

## Installation

### Option 1: Build from Source

1. **Clone the repository:**
```bash
git clone https://github.com/sidhantchadha/QuickLookIPA.git
cd QuickLookIPA
```

2. **Open in Xcode:**
```bash
open QuickLookIPA.xcodeproj
```

3. **Build and run:**
   - Select the QuickLookIPA scheme
   - Choose your target (My Mac)
   - Press ⌘R to build and run

### Option 2: Download Release

Download the latest release from the [Releases](https://github.com/sidhantchadha/QuickLookIPA/releases) page.

## Usage

### Basic Inspection

1. **Launch QuickLookIPA**
2. **Open an IPA file:**
   - Drag and drop an .ipa file onto the window, OR
   - Press ⌘O and select a file, OR
   - Click "New" button in the toolbar
3. **View inspection results** in organized sections:
   - Basic Information
   - Provisioning Profile
   - Entitlements
   - Code Signature
   - Binary Analysis
   - Frameworks & Extensions
   - Security Analysis

### Resigning an IPA

1. **Inspect an IPA** using any method above
2. **Click "Resign" button** in the toolbar
3. **Configure resign options:**
   - Select a provisioning profile (.mobileprovision)
   - Choose a code signing certificate
   - Optionally change the bundle identifier
4. **Click "Resign IPA"** and choose output location
5. **Wait for completion** - progress is shown in real-time
6. **Find your resigned IPA** in the specified location

### Comparing IPAs

1. **Click "Compare" button** in the toolbar
2. **Select two IPA files** to compare
3. **View differences** highlighted in the comparison view:
   - Version changes (green for new, red for old)
   - Certificate differences
   - Entitlement changes
   - Binary architecture differences

### Viewing History

1. **Click "History" in the sidebar** (or press ⌘H)
2. **Click any inspection** to view its details
3. **Search history** using the search field
4. **Clear history** using the purge button

### Exporting Reports

1. **Inspect an IPA**
2. **Click "Export" button** in the toolbar
3. **Choose export format:**
   - JSON: Machine-readable format
   - Markdown: Documentation-friendly format
   - Text: Plain text report
   - PDF: Professional formatted document
4. **Choose save location** and click Save

## Keyboard Shortcuts

| Shortcut | Action |
|----------|--------|
| ⌘O | Open IPA file |
| ⌘E | Export report (JSON) |
| ⇧⌘E | Export as Markdown |
| ⇧⌘P | Export as PDF |
| ⌘H | Show/Hide history |
| ⇧⌘D | Toggle debug logging |
| ⌘W | Close window |
| ⌘Q | Quit application |

## Requirements

- **macOS**: 14.0 (Sonoma) or later
- **Xcode**: 15.0 or later (for building)
- **Swift**: 5.9 or later
- **Architecture**: Apple Silicon (M1/M2/M3) or Intel

### For Resigning IPAs:

- Valid code signing certificate installed in Keychain
- Provisioning profile (.mobileprovision) file
- Xcode Command Line Tools installed

## Technical Details

### Architecture

QuickLookIPA is built using modern Swift and SwiftUI with the following architecture:

- **Services Layer**: Core business logic (IPAInspectorService, ResignService, ExportService)
- **Models**: Data structures (IPAInfo, ProvisioningProfile, Entitlement, etc.)
- **Views**: SwiftUI views (MainView, ResignView, ComparisonView)
- **Managers**: Utilities (HistoryManager for persistence)

### Data Storage

- Inspection history is stored in JSON format at:
  ```
  ~/Library/Application Support/QuickLookIPA/history.json
  ```
- Maximum 50 inspections are kept in history
- Automatic cleanup of old entries

### Security

- Proper handling of security-scoped resources for sandboxed file access
- No network requests - completely offline
- No data collection or telemetry
- File operations use secure temporary directories with automatic cleanup

### Performance

- Background processing for non-blocking UI
- Efficient memory usage for large IPA files
- Maximum IPA size: 500MB
- Lazy loading of inspection data

## Troubleshooting

### "Cannot open IPA file"
- Ensure the file is a valid .ipa file (renamed .zip files may not work)
- Check file permissions - the file must be readable
- Try copying the IPA to a local folder (not on network drive)

### "Failed to extract IPA"
- Verify the IPA is not corrupted (check file size)
- Ensure sufficient disk space for temporary extraction
- Check that unzip utility is available at `/usr/bin/unzip`

### "No provisioning profile found"
- Some IPAs may not contain embedded.mobileprovision (development builds)
- Enterprise or ad-hoc signed IPAs should contain the profile

### Resigning fails
- Verify you have a valid code signing certificate in Keychain
- Check that the provisioning profile matches your certificate
- Ensure Xcode Command Line Tools are installed: `xcode-select --install`
- Check Console.app for detailed codesign error messages

### Export fails
- Ensure you have write permissions to the destination folder
- For PDF export, sufficient memory must be available
- Try exporting to Desktop or Documents folder

## Contributing

Contributions are welcome! Please follow these guidelines:

1. **Fork the repository**
2. **Create a feature branch:**
   ```bash
   git checkout -b feature/AmazingFeature
   ```
3. **Commit your changes:**
   ```bash
   git commit -m 'Add some AmazingFeature'
   ```
4. **Push to the branch:**
   ```bash
   git push origin feature/AmazingFeature
   ```
5. **Open a Pull Request**

### Development Setup

```bash
# Clone the repo
git clone https://github.com/sidhantchadha/QuickLookIPA.git
cd QuickLookIPA

# Open in Xcode
open QuickLookIPA.xcodeproj

# Build and run
# Press ⌘R in Xcode
```

### Code Style

- Follow Swift API Design Guidelines
- Use SwiftUI best practices
- Add comments for complex logic
- Write clear commit messages

## Roadmap

Future features under consideration:

- [ ] Batch IPA processing
- [ ] Advanced filtering and search in history
- [ ] Custom export templates
- [ ] IPA file optimization tools
- [ ] Integration with Xcode
- [ ] Command-line interface (CLI)
- [ ] Automated testing workflows

## Changelog

### Version 1.1.0 (2026-11-21)

- Initial production release
- Complete IPA inspection with 28+ features
- Provisioning profile parsing with security command
- Entitlements extraction using codesign
- IPA resigning with certificate management
- Export to JSON, Markdown, Text, and PDF
- Persistent inspection history with search
- Side-by-side IPA comparison
- Modern SwiftUI interface with dark mode
- Comprehensive error handling and validation

## License

Distributed under the MIT License. See `LICENSE` for more information.

## Author

**Sidhant Chadha**
- GitHub: [@sidhantchadha](https://github.com/sidhantchadha)
- Email: sidhantchadha@example.com

## Acknowledgments

- Built with [SwiftUI](https://developer.apple.com/xcode/swiftui/)
- Uses macOS native tools: `unzip`, `security`, `codesign`, `openssl`
- Inspired by the need for better IPA inspection tools

## Support

If you find this project helpful, please consider:
- ⭐ Starring the repository
- 🐛 Reporting bugs via [Issues](https://github.com/sidhantchadha/QuickLookIPA/issues)
- 💡 Suggesting features via [Issues](https://github.com/sidhantchadha/QuickLookIPA/issues)
- 📖 Contributing to documentation

---

**Made with ❤️ by [Sidhant Chadha](https://github.com/sidhantchadha)**
