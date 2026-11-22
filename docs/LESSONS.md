# Online lessons

New lessons reach the app without an update. The app reads one JSON file from the address in `GermigoLessonsURL` (`App/Info.plist`) when it comes to the foreground and during background refresh when iOS allows it, at most once an hour. It asks only for a changed copy: a host that sends `ETag` or `Last-Modified` answers in a few bytes when nothing changed, and a host that sends neither makes every check download the whole file. It keeps the last copy that read correctly; the six bundled lessons stay in every case.

## Rules in the app

- A lesson appears on its `released` day, at midnight in the phone's time zone.
- For its first 7 days it is open to everyone, listed under This week, and the Guide puts it forward as the new lesson until it is read.
- After that week it joins the ladder: each online lesson, in release order, needs 5 more right answers in the daily quiz than the one before it (30, 35, 40, and so on after the bundled 25).
- A lesson read once stays open.
- Each upcoming lesson is announced at 10 AM on its release day, unless New lessons is off in Settings. The announcement is scheduled when the app reads the file, so publishing a lesson a few days ahead makes it reach more phones on time.

## File format

UTF-8 JSON, served over https with status 200, under 1 MB. Every lesson needs English and French text. A file that does not read, or is too large, is ignored and the previous copy stays. A source needs an https address: any other link is not shown.

```json
{
  "lessons": [
    {
      "id": "stomach-bug",
      "icon": "drop.fill",
      "released": "2026-11-30",
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
- `icon`: an SF Symbol name, optional.
- `released`: `yyyy-MM-dd`.
- Keep lessons in the file after their week; removing one removes it from every phone at the next download.

## Hosting

Any https address that serves the file works. GitHub Pages serves public repositories on GitHub Free; a private repository needs GitHub Pro. A raw file address from a public repository also works.
