#!/usr/bin/env python3
"""Requests every source link of the app's content and of the lesson files, and reports the ones that do not answer.
Usage: python3 tools/check_links.py. Informational in CI. A site that refuses scripts
(401, 403 or 429) is listed as blocked, not verified, and does not fail the run."""
import json
import pathlib
import sys
import urllib.error
import urllib.request

ROOT = pathlib.Path(__file__).resolve().parent.parent
EXTRA = ["https://www.apple.com/legal/internet-services/itunes/dev/stdeula/"]
BLOCKED = {401, 403, 429}
AGENT = "Mozilla/5.0 (Macintosh; Intel Mac OS X 14_0) AppleWebKit/605.1.15 (KHTML, like Gecko) Version/17.0 Safari/605.1.15"


def collect():
    links = {}
    for name in ("germs.json", "articles.json"):
        for entry in json.loads((ROOT / "App" / "Content" / name).read_text(encoding="utf-8")):
            for source in entry.get("sources", []):
                links.setdefault(source["url"], f"{name}: {entry['id']}")
            for url in (entry.get("canadaSource") or {}).get("url", {}).values():
                links.setdefault(url, f"{name}: {entry['id']} (Canada)")
    for name in ("server/lessons.json", "server/drafts/lessons.json"):
        path = ROOT / name
        if path.is_file():
            for lesson in json.loads(path.read_text(encoding="utf-8")).get("lessons", []):
                for source in lesson.get("sources", []):
                    links.setdefault(source["url"], f"{name}: {lesson['id']}")
    for url in EXTRA:
        links.setdefault(url, "legal screen")
    return links


def status(url):
    request = urllib.request.Request(url, headers={"User-Agent": AGENT, "Accept": "text/html,*/*"})
    try:
        with urllib.request.urlopen(request, timeout=20) as response:
            return response.status
    except urllib.error.HTTPError as error:
        return error.code
    except Exception as error:
        return f"{type(error).__name__}: {error}"


def main():
    links = collect()
    broken = []
    blocked = []
    for url, owner in sorted(links.items()):
        result = status(url)
        if result == 200:
            label = "ok      "
        elif result in BLOCKED:
            label = "blocked "
            blocked.append(url)
        else:
            label = "BROKEN  "
            broken.append(url)
        print(f"{label}{result}  {url}  ({owner})")
    answered = len(links) - len(broken) - len(blocked)
    print(f"check_links: {answered} answered 200, {len(blocked)} refused this script (not verified), {len(broken)} broken")
    sys.exit(1 if broken else 0)


if __name__ == "__main__":
    main()
