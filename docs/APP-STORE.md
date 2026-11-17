# App Store checklist

What the code already covers, what has to be done in App Store Connect, and what is still open.
Guideline numbers refer to the App Review Guidelines: https://developer.apple.com/app-store/review/guidelines/

## 1. Covered in the repository

| Requirement | How it is met | Where |
| --- | --- | --- |
| Built with Xcode 26 and the iOS 26 SDK (required since April 28, 2026) | Workflows run on `macos-26`; `check_bundle.py` prints the SDK used | `.github/workflows/` |
| Privacy manifest, one per binary | No tracking, UserDefaults reason `CA92.1`, collected data declared | `App/PrivacyInfo.xcprivacy`, `Widgets/PrivacyInfo.xcprivacy` |
| Export compliance | `ITSAppUsesNonExemptEncryption` is `false` (HTTPS only) | `App/Info.plist` |
| 1.2 User-generated content: filter | Crew and display names are filtered server-side | `server/server.js` (`cleanName`) |
| 1.2: report | Report menu on every member and feed item; two reporters hide the name until reviewed | `CrewScreen.swift`, `server/server.js` |
| 1.2: block | Block hides a member and their posts on the device | `CrewStore.block` |
| 1.2: terms with no tolerance for abuse | Rules must be accepted before creating or joining a crew | `CrewJoinView`, `legal.json` |
| 1.2: published contact | Support address in Settings, legal screens and Crew | `PetriSupportEmail` |
| 1.4.1 Medical information | General information only, sources linked on every card, "not medical advice" on each screen, no diagnosis or dosing | `germs.json`, `GermDetailScreen.swift` |
| 2.1 Completeness | No placeholder may ship: `check_repo.py --release` fails on them | `tools/check_repo.py` |
| 2.5.4 Background modes | `fetch` only, used to refresh the crew radar | `App/Info.plist` |
| 3.1.1 In-app purchase | The Season Pass is sold through StoreKit only | `PurchaseManager.swift` |
| 3.1.2 Subscription disclosure | Name, period, full price most prominent, trial length and price after it, auto-renewal, Restore, Terms, Privacy | `PaywallView.swift` |
| 3.1.2 Manage subscription | Settings opens the system subscription sheet | `SettingsScreen.swift` |
| 4.6 Alternate icons | Changed only by the user, from Settings | `SettingsDetailScreens.swift` |
| 5.1.1(i) Privacy policy | In the app (offline) and on the server at `/privacy` | `LegalScreen.swift`, `server/server.js` |
| Purpose strings | Photo library (add only), in English and French | `App/*/InfoPlist.strings` |
| 5.1.1(v) Accounts | No account or sign-in. Leaving a crew deletes the server data. Delete Everything erases the device data. | `CrewStore.leave`, `AppModel.eraseEverything` |
| 5.1.2 Data use | No ads, trackers or third-party SDKs | whole app |
| 5.1.3(ii) Health data and iCloud | The journal is a local file. iCloud and HealthKit are not used. | `Persistence.swift` |
| Accessibility | Labels on custom controls, system text styles for reading text, Reduce Motion honored | screens |

## 2. To do before the first upload

1. **Apple Developer Program.** Enrollment is required for TestFlight and the App Store.
2. **Bundle identifier.** `ca.petri.app` must be available to the account. If it is not, change it in `project.yml` (both targets), both `.entitlements` files, `Shared/AppGroup.swift`, `App/Services/AppConfig.swift` (refresh task and keychain service), `App/Info.plist` (`BGTaskSchedulerPermittedIdentifiers`) and `PassProduct` in `App/Services/PurchaseManager.swift`.
3. **Crew server.** Deploy `server/` on a host with a persistent disk, set `ADMIN_TOKEN` and `SUPPORT_EMAIL`, then put its https address in `PetriServerURL`. To ship without Crew, set `PetriCrewEnabled` to `false`.
4. **Support address.** Put a monitored address in `PetriSupportEmail`.
5. **Subscriptions.** In App Store Connect create one subscription group with two products, then attach them to the first version:
   - `ca.petri.app.pass.yearly`: 1 year, with a 7-day free introductory offer
   - `ca.petri.app.pass.monthly`: 1 month
6. **Secrets for the Release workflow.** `APPLE_TEAM_ID`, `ASC_KEY_ID`, `ASC_ISSUER_ID`, `ASC_KEY_P8` (an App Store Connect API key with the App Manager role).
7. **App Store Connect record.** Name, subtitle, description, keywords, screenshots, support URL (`<server>/support`), privacy policy URL (`<server>/privacy`).
8. **Name check.** Search the App Store and trademark registers for "Petri" in the target countries.

## 3. Answers for App Store Connect

**Category.** Health & Fitness or Lifestyle. Do not select the Kids category: the app is for parents.

**Privacy nutrition labels.** Data collected, all "linked to the user", none used for tracking, purpose "App Functionality":

| Type | Why |
| --- | --- |
| Name | The display name chosen for a crew |
| Health | Germs the user chooses to share with a crew |
| Other User Content | Crew name and reactions |
| User ID | The anonymous crew session |

If Crew is disabled, the answer is "Data Not Collected".

**Age rating.** Medical or treatment information: infrequent. User-generated content: yes, with the controls listed in section 1. Messaging, chat and advertising: no. Unrestricted web access: no. Expect 13+.

**Review notes.** Suggested text:

> Petri is a humor app for parents with general health information from public sources. It does not diagnose.
> No account is needed. To test Crew: subscribe in the sandbox, open the Crew tab, start a crew, then join it from a second device with the invite code.
> Report and Block are in the menu next to each member and each feed item. Reports are reviewed within 24 hours through the server's admin endpoint.
> Leaving a crew deletes the member's data from the server. Settings > Delete Everything erases all local data.

## 4. Open risks

| Risk | Detail |
| --- | --- |
| 5.1.1(ix) | Apple expects apps in regulated fields that collect sensitive data, health included, to be submitted by a legal entity. Petri keeps the journal on the device and offers general information only, but a reviewer may still ask. Disabling Crew removes all health data collection. |
| Field Notes review | The health text was written from the linked public sources and has not been reviewed by a clinician. |
| Source links | `check_links.py` reports the links that stop answering. Fix or replace them before a release. |
| Moderation duty | Guideline 1.2 expects timely responses. `GET /admin/reports` must be checked daily once Crew is live. |
| Crew alerts | The radar is refreshed by background fetch, which iOS schedules at its own pace. There is no push server. |
| Live Activity length | iOS ends a Live Activity after about 8 hours. Local notifications cover the rest of the window. |
| Siri phrases | App Shortcuts phrases are English only. |
| Legal text | The privacy policy and terms were not reviewed by a lawyer. |
