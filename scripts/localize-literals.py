#!/usr/bin/env python3
"""One-off helper for the English version: wraps Czech text literals that SwiftUI does not localize by itself
(plain `String` values) in `String(localized:)`, so they reach the string catalog.

Run `scripts/sync-strings.py` after a build first; literals already in the catalog are left alone.
`--dry` lists what would change and the places that need a human look instead.
"""
import json
import os
import re
import sys

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
DIRS = ["Kept", "KeptWidgets", "Shared"]
SKIP_FILES = {
    "ExerciseTechnique.swift", "ExerciseTechnique+More.swift", "ExerciseCatalog.swift", "ExerciseCatalog+English.swift",
    "NotificationTemplates.swift", "DeveloperSection.swift",
}
CZECH = re.compile(r"[áčďéěíňóřšťúůýžÁČĎÉĚÍŇÓŘŠŤÚŮÝŽ]|\b(je|se|na|do|bez|jsi|ti|tě|tvůj|tvoje|týden|den|dny|úkol|úkoly|body|bodů|nic|ano|ne)\b", re.I)
LITERAL = re.compile(r'(?<![\\#])"((?:[^"\\\n]|\\.)*)"')
SKIP_LINE = re.compile(r"^\s*(//|///|\*)|logger\.|Logger\(|print\(|fatalError|@AppStorage|UserDefaults|forKey:|accessibilityIdentifier|#Preview|Text\(verbatim:|LocalizedStringResource|ExercisePresets")
# A quote inside an interpolation: hand-made plurals and the like, rewritten by hand.
NESTED = re.compile(r'\\\([^)]*"')
WORDLIKE = re.compile(r"^(?=.*[A-Za-zÁ-ž])(?![a-z0-9_.\-]+$)[^{}<>\\]*$")


def scan_literals(line):
    """Top-level string literals on a line as (start, end, text, has_nested), aware of interpolations,
    so a literal inside `\\( )` belongs to its outer literal instead of being cut out of it."""
    found = []
    i, n = 0, len(line)
    while i < n:
        c = line[i]
        if c == "/" and line.startswith("//", i):
            break
        if c == '"' and not line.startswith('"""', i) and (i == 0 or line[i - 1] != "#"):
            start, i, nested = i, i + 1, False
            while i < n:
                if line[i] == "\\" and i + 1 < n and line[i + 1] == "(":
                    depth, i, in_str = 1, i + 2, False
                    while i < n and depth:
                        ch = line[i]
                        if in_str:
                            if ch == "\\":
                                i += 1
                            elif ch == '"':
                                in_str = False
                        elif ch == '"':
                            in_str, nested = True, True
                        elif ch == "(":
                            depth += 1
                        elif ch == ")":
                            depth -= 1
                        i += 1
                    continue
                if line[i] == "\\":
                    i += 2
                    continue
                if line[i] == '"':
                    break
                i += 1
            found.append((start, i + 1, line[start + 1:i], nested))
        i += 1
    return found


def extracted_positions():
    """Where the compiler found localizable literals in the last build: (file, line, column of the quote)."""
    import glob
    import subprocess
    out = subprocess.run(["xcodebuild", "-scheme", "Kept", "-showBuildSettings", "-json"], cwd=ROOT,
                         capture_output=True, text=True).stdout
    objroot = json.loads(out)[0]["buildSettings"]["OBJROOT"]
    positions = set()
    for path in glob.glob(f"{objroot}/Kept.build/*/*.build/Objects-normal/*/*.stringsdata"):
        with open(path, encoding="utf-8") as f:
            data = json.load(f)
        for table in data.get("tables", {}).values():
            for entry in table:
                loc = entry["location"]
                positions.add((data["source"], loc["startingLine"], loc["startingColumn"]))
    return positions


def catalog_patterns():
    keys = set()
    for path in ("Kept/Localizable.xcstrings", "KeptWidgets/Localizable.xcstrings"):
        with open(os.path.join(ROOT, path), encoding="utf-8") as f:
            keys.update(k for k, v in json.load(f)["strings"].items() if v.get("extractionState") != "stale")
    return keys


def as_key_regex(literal):
    """The catalog key a literal would produce: every interpolation becomes some format specifier."""
    parts = re.split(r"\\\((?:[^()]|\([^()]*\))*\)", literal)
    body = r"%(?:\d+\$)?(?:lld|ld|d|@|f|\.\d+f|lf)".join(re.escape(p.replace('\\"', '"').replace("\\\\", "\\")) for p in parts)
    return re.compile("^" + body + "$")


def main():
    dry = "--dry" in sys.argv
    positions = extracted_positions()
    changed_files = 0
    wrapped = 0
    review = []
    for base in DIRS:
        for dirpath, _, files in os.walk(os.path.join(ROOT, base)):
            for name in files:
                if not name.endswith(".swift") or name in SKIP_FILES:
                    continue
                path = os.path.join(dirpath, name)
                rel = os.path.relpath(path, ROOT)
                with open(path, encoding="utf-8") as f:
                    lines = f.readlines()
                out = []
                touched = False
                for number, line in enumerate(lines, 1):
                    if SKIP_LINE.search(line) or not CZECH.search(line):
                        out.append(line)
                        continue
                    if re.match(r"\s*case\s+\w+\s*=\s*\"", line):
                        review.append(f"{rel}:{number}: (raw value) {line.strip()[:140]}")
                        out.append(line)
                        continue
                    new = line
                    offset = 0
                    spans = scan_literals(line)
                    wraps_czech = any(CZECH.search(t) for _, _, t, _ in spans)
                    for start0, end0, text, nested in spans:
                        if nested and CZECH.search(text):
                            review.append(f"{rel}:{number}: (nested) {line.strip()[:140]}")
                            continue
                        m = type("M", (), {"start": lambda self, s=start0: s, "end": lambda self, e=end0: e})()
                        if not CZECH.search(text) and not (wraps_czech and WORDLIKE.match(text)):
                            continue
                        column = m.start() + 1
                        byte_column = len(line[:m.start()].encode("utf-8")) + 1
                        if (path, number, column) in positions or (path, number, byte_column) in positions:
                            continue
                        before = line[:m.start()]
                        after = line[m.end():]
                        if re.search(r"\bcase\s+[^=]*=\s*$", before) or re.search(r"\bcase\s+$", before) \
                                or re.match(r"\s*:", after) and not re.search(r"\?\s*$", before) \
                                or re.search(r"==\s*$|!=\s*$", before) or re.match(r"\s*[=!]=", after):
                            review.append(f"{rel}:{number}: {line.strip()[:140]}")
                            continue
                        start, end = m.start() + offset, m.end() + offset
                        new = new[:start] + "String(localized: " + new[start:end] + ")" + new[end:]
                        offset += len("String(localized: )")
                        wrapped += 1
                    if new != line:
                        touched = True
                        if dry:
                            print(f"{rel}:{number}: {new.strip()[:160]}")
                    out.append(new)
                if touched and not dry:
                    with open(path, "w", encoding="utf-8") as f:
                        f.writelines(out)
                if touched:
                    changed_files += 1
    print(f"\n{wrapped} literals in {changed_files} files", file=sys.stderr)
    print("\nNEEDS A LOOK (dictionary keys, case patterns, comparisons):", file=sys.stderr)
    for item in review:
        print("  " + item, file=sys.stderr)


if __name__ == "__main__":
    main()
