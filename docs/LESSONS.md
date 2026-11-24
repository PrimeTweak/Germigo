# Online lessons and Going around

New lessons and the weekly "Going around" reports reach the app without an update. The app reads one JSON file from the address in `GermilyLessonsURL` (`App/Info.plist`) when it comes to the foreground and during background refresh when iOS allows it, at most once an hour. It asks only for a changed copy: a host that sends `ETag` or `Last-Modified` answers in a few bytes when nothing changed, and a host that sends neither makes every check download the whole file. It keeps the last copy that read correctly; the six bundled lessons stay in every case.

## Rules in the app

- A lesson appears on its `released` day, at midnight in the phone's time zone.
- An online lesson opens with the Season Pass. For its first 7 days it is listed under This week, and the Guide puts it forward as the new lesson until it is read; without the Pass it shows its lock and leads to the offer.
- The bundled lessons stay free: each opens with right answers in the daily quiz.
- A lesson read once stays open.
- With the Season Pass, each upcoming lesson is announced at 10 AM on its release day, unless New lessons is off in Settings. The announcement is scheduled when the app reads the file, so publishing a lesson a few days ahead makes it reach more phones on time.

## File format

UTF-8 JSON, served over https with status 200, under 1 MB. Every lesson needs English and French text. A file that does not read, or is too large, is ignored and the previous copy stays. A source needs an https address: any other link is not shown.

```json
{
  "lessons": [
    {
      "id": "stomach-bug",
      "icon": "drop.fill",
      "released": "2026-11-30",
      "reviewedOn": "2026-11-20",
      "title": { "en": "Stomach bug, minus the panic", "fr": "La gastro, sans paniquer" },
      "summary": { "en": "What to do in the first 24 hours, and when to call.", "fr": "Quoi faire les premières 24 heures, et quand appeler." },
      "paragraphs": [
        { "en": "First paragraph.", "fr": "Premier paragraphe." }
      ],
      "sources": [
        { "name": "Source name", "url": "https://example.org/page" }
      ]
    }
  ]
}
```

- `id`: unique, never reused, never the id of a bundled lesson. Changing it makes the lesson new again.
- `icon`: an SF Symbol name, shown beside the title; optional, a graduation cap when left out.
- `released`: `yyyy-MM-dd`.
- `reviewedOn`: `yyyy-MM-dd`, the day a health professional approved the lesson. The server leaves out any lesson without one, or with a source that is not https, and the app shows the month under the sources.
- Keep lessons in the file after their week; removing one removes it from every phone at the next download.

## Going around

The same file carries `goingAround`: a public health report a week for Canada and for the US, summarized in our words, never with advice. The Guide shows it to everyone, free, at the front of This week, and a screen lists each germ, where it is heading and the source. The app picks the newest report for the phone's country published in the last 35 days, and leaves out any germ that is not in `germs.json`. Only phones set to Canada or the US see one; elsewhere the Guide shows no report. The screen says the figures are national and a region can differ.

```json
{
  "goingAround": [
    {
      "id": "ca-2026-45",
      "region": "CA",
      "week": "2026-11-08",
      "published": "2026-11-20",
      "approvedOn": "2026-11-20",
      "headline": { "en": "Flu is picking up this week.", "fr": "La grippe prend de l'ampleur cette semaine." },
      "germs": [
        { "germID": "flu", "trend": "rising", "line": { "en": "Picking up in most provinces.", "fr": "En hausse dans la plupart des provinces." } }
      ],
      "source": { "name": "Public Health Agency of Canada: FluWatch+", "url": "https://www.canada.ca/en/public-health/services/diseases/flu-influenza/influenza-surveillance.html" }
    }
  ]
}
```

- `region`: `CA` or `US`. Canada follows FluWatch+, each Friday from October to May and once a month in summer; the US follows the CDC's weekly reports.
- `week`: the first day of the week the report covers. `published`: the day the source published it.
- `trend`: `rising`, `steady`, `falling` or `low`, as the source says it; never a level we would make up.
- `headline`: at most 70 characters; each `line` at most 90. `check_repo.py` holds these and the content rule.
- `approvedOn`: the day the summary was approved. The server leaves out any report without one, from another country, or with a source that is not https.

Reports are written in `server/drafts/going-around.json`, in the same format without `approvedOn`. Once approved, a report moves to `server/lessons.json` with its `approvedOn`.

## Hosting

The crew server serves `server/lessons.json` at `/lessons.json`, with an `ETag`. Put `<server>/lessons.json` in `GermilyLessonsURL`. To publish, edit the file and push: the host redeploys, and the server reads the file when it starts. A file over 1 MB, or without a `lessons` list, is not served, and the app keeps its copy. A file without `goingAround` is still served, with no report.

## Drafts and review

Lessons are written in `server/drafts/lessons.json`, in the same format without `released` or `reviewedOn`; the server never serves that file. `check_repo.py` applies the content rule to drafts too (see `README.md`). Once a health professional approves a batch, each lesson moves to `server/lessons.json` with its `reviewedOn` and a `released` day, one week apart.
