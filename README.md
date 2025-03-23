# QuickLookIPA

QuickLookIPA is a handy macOS Quick Look plugin that enables you to preview `.ipa` files directly from Finder, simplifying the workflow for iOS developers and testers.

## Features

- Quick Look integration for `.ipa` files
- Preview app icons, metadata, and essential details
- Improve efficiency by eliminating the need to open external tools

## Installation

1. **Clone this repository:**

```bash
git clone https://github.com/sidhantchadha/QuickLookIPA.git
```

2. **Navigate to the cloned directory and build:**

```bash
cd QuickLookIPA
xcodebuild
```

3. **Copy the generated plugin to the QuickLook folder:**

```bash
cp -r build/Release/QuickLookIPA.qlgenerator ~/Library/QuickLook/
```

4. **Refresh Quick Look:**

```bash
qlmanage -r
qlmanage -r cache
```

## Usage

Once installed, simply select any `.ipa` file in Finder and hit the **spacebar** to preview app details.

## Compatibility

- macOS 10.15+ (Catalina, Big Sur, Monterey, Ventura, Sonoma)
- Xcode 13+

## Contributions

Contributions and suggestions are always welcome!

- Fork the repository
- Create a branch (`git checkout -b feature/AmazingFeature`)
- Commit changes (`git commit -m 'Add amazing feature'`)
- Push to your branch (`git push origin feature/AmazingFeature`)
- Open a Pull Request

## License

Distributed under the MIT License. See `LICENSE` for more information.

## Author

[Sidhant Chadha](https://github.com/sidhantchadha)

