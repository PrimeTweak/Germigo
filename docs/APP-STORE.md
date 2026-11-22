# App Store checklist

What the code already covers, what has to be done in App Store Connect, and what is still open.
Guideline numbers refer to the App Review Guidelines: https://developer.apple.com/app-store/review/guidelines/

## 1. Covered in the repository

| Requirement | How it is met | Where |
| --- | --- | --- |
| Built with Xcode 26 and the iOS 26 SDK (required since April 28, 2026) | Workflows run on `macos-26`; `check_bundle.py` prints the SDK used | `.github/workflows/` |
| Privacy manifest, one per binary | No tracking, UserDefaults reason `CA92.1`, collected data declared | `App/PrivacyInfo.xcprivacy`, `Widgets/PrivacyInfo.xcprivacy` |
| Export compliance | `ITSAppUsesNonExemptEncryption` is `false` (HTTPS only) | `App/Info.plist` |
| 1.2 User-generated content: filter | Crew, display, daycare and group names are filtered server-side | `server/server.js` (`cleanName`) |
| 1.2: report | Report menu on every member, feed item and daycare notice; two reporters hide a name until reviewed, a reported notice leaves the reporter's phone | `CrewScreen.swift`, `DaycareScreens.swift`, `server/server.js` |
| 1.2: block | Block hides a member and their posts on the device; leaving a daycare stops its notices | `CrewStore.block`, `DaycareStore.leave` |
| 1.2: terms with no tolerance for abuse | Rules must be accepted before creating or joining a crew, and before signing a daycare up | `CrewJoinView`, `DaycareSetupSheet`, `legal.json` |
| 1.2: published contact | Support address in Settings, legal screens and Crew | `GermigoSupportEmail` |
| 1.4.1 Medical information | General information only, sources linked on every card, "not medical advice" on each screen, no diagnosis or dosing | `germs.json`, `GermDetailScreen.swift` |
| 2.1 Completeness | No placeholder may ship: `check_repo.py --release` fails on them | `tools/check_repo.py` |
| 2.5.4 Background modes | `fetch` only, used to refresh the crew radar | `App/Info.plist` |
| 4.5.4 Push notifications | Used only for daycare notices the family subscribed to; permission is asked when joining a daycare; no marketing | `PushRegistrar.swift`, `server/push.js` |
| 3.1.1 In-app purchase | The Season Pass and the tip jar are sold through StoreKit only; tips unlock nothing | `PurchaseManager.swift`, `SettingsScreen.swift` |
| 3.1.2 Subscription disclosure | Name, period, full price most prominent, trial length and price after it, auto-renewal, Restore, Terms, Privacy | `PaywallView.swift` |
| 3.1.2 Manage subscription | Settings opens the system subscription sheet | `SettingsScreen.swift` |
| 4.6 Alternate icons | Changed only by the user, from Settings | `SettingsDetailScreens.swift` |
| 5.1.1(i) Privacy policy | In the app (offline) and on the server at `/privacy` | `LegalScreen.swift`, `server/server.js` |
| Purpose strings | Camera (photos for the sick history, scanning a daycare's code), and photo library (add only), in English and French. Picking photos uses the system picker, which needs no permission. | `App/*/InfoPlist.strings` |
| 5.1.1(v) Accounts | No account or sign-in. Leaving a crew or a daycare, or closing a daycare, deletes the server data. Delete everything erases the device data and what this phone put on the server. | `CrewStore.leave`, `DaycareStore`, `AppModel.eraseEverything` |
| 5.1.2 Data use | No ads, trackers or third-party SDKs | whole app |
| 5.1.3(ii) Health data and iCloud | The journal is a local file. iCloud and HealthKit are not used. A backup is a file the user saves where they choose. | `Persistence.swift`, `SettingsScreen.swift` |
| Accessibility | Labels on custom controls, system text styles for reading text, Reduce Motion honored | screens |

## 2. To do before the first upload

1. **Apple Developer Program.** Enrollment is required for TestFlight and the App Store.
2. **Bundle identifier.** `ca.germigo.app` must be available to the account. If it is not, change it in `project.yml` (both targets), both `.entitlements` files, `Shared/AppGroup.swift`, `App/Services/AppConfig.swift` (refresh task and keychain service), `App/Info.plist` (`BGTaskSchedulerPermittedIdentifiers`) and `PassProduct` and `TipProduct` in `App/Services/PurchaseManager.swift`.
3. **Crew server.** Deploy `server/` on a host with a persistent disk. Set `NODE_ENV=production`, `DATA_DIR`, `ADMIN_TOKEN`, `SUPPORT_EMAIL`, `PUBLISHER_NAME` and `TRUST_PROXY_HOPS` (see the README), then put its https address in `GermigoServerURL`. To ship without Crew, set `GermigoCrewEnabled` to `false`.
4. **Support address, publisher and share page.** Put a monitored address in `GermigoSupportEmail`, the publisher's name in `GermigoPublisherName`, and `<server>/get` in `GermigoShareURL` (the page the share cards' QR code opens). The release check fails while any of them holds its placeholder. Once the app is live, set `APP_STORE_URL` on the server so that page links to it.
5. **Daycare notices.** On developer.apple.com, turn on Push Notifications for the `ca.germigo.app` identifier, create an APNs key (.p8) and set `APNS_KEY`, `APNS_KEY_ID` and `APNS_TEAM_ID` on the server. For notices by email, add a domain to Postmark (inbound and sender), then set `POSTMARK_TOKEN`, `MAIL_FROM`, `INBOUND_EMAIL_DOMAIN` and `INBOUND_EMAIL_TOKEN` (see the README). Pushes don't reach a sideloaded build: test them with TestFlight.
6. **Online lessons.** Host the lesson file described in `docs/LESSONS.md` and put its https address in `GermigoLessonsURL`. Until then the app shows only its bundled lessons.
7. **Subscriptions.** In App Store Connect create one subscription group with two products, turn on Family Sharing for both, then attach them to the first version:
   - `ca.germigo.app.pass.yearly`: 1 year, CA$24.99, with a 14-day free introductory offer
   - `ca.germigo.app.pass.monthly`: 1 month, CA$3.99
8. **Tip jar.** Create three consumable products: `ca.germigo.app.tip.small` (CA$1.99), `ca.germigo.app.tip.medium` (CA$4.99) and `ca.germigo.app.tip.large` (CA$9.99). Settings lists them cheapest first under "Offer a soup".
9. **Offer codes.** Codes that give the Season Pass are created on the subscription's Offer Codes page. Settings opens Apple's redemption sheet with "Redeem a code".
10. **App Store Small Business Program.** Enroll before the first sale to pay a 15% commission instead of 30%.
11. **Secrets for the Release workflow.** `APPLE_TEAM_ID`, `ASC_KEY_ID`, `ASC_ISSUER_ID`, `ASC_KEY_P8` (an App Store Connect API key with the App Manager role).
12. **App Store Connect record.** Name, subtitle, description, keywords, screenshots, support URL (`<server>/support`), privacy policy URL (`<server>/privacy`).
13. **Name check.** Search the App Store and trademark registers for "Germigo" in the target countries.

## 3. Answers for App Store Connect

**Category.** Health & Fitness or Lifestyle. Do not select the Kids category: the app is for parents.

**Privacy nutrition labels.** Data collected, none used for tracking, purpose "App Functionality", all "linked to the user" except Device ID:

| Type | Why |
| --- | --- |
| Name | The display name chosen for a crew |
| Health | Germs the user chooses to share with a crew |
| Other User Content | Crew name and reactions, daycare notices |
| User ID | The anonymous crew and daycare sessions |
| Email Address | The address a daycare sends notices from, if it uses email |
| Device ID | The push address of a family that joins a daycare, not linked to the user |

If Crew is disabled, the answer is "Data Not Collected".

**Age rating.** Medical or treatment information: infrequent. User-generated content: yes, with the controls listed in section 1. Messaging, chat and advertising: no. Unrestricted web access: no. Expect 13+.

**Review notes.** Suggested text:

> Germigo is a humor app for parents with general health information from public sources. It does not diagnose: the symptom pages only sort the app's catalog for the parent's own logbook, and the result says it is a guess.
> No account is needed. To test Crew: subscribe in the sandbox, open the Crew tab, start a crew, then join it from a second device with the invite code.
> Report and Block are in the menu next to each member and each feed item. Reports are reviewed within 24 hours on the server's moderation page.
> Daycare notices are free: in Crew, tap I run a daycare, create one, then open Invite families for its code. On a second device, tap Join a daycare, enter the code and pick a group. Send a notice from Daycare mode: the second device gets a push. Report is in the notice's menu.
> Leaving a crew deletes the member's data from the server. Settings > Data and privacy > Delete everything erases all local data.

Add a link to a short video of the two-device flows (Crew, and a daycare notice arriving as a push): a reviewer with one device cannot see them.

## 4. Open risks

| Risk | Detail |
| --- | --- |
| 5.1.1(ix) | Apple expects apps in regulated fields that collect sensitive data, health included, to be submitted by a legal entity. Germigo keeps the journal and its photos on the device and offers general information only, but a reviewer may still ask, more so now that photos of sick kids can be kept for a doctor. Disabling Crew removes all health data collection. |
| 1.4.1 | The symptom pages rank the catalog's germs by the signs a parent ticks. The screen calls the result a guess for the logbook, not a diagnosis, and trouble breathing leads to the help lines instead of a list. A reviewer may still read it as a diagnostic feature. |
| Case file review | Timing, contagion, care and "when to call" statements were re-read against the linked pages on 2026-11-19, and the "what it is", symptom and spread lines on 2026-11-20. The text has not been reviewed by a clinician, and the trivia lines of the deep dives are not covered by the linked pages. |
| Source links | `check_links.py` fails on a broken link and lists as blocked the sites that refuse scripts. Open the blocked ones in a browser before a release. |
| Moderation duty | Guideline 1.2 expects timely responses. The moderation page at `<server>/admin`, which lists reported members and notices, must be checked daily once Crew is live. |
| Crew alerts | The radar is refreshed by background fetch, which iOS schedules at its own pace. Only daycare notices are pushed. |
| Daycare identity | Anyone can sign a daycare up; the terms require the daycare's authorization, but the server does not verify it. A false daycare is removed on report. |
| Live Activity length | iOS ends a Live Activity after about 8 hours, so it starts only when the window closes within 8 hours and the app is opened. Local notifications and the widget cover the rest of the window. |
| Siri phrases | App Shortcuts phrases are English only. |
| Legal text | The privacy policy and terms were not reviewed by a lawyer. |
