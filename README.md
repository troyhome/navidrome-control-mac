# Navidrome Control (Mac)

A small, unofficial Mac app that makes it easy to run [Navidrome](https://www.navidrome.org), the self-hosted music server, without using Terminal.

It is not affiliated with the Navidrome project and does not include any Navidrome code.

## What it does

- First-time setup: installs Navidrome, creates the config, and makes it start automatically at login
- Start, stop and restart the server with buttons
- Open Navidrome in your browser (starts the server first if needed)
- Change the main music folder with a normal folder picker
- Shortcut to Navidrome's own library settings for adding or removing extra folders
- Quick access to the log, config file and data folder

Extra music libraries can only be managed inside Navidrome's web interface, so that button takes you there.

## Install

1. Download `NavidromeControl.dmg` from the Releases page.
2. Open it and drag Navidrome Control into Applications.
3. The first time, right-click the app and choose Open (the app is not signed with a paid Apple developer account).
4. Choose your music folder and click Set Up Navidrome.

First-time setup uses [Homebrew](https://brew.sh) to install Navidrome and ffmpeg. Install Homebrew first if you don't have it.

Requires macOS 13 or later. Works on Apple silicon and Intel Macs.

## Build from source

You need the Xcode Command Line Tools (`xcode-select --install`).

```
bash build.sh --install   # builds and copies the app to /Applications
bash make-dmg.sh          # builds dist/NavidromeControl.dmg
```

## How it works

The app manages a standard macOS background service (a launchd agent named `com.navidrome`) and a config file at `~/navidrome/navidrome.toml`. Navidrome's web interface runs at http://localhost:4533.

## License

MIT. Navidrome itself is a separate project with its own license.
