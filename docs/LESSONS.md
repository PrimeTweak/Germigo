# Online lessons

New lessons reach the app without an update. The app downloads one JSON file from the address in `GermigoLessonsURL` (`App/Info.plist`) each time it comes to the foreground, and during background refresh when iOS allows it. It keeps the last copy that read correctly; the six bundled lessons stay in every case.

## Rules in the app

- A lesson appears on its `released` day, at midnight in the phone's time zone.
- For its first 7 days it is open to everyone, listed under This week, and the Lab shows a dot on the lessons button until it is read.
- After that week it joins the ladder: each online lesson, in release order, needs 5 more right answers in the daily quiz than the one before it (30, 35, 40, and so on after the bundled 25).
- A lesson read once stays open.
- Each upcoming lesson is announced at 10 AM on its release day, unless New lessons is off in Settings. The announcement is scheduled when the app reads the file, so publishing a lesson a few days ahead makes it reach more phones on time.

## File format

UTF-8 JSON, served over https with status 200. Every lesson needs English and French text. A file that does not read is ignored and the previous copy stays.

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
