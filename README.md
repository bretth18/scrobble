# scrobble

A macOS menu bar application that scrobbles music via the system player to Last.fm.

## Info

Scrobble was created from a desire to create a reliable, minimal scrobbler for macOS, compatible with Apple Music. This application utilizes a workaround to access the private `MediaRemote.framework` to read the current track information from the system.


## Screenshots

<img width="200" height="200" alt="scrobblescreenshot1" src="https://github.com/user-attachments/assets/9581e9cf-2447-4a02-907e-c244f39d2642" />



## Installation

### Prerequisites
- macOS 15+
- Last.fm account

### From GitHub Releases

1. Download the latest release from the [Releases](https://github.com/bretth18/scrobble/releases) page.
2. Move the `Scrobble.app` to your Applications folder.
3. Open the app. You may need to approve it in System Preferences > Security & Privacy > General.

## Authentication
1. Open the settings window from the menu bar (or `CMD,` with the app focused).
2. Enter your Last.fm username and click "Authenticate".
3. A browser window will open; log in to Last.fm and authorize the app.
4. Retry authentication if needed.


## Development

### Prerequisites
- Xcode 15+ (Swift 5.9+)

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
Run `make build` or use Xcode.

### CI/CD
GitHub Actions is configured to build and release the app on push to `main`.
