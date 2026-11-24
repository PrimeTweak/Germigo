#!/usr/bin/env python3
"""Checks that the repository is complete and consistent before a build.
Usage: python3 tools/check_repo.py [--release]. With --release, placeholders that must be
replaced before an App Store upload also fail the check."""
import datetime
import json
import pathlib
import plistlib
import re
import struct
import sys

ROOT = pathlib.Path(__file__).resolve().parent.parent
RELEASE = "--release" in sys.argv
errors = []
notes = []
SPEC = re.compile(r"%(?:\d+\$)?(?:lld|@|d|f)")
STRING_LINE = re.compile(r'^"((?:[^"\\]|\\.)*)"\s*=\s*"((?:[^"\\]|\\.)*)";\s*$')

# Longest "Shows up" or "Lasts" text a timeline column of a germ page is given.
TILE_TEXT_LIMIT = 30

# Publishers whose pages may back a health text; a subdomain counts as its publisher.
TRUSTED_SOURCES = ("canada.ca", "quebec.ca", "inspq.qc.ca", "cps.ca", "cdc.gov", "nhs.uk", "medlineplus.gov",
                   "aap.org", "healthychildren.org", "mayoclinic.org", "ncbi.nlm.nih.gov", "hse.ie", "asm.org", "ucl.ac.uk")
# Words that would turn a health text into dosing advice.
DOSING = re.compile(r"\b(?:mg|ml|doses?|dosage|dosing|posologie|give (?:your|the) (?:child|kid|baby)|"
                    r"donne(?:-lui| à ton enfant| à ton bébé))\b", re.I)
NUMBER = re.compile(r"\d+(?:[.,]\d+)?")
THOUSANDS = re.compile(r"(?<=\d)[,\s\u00a0\u202f](?=\d{3}\b)")
# A Fahrenheit conversion given only in English, beside its Celsius figure.
FAHRENHEIT = re.compile(r"\d+(?:[.,]\d+)?\s*°F")
REPORT_HEADLINE_LIMIT = 70
REPORT_LINE_LIMIT = 90
TRENDS = ("rising", "steady", "falling", "low")
MYTH_CLAIM_LIMIT = 90
MYTH_EXPLANATION_LIMIT = 200
# A review older than this is flagged as due for a new one.
REVIEW_MAX_DAYS = 730
DAY = re.compile(r"\d{4}-\d{2}-\d{2}")

REQUIRED = [
    "project.yml", ".gitignore", ".github/workflows/build-ipa.yml", ".github/workflows/release.yml",
    "App/Info.plist", "App/Germily.entitlements", "App/PrivacyInfo.xcprivacy", "App/GermilyApp.swift",
    "App/Content/germs.json", "App/Content/articles.json", "App/Content/legal.json",
    "App/en.lproj/InfoPlist.strings", "App/fr.lproj/InfoPlist.strings",
    "App/Sounds/flap.wav", "App/Sounds/reveal.wav", "App/Sounds/badge.wav",
    "Shared/en.lproj/Localizable.strings", "Shared/fr.lproj/Localizable.strings",
    "Widgets/Info.plist", "Widgets/GermilyWidgets.entitlements", "Widgets/PrivacyInfo.xcprivacy",
    "server/server.js", "server/test.js", "server/legal.json", "server/package.json",
    "server/illnesses.json", "server/text.json", "server/push.js", "server/mail.js",
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
                "NSPhotoLibraryAddUsageDescription", "NSFaceIDUsageDescription", "NSMotionUsageDescription",
                "BGTaskSchedulerPermittedIdentifiers",
                "CFBundleLocalizations"):
        if key not in app:
            fail(f"App/Info.plist: missing {key}")
    if widgets.get("NSExtension", {}).get("NSExtensionPointIdentifier") != "com.apple.widgetkit-extension":
        fail("Widgets/Info.plist: wrong extension point")
    for relative in ("App/Germily.entitlements", "Widgets/GermilyWidgets.entitlements"):
        groups = read_plist(relative).get("com.apple.security.application-groups", [])
        if groups != ["group.ca.germily.app"]:
            fail(f"{relative}: app group must be group.ca.germily.app")
    if read_plist("App/Germily.entitlements").get("aps-environment") not in ("development", "production"):
        fail("App/Germily.entitlements: aps-environment is needed for daycare notices")
    for relative in ("App/PrivacyInfo.xcprivacy", "Widgets/PrivacyInfo.xcprivacy"):
        manifest = read_plist(relative)
        if manifest.get("NSPrivacyTracking") is not False:
            fail(f"{relative}: NSPrivacyTracking must be false")
    if RELEASE:
        server = str(app.get("GermilyServerURL", ""))
        email = str(app.get("GermilySupportEmail", ""))
        if ".invalid" in email or "@" not in email:
            fail("release: set GermilySupportEmail in App/Info.plist to a real address")
        publisher = str(app.get("GermilyPublisherName", ""))
        if ".invalid" in publisher or not publisher.strip():
            fail("release: set GermilyPublisherName in App/Info.plist to the person or company that publishes the app")
        share = str(app.get("GermilyShareURL", ""))
        if ".invalid" in share or not share.startswith("https://"):
            fail("release: set GermilyShareURL in App/Info.plist to the https page the share cards' QR code opens")
        if app.get("GermilyCrewEnabled", True) and (".invalid" in server or not server.startswith("https://")):
            fail("release: set GermilyServerURL in App/Info.plist to the deployed https server, or set GermilyCrewEnabled to false")


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
        myths = germ.get("myths")
        if not isinstance(myths, list) or not myths:
            fail(f"germs.json {gid}: needs a list of myths")
        urls = [source.get("url") for source in germ.get("sources", [])]
        for index, myth in enumerate(myths or []):
            where = f"germs.json {gid}.myths[{index}]"
            if not re.fullmatch(rf"{gid}-\d+", str(myth.get("id", ""))):
                fail(f"{where}: id must be {gid}- then a number")
            localized(myth.get("claim"), f"{where}.claim")
            localized(myth.get("explanation"), f"{where}.explanation")
            if not isinstance(myth.get("isTrue"), bool):
                fail(f"{where}: isTrue must be true or false")
            if myth.get("source") not in urls:
                fail(f"{where}: source must be the url of one of the germ's sources")
        kid = germ.get("kidSource")
        if kid is not None and kid not in [source.get("url") for source in germ.get("sources", [])]:
            fail(f"germs.json {gid}: kidSource must be one of the germ's sources")
        canada = germ.get("canadaSource")
        if canada is not None:
            localized(canada.get("name"), f"germs.json {gid}.canadaSource.name")
            localized(canada.get("url"), f"germs.json {gid}.canadaSource.url")
            if not all(str(url).startswith("https://") for url in (canada.get("url") or {}).values()):
                fail(f"germs.json {gid}: canadaSource urls must be https")
        words = germ.get("searchWords")
        if words is not None and not all(
                isinstance(words.get(language), list) and words[language]
                and all(isinstance(word, str) and word.strip() for word in words[language]) for language in ("en", "fr")):
            fail(f"germs.json {gid}: searchWords needs en and fr lists of words")
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
    for kind in ("privacy", "terms", "health"):
        sections = legal.get(kind) or []
        if not sections:
            fail(f"legal.json: no {kind} sections")
        for index, section in enumerate(sections):
            localized(section.get("title"), f"legal.json {kind}[{index}].title")
            localized(section.get("body"), f"legal.json {kind}[{index}].body")
    for key in ("privacyTitle", "termsTitle", "healthTitle", "supportTitle", "updatedLabel", "publisherLabel", "contactLabel",
                "eulaLabel", "supportIntro", "supportDelete", "landingTagline", "landingIntro", "landingStore",
                "landingSoon", "daycareHeading", "daycareSteps"):
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
    check_illnesses(germs)
    return germs


def texts(value, path=""):
    """Every text in English and French inside a piece of content, with where it sits."""
    if isinstance(value, dict):
        if set(value) & {"en", "fr"} and all(isinstance(item, str) for item in value.values()):
            yield path, value
            return
        for key, item in value.items():
            yield from texts(item, f"{path}.{key}" if path else key)
    elif isinstance(value, list):
        for index, item in enumerate(value):
            yield from texts(item, f"{path}[{index}]")


def numbers(text):
    return {item.replace(",", ".") for item in NUMBER.findall(THOUSANDS.sub("", FAHRENHEIT.sub("", text)))}


def check_texts(content, where):
    """The content rule, line by line: both languages, the same figures in each, and no dosing words."""
    for path, value in texts(content):
        place = f"{where}.{path}" if path else where
        if not value.get("en", "").strip() or not value.get("fr", "").strip():
            fail(f"{place}: needs non-empty en and fr text")
            continue
        if path.endswith("url"):
            continue
        if numbers(value["en"]) != numbers(value["fr"]):
            fail(f"{place}: en and fr give different figures ({sorted(numbers(value['en']))} vs {sorted(numbers(value['fr']))})")
        for language in ("en", "fr"):
            found = DOSING.search(value[language])
            if found:
                fail(f"{place}.{language}: {found.group(0)!r} reads as dosing advice; say what it is, never how much to take")


def trusted(url):
    host = re.sub(r"^https://([^/]+).*$", r"\1", url).lower()
    return any(host == name or host.endswith("." + name) for name in TRUSTED_SOURCES)


def check_trusted(urls, where):
    for url in urls:
        if not trusted(url):
            fail(f"{where}: {url} is not from a recognized health publisher (TRUSTED_SOURCES)")


def check_review(value, where, required):
    """The day a health professional approved the text, yyyy-mm-dd."""
    if value is None:
        if required:
            fail(f"{where}: needs reviewedOn, the day a health professional approved it (yyyy-mm-dd)")
        return False
    try:
        day = datetime.date.fromisoformat(value) if DAY.fullmatch(str(value)) else None
    except ValueError:
        day = None
    if day is None:
        fail(f"{where}: reviewedOn must be a real day written yyyy-mm-dd")
    elif day > datetime.date.today():
        fail(f"{where}: reviewedOn is in the future")
    elif (datetime.date.today() - day).days > REVIEW_MAX_DAYS:
        notes.append(f"{where}: reviewed on {value}, more than 2 years ago; due for a new review")
    return True


def check_lesson(lesson, where, live):
    if not lesson.get("id"):
        fail(f"{where}: needs an id")
    localized(lesson.get("title"), f"{where}.title")
    localized(lesson.get("summary"), f"{where}.summary")
    if not lesson.get("paragraphs"):
        fail(f"{where}: needs paragraphs")
    check_sources(lesson.get("sources"), where)
    if live:
        released = str(lesson.get("released", ""))
        try:
            datetime.date.fromisoformat(released) if DAY.fullmatch(released) else fail(f"{where}: released must be yyyy-mm-dd")
        except ValueError:
            fail(f"{where}: released must be a real day")
    elif "released" in lesson or "reviewedOn" in lesson:
        fail(f"{where}: a draft gets its release and review days when it moves to server/lessons.json")
    check_review(lesson.get("reviewedOn"), where, required=live)


def real_day(value, where, field):
    """A day written yyyy-mm-dd, or None after a failure."""
    try:
        return datetime.date.fromisoformat(value) if DAY.fullmatch(str(value)) else fail(f"{where}: {field} must be yyyy-mm-dd")
    except ValueError:
        return fail(f"{where}: {field} must be a real day")


def check_report(report, where, live, germ_ids):
    """A "Going around" report: a known country, real days, known germs, a trusted source, short lines."""
    if not report.get("id"):
        fail(f"{where}: needs an id")
    if report.get("region") not in ("CA", "US"):
        fail(f"{where}: region must be CA or US")
    real_day(report.get("week"), where, "week")
    published = real_day(report.get("published"), where, "published")
    if published and published > datetime.date.today():
        fail(f"{where}: published is in the future")
    check_texts(report, where)
    for language in ("en", "fr"):
        headline = (report.get("headline") or {}).get(language, "")
        if len(headline) > REPORT_HEADLINE_LIMIT:
            fail(f"{where}.headline.{language}: {len(headline)} characters, over {REPORT_HEADLINE_LIMIT}")
    if not report.get("germs"):
        fail(f"{where}: needs germs")
    for index, item in enumerate(report.get("germs") or []):
        place = f"{where}.germs[{index}]"
        if item.get("germID") not in germ_ids:
            fail(f"{place}: germID {item.get('germID')!r} is not in germs.json")
        if item.get("trend") not in TRENDS:
            fail(f"{place}: trend must be one of {', '.join(TRENDS)}")
        for language in ("en", "fr"):
            line = (item.get("line") or {}).get(language, "")
            if len(line) > REPORT_LINE_LIMIT:
                fail(f"{place}.line.{language}: {len(line)} characters, over {REPORT_LINE_LIMIT}")
    source = report.get("source") or {}
    if not source.get("name"):
        fail(f"{where}: the source needs a name")
    check_trusted([source.get("url", "")], where)
    if live:
        approved = real_day(report.get("approvedOn"), where, "approvedOn")
        if approved and approved > datetime.date.today():
            fail(f"{where}: approvedOn is in the future")
    elif "approvedOn" in report:
        fail(f"{where}: a draft gets its approval day when it moves to server/lessons.json")


def check_reports(germs):
    """The weekly "Going around" reports, served and in draft."""
    germ_ids = {germ.get("id") for germ in germs}
    live = (read_json("server/lessons.json") or {}).get("goingAround", [])
    drafts_file = ROOT / "server/drafts/going-around.json"
    drafts = (read_json("server/drafts/going-around.json") or {}).get("goingAround", []) if drafts_file.is_file() else []
    for name, reports, is_live in (("server/lessons.json", live, True), ("server/drafts/going-around.json", drafts, False)):
        for report in reports:
            check_report(report, f"{name} report {report.get('id', '?')}", is_live, germ_ids)
    ids = [report.get("id") for report in live + drafts]
    for duplicate in sorted({item for item in ids if ids.count(item) > 1}):
        fail(f"going around: id {duplicate!r} is used more than once across server/lessons.json and its drafts")
    if drafts:
        notes.append(f"{len(drafts)} Going around reports await approval in server/drafts/going-around.json")


def check_editorial(germs):
    """The content rule for the Guide: sourced, reviewed, bilingual, no dosing, myths short and unique.
    It covers the bundled germs and lessons, the online lesson file and its drafts."""
    articles = read_json("App/Content/articles.json") or []
    live = (read_json("server/lessons.json") or {}).get("lessons", [])
    drafts_file = ROOT / "server/drafts/lessons.json"
    drafts = (read_json("server/drafts/lessons.json") or {}).get("lessons", []) if drafts_file.is_file() else []
    unreviewed = 0
    claims = {"en": set(), "fr": set()}
    myth_ids = set()
    for germ in germs:
        gid = germ.get("id", "?")
        where = f"germs.json {gid}"
        check_texts(germ, where)
        canada = germ.get("canadaSource") or {}
        check_trusted([source.get("url", "") for source in germ.get("sources", [])]
                      + list((canada.get("url") or {}).values()), where)
        for index, myth in enumerate(germ.get("myths") or []):
            place = f"{where}.myths[{index}]"
            if myth.get("id") in myth_ids:
                fail(f"{place}: id {myth.get('id')} is used twice")
            myth_ids.add(myth.get("id"))
            for language in ("en", "fr"):
                claim = (myth.get("claim") or {}).get(language, "")
                explanation = (myth.get("explanation") or {}).get(language, "")
                if len(claim) > MYTH_CLAIM_LIMIT:
                    fail(f"{place}.claim.{language}: {len(claim)} characters, over {MYTH_CLAIM_LIMIT}")
                if len(explanation) > MYTH_EXPLANATION_LIMIT:
                    fail(f"{place}.explanation.{language}: {len(explanation)} characters, over {MYTH_EXPLANATION_LIMIT}")
                key = re.sub(r"[^\w]+", " ", claim.lower()).strip()
                if key in claims[language]:
                    fail(f"{place}.claim.{language}: the same myth appears twice")
                claims[language].add(key)
        if not check_review(germ.get("reviewedOn"), where, required=RELEASE):
            unreviewed += 1
    for article in articles:
        where = f"articles.json {article.get('id', '?')}"
        check_texts(article, where)
        check_trusted([source.get("url", "") for source in article.get("sources", [])], where)
        if not check_review(article.get("reviewedOn"), where, required=RELEASE):
            unreviewed += 1
    for name, lessons, is_live in (("server/lessons.json", live, True), ("server/drafts/lessons.json", drafts, False)):
        for lesson in lessons:
            where = f"{name} {lesson.get('id', '?')}"
            check_lesson(lesson, where, is_live)
            check_texts(lesson, where)
            check_trusted([source.get("url", "") for source in lesson.get("sources", [])], where)
    ids = [item.get("id") for item in articles + live + drafts]
    for duplicate in sorted({item for item in ids if ids.count(item) > 1}):
        fail(f"lessons: id {duplicate!r} is used more than once across articles.json, server/lessons.json and its drafts")
    if unreviewed:
        notes.append(f"{unreviewed} germs and bundled lessons have no reviewedOn yet; --release requires it")
    if drafts:
        notes.append(f"{len(drafts)} lessons await health review in server/drafts/lessons.json")


def check_illnesses(germs):
    """The names the server reads in email subjects and writes in notifications follow germs.json."""
    illnesses = read_json("server/illnesses.json") or {}
    expected = {g.get("id"): g for g in germs if g.get("id") != "mystery"}
    if set(illnesses) != set(expected):
        fail("server/illnesses.json: ids must be those of germs.json, without mystery")
    for gid, entry in illnesses.items():
        germ = expected.get(gid)
        if not germ:
            continue
        for language in ("en", "fr"):
            if entry.get(language) != (germ.get("illness") or {}).get(language):
                fail(f"server/illnesses.json {gid}.{language}: must match the illness name in germs.json")
        aliases = entry.get("aliases")
        if not isinstance(aliases, list) or not all(isinstance(alias, str) and alias.strip() for alias in aliases):
            fail(f"server/illnesses.json {gid}: aliases must be a list of names")


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


def mascot_faces():
    """The raw values of MascotFace, read from its enum: each one needs its mascot image."""
    code = (ROOT / "App/Design/MascotMind.swift").read_text()
    body = code.split("enum MascotFace", 1)[1].split("}", 1)[0]
    faces = []
    for line in body.splitlines():
        line = line.strip()
        if line.startswith("case "):
            for item in line[5:].split(","):
                name, _, raw = item.partition("=")
                faces.append(raw.strip().strip('"') if raw else name.strip())
    return faces


def look_count():
    """Looks.count, read from AppData.swift: each look needs its healthy and sick image."""
    match = re.search(r"enum Looks \{\s*static let count = (\d+)", (ROOT / "App/Models/AppData.swift").read_text())
    return int(match.group(1)) if match else 0


def check_assets(germs):
    count = look_count()
    if not count:
        fail("App/Models/AppData.swift: Looks.count not found")
    for look in range(count):
        for state in ("well", "sick"):
            if not imageset_ok("App/Assets.xcassets", f"buddy-{look}-{state}"):
                fail(f"App/Assets.xcassets: missing image buddy-{look}-{state}")
    for germ in germs:
        for catalog in ("App/Assets.xcassets", "Widgets/Assets.xcassets"):
            if not imageset_ok(catalog, f"germ-{germ.get('id')}"):
                fail(f"{catalog}: missing image germ-{germ.get('id')}")
    mascot = tuple(f"mascot-{face}" for face in mascot_faces() + ["pacifier"])
    levels_source = (ROOT / "App/Models/Progress.swift").read_text(encoding="utf-8")
    rewards = re.search(r"enum LevelRewards \{\s*static let stickers = \[([^\]]*)\]", levels_source)
    thresholds = re.search(r"static let thresholds = \[([^\]]*)\]", levels_source)
    stickers = tuple(f"sticker-{name}" for name in re.findall(r'"(\w+)"', rewards.group(1))) if rewards else ()
    if not thresholds or len(stickers) != len(thresholds.group(1).split(",")):
        fail("App/Models/Progress.swift: LevelRewards needs one sticker per level")
    book = re.search(r"enum StickerBook \{(.*?)\n    /// Where a sticker lands", levels_source, re.S)
    extras = tuple(f"sticker-{name}" for name in re.findall(r'"(\w+)"', book.group(1))) if book else ()
    if not extras:
        fail("App/Models/Progress.swift: StickerBook lists no stickers")
    stickers += extras
    for name in ("dish", "sticker-soup", "sticker-tissue", "sticker-tea", "sticker-heart") + stickers + mascot:
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
        for key in ("NSCameraUsageDescription", "NSPhotoLibraryAddUsageDescription", "NSFaceIDUsageDescription"):
            if key not in info:
                fail(f"App/{language}.lproj/InfoPlist.strings: missing {key}")


def main():
    check_files()
    check_plists()
    germs = check_content()
    check_editorial(germs)
    check_reports(germs)
    check_assets(germs)
    check_strings()
    if errors:
        print(f"check_repo: {len(errors)} problem(s)")
        for message in errors:
            print("  - " + message)
        sys.exit(1)
    print("check_repo: OK" + (" (release)" if RELEASE else ""))
    for message in notes:
        print("  note: " + message)


if __name__ == "__main__":
    main()
