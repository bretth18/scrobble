# Scrobble for macOS

A macOS menu bar application that scrobbles music via the system player to Last.fm.

## Info

Scrobble was created from a desire to create a reliable, minimal scrobbler for macOS. Before macOS Tahoe, audio track metadata from Apple Music was available via AppleScript calls. This application now utilizes a workaround to access the private `MediaRemote.framework` to access the current track information.



## Development

### Prerequisites
- Xcode 15+ (Swift 5.9+)

### Setup
1. Clone the repository.
2. Run `make setup` to generate a dummy `Secrets.swift`.
3. Open `scrobble.xcodeproj`.

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
You must set the following repository secrets:
- `LASTFM_API_KEY`
- `LASTFM_API_SECRET`
