#!/usr/bin/env python3
"""Static checks on the Swift sources that need no compiler.

Catches the mistakes that are cheap to find early: unbalanced delimiters, missing translations,
format strings whose arguments do not match, shared code that depends on app-only types,
image names that are not in the asset catalog, and color values kept outside Shared/Swatch.swift.
"""
import json
import pathlib
import re
import sys

ROOT = pathlib.Path(__file__).resolve().parent.parent
TARGETS = {"Germily": ["App", "Shared"], "GermilyWidgets": ["Widgets", "Shared"]}
CATALOG = {"App": "App/Assets.xcassets", "Widgets": "Widgets/Assets.xcassets"}
SWATCH = "Shared/Swatch.swift"
STRING = r'"((?:[^"\\]|\\.)*)"'
SPEC = re.compile(r"%(?:(\d+)\$)?(?:lld|@|d|f)")
STRING_LINE = re.compile(r'^"((?:[^"\\]|\\.)*)"\s*=\s*"((?:[^"\\]|\\.)*)";\s*$')
TYPE_DECL = re.compile(r"^(?:public |internal |private |fileprivate )?(?:final )?(?:struct|class|enum|protocol|actor) ([A-Za-z_][A-Za-z0-9_]*)", re.M)
KEY_PATTERNS = [
    re.compile(r"\bone:\s*" + STRING),
    re.compile(r"\bother:\s*" + STRING),
    re.compile(r"LocalizedStringResource\s*=\s*" + STRING),
    re.compile(r"IntentDescription\(\s*" + STRING),
    re.compile(r"shortTitle:\s*" + STRING),
    re.compile(r"@Parameter\(title:\s*" + STRING),
    re.compile(r"\.value\(\s*" + STRING),
]
errors = []
warnings = []


def fail(message):
    errors.append(message)


def swift_files(folder):
    return sorted((ROOT / folder).rglob("*.swift"))


def strip(source, keep_strings):
    """Blanks out comments, and string contents unless keep_strings, preserving length and newlines."""
    out = []
    i, n = 0, len(source)
    while i < n:
        two = source[i:i + 2]
        if two == "//":
            end = source.find("\n", i)
            end = n if end == -1 else end
            out.append(" " * (end - i))
            i = end
        elif two == "/*":
            end = source.find("*/", i + 2)
            end = n if end == -1 else end + 2
            out.append("".join("\n" if ch == "\n" else " " for ch in source[i:end]))
            i = end
        elif source[i] == '"':
            j = i + 1
            while j < n and source[j] != '"' and source[j] != "\n":
                j += 2 if source[j] == "\\" else 1
            j = min(j, n - 1)
            body = source[i + 1:j]
            out.append('"' + (body if keep_strings else " " * len(body)) + '"')
            i = j + 1
        else:
            out.append(source[i])
            i += 1
    return "".join(out)


def unescape(text):
    return text.replace('\\"', '"').replace("\\\\", "\\")


def load_strings(language):
    table = {}
    path = ROOT / "Shared" / f"{language}.lproj" / "Localizable.strings"
    for line in path.read_text(encoding="utf-8").splitlines():
        match = STRING_LINE.match(line.strip())
        if match:
            table[unescape(match.group(1))] = unescape(match.group(2))
    return table


def specifier_count(key):
    found = list(SPEC.finditer(key))
    positions = {int(m.group(1)) for m in found if m.group(1)}
    return max(positions) if positions else len(found)


def call_arguments(code, start):
    """Counts the top-level arguments of the call whose opening parenthesis is at start."""
    depth, count, seen = 0, 0, False
    for index in range(start, len(code)):
        char = code[index]
        if char in "([{":
            depth += 1
        elif char in ")]}":
            depth -= 1
            if depth == 0:
                return count + (1 if seen else 0)
        elif depth == 1:
            if char == ",":
                count += 1
                seen = False
            elif not char.isspace():
                seen = True
    return -1


def check_balance(path, code):
    pairs = {")": "(", "]": "[", "}": "{"}
    stack = []
    line = 1
    for char in code:
        if char == "\n":
            line += 1
        elif char in "([{":
            stack.append((char, line))
        elif char in pairs:
            if not stack or stack[-1][0] != pairs[char]:
                fail(f"{path}:{line}: unexpected '{char}'")
                return
            stack.pop()
    if stack:
        fail(f"{path}:{stack[-1][1]}: '{stack[-1][0]}' is never closed")


def check_keys(path, code, kept, english, french):
    used = []
    for match in re.finditer(r"\btr\(\s*" + STRING, kept):
        key = unescape(match.group(1))
        used.append(key)
        arguments = call_arguments(code, match.start() + 2)
        expected = specifier_count(key) + 1
        if arguments != expected:
            line = kept.count("\n", 0, match.start()) + 1
            fail(f"{path}:{line}: tr() has {arguments - 1} argument(s) but the text has {expected - 1} placeholder(s): {key!r}")
    for pattern in KEY_PATTERNS:
        for match in pattern.finditer(kept):
            key = unescape(match.group(1))
            used.append(key)
            if pattern.pattern.startswith(r"\bone") or pattern.pattern.startswith(r"\bother"):
                if specifier_count(key) > 1:
                    fail(f"{path}: trCount text takes at most one placeholder: {key!r}")
    for key in used:
        if key not in english:
            fail(f"{path}: text missing from en Localizable.strings: {key!r}")
        if key not in french:
            fail(f"{path}: text missing from fr Localizable.strings: {key!r}")
    return set(used)


def catalog_images(folder):
    root = ROOT / CATALOG[folder]
    return {p.name[:-len(".imageset")] for p in root.glob("*.imageset")} if root.is_dir() else set()


def check_images(path, kept, folder):
    names = catalog_images(folder)
    for match in re.finditer(r"\bImage\(\s*" + STRING + r"\s*\)", kept):
        if match.group(1) not in names:
            fail(f"{path}: image {match.group(1)!r} is not in {CATALOG[folder]}")
    for match in re.finditer(r"\bImage\(\s*" + STRING + r"\s*\+", kept):
        prefix = match.group(1)
        if not any(name.startswith(prefix) for name in names):
            fail(f"{path}: no image starts with {prefix!r} in {CATALOG[folder]}")
    for match in re.finditer(r'id:\s*"(germ-[a-z]+)"', kept):
        if match.group(1) not in names:
            fail(f"{path}: image {match.group(1)!r} is not in {CATALOG[folder]}")


def check_stored_properties(path, code):
    """Warns about private stored properties that make a memberwise initializer private."""
    lines = code.splitlines()
    for number, line in enumerate(lines, 1):
        text = line.strip()
        if not re.match(r"private (var|let) \w+", text) or "{" in text:
            continue
        if text.startswith("private let") and "=" in text:
            continue
        previous = lines[number - 2].strip() if number >= 2 else ""
        if previous.startswith("@") or "static" in text:
            continue
        warnings.append(f"{path}:{number}: private stored property may hide the memberwise initializer: {text[:60]}")


def main():
    english = load_strings("en")
    french = load_strings("fr")
    sources = {}
    for folder in ("App", "Shared", "Widgets"):
        for path in swift_files(folder):
            raw = path.read_text(encoding="utf-8")
            sources[path] = (folder, strip(raw, keep_strings=False), strip(raw, keep_strings=True), raw)

    used_keys = set()
    declared = {"App": {}, "Shared": {}, "Widgets": {}}
    for path, (folder, code, kept, raw) in sources.items():
        relative = path.relative_to(ROOT).as_posix()
        check_balance(relative, code)
        used_keys |= check_keys(relative, code, kept, english, french)
        if folder in CATALOG:
            check_images(relative, kept, folder)
        if relative.startswith(("App/Screens/", "App/Design/", "Widgets/")):
            check_stored_properties(relative, code)
        if re.search(r"\b(TODO|FIXME|XXX)\b", raw):
            fail(f"{relative}: leftover TODO or FIXME")
        if re.search(r"^\s*(debugPrint|print)\(", code, re.M):
            fail(f"{relative}: leftover print statement")
        if relative != SWATCH and re.search(r"\b0x[0-9A-Fa-f]{6}\b", code):
            fail(f"{relative}: color value written outside {SWATCH}")
        top_level = [m.group(1) for m in TYPE_DECL.finditer(code)]
        for name in top_level:
            declared[folder].setdefault(name, relative)

    for target, folders in TARGETS.items():
        seen = {}
        mains = 0
        for path, (folder, code, _kept, _raw) in sources.items():
            if folder not in folders:
                continue
            relative = path.relative_to(ROOT).as_posix()
            mains += len(re.findall(r"^@main\b", code, re.M))
            for match in TYPE_DECL.finditer(code):
                if match.group(0).startswith(("private ", "fileprivate ")):
                    continue
                name = match.group(1)
                if name in seen and seen[name] != relative:
                    fail(f"{target}: type {name} is declared in both {seen[name]} and {relative}")
                seen[name] = relative
        if mains != 1:
            fail(f"{target}: expected exactly one @main, found {mains}")

    app_only = set(declared["App"]) - set(declared["Shared"]) - set(declared["Widgets"])
    for path, (folder, code, _kept, _raw) in sources.items():
        if folder == "App":
            continue
        relative = path.relative_to(ROOT).as_posix()
        for name in app_only:
            if re.search(r"\b" + re.escape(name) + r"\b", code):
                fail(f"{relative}: uses {name}, which only exists in the app target ({declared['App'][name]})")

    swatch = (ROOT / SWATCH).read_text(encoding="utf-8")
    elsewhere = "\n".join(code for path, (_f, code, _k, _r) in sources.items() if path.relative_to(ROOT).as_posix() != SWATCH)
    for name in re.findall(r"static let (\w+): UInt32", swatch):
        if not re.search(r"\bSwatch\." + name + r"\b", elsewhere):
            fail(f"{SWATCH}: color {name} is not used anywhere")

    unused = sorted(set(english) - used_keys)
    for key in unused:
        fail(f"Localizable.strings: text is not used anywhere in the code: {key!r}")

    for message in warnings:
        print("warning: " + message)
    if errors:
        print(f"check_swift: {len(errors)} problem(s)")
        for message in errors:
            print("  - " + message)
        sys.exit(1)
    print(f"check_swift: OK ({len(sources)} files, {len(used_keys)} texts)")


if __name__ == "__main__":
    main()
