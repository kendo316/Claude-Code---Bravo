# Finders Keepers

A private iPhone app for the screenshots you take and then lose. It reads your Screenshots album directly, lets you search the words inside them, and once a week walks you through your oldest 25: keep, delete, or next week.

Everything happens on the phone. There is no account, no server and no tracking, and the app contains no networking code.

## What it does

- **Pile.** Every screenshot, newest first. Search covers titles and the text inside the images. Filter by group. Screenshots that mention a day still to come float to the top.
- **Weekly look.** The oldest screenshots that are due, one at a time. Swipe right to keep, left to delete, up for next week, or use the buttons. Undo is always there.
- **Deleting is real, and safe.** Deleted screenshots go to Photos' Recently Deleted for 30 days. iOS asks once for the whole batch.
- **Reading.** Apple Vision finds the text. The system data detector finds dates, addresses and links. Apple Intelligence, on the phone, writes a title and picks a group.
- **Ask.** Ask a plain question and get an answer from the screenshots most likely to know.
- **Reminder.** An optional weekly notification, on the day and time you choose.

## How the code is laid out

| Folder | What lives there |
| --- | --- |
| `FindersKeepers/Core` | The rules, in plain Swift with no Apple UI or Photos code: what is due, how dates are read, search, the saved file's shape. Covered by tests. |
| `FindersKeepers/Services` | The only code that talks to Photos, Vision, the on-device model, notifications and the disk. |
| `FindersKeepers/Store.swift` | The single source of truth the screens read from. |
| `FindersKeepers/Views` | The screens. |
| `Tests/FKCoreTests` | Tests for Core. Run with `swift test`. |
| `tools` | Scripts that generate the Xcode project, the icon and the made-up test screenshots, and run the app in a simulator. |

## Checks that run on every change

`.github/workflows/build.yml` runs on GitHub's Mac servers:

1. `swift test` on the core rules.
2. A full compile for iPhone in the Swift 6 language mode, where data-race mistakes are compile errors.
3. A release archive, exactly as the TestFlight workflow builds it.
4. A run in an iPhone simulator with six made-up screenshots, saving a picture of each screen.

## Getting it onto a phone

**With an M-series Mac:** open `FindersKeepers.xcodeproj` in Xcode 27 or later, choose your team under Signing & Capabilities, plug in the phone, press Run.

**Without a Mac:** `.github/workflows/testflight.yml` builds, signs and uploads to TestFlight when the branch `finders-keepers-release` is pushed. It needs an Apple Developer Program membership and four repository secrets:

| Secret | Value |
| --- | --- |
| `APPLE_TEAM_ID` | Your 10-character Team ID |
| `ASC_KEY_ID` | App Store Connect API key ID (Team key, Admin role) |
| `ASC_ISSUER_ID` | The Issuer ID shown above the key list |
| `ASC_KEY_P8` | The full contents of the downloaded `.p8` file |

## Privacy and safety notes

- No network code. The app imports no networking APIs and declares no network entitlements.
- One permission: Photos. Calendar events are added through Apple's own event sheet, which needs no calendar access.
- Saved data is one JSON file in the app's private container, written with iOS complete file protection (encrypted while the phone is locked).
- Text found in screenshots is treated as material to describe. The prompts tell the model so, and the model has no tools, so a screenshot cannot make the app do anything.
- No third-party packages.
