#!/usr/bin/env python3
"""Requests every source link shown in the app and reports the ones that do not answer.

Usage: python3 tools/check_links.py
Needs network access, so it runs as an informational step in CI.
"""
import json
import pathlib
import sys
import urllib.error
import urllib.request

ROOT = pathlib.Path(__file__).resolve().parent.parent
EXTRA = ["https://www.apple.com/legal/internet-services/itunes/dev/stdeula/"]
AGENT = "Mozilla/5.0 (Macintosh; Intel Mac OS X 14_0) AppleWebKit/605.1.15 (KHTML, like Gecko) Version/17.0 Safari/605.1.15"


def collect():
    links = {}
    for name in ("germs.json", "articles.json"):
        for entry in json.loads((ROOT / "App" / "Content" / name).read_text(encoding="utf-8")):
            for source in entry.get("sources", []):
                links.setdefault(source["url"], f"{name}: {entry['id']}")
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
    for url, owner in sorted(links.items()):
        result = status(url)
        print(f"{result}  {url}  ({owner})")
        if result != 200:
            broken.append(url)
    print(f"check_links: {len(links) - len(broken)} of {len(links)} links answered 200")
    sys.exit(1 if broken else 0)


if __name__ == "__main__":
    main()
