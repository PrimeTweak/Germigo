# Germigo

iOS app (SwiftUI, iOS 26.2+) that turns the germs a kid brings home from daycare into a card collection for the parent. English and French.

## Build

**Build IPA** runs on demand: on github.com, open **Actions > Build IPA > Run workflow**. A push does not start it. The run attaches `Germigo-ipa-<run>`, an unsigned IPA for sideloading.

The workflow, in order:

1. `tools/check_repo.py` and `tools/check_swift.py`: the repository is complete and consistent.
2. `server/test.js`: crew server tests.
3. `tools/run_logic_tests.sh`: journal rules, streaks, badges, levels, skill tree, milestones, couple duel, family league, season story, stats and journal decoding, compiled and run on the build machine. It does not stop the build.
4. A type check of every Swift file, when the **typecheck** box is ticked. It does not stop the build; it lists all compiler errors at once in the step log and in `build-logs-<run>`.
5. `tools/check_links.py`: requests every source link shown in the app. A site that refuses scripts is listed as blocked, which means not verified. Informational.
6. XcodeGen generates `Germigo.xcodeproj` from `project.yml`, then `xcodebuild` builds without signing.
7. `tools/check_bundle.py` inspects the built app, then the IPA is packaged.

**Release to TestFlight** is a manual workflow. Setup is in `docs/APP-STORE.md`.

## Layout

| Path | Contents |
| --- | --- |
| `App/` | App target: models, store, services, design system, screens, App Intents |
| `App/Content/` | `germs.json`, `articles.json`, `legal.json` |
| `Shared/` | Code and strings compiled into both targets |
| `Widgets/` | Widget extension: streak widget, incubation widget, Live Activity |
| `server/` | Crew server, daycare notices and legal pages (Node, no dependencies) |
| `Tests/LogicTests/` | Logic checks that run without a simulator |
| `tools/` | Repository, source, bundle and link checks |
| `project.yml` | XcodeGen project definition |
| `CLAUDE.md`, `.claude/` | Instructions, path rules, skills and guards for Claude Code |

## Configuration

Set in `App/Info.plist`:

| Key | Purpose |
| --- | --- |
| `GermigoServerURL` | Base URL of the deployed crew server. While it holds the placeholder, Crew shows as offline. |
| `GermigoSupportEmail` | Contact address shown in Settings, the legal screens and Crew. |
| `GermigoPublisherName` | Person or company that publishes the app, named in the legal screens. |
| `GermigoShareURL` | Page the QR code on every share card opens, normally `<server>/get`. While it holds the placeholder, cards carry no QR code. |
| `GermigoLessonsURL` | https address of the online lesson file (see `docs/LESSONS.md`). While it holds the placeholder, the Guide shows only the bundled lessons. |
| `GermigoCrewEnabled` | `false` removes the Crew tab and its settings. |

The app opens `germigo://log` (log sheet) and `germigo://today`. The streak widget uses them.

Sideload builds are compiled with `GERMIGO_SIDELOAD`, which adds a Season Pass switch in Settings and, while `GermigoServerURL` holds the placeholder, a sample crew kept in memory. Release builds have neither.

Widgets read a snapshot from the app group `group.ca.germigo.app`. An unsigned or re-signed build has no app group, so its widgets stay empty.

## Journal

The journal is one JSON file in Application Support. Decoding is tolerant: a key missing from the file takes its default, and unknown keys are ignored, so a journal written by another version still loads. A file that cannot be decoded is renamed `journal-unreadable-<time>.json`, never overwritten, and can be exported from Settings > Your Data.

Photos are JPEG files in `Application Support/Germigo/Photos`, named by the id the journal lists them under.

When a stored type changes, add the new field with a default in its `init(from:)` in `App/Models/AppData.swift` and extend `Tests/LogicTests/main.swift`.

Settings > Back up now (also in Data and privacy) shares the journal as `germigo-backup.json`: the same format as the file on disk, plus the photo files as base64 under `photoFiles`. Restore a backup reads such a file back and replaces the journal and its photos after a confirmation.

Skill tree titles, streak milestones, the couple duel and the season story are computed from the journal in `App/Store/ProgressEngine.swift`; only the worn title and the last celebrated milestone are stored.

The household's characters are the images `buddy-<n>-well` and `buddy-<n>-sick`. A kid's `colorIndex` picks one, as do the journal's `hostLook` and `partnerLook`.

The Guide tab (`App/Screens/LabScreen.swift`) holds the search, the daily quiz, the week's germ, myth and lesson, the illnesses shelved by part of the body, and the lessons. What it has already revealed and the answer to the week's myth are kept in `UserDefaults` under `GuideKeys`, outside the journal and its backup. The daily quiz is built in `App/Store/QuizEngine.swift` from the myths, boss attacks and timings in `germs.json`. The journal keeps only the day's round, the questions asked or missed, the days done and the count of right answers, which unlocks the lessons and adds points.

## Text

User-facing strings go through `tr("English text")`. The English text is the key in `Shared/en.lproj` and `Shared/fr.lproj`. A string missing from either file, or no longer used, fails `check_swift.py`.

Germ and article text is bilingual inside the JSON files. A germ's `about`, `symptoms` and `spreads` restate its listed sources only; a list stays empty when the sources say nothing on the subject. A symptom line may carry `tags`, the signs of the symptom pages it stands for; `App/Store/SymptomEngine.swift` ranks the germs by the tags they share with the ticked signs.

## Colors

Every color value lives in `Shared/Swatch.swift`, shared by the app and the widgets. The interface stays neutral with one accent: the roles that follow the theme, Dark Mode and Increase Contrast (surfaces, text levels, accent) are resolved in `App/Design/Palette.swift`. A color value written anywhere else, or a swatch no longer used, fails `check_swift.py`.

## Crew server

```
cd server
node server.js
node test.js
```

| Variable | Purpose |
| --- | --- |
| `PORT` | Listening port. Default 8080. |
| `DATA_DIR` | Folder for `germigo.json`. Must be on a persistent disk, or crews are lost on restart. With `NODE_ENV=production` the server refuses to start without it. |
| `ADMIN_TOKEN` | Unlocks the moderation page and its endpoints. |
| `SUPPORT_EMAIL` | Contact shown on `/support`, `/privacy` and `/terms`. |
| `PUBLISHER_NAME` | Publisher named on `/privacy` and `/terms`. |
| `APP_STORE_URL` | App Store link shown on the landing page (`/` and `/get`). Until it is set, the page says the app is coming soon. |
| `TRUST_PROXY_HOPS` | Number of reverse proxies in front of the server. Default 0: the socket address is used and `X-Forwarded-For` is ignored. Most hosts need 1. |
| `BLOCKED_WORDS` | Extra comma-separated words rejected in names. |
| `APNS_KEY`, `APNS_KEY_ID`, `APNS_TEAM_ID` | The Apple push key (`.p8` content, newlines may be written `\n`), its key ID and the team ID. Without them, daycare notices are stored but no push is sent. |
| `APNS_TOPIC` | Bundle identifier the pushes are for. Default `ca.germigo.app`. |
| `APNS_ENV` | `sandbox` for builds run from Xcode. TestFlight and App Store builds use the default, production. |
| `POSTMARK_TOKEN`, `MAIL_FROM` | Postmark server token and sender address for the replies to daycares that send notices by email. |
| `INBOUND_EMAIL_DOMAIN` | Domain of the daycares' private addresses, for example `notices.germigo.app`. Without it, notices by email are off. |
| `INBOUND_EMAIL_TOKEN` | Secret in the inbound webhook URL. |

Rate limits are counted per client address, so `TRUST_PROXY_HOPS` must match the host: too low and every user shares one limit, too high and a client can forge its address.

Moderation: open `<server>/admin` in a browser, type the admin token, then remove a member or dismiss the reports about them. Removing a member also gives the crew a new invite code, so the old code no longer lets anyone in.

Retention: shared germs older than 400 days, members who have not connected for 400 days and empty crews are removed automatically. One address can create 5 crews a day.

`server/legal.json` must stay identical to `App/Content/legal.json`. It also holds the text of the web pages.

## Daycare notices

Free for daycares and families, inside the Crew tab and outside the Season Pass. A director signs the daycare up from the app (I run a daycare), with up to 12 groups. Families join with the daycare's code, typed or scanned, and pick each kid's group; which kid is in which group stays on the phone, and the server keeps only the groups chosen, the push address and the language. A notice names an illness from the catalog, a group or the whole daycare, and an optional note of up to 280 characters.

- **From the app.** Daycare mode > Send a notice. Each family it reaches gets a push titled with the daycare's name.
- **By email.** Each daycare gets a private address on `INBOUND_EMAIL_DOMAIN`. Only mail from the address the director saved is used. The subject gives the illness, then the group (`Gastro - Trottineurs`); without a group, the notice goes to the whole daycare. The server always replies: sent to how many families, or what was unclear. Point the domain's MX record to Postmark, and set the inbound webhook to `<server>/v1/inbound-email?token=<INBOUND_EMAIL_TOKEN>`.
- **Poster.** The daycare's QR code opens `<server>/d/<code>`, a page with the code and how to join.

Limits: 10 notices a day per daycare, 3 daycares a day per address. Reported notices appear on the moderation page, where a notice or a whole daycare can be removed. Notices older than 400 days, and daycares and subscriptions not opened for 400 days, are removed automatically. `server/illnesses.json` holds the illness names read in subjects and written in pushes; its names must match `germs.json`.

