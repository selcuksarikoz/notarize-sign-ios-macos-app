# macOS Application Notarization and Signing Guide

This guide explains how to use the two provided scripts for signing and notarizing macOS applications.

## Prerequisites

- macOS development environment
- Xcode command line tools installed (`xcode-select --install`)
- Apple Developer account
- App-specific password (create at [appleid.apple.com](https://appleid.apple.com))
- Team ID (from Apple Developer portal)
- Developer ID Application certificate installed in Keychain

## Script 1: `notarize_app.sh` (Notarization Only)

Use this script when your app is already signed and just needs notarization.

### Usage Steps:

1. **Make the script executable**:
   ```bash
   chmod +x notarize.sh
   or
   chmod +x sign.sh
2. **How use them?**
   ```sh sign.sh``` or ```sh notarize.sh```

### **notarize.sh script just notarized your app on apple server
### **sign.sh file sign and notarized your app, and get back status