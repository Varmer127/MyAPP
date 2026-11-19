#!/usr/bin/env python3
"""Writes translations into the string catalogs.

Input: a JSON file mapping a catalog key (the Czech text) to its English text, or to
`{"en": {"one": "...", "other": "..."}, "cs": {"one": "...", "few": "...", "many": "...", "other": "..."}}`
for texts with plural forms. Keys are looked up in both catalogs; unknown keys are reported, not added.

Usage: scripts/apply-translations.py translations.json
"""
import json
import os
import sys

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
CATALOGS = ["Kept/Localizable.xcstrings", "KeptWidgets/Localizable.xcstrings"]


def unit(value):
    return {"stringUnit": {"state": "translated", "value": value}}


def localization(value):
    if isinstance(value, dict):
        return {"variations": {"plural": {form: unit(text) for form, text in value.items()}}}
    return unit(value)


def main():
    with open(sys.argv[1], encoding="utf-8") as f:
        translations = json.load(f)
    catalogs = {}
    for path in CATALOGS:
        with open(os.path.join(ROOT, path), encoding="utf-8") as f:
            catalogs[path] = json.load(f)
    unknown = []
    applied = 0
    for key, value in translations.items():
        targets = [c for c in catalogs.values() if key in c["strings"]]
        if not targets:
            unknown.append(key)
            continue
        for catalog in targets:
            entry = catalog["strings"][key]
            localizations = entry.setdefault("localizations", {})
            if isinstance(value, dict) and ("en" in value or "cs" in value):
                for language, forms in value.items():
                    localizations[language] = localization(forms)
            else:
                localizations["en"] = localization(value)
        applied += 1
    for path, catalog in catalogs.items():
        with open(os.path.join(ROOT, path), "w", encoding="utf-8") as f:
            json.dump(catalog, f, ensure_ascii=False, indent=2, separators=(",", " : "))
            f.write("\n")
    print(f"{applied} applied, {len(unknown)} unknown")
    for key in unknown:
        print("  unknown:", key)


if __name__ == "__main__":
    main()
