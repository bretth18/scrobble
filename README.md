# scrobble

A macOS menu bar application that scrobbles music via the system player to Last.fm.

## Info

Scrobble was created from a desire to create a reliable, minimal scrobbler for macOS, compatible with Apple Music. This application utilizes a workaround to access the private `MediaRemote.framework` to read the current track information from the system.


[![Release](https://github.com/bretth18/scrobble/actions/workflows/release.yml/badge.svg)](https://github.com/bretth18/scrobble/actions/workflows/release.yml)[![Nightly Build](https://github.com/bretth18/scrobble/actions/workflows/nightly.yml/badge.svg)](https://github.com/bretth18/scrobble/actions/workflows/nightly.yml)



## Screenshots

<img width="200" height="200" alt="scrobblescreenshot1" src="https://github.com/user-attachments/assets/9581e9cf-2447-4a02-907e-c244f39d2642" />

<img width="200" height="200" alt="scrobblesceenshot2" src="https://github.com/user-attachments/assets/5f6807fb-c066-4281-a252-da6616379b0c" />


## Installation

### Prerequisites
- macOS 26+
- Last.fm account

### From GitHub Releases

1. Download the latest release from the [Releases](https://github.com/bretth18/scrobble/releases) page. Unsigned builds are available in from the `.zip` assets. It's recommended to use the `.pkg` signed installer for ease of use.
2. Open the app. You may need to approve it in System Preferences > Security & Privacy > General.

## Authentication
1. Open the settings window from the menu bar (or `CMD,` with the app focused).
2. Enter your Last.fm username and click "Authenticate".
3. A browser window will open; log in to Last.fm and authorize the app.
4. Retry authentication if needed.

## Uninstallation
1. Quit the app.
2. Delete the app from the Applications folder.

## Features
- Scrobble music from the system player (Apple Music, Spotify, etc.) to Last.fm.
- Menu bar interface with current track info, source selection and friends listening activity.


## Contributing
Contributions are welcome, Please open an issue or submit a pull request.

### Reporting Issues
If you encounter any bugs or have feature requests, please open an issue on the [GitHub Issues](https://github.com/bretth18/scrobble/issues) page.


## Development

### Prerequisites
- Xcode 15+ (Swift 6.x)

### Setup
1. Clone the repository.
2. Open `scrobble.xcodeproj`.

### Secrets
To work with the real API, create a file named `Configs/Secrets.xcconfig` (this file is gitignored) and add your keys:
```xcconfig
LASTFM_API_KEY = your_api_key_here
LASTFM_API_SECRET = your_api_secret_here
```
The app reads these values via `Info.plist` at build time.

### Build
Run `xcodebuild` or use Xcode.

### CI/CD
GitHub Actions is configured to build and release the app on push to `main`.


## License
See [LICENSE](LICENSE)
