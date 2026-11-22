# App Store checklist

What the code already covers, what has to be done in App Store Connect, and what is still open.
Guideline numbers refer to the App Review Guidelines: https://developer.apple.com/app-store/review/guidelines/

## 1. Covered in the repository

| Requirement | How it is met | Where |
| --- | --- | --- |
| Built with Xcode 26 and the iOS 26 SDK (required since April 28, 2026) | Workflows run on `macos-26`; `check_bundle.py` prints the SDK used | `.github/workflows/` |
| Privacy manifest, one per binary | No tracking, UserDefaults reason `CA92.1`, collected data declared | `App/PrivacyInfo.xcprivacy`, `Widgets/PrivacyInfo.xcprivacy` |
| Export compliance | `ITSAppUsesNonExemptEncryption` is `false` (HTTPS only) | `App/Info.plist` |
| 1.2 User-generated content: filter | Crew, display, daycare and group names are filtered server-side; notice notes refuse links and insults | `server/server.js` (`cleanName`, `hasBlockedWord`) |
| 1.2: report | Report menu on every member, feed item and daycare notice; two reporters hide a name until reviewed, a reported notice leaves the reporter's phone | `CrewScreen.swift`, `DaycareScreens.swift`, `server/server.js` |
| 1.2: block | Block hides a member and their posts on the device; leaving a daycare stops its notices | `CrewStore.block`, `DaycareStore.leave` |
| 1.2: terms with no tolerance for abuse | Rules must be accepted before creating or joining a crew, and before signing a daycare up | `CrewJoinView`, `DaycareSetupSheet`, `legal.json` |
| 1.2: published contact | Support address in Settings, legal screens and Crew | `GermilySupportEmail` |
| 1.4.1 Medical information | General information only, sources linked on every card, "not medical advice" on each screen, no diagnosis or dosing | `germs.json`, `GermDetailScreen.swift` |
| 2.1 Completeness | No placeholder may ship: `check_repo.py --release` fails on them | `tools/check_repo.py` |
| 2.5.4 Background modes | `fetch` only, used to refresh the crew radar | `App/Info.plist` |
| 4.5.4 Push notifications | Used only for daycare notices the family subscribed to; permission is asked when joining a daycare; no marketing | `PushRegistrar.swift`, `server/push.js` |
| 3.1.1 In-app purchase | The Season Pass and the tip jar are sold through StoreKit only; tips unlock nothing | `PurchaseManager.swift`, `SettingsScreen.swift` |
| 3.1.2 Subscription disclosure | Name, period, full price most prominent, trial length and price after it, auto-renewal, Restore, Terms, Privacy | `PaywallView.swift` |
| 3.1.2 Manage subscription | Settings opens the system subscription sheet | `SettingsScreen.swift` |
| 4.6 Alternate icons | Changed only by the user, from Settings | `SettingsDetailScreens.swift` |
| 5.1.1(i) Privacy policy | In the app (offline) and on the server at `/privacy`; the consumer health data policy at `/health-data`, linked from the home page as Washington's My Health My Data Act requires | `LegalScreen.swift`, `server/server.js` |
| Purpose strings | Camera (photos for the sick history, scanning a daycare's code), photo library (add only), Face ID (app lock) and motion (the tilt that makes the Today mascot lean), in English and French. Picking photos uses the system picker, which needs no permission. | `App/*/InfoPlist.strings` |
| 5.1.1(v) Accounts | No account or sign-in. Leaving a crew or a daycare, or closing a daycare, deletes the server data. Delete everything erases the device data and what this phone put on the server. | `CrewStore.leave`, `DaycareStore`, `AppModel.eraseEverything` |
| 5.1.2 Data use | No ads, trackers or third-party SDKs | whole app |
| 5.1.3(ii) Health data and iCloud | The journal is a local file. iCloud and HealthKit are not used. A backup is a file the user saves where they choose. | `Persistence.swift`, `SettingsScreen.swift` |
| Accessibility | Labels on custom controls, system text styles for reading text, Reduce Motion honored | screens |

## 2. To do before the first upload

1. **Apple Developer Program.** Enrollment is required for TestFlight and the App Store. The plan is to enroll as an individual: see 5.1.1(ix) under Open risks.
2. **Bundle identifier.** `ca.germily.app` must be available to the account. If it is not, change it in `project.yml` (both targets), both `.entitlements` files, `Shared/AppGroup.swift`, `App/Services/AppConfig.swift` (refresh task and keychain service), `App/Info.plist` (`BGTaskSchedulerPermittedIdentifiers`) and `PassProduct` and `TipProduct` in `App/Services/PurchaseManager.swift`.
3. **Crew server on Railway.** Hobby plan, region US East (Virginia). Create a service from this repository with `server` as its root directory, keep one replica, and attach a volume mounted at `/data`. Set `NODE_ENV=production`, `DATA_DIR=/data`, `ADMIN_TOKEN` (random, 32 characters or more: it is the only lock on the moderation page), `SUPPORT_EMAIL`, `PUBLISHER_NAME` and `CLIENT_IP_HEADER=x-real-ip` (see the README). On the workspace Usage page, set a custom email alert at $8 and a hard limit at $15: at the limit Railway stops the service, so Crew and daycare notices go offline and the journal keeps working. Put the service's `.up.railway.app` address in `GermilyServerURL`. To ship without Crew, set `GermilyCrewEnabled` to `false`. Keep Railway's data processing addendum with `docs/PRIVACY-ASSESSMENT.md`, and have the assessment approved before the server holds real data.
4. **Support address, publisher and share page.** Put a monitored address in `GermilySupportEmail`, the publisher's name in `GermilyPublisherName`, and `<server>/get` in `GermilyShareURL` (the page the share cards' QR code opens). The release check fails while any of them holds its placeholder. Once the app is live, set `APP_STORE_URL` on the server so that page links to it.
5. **Daycare notices.** On developer.apple.com, turn on Push Notifications for the `ca.germily.app` identifier, create an APNs key (.p8) and set `APNS_KEY`, `APNS_KEY_ID` and `APNS_TEAM_ID` on the server. Pushes don't reach a sideloaded build: test them with TestFlight. Notices by email are off at launch: leave `INBOUND_EMAIL_DOMAIN` unset and `GermilyEmailNoticesEnabled` false. To turn them on later, add a domain to Postmark (inbound and sender), set `POSTMARK_TOKEN`, `MAIL_FROM`, `INBOUND_EMAIL_DOMAIN` and `INBOUND_EMAIL_TOKEN` (see the README), set the SpamAssassin threshold in the Inbound stream's Settings (Postmark counts every inbound message it processes toward the monthly volume, before the server's own limit), set `GermilyEmailNoticesEnabled` to true, and declare it everywhere data leaving the phone is listed: the director's address and Postmark in the privacy policy (`legal.json`), Email Address in `App/PrivacyInfo.xcprivacy` and the privacy labels, and Postmark in the privacy assessment.
6. **Online lessons.** Put `<server>/lessons.json` in `GermilyLessonsURL`. The server serves `server/lessons.json` (see `docs/LESSONS.md`). Until the address is set, the app shows only its bundled lessons.
7. **Subscriptions.** In App Store Connect create one subscription group with two products, turn on Family Sharing for both, then attach them to the first version:
   - `ca.germily.app.pass.yearly`: 1 year, CA$24.99, with a 14-day free introductory offer
   - `ca.germily.app.pass.monthly`: 1 month, CA$3.99
8. **Tip jar.** Create three consumable products: `ca.germily.app.tip.small` (CA$1.99), `ca.germily.app.tip.medium` (CA$4.99) and `ca.germily.app.tip.large` (CA$9.99). Settings lists them cheapest first under "Offer a soup".
9. **Offer codes.** Codes that give the Season Pass are created on the subscription's Offer Codes page. Settings opens Apple's redemption sheet with "Redeem a code".
10. **App Store Small Business Program.** Enroll before the first sale to pay a 15% commission instead of 30%.
11. **Secrets for the Release workflow.** `APPLE_TEAM_ID`, `ASC_KEY_ID`, `ASC_ISSUER_ID`, `ASC_KEY_P8` (an App Store Connect API key with the App Manager role).
12. **App Store Connect record.** Name, subtitle, description, keywords, screenshots, support URL (`<server>/support`), privacy policy URL (`<server>/privacy`). End the description, in English and in French, with `Terms of Use: https://www.apple.com/legal/internet-services/itunes/dev/stdeula/`: guideline 3.1.2 requires the Terms of Use link in the metadata of an app with subscriptions, and a description that lacks it in one language is rejected.
13. **Name check.** Search the App Store and trademark registers for "Germily" in the target countries.
14. **Review demo.** On the production server, create a crew with two or three members and a few shared germs, and a daycare with a group and a recent notice. Put their codes in the review notes below, and record a short video of a daycare notice arriving as a push. Keep them for every review.
15. **First TestFlight build.** Before submitting, check on a phone: a daycare notice arrives as a push (the signed build must use the production push environment); one phone can join the daycare it created and receive its notice, as the review notes say; Today and the log sheet at the largest text size; and the app on an iPad, where Apple may test an iPhone app.
16. **Approval day.** In App Store Connect, choose to release the version manually. Once it is approved: on github.com/settings/billing, under Budgets and alerts, create a $10 budget for Actions with "Stop usage when budget limit is reached"; make the repository private; then release.

## 3. Answers for App Store Connect

**Category.** Health & Fitness or Lifestyle. Do not select the Kids category: the app is for parents.

**Privacy nutrition labels.** Data collected, none used for tracking, purpose "App Functionality", all "linked to the user" except Device ID:

| Type | Why |
| --- | --- |
| Name | The display name chosen for a crew |
| Health | Germs the user chooses to share with a crew |
| Other User Content | Crew name and reactions, daycare notices |
| User ID | The anonymous crew and daycare sessions |
| Device ID | The push address of a family that joins a daycare, not linked to the user |

If Crew is disabled, the answer is "Data Not Collected".

**Age rating.** Medical or treatment information: infrequent. User-generated content: yes, with the controls listed in section 1. Messaging, chat and advertising: no. Unrestricted web access: no. Expect 13+.

**Review notes.** Replace the bracketed parts, then paste:

> Germily is a humor app for parents who catch the germs their kids bring home from daycare. It offers general health information from public sources and does not diagnose: the symptom pages only sort the app's own catalog for the parent's logbook, the result is labeled as a guess, and "Trouble breathing" leads to help lines instead of a list.
>
> No account or login is needed. Everything works offline except Crew and daycare notices.
>
> Season Pass: tap any lock, or Settings > Season Pass, and subscribe with a sandbox account. "Restore purchases" is on the same screen. Tips are one-time purchases that unlock nothing.
>
> Crew (requires the Season Pass): open the Crew tab, choose "Join a crew" and enter the demo code [DEMO CREW CODE] to see a crew with members, a feed and reactions. "Start a crew" creates a new one. Report and Block are in the menu next to each member and each feed item; reports are reviewed within 24 hours.
>
> Daycare notices (free): in the Crew tab, tap "Join a daycare", enter [DEMO DAYCARE CODE] and pick a group to see its notices. To send one, tap "I run a daycare", create a daycare, open Invite families for its code, join it from the same phone with "Join a daycare", then send a notice from Daycare mode: it arrives as a push. A short video of both flows: [VIDEO LINK].
>
> Permissions: the camera is used only to take a photo for a family member's sick history or to scan a daycare's code. Photo library access is add-only, to save share cards. Face ID is used only by the optional app lock, through iOS: the app never sees the face data. The tilt of the phone makes the mascot on Today lean while it is awake; it is read on the device and never stored or sent. Notifications are optional: reminders are created on the device; only daycare notices are pushed.
>
> Data: leaving a crew deletes the member's data from the server. Settings > Data and privacy > Delete everything erases the journal on the phone and the crew and daycare data on the server.

## 4. Open risks

| Risk | Detail |
| --- | --- |
| 5.1.1(ix) | Apple expects apps in regulated fields that collect sensitive data, health included, to be submitted by a legal entity. Germily keeps the journal and its photos on the device and offers general information only, but a reviewer may still ask, more so now that photos of sick kids can be kept for a doctor. Disabling Crew removes all health data collection. The developer account is planned as an individual: if review asks for an organization, the account must be converted, which needs an incorporated company, or Crew must be disabled. A question for the lawyer. |
| 1.4.1 | The symptom pages rank the catalog's germs by the signs a parent ticks. The screen calls the result a guess for the logbook, not a diagnosis, and trouble breathing leads to the help lines instead of a list. A reviewer may still read it as a diagnostic feature. |
| Case file review | Timing, contagion, care and "when to call" statements were re-read against the linked pages on 2026-11-19, and the "what it is", symptom and spread lines on 2026-11-20. The text has not been reviewed by a clinician, and the trivia lines of the deep dives are not covered by the linked pages. |
| Source links | `check_links.py` fails on a broken link and lists as blocked the sites that refuse scripts. Open the blocked ones in a browser before a release. |
| Moderation duty | Guideline 1.2 expects timely responses. The moderation page at `<server>/admin`, which lists reported members and notices, must be checked daily once Crew is live. |
| Crew alerts | The radar is refreshed by background fetch, which iOS schedules at its own pace. Only daycare notices are pushed. |
| Daycare identity | Anyone can sign a daycare up; the terms require the daycare's authorization, but the server does not verify it. A false daycare is removed on report. |
| Email sender | Notices by email are off at launch. A notice by email is accepted on its From address, which someone who knows a daycare's private address can forge. Whether to require the SPF or DKIM result is to be decided from the headers of a real Postmark message. The director's address is not confirmed either: replies stop at 20 a day per daycare, and a confirmation step is to be decided. |
| Large emails | Notices by email are off at launch. An email heavier than 512 KB, for example with a photo attached, is refused without a reply. To check with a real Postmark message. |
| Notice notes | The note of a notice sent from the app is free text, without links, beside a status and ready-made messages. Notices have no field for a child; the policy and the terms say the daycare answers for its note and must never name a child in it, and nothing else checks it. Notes refuse links and a short list of English and French insults, plurals included; words with an everyday meaning, such as "retard" in French or "bite" in English, are left to the report button. |
| Daycare list | A daycare's list stops at 600 families. A director can replace the code (Daycare settings > New code, 5 a day), which stops new families with the old code, but cannot remove a family already in. |
| Season Pass on the server | Crew is reserved to the Season Pass in the app only: the server does not check a purchase. Verifying the App Store transaction needs the developer account. |
| Shared addresses | Limits count an IPv4 address alone and an IPv6 address by its /64 network. People behind one shared address, such as a school network, a carrier or iCloud Private Relay, share its limits. |
| App lock | Settings > App lock asks for Face ID, Touch ID or the passcode when Germily opens or comes back from the background. Off by default. Widgets, the Live Activity and notifications still show on the Lock Screen and the Home Screen. |
| Motion permission | The Today mascot reads the tilt with `CMMotionManager` only while it is awake and the app is in front. Whether iOS asks a permission for it is to be checked on a device; the purpose string is there in case it does. |
| Public repository | While the repository is public, anyone signed in to GitHub can download the workflow artifacts, and the sideload build carries a Season Pass switch. It becomes private on approval day (section 2, step 16), budget first: private builds use the account's included macOS minutes. |
| Host terms for health data | Railway encrypts stored data, volumes included, with AES-256, but its data processing addendum lists no special-category data, so it has no terms for health data such as shared germs. A question for the lawyer, with the privacy assessment. |
| Copied text | The doctor's summary and a daycare's private address leave the clipboard after five minutes, but Universal Clipboard still carries them to the user's other devices in the meantime. |
| Live Activity length | iOS ends a Live Activity after about 8 hours, so it starts only when the window closes within 8 hours and the app is opened. Local notifications and the widget cover the rest of the window. |
| Siri phrases | App Shortcuts phrases are English only. |
| US age laws | Texas requires apps to request the age range Apple shares and to treat the answer as known; Utah and Louisiana follow later. The plan for a user under 18 in those states: the journal stays, and Crew, daycare notices and purchases are off. It uses Apple's Declared Age Range API and waits for the developer account, which its sandbox testing needs. |
| Legal text | The privacy policy, the terms, the health data policy and `docs/PRIVACY-ASSESSMENT.md` were not reviewed by a lawyer. Open questions for that review: whether the journal kept only on the phone counts as collected health data in Washington, and whether other states' health data laws apply. |
| Code ownership | The code, the characters and the sounds were made with Claude. Anthropic assigns its rights in them, but purely AI-generated material is not protected by copyright in the United States, and the repository is public. Making it private and filing the Germily trademark are to be decided. |
| Apple symbols on shared cards | Three share cards draw SF Symbols (`StoryCards.swift`), which Apple's license reserves to Apple platforms and forbids in logos. Replacing them with Germily drawings is to be decided. |
