# Petri

iOS app (SwiftUI, iOS 26.2+) that turns the germs a kid brings home from daycare into a card collection for the parent. English and French.

## Build

Every push to `main` runs **Build IPA** on GitHub Actions and attaches `Petri-ipa-<run>` to the run. The IPA is unsigned, for sideloading.

The workflow, in order:

1. `tools/check_repo.py` and `tools/check_swift.py`: the repository is complete and consistent.
2. `server/test.js`: crew server tests.
3. A type check of every Swift file. It does not stop the build; it lists all compiler errors at once in the step log and in `build-logs-<run>`.
4. `tools/check_links.py`: requests every source link shown in the app. Informational.
5. XcodeGen generates `Petri.xcodeproj` from `project.yml`, then `xcodebuild` builds without signing.
6. `tools/check_bundle.py` inspects the built app, then the IPA is packaged.

**Release to TestFlight** is a manual workflow. Setup is in `docs/APP-STORE.md`.

## Layout

| Path | Contents |
| --- | --- |
| `App/` | App target: models, store, services, design system, screens, App Intents |
| `App/Content/` | `germs.json`, `articles.json`, `legal.json` |
| `Shared/` | Code and strings compiled into both targets |
| `Widgets/` | Widget extension: streak widget, incubation widget, Live Activity |
| `server/` | Crew server and legal pages (Node, no dependencies) |
| `tools/` | Repository, source, bundle and link checks |
| `project.yml` | XcodeGen project definition |

## Configuration

Set in `App/Info.plist`:

| Key | Purpose |
| --- | --- |
| `PetriServerURL` | Base URL of the deployed crew server. While it holds the placeholder, Crew shows as offline. |
| `PetriSupportEmail` | Contact address shown in Settings, the legal screens and Crew. |
| `PetriCrewEnabled` | `false` removes the Crew tab and its settings. |

Sideload builds are compiled with `PETRI_SIDELOAD`, which adds a Season Pass switch in Settings. Release builds do not have it.

Widgets read a snapshot from the app group `group.ca.petri.app`. An unsigned or re-signed build has no app group, so its widgets stay empty.

## Text

User-facing strings go through `tr("English text")`. The English text is the key in `Shared/en.lproj` and `Shared/fr.lproj`. A string missing from either file, or no longer used, fails `check_swift.py`.

Germ and article text is bilingual inside the JSON files.

## Crew server

```
cd server
node server.js
node test.js
```

| Variable | Purpose |
| --- | --- |
| `PORT` | Listening port. Default 8080. |
| `DATA_DIR` | Folder for `petri.json`. Must be on a persistent disk, or crews are lost on restart. |
| `ADMIN_TOKEN` | Enables `/admin/reports` and `/admin/members/<id>/remove` or `/clear`. |
| `SUPPORT_EMAIL` | Contact shown on `/support`, `/privacy` and `/terms`. |
| `BLOCKED_WORDS` | Extra comma-separated words rejected in names. |

`server/legal.json` must stay identical to `App/Content/legal.json`.
