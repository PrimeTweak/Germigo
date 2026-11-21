#!/usr/bin/env python3
"""Checks that the repository is complete and consistent before a build.

Usage: python3 tools/check_repo.py [--release]
With --release, placeholders that must be replaced before an App Store upload also fail the check.
"""
import json
import pathlib
import plistlib
import re
import struct
import sys

ROOT = pathlib.Path(__file__).resolve().parent.parent
RELEASE = "--release" in sys.argv
errors = []
SPEC = re.compile(r"%(?:\d+\$)?(?:lld|@|d|f)")
STRING_LINE = re.compile(r'^"((?:[^"\\]|\\.)*)"\s*=\s*"((?:[^"\\]|\\.)*)";\s*$')

# Longest "Shows up" or "Lasts" text a timeline column of a germ page is given.
TILE_TEXT_LIMIT = 30

REQUIRED = [
    "project.yml", ".gitignore", ".github/workflows/build-ipa.yml", ".github/workflows/release.yml",
    "App/Info.plist", "App/Petri.entitlements", "App/PrivacyInfo.xcprivacy", "App/PetriApp.swift",
    "App/Content/germs.json", "App/Content/articles.json", "App/Content/legal.json",
    "App/en.lproj/InfoPlist.strings", "App/fr.lproj/InfoPlist.strings",
    "App/Sounds/flap.wav", "App/Sounds/reveal.wav", "App/Sounds/badge.wav",
    "Shared/en.lproj/Localizable.strings", "Shared/fr.lproj/Localizable.strings",
    "Widgets/Info.plist", "Widgets/PetriWidgets.entitlements", "Widgets/PrivacyInfo.xcprivacy",
    "server/server.js", "server/test.js", "server/legal.json", "server/package.json",
    "README.md", "docs/APP-STORE.md",
    "App/Store/JournalRules.swift", "App/Store/ProgressEngine.swift", "Tests/LogicTests/main.swift", "tools/run_logic_tests.sh",
]


def fail(message):
    errors.append(message)


def read_plist(relative):
    try:
        return plistlib.loads((ROOT / relative).read_bytes())
    except Exception as error:
        fail(f"{relative}: not a valid property list ({error})")
        return {}


def read_json(relative):
    try:
        return json.loads((ROOT / relative).read_text(encoding="utf-8"))
    except Exception as error:
        fail(f"{relative}: not valid JSON ({error})")
        return None


def png_info(path):
    """Returns (width, height, has_alpha) from the PNG header."""
    data = path.read_bytes()[:33]
    if data[:8] != b"\x89PNG\r\n\x1a\n":
        return None
    width, height, _depth, color_type = struct.unpack(">IIBB", data[16:26])
    return width, height, color_type in (4, 6)


def localized(value, where):
    if not isinstance(value, dict) or not value.get("en") or not value.get("fr"):
        fail(f"{where}: needs non-empty en and fr text")


def check_files():
    for relative in REQUIRED:
        if not (ROOT / relative).is_file():
            fail(f"missing file: {relative}")
    for path in ROOT.rglob("*"):
        if path.is_dir() and path.name == "Resources" and ".git" not in path.parts:
            fail(f"folder named Resources is reserved inside app bundles: {path.relative_to(ROOT)}")


def check_plists():
    app = read_plist("App/Info.plist")
    widgets = read_plist("Widgets/Info.plist")
    for key in ("CFBundleDisplayName", "UILaunchScreen", "NSSupportsLiveActivities", "ITSAppUsesNonExemptEncryption",
                "NSPhotoLibraryAddUsageDescription", "BGTaskSchedulerPermittedIdentifiers", "CFBundleLocalizations"):
        if key not in app:
            fail(f"App/Info.plist: missing {key}")
    if widgets.get("NSExtension", {}).get("NSExtensionPointIdentifier") != "com.apple.widgetkit-extension":
        fail("Widgets/Info.plist: wrong extension point")
    for relative in ("App/Petri.entitlements", "Widgets/PetriWidgets.entitlements"):
        groups = read_plist(relative).get("com.apple.security.application-groups", [])
        if groups != ["group.ca.petri.app"]:
            fail(f"{relative}: app group must be group.ca.petri.app")
    for relative in ("App/PrivacyInfo.xcprivacy", "Widgets/PrivacyInfo.xcprivacy"):
        manifest = read_plist(relative)
        if manifest.get("NSPrivacyTracking") is not False:
            fail(f"{relative}: NSPrivacyTracking must be false")
    if RELEASE:
        server = str(app.get("PetriServerURL", ""))
        email = str(app.get("PetriSupportEmail", ""))
        if ".invalid" in email or "@" not in email:
            fail("release: set PetriSupportEmail in App/Info.plist to a real address")
        publisher = str(app.get("PetriPublisherName", ""))
        if ".invalid" in publisher or not publisher.strip():
            fail("release: set PetriPublisherName in App/Info.plist to the person or company that publishes the app")
        share = str(app.get("PetriShareURL", ""))
        if ".invalid" in share or not share.startswith("https://"):
            fail("release: set PetriShareURL in App/Info.plist to the https page the share cards' QR code opens")
        if app.get("PetriCrewEnabled", True) and (".invalid" in server or not server.startswith("https://")):
            fail("release: set PetriServerURL in App/Info.plist to the deployed https server, or set PetriCrewEnabled to false")


def check_content():
    germs = read_json("App/Content/germs.json") or []
    articles = read_json("App/Content/articles.json") or []
    legal = read_json("App/Content/legal.json") or {}
    if len(germs) != 24:
        fail(f"germs.json: expected 24 germs, found {len(germs)}")
    if sorted(g.get("number") for g in germs) != list(range(1, len(germs) + 1)):
        fail("germs.json: numbers must run from 1 without gaps")
    if len({g.get("id") for g in germs}) != len(germs):
        fail("germs.json: duplicate ids")
    rarities = {"common", "uncommon", "rare", "epic", "legendary"}
    for germ in germs:
        gid = germ.get("id", "?")
        for key in ("illness", "phrase", "scientific", "showsUp", "lasts", "doctor"):
            localized(germ.get(key), f"germs.json {gid}.{key}")
        if germ.get("family") not in ("airways", "gut", "skin", "other"):
            fail(f"germs.json {gid}: family must be airways, gut, skin or other")
        up_to = germ.get("lastsUpToDays")
        if up_to is not None and (not isinstance(up_to, int) or up_to < 1):
            fail(f"germs.json {gid}: lastsUpToDays must be a positive number of days")
        localized(germ.get("doctorLead"), f"germs.json {gid}.doctorLead")
        if not germ.get("doctorSigns"):
            fail(f"germs.json {gid}: needs at least one doctorSigns entry")
        for index, sign in enumerate(germ.get("doctorSigns", [])):
            localized(sign, f"germs.json {gid}.doctorSigns[{index}]")
        if germ.get("doctorNote") is not None:
            localized(germ.get("doctorNote"), f"germs.json {gid}.doctorNote")
        boss = germ.get("boss") or {}
        localized(boss.get("attack"), f"germs.json {gid}.boss.attack")
        localized(boss.get("weakness"), f"germs.json {gid}.boss.weakness")
        myth = germ.get("myth") or {}
        localized(myth.get("claim"), f"germs.json {gid}.myth.claim")
        localized(myth.get("explanation"), f"germs.json {gid}.myth.explanation")
        if not isinstance(myth.get("isTrue"), bool):
            fail(f"germs.json {gid}: myth.isTrue must be true or false")
        kid = germ.get("kidSource")
        if kid is not None and kid not in [source.get("url") for source in germ.get("sources", [])]:
            fail(f"germs.json {gid}: kidSource must be one of the germ's sources")
        for key in ("showsUp", "lasts"):
            for language, text in (germ.get(key) or {}).items():
                if len(str(text)) > TILE_TEXT_LIMIT:
                    fail(f"germs.json {gid}.{key}.{language}: longer than {TILE_TEXT_LIMIT} characters, the timeline column shows two lines")
        if germ.get("rarity") not in rarities:
            fail(f"germs.json {gid}: unknown rarity")
        for key in ("tintLight", "tintDeep"):
            if not re.fullmatch(r"#[0-9A-Fa-f]{6}", str(germ.get(key))):
                fail(f"germs.json {gid}: {key} must be #RRGGBB")
        low, high = germ.get("incubationMinHours"), germ.get("incubationMaxHours")
        if (low is None) != (high is None) or (low is not None and not 0 < low < high):
            fail(f"germs.json {gid}: incubation hours must be both set, with min below max")
        if len(germ.get("facts", [])) < 2 or len(germ.get("tips", [])) < 2 or not germ.get("deepDive"):
            fail(f"germs.json {gid}: needs facts, tips and a deep dive")
        for index, item in enumerate(germ.get("facts", [])):
            localized(item.get("label"), f"germs.json {gid}.facts[{index}].label")
            localized(item.get("value"), f"germs.json {gid}.facts[{index}].value")
        for index, item in enumerate(germ.get("tips", [])):
            localized(item.get("title"), f"germs.json {gid}.tips[{index}].title")
            localized(item.get("body"), f"germs.json {gid}.tips[{index}].body")
        for index, item in enumerate(germ.get("deepDive", [])):
            localized(item, f"germs.json {gid}.deepDive[{index}]")
        check_health_sheet(germ, gid)
        check_sources(germ.get("sources"), f"germs.json {gid}")
    if not articles:
        fail("articles.json: no articles")
    thresholds = [article.get("unlockAtAnswers") for article in articles]
    if not all(isinstance(value, int) and value >= 0 for value in thresholds) or len(set(thresholds)) != len(thresholds):
        fail("articles.json: every article needs its own unlockAtAnswers, a whole number from 0")
    for article in articles:
        aid = article.get("id", "?")
        localized(article.get("title"), f"articles.json {aid}.title")
        localized(article.get("summary"), f"articles.json {aid}.summary")
        for index, item in enumerate(article.get("paragraphs", [])):
            localized(item, f"articles.json {aid}.paragraphs[{index}]")
        check_sources(article.get("sources"), f"articles.json {aid}")
    for kind in ("privacy", "terms"):
        sections = legal.get(kind) or []
        if not sections:
            fail(f"legal.json: no {kind} sections")
        for index, section in enumerate(sections):
            localized(section.get("title"), f"legal.json {kind}[{index}].title")
            localized(section.get("body"), f"legal.json {kind}[{index}].body")
    for key in ("privacyTitle", "termsTitle", "supportTitle", "updatedLabel", "publisherLabel", "contactLabel",
                "eulaLabel", "supportIntro", "supportDelete", "landingTagline", "landingIntro", "landingStore",
                "landingSoon"):
        localized((legal.get("web") or {}).get(key), f"legal.json web.{key}")
    points = (legal.get("web") or {}).get("landingPoints") or []
    if not points:
        fail("legal.json: web.landingPoints is empty")
    for index, point in enumerate(points):
        localized(point, f"legal.json web.landingPoints[{index}]")
    if (ROOT / "server/legal.json").is_file() and (ROOT / "App/Content/legal.json").is_file():
        if (ROOT / "server/legal.json").read_bytes() != (ROOT / "App/Content/legal.json").read_bytes():
            fail("server/legal.json must be identical to App/Content/legal.json")
    server = (ROOT / "server/server.js").read_text(encoding="utf-8") if (ROOT / "server/server.js").is_file() else ""
    block = re.search(r"const GERM_IDS = new Set\(\[(.*?)\]\)", server, re.S)
    server_ids = set(re.findall(r"'([a-z]+)'", block.group(1))) if block else set()
    if server_ids != {g.get("id") for g in germs}:
        fail("server/server.js: GERM_IDS must match the ids in germs.json")
    return germs


def check_health_sheet(germ, gid):
    """The case file's own sections: what it is, symptoms and spread, each list keyed even when empty."""
    localized(germ.get("about"), f"germs.json {gid}.about")
    for key in ("aboutMore", "symptomsNote", "spreadNote"):
        if germ.get(key) is not None:
            localized(germ.get(key), f"germs.json {gid}.{key}")
    for key in ("symptoms", "spreads"):
        if not isinstance(germ.get(key), list):
            fail(f"germs.json {gid}: {key} must be a list, empty when the sources say nothing")
    engine = (ROOT / "App/Store/SymptomEngine.swift").read_text(encoding="utf-8")
    signs = set(re.findall(r'Symptom\(id: "([a-z_]+)"', engine))
    for index, item in enumerate(germ.get("symptoms") or []):
        if not item.get("icon"):
            fail(f"germs.json {gid}.symptoms[{index}]: needs an icon")
        localized(item.get("text"), f"germs.json {gid}.symptoms[{index}].text")
        for tag in item.get("tags") or []:
            if tag not in signs:
                fail(f"germs.json {gid}.symptoms[{index}]: tag {tag!r} is not a sign of the symptom picker")
    for index, item in enumerate(germ.get("spreads") or []):
        if not item.get("icon"):
            fail(f"germs.json {gid}.spreads[{index}]: needs an icon")
        localized(item.get("title"), f"germs.json {gid}.spreads[{index}].title")
        if item.get("detail") is not None:
            localized(item.get("detail"), f"germs.json {gid}.spreads[{index}].detail")


def check_sources(sources, where):
    if not sources:
        fail(f"{where}: needs at least one source")
        return
    for source in sources:
        if not source.get("name") or not str(source.get("url", "")).startswith("https://"):
            fail(f"{where}: every source needs a name and an https url")


def imageset_ok(catalog, name):
    folder = ROOT / catalog / f"{name}.imageset"
    contents = folder / "Contents.json"
    if not contents.is_file():
        return False
    try:
        images = json.loads(contents.read_text())["images"]
    except Exception:
        return False
    return any("filename" in image and (folder / image["filename"]).is_file() for image in images)


def check_assets(germs):
    for germ in germs:
        for catalog in ("App/Assets.xcassets", "Widgets/Assets.xcassets"):
            if not imageset_ok(catalog, f"germ-{germ.get('id')}"):
                fail(f"{catalog}: missing image germ-{germ.get('id')}")
    for name in ("dish", "sticker-soup", "sticker-tissue", "sticker-tea", "sticker-heart"):
        if not imageset_ok("App/Assets.xcassets", name):
            fail(f"App/Assets.xcassets: missing image {name}")
    for catalog, colors in (("App/Assets.xcassets", ("AccentColor", "LaunchBackground")),
                            ("Widgets/Assets.xcassets", ("AccentColor", "WidgetBackground"))):
        for color in colors:
            if not (ROOT / catalog / f"{color}.colorset" / "Contents.json").is_file():
                fail(f"{catalog}: missing color {color}")

    progress = (ROOT / "App/Models/Progress.swift").read_text(encoding="utf-8")
    alternates = set(re.findall(r'return "(AppIcon[A-Za-z]+)"', progress))
    options = re.search(r"enum AppIconOption.*?var id", progress, re.S)
    cases = re.findall(r"case (\w+)", options.group(0)) if options else []
    project = (ROOT / "project.yml").read_text(encoding="utf-8")
    declared = re.search(r'ASSETCATALOG_COMPILER_ALTERNATE_APPICON_NAMES:\s*"([^"]*)"', project)
    if not declared or set(declared.group(1).split()) != alternates:
        fail("project.yml: alternate icon names must match AppIconOption.alternateName")
    for name in {"AppIcon"} | alternates:
        folder = ROOT / "App/Assets.xcassets" / f"{name}.appiconset"
        pngs = list(folder.glob("*.png")) if folder.is_dir() else []
        if len(pngs) != 1:
            fail(f"App/Assets.xcassets: {name}.appiconset needs exactly one PNG")
            continue
        info = png_info(pngs[0])
        if not info or info[:2] != (1024, 1024) or info[2]:
            fail(f"{name}: the icon must be a 1024x1024 PNG without an alpha channel")
    for case in cases:
        if not imageset_ok("App/Assets.xcassets", f"icon-preview-{case}"):
            fail(f"App/Assets.xcassets: missing image icon-preview-{case}")


def parse_strings(relative):
    table = {}
    path = ROOT / relative
    if not path.is_file():
        return table
    for number, line in enumerate(path.read_text(encoding="utf-8").splitlines(), 1):
        stripped = line.strip()
        if not stripped or stripped.startswith("/*"):
            continue
        match = STRING_LINE.match(stripped)
        if not match:
            fail(f"{relative}:{number}: malformed line")
            continue
        if match.group(1) in table:
            fail(f"{relative}:{number}: duplicate key")
        table[match.group(1)] = match.group(2)
    return table


def check_strings():
    english = parse_strings("Shared/en.lproj/Localizable.strings")
    french = parse_strings("Shared/fr.lproj/Localizable.strings")
    if set(english) != set(french):
        fail(f"Localizable.strings: en and fr keys differ ({len(set(english) ^ set(french))} keys)")
    for key, value in french.items():
        if sorted(SPEC.findall(key)) != sorted(SPEC.findall(value)):
            fail(f"fr Localizable.strings: format specifiers differ for {key!r}")
    for key, value in english.items():
        if sorted(SPEC.findall(key)) != sorted(SPEC.findall(value)):
            fail(f"en Localizable.strings: format specifiers differ for {key!r}")
    for language in ("en", "fr"):
        info = parse_strings(f"App/{language}.lproj/InfoPlist.strings")
        for key in ("NSCameraUsageDescription", "NSPhotoLibraryAddUsageDescription"):
            if key not in info:
                fail(f"App/{language}.lproj/InfoPlist.strings: missing {key}")


def main():
    check_files()
    check_plists()
    germs = check_content()
    check_assets(germs)
    check_strings()
    if errors:
        print(f"check_repo: {len(errors)} problem(s)")
        for message in errors:
            print("  - " + message)
        sys.exit(1)
    print("check_repo: OK" + (" (release)" if RELEASE else ""))


if __name__ == "__main__":
    main()
