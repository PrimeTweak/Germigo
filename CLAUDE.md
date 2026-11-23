# Germily

iOS app (SwiftUI, iOS 26.2+, English and French) that turns the germs a kid brings home from daycare into a card collection for the parent, with a small Node server in `server/`. `README.md` describes the layout, the configuration keys and the server.

## Checks

Run all three before handing anything over, or use `/qa`:

- `python3 tools/check_swift.py`
- `python3 tools/check_repo.py`
- `node server/test.js`

No Swift compiler runs outside the Build IPA workflow. When Swift changed, say that it was checked but not compiled.

## Rules

- Everything in the repository is in English: code, comments, string keys, docs. French lives only in the strings files and the content files (`App/Content/*.json`, `server/legal.json`, `server/illnesses.json`, `server/text.json`, `server/lessons.json`, `server/drafts/lessons.json`).
- Comments describe what the code does, impersonally and in plain words, in three lines at most. A comment that no longer matches its code is rewritten or removed.
- No dead code: nothing unused, nothing never called, nothing commented out, nothing kept for later.
- No leftover logs, probes or debug output. The server logs only errors and its start.
- Every icon says what its control does, one idea keeps one icon across the app, and the rows of a list all have an icon or none do.
- Corner radii come from `Radius`: three values, nothing in between.
- Page margins come from `Spacing.page`; padding inside cards and controls keeps its own value.
- Every door to the Season Pass passes its `PassReason` to `PaywallView` and words its offer with `PassOfferText`, `PassOfferTag` or `PassOfferLink`.
- User-facing text goes through `tr()` or `trCount()`. The key is the English text, and both `Localizable.strings` files get the line.
- `server/legal.json` and `App/Content/legal.json` are the same file, byte for byte.
- Data that leaves the phone is reflected in `legal.json`, `App/PrivacyInfo.xcprivacy` and `docs/APP-STORE.md` in the same change.
- Health content is general information with a linked source. No diagnosis, no dosing. `check_repo.py` holds the content rule's checks; `reviewedOn` is set only on the day a health professional approves the text.
- Never commit secrets. Keys and `.env` files stay out of the repository.
- `.github/workflows/` changes only when the owner requests it.

## Working with the owner

- The owner reads French and does not use a terminal: talk to them in French and give steps for Finder, github.com or GitHub Desktop.
- Deliver exactly what was requested. Put reservations next to the delivery, never in place of it.
- A change that touches several screens starts with a mockup or a summary table, then waits for an explicit go.
- Say what was measured and what was deduced. Do not ship a fix that rests on a deduction.
- When something must be measured on a device, ship one probe that measures everything at once, then one fix.
- List new and deleted files with every delivery. A build fix ships alone.

## More

Animations follow `docs/MOTION.md`: read it before adding or changing one. Rules for one part of the tree live in `.claude/rules/`. Procedures live in `.claude/skills/`: `/qa`, `/investigate`, `/review-pr`, `/land-and-deploy` and `/canary`.
