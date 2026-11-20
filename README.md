# Petri

iOS app (SwiftUI, iOS 26.2+) that turns the germs a kid brings home from daycare into a card collection for the parent. English and French.

## Build

**Build IPA** runs on demand: on github.com, open **Actions > Build IPA > Run workflow**. A push does not start it. The run attaches `Petri-ipa-<run>`, an unsigned IPA for sideloading.

The workflow, in order:

1. `tools/check_repo.py` and `tools/check_swift.py`: the repository is complete and consistent.
2. `server/test.js`: crew server tests.
3. `tools/run_logic_tests.sh`: journal rules, streaks, badges, levels, skill tree, milestones, couple duel, season story, stats and journal decoding, compiled and run on the build machine. It does not stop the build.
4. A type check of every Swift file, when the **typecheck** box is ticked. It does not stop the build; it lists all compiler errors at once in the step log and in `build-logs-<run>`.
5. `tools/check_links.py`: requests every source link shown in the app. A site that refuses scripts is listed as blocked, which means not verified. Informational.
6. XcodeGen generates `Petri.xcodeproj` from `project.yml`, then `xcodebuild` builds without signing.
7. `tools/check_bundle.py` inspects the built app, then the IPA is packaged.

**Release to TestFlight** is a manual workflow. Setup is in `docs/APP-STORE.md`.

## Layout

| Path | Contents |
| --- | --- |
| `App/` | App target: models, store, services, design system, screens, App Intents |
| `App/Content/` | `germs.json`, `articles.json`, `legal.json` |
| `Shared/` | Code and strings compiled into both targets |
| `Widgets/` | Widget extension: streak widget, incubation widget, Live Activity |
| `server/` | Crew server and legal pages (Node, no dependencies) |
| `Tests/LogicTests/` | Logic checks that run without a simulator |
| `tools/` | Repository, source, bundle and link checks |
| `project.yml` | XcodeGen project definition |

## Configuration

Set in `App/Info.plist`:

| Key | Purpose |
| --- | --- |
| `PetriServerURL` | Base URL of the deployed crew server. While it holds the placeholder, Crew shows as offline. |
| `PetriSupportEmail` | Contact address shown in Settings, the legal screens and Crew. |
| `PetriPublisherName` | Person or company that publishes the app, named in the legal screens. |
| `PetriShareURL` | Page the QR code on every share card opens, normally `<server>/get`. While it holds the placeholder, cards carry no QR code. |
| `PetriCrewEnabled` | `false` removes the Crew tab and its settings. |

The app opens `petri://log` (log sheet) and `petri://today`. The streak widget uses them.

Sideload builds are compiled with `PETRI_SIDELOAD`, which adds a Season Pass switch in Settings. Release builds do not have it.

Widgets read a snapshot from the app group `group.ca.petri.app`. An unsigned or re-signed build has no app group, so its widgets stay empty.

## Journal

The journal is one JSON file in Application Support. Decoding is tolerant: a key missing from the file takes its default, and unknown keys are ignored, so a journal written by another version still loads. A file that cannot be decoded is renamed `journal-unreadable-<time>.json`, never overwritten, and can be exported from Settings > Your Data.

When a stored type changes, add the new field with a default in its `init(from:)` in `App/Models/AppData.swift` and extend `Tests/LogicTests/main.swift`.

Settings > Your Data > Back Up shares the journal as `petri-backup.json`, in the same format as the file on disk. Restore reads such a file back and replaces the journal after a confirmation.

Skill tree titles, streak milestones, the couple duel and the season story are computed from the journal in `App/Store/ProgressEngine.swift`; only the worn title and the last celebrated milestone are stored.

The Lab's daily quiz is built in `App/Store/QuizEngine.swift` from the myths, boss attacks and timings in `germs.json`. The journal keeps only the day's round, the questions asked or missed, the days done and the count of right answers, which unlocks the lessons and adds points.

## Text

User-facing strings go through `tr("English text")`. The English text is the key in `Shared/en.lproj` and `Shared/fr.lproj`. A string missing from either file, or no longer used, fails `check_swift.py`.

Germ and article text is bilingual inside the JSON files. A germ's `about`, `symptoms` and `spreads` restate its listed sources only; a list stays empty when the sources say nothing on the subject.

## Colors

Every color value lives in `Shared/Swatch.swift`, shared by the app and the widgets. Roles that follow the theme, Dark Mode and Increase Contrast (text levels, success, progress, crown) are resolved in `App/Design/Palette.swift`. A color value written anywhere else, or a swatch no longer used, fails `check_swift.py`.

## Crew server

```
cd server
node server.js
node test.js
```

| Variable | Purpose |
| --- | --- |
| `PORT` | Listening port. Default 8080. |
| `DATA_DIR` | Folder for `petri.json`. Must be on a persistent disk, or crews are lost on restart. With `NODE_ENV=production` the server refuses to start without it. |
| `ADMIN_TOKEN` | Unlocks the moderation page and its endpoints. |
| `SUPPORT_EMAIL` | Contact shown on `/support`, `/privacy` and `/terms`. |
| `PUBLISHER_NAME` | Publisher named on `/privacy` and `/terms`. |
| `APP_STORE_URL` | App Store link shown on the landing page (`/` and `/get`). Until it is set, the page says the app is coming soon. |
| `TRUST_PROXY_HOPS` | Number of reverse proxies in front of the server. Default 0: the socket address is used and `X-Forwarded-For` is ignored. Most hosts need 1. |
| `BLOCKED_WORDS` | Extra comma-separated words rejected in names. |

Rate limits are counted per client address, so `TRUST_PROXY_HOPS` must match the host: too low and every user shares one limit, too high and a client can forge its address.

Moderation: open `<server>/admin` in a browser, type the admin token, then remove a member or dismiss the reports about them. Removing a member also gives the crew a new invite code, so the old code no longer lets anyone in.

Retention: shared germs older than 400 days, members who have not connected for 400 days and empty crews are removed automatically. One address can create 5 crews a day.

`server/legal.json` must stay identical to `App/Content/legal.json`. It also holds the text of the web pages.
