#!/usr/bin/env python3
"""Inspects a built Germigo.app and reports what is actually inside it.

Usage: python3 tools/check_bundle.py path/to/Germigo.app
Missing essentials fail the check; everything else is printed as a measured fact or a warning.
"""
import pathlib
import plistlib
import sys

ALTERNATES = ["AppIconDaylight", "AppIconNightShift", "AppIconSnowDay", "AppIconSoupBowl", "AppIconGolden", "AppIconHolo"]
ESSENTIAL = [
    "Germigo", "Info.plist", "Assets.car", "germs.json", "articles.json", "legal.json",
    "en.lproj/Localizable.strings", "fr.lproj/Localizable.strings",
    "PlugIns/GermigoWidgets.appex/GermigoWidgets", "PlugIns/GermigoWidgets.appex/Info.plist",
]
EXPECTED = [
    "PrivacyInfo.xcprivacy", "flap.wav", "reveal.wav", "badge.wav",
    "en.lproj/InfoPlist.strings", "fr.lproj/InfoPlist.strings",
    "PlugIns/GermigoWidgets.appex/Assets.car", "PlugIns/GermigoWidgets.appex/PrivacyInfo.xcprivacy",
    "PlugIns/GermigoWidgets.appex/en.lproj/Localizable.strings",
    "PlugIns/GermigoWidgets.appex/fr.lproj/Localizable.strings",
]


def main():
    if len(sys.argv) != 2:
        print(__doc__)
        sys.exit(2)
    app = pathlib.Path(sys.argv[1])
    errors, warnings = [], []
    if not app.is_dir():
        print(f"check_bundle: {app} does not exist")
        sys.exit(1)

    for relative in ESSENTIAL:
        if not (app / relative).is_file():
            errors.append(f"missing {relative}")
    for relative in EXPECTED:
        if not (app / relative).is_file():
            warnings.append(f"missing {relative}")
    for path in app.rglob("Resources"):
        if path.is_dir():
            errors.append(f"reserved folder name inside the bundle: {path.relative_to(app)}")

    info, widget = {}, {}
    try:
        info = plistlib.loads((app / "Info.plist").read_bytes())
        widget = plistlib.loads((app / "PlugIns/GermigoWidgets.appex/Info.plist").read_bytes())
    except Exception as error:
        errors.append(f"unreadable Info.plist: {error}")

    print("Bundle facts")
    for key in ("CFBundleIdentifier", "CFBundleShortVersionString", "CFBundleVersion", "MinimumOSVersion",
                "DTSDKName", "DTXcode", "DTXcodeBuild", "DTPlatformVersion"):
        print(f"  {key}: {info.get(key)}")
    print(f"  widget CFBundleIdentifier: {widget.get('CFBundleIdentifier')}")
    size = sum(p.stat().st_size for p in app.rglob("*") if p.is_file())
    print(f"  size on disk: {size / 1_000_000:.1f} MB")

    for key in ("CFBundleShortVersionString", "CFBundleVersion"):
        if info.get(key) != widget.get(key):
            errors.append(f"{key} differs between the app ({info.get(key)}) and the widget extension ({widget.get(key)})")
    if widget.get("NSExtension", {}).get("NSExtensionPointIdentifier") != "com.apple.widgetkit-extension":
        errors.append("the widget extension has the wrong extension point")
    if not str(widget.get("CFBundleIdentifier", "")).startswith(str(info.get("CFBundleIdentifier", "?")) + "."):
        errors.append("the widget bundle identifier must start with the app bundle identifier")

    sdk = str(info.get("DTSDKName", ""))
    digits = "".join(ch for ch in sdk.replace("iphoneos", "").split(".")[0] if ch.isdigit())
    if not sdk.startswith("iphoneos") or not digits or int(digits) < 26:
        warnings.append(f"built with SDK {sdk or 'unknown'}; App Store uploads need the iOS 26 SDK or later")

    icons = info.get("CFBundleIcons", {})
    found = sorted(icons.get("CFBundleAlternateIcons", {}).keys())
    print(f"  alternate icons: {', '.join(found) if found else 'none'}")
    for name in ALTERNATES:
        if name not in found:
            warnings.append(f"alternate icon {name} is not declared in the built Info.plist")
    for key in ("NSSupportsLiveActivities", "NSPhotoLibraryAddUsageDescription", "ITSAppUsesNonExemptEncryption"):
        if key not in info:
            warnings.append(f"{key} is missing from the built Info.plist")

    for message in warnings:
        print("warning: " + message)
    if errors:
        print(f"check_bundle: {len(errors)} problem(s)")
        for message in errors:
            print("  - " + message)
        sys.exit(1)
    print("check_bundle: OK")


if __name__ == "__main__":
    main()
