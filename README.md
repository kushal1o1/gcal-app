<p align="center">
  <img src="android/app/src/main/res/mipmap-xxxhdpi/ic_launcher.png" width="96" alt="gcal app icon">
</p>

<h1 align="center">gcal</h1>

<p align="center">Voice reminders for Google Calendar. Tap the mic, speak, done.</p>

> A lightweight Flutter client for [gcal-svr](https://github.com/kushal1o1/gcal-server). The app only handles the interface. Built with assistance from Claude.

The app records your speech, sends the text to a server, and shows a preview.
The server turns the phrase into a Google Calendar event, and Google handles the
reminders and notifications.

## Features

- **Voice input** with a preview before anything is created
- **Urgent and repeating** reminders, shown as tags in the preview
- **Upcoming events** with load-more, filters, bulk delete, and reminder editing
- **Offline drafts:** reminders created without a connection are queued and synced later
- **Home-screen widget** showing your next three events

## Install

Download the APK from the [landing page](https://kushal1o1.github.io/gcal-app/) or
the [latest release](https://github.com/kushal1o1/gcal-app/releases/latest).

| File | For |
|---|---|
| `gcal-arm64-v8a.apk` | most phones (64-bit ARM) |
| `gcal-armeabi-v7a.apk` | older 32-bit phones |
| `gcal-x86_64.apk` | emulators and x86 devices |

Open the file and allow installs from your browser when Android asks.

## Setup

The app needs two values, entered in its **Settings** screen:

- **Server URL:** the base URL of a running `gcal-svr`
- **API token:** the `API_TOKEN` set on that server

Do not share either value publicly. Anyone with both can add and delete events on
the calendar the server writes to. See the [server README](https://github.com/kushal1o1/gcal-server)
to run your own copy.

## Permissions

- `INTERNET`: talks to your server
- `RECORD_AUDIO`: speech input

## Build from source

Requires Flutter (stable) and Java 17.

```bash
flutter pub get
flutter run                          # run on a connected device or emulator
flutter build apk --release --split-per-abi
```

CI builds the same APKs on every push and attaches them to tagged releases. See
[`.github/workflows/android.yml`](.github/workflows/android.yml).

## Related projects

- [gcal-svr](https://github.com/kushal1o1/gcal-server): the server this app calls
- [gcal](https://github.com/kushal1o1/gcal): the original Python CLI

## Platform

Android only for now.
