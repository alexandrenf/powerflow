# Powerflow

![Powerflow Screenshot](https://raw.githubusercontent.com/lzt1008/powerflow/assets/screenshot.png)

Powerflow is a macOS application designed to monitor the **power usage** and **charging status** of your devices. With Powerflow, you can gain insights into your device's power consumption.

## Features

- 🖥️ **Monitoring**: Monitor your Mac and iOS devices power consumption and charging status in real-time.
- 📊 **Detailed Insights**: View historical power usage and charging trends.
- 🚀 **Lightweight and Fast**: Designed with performance in mind for seamless operation.

## Development (Swift / macOS)

Powerflow **0.3+** is a native **SwiftUI** app. The legacy Tauri/Vue/Rust code remains in the repo for reference during migration.

### Requirements

- macOS 14+
- Xcode 15+ (Xcode 27 recommended for macOS 27)

### Build & run

```bash
brew install xcodegen   # once
cd Powerflow
xcodegen generate
open Powerflow.xcodeproj
```

Or from the command line:

```bash
cd Powerflow
xcodegen generate
xcodebuild -scheme Powerflow -configuration Debug -destination 'platform=macOS' build
open ~/Library/Developer/Xcode/DerivedData/*/Build/Products/Debug/Powerflow.app
```

### Legacy Tauri app

The previous stack (`src-tauri/`, `src/`, `pnpm`) is deprecated. It does not run on macOS 26+ due to outdated Tauri/wry dependencies.

---

## Installation

### Manual Installation
1. Download the latest `.dmg` file from the [Releases](https://github.com/lzt1008/powerflow/releases) page.
2. Open the `.dmg` file and drag the Powerflow app to your Applications folder.
3. If you encounter an error, try the following steps:
- Open **System Preferences** > **Security & Privacy**.
- In the **General** tab, you will see a message about Powerflow being blocked.
- Click **"Open Anyway"**.
- Confirm the dialog that appears by clicking **"Open"**.

### Install via Homebrew

Open your terminal and run the following command:

```bash
brew tap lzt1008/powerflow
brew install --cask powerflow
```

## Contributing

We welcome contributions! Here's how you can help:

1. Fork the repository.
2. Create a new branch for your feature or bugfix.
3. Commit your changes and push them to your branch.
4. Create a pull request for review.

## License

Powerflow is released under the [MIT License](https://github.com/lzt1008/powerflow/blob/main/LICENSE). Feel free to use, modify, and distribute this software as per the license terms.

## Feedback and Support

We'd love to hear from you! If you have any feedback, issues, or suggestions, please [open an issue](https://github.com/lzt1008/powerflow/issues) on GitHub

Thank you for using Powerflow! 🚀
