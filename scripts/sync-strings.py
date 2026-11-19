#!/usr/bin/env python3
"""Fills the string catalogs from a build, the way Xcode does when it builds in the IDE.

The Swift compiler writes every localizable text it finds into `.stringsdata` files (SWIFT_EMIT_LOC_STRINGS).
This script merges them into `Kept/Localizable.xcstrings` and `KeptWidgets/Localizable.xcstrings`:
new texts are added, texts no longer in the code are marked stale, translations are never touched.

Usage: build once (any destination), then run `scripts/sync-strings.py`. `--check` only reports.
"""
import glob
import json
import os
import subprocess
import sys

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
TARGETS = {"Kept": "Kept/Localizable.xcstrings", "KeptWidgets": "KeptWidgets/Localizable.xcstrings"}
# Shown through `LocalizedStringKey(rawValue)`, which the compiler cannot see: picker options backed by raw values.
MANUAL = {"Kept": ["Všechny", "Získané", "Zbývá", "Vše", "Dny", "Selhání", "Týdny", "Váha", "Odhad maxima", "Objem",
                   "Rychle", "Kopie týdne", "Jeden úkol"]}
LETTERS = __import__("re").compile(r"[^\W\d_]")
FORMAT = __import__("re").compile(r"%(?:\d+\$)?(?:lld|ld|d|@|f|\.\d+f|lf|%)")


def derived_data():
    out = subprocess.run(["xcodebuild", "-scheme", "Kept", "-showBuildSettings", "-json"], cwd=ROOT,
                         capture_output=True, text=True).stdout
    settings = json.loads(out)
    return settings[0]["buildSettings"]["OBJROOT"]


def extracted(objroot, target):
    keys = {}
    for path in glob.glob(f"{objroot}/Kept.build/*/{target}.build/Objects-normal/*/*.stringsdata"):
        if os.path.basename(path).startswith("ExtractedAppShortcuts"):
            continue
        with open(path, encoding="utf-8") as f:
            data = json.load(f)
        for entry in data.get("tables", {}).get("Localizable", []):
            keys.setdefault(entry["key"], entry.get("comment", ""))
    return keys


def sync(catalog_path, keys, check, manual=()):
    path = os.path.join(ROOT, catalog_path)
    if os.path.exists(path):
        with open(path, encoding="utf-8") as f:
            catalog = json.load(f)
    else:
        catalog = {"sourceLanguage": "cs", "strings": {}, "version": "1.0"}
    strings = catalog["strings"]
    keys = dict(keys)
    for key in manual:
        keys.setdefault(key, "")
    added = [k for k in keys if k not in strings]
    for key in added:
        strings[key] = {}
        # Nothing to translate in a text made only of numbers, symbols and placeholders.
        if not LETTERS.search(FORMAT.sub("", key)):
            strings[key]["shouldTranslate"] = False
    stale = 0
    for key, entry in strings.items():
        if key in keys or key in manual:
            entry.pop("extractionState", None)
            if keys[key]:
                entry["comment"] = keys[key]
        elif entry.get("extractionState") not in ("manual",):
            entry["extractionState"] = "stale"
            stale += 1
    missing = [k for k, e in strings.items()
               if e.get("extractionState") != "stale" and e.get("shouldTranslate", True)
               and "en" not in e.get("localizations", {})]
    print(f"{catalog_path}: {len(keys)} in code, {len(added)} new, {stale} stale, {len(missing)} without English")
    if not check:
        catalog["strings"] = dict(sorted(strings.items(), key=lambda kv: kv[0].lower()))
        with open(path, "w", encoding="utf-8") as f:
            json.dump(catalog, f, ensure_ascii=False, indent=2, separators=(",", " : "))
            f.write("\n")
    return len(missing)


def main():
    check = "--check" in sys.argv
    objroot = derived_data()
    total_missing = 0
    for target, catalog in TARGETS.items():
        total_missing += sync(catalog, extracted(objroot, target), check, MANUAL.get(target, []))
    return 0


if __name__ == "__main__":
    sys.exit(main())
