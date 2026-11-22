# Privacy assessment

Working draft of the privacy impact assessment that Québec's private-sector privacy act requires before personal information is communicated outside Québec (section 17) and for a new information system (section 3.3). It follows the structure of the Commission d'accès à l'information guide: https://www.cai.gouv.qc.ca/uploads/pdfs/CAI_GU_EFVP.pdf. The host is Railway, region US East (Virginia). Notices by email are off at launch, so Postmark receives nothing until they are turned on.

## Personal information concerned

| Information | Sensitive | Where it is kept | How long |
| --- | --- | --- | --- |
| Shared germs, with the time shared and the recovery time | Yes, health | Crew server | Until the member leaves; 400 days at most |
| Crew name and emblem, display name, reactions, hashed session key | No | Crew server | Until the member leaves; 400 days without opening the crew |
| Daycare name and group names | No | Crew server | Until the daycare closes; 400 days without opening |
| Notices with their status, ready-made messages and notes | No | Crew server | 90 days, or until the daycare closes |
| Groups chosen, app language, hashed session key, Apple push address | No | Crew server; the push address also at Apple | Until the parent leaves; 400 days without opening |
| IP address | No | Server memory for rate limits; host logs | One day at most in memory; host logs: To complete from Railway's log retention for the plan |
| Journal, symptoms, photos, kids' and partner's first names | Yes, health | The phone only | Not communicated |
| The phone's tilt, while the Today mascot is awake | No | Read on the phone, never stored | Not communicated |

## Communications outside Québec

| Recipient | What it receives | Where | Written agreement |
| --- | --- | --- | --- |
| Railway (host) | Everything the server stores | United States, US East (Virginia) | Railway's data processing addendum (railway.com/legal/dpa), kept with this file. It lists no special-category data, so it has no terms for health data. |
| Apple Push Notification service | Push address, notice title and text | Outside Québec | Apple Developer Program License Agreement |

## Factors assessed

- **Sensitivity.** Shared germs are health information, linked to a display name the member chooses. The server never receives the journal, the photos or any child's name. Sharing a germ is off until the parent turns it on.
- **Purpose.** Shared germs feed the crew's radar and, when the member chooses, its feed. Daycare data delivers notices. Nothing is used for ads, profiling or analytics, and nothing is sold.
- **Protection.** HTTPS only. Session keys are stored as SHA-256 hashes. The data file is readable by its owner only. Limits per address, member and daycare. Responses carry only the fields the app shows. Leaving a crew or a daycare deletes its data at once. The text of an email notice is not kept.
- **Legal framework of the destination.** The United States have no federal law equivalent to Québec's; protection rests on the written agreements above. Railway's addendum does not cover health data, a point to settle with the lawyer before approval.

## Residual risks and measures

| Risk | Measure |
| --- | --- |
| A breach at the host exposes shared germs with display names | Minimal data and hashed keys; Railway encrypts stored data, volumes included, with AES-256 |
| When notices by email are turned on, Postmark receives the whole email although the server keeps only the subject | The privacy policy says so; add Postmark to this assessment, with its addendum and message retention, before turning them on |
| A member's germs stay on the server after they stop using the app | Removal after 400 days without opening the crew |

## Approval

Approved by the person in charge of the protection of personal information on: To complete.
