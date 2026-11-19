#!/usr/bin/env bash
# Fast checks that need no build: things that must never reach a release.
set -u
cd "$(dirname "$0")/.."
failed=0

# 1. The developer section must stay inside #if DEBUG.
if ! head -5 Kept/Views/Settings/DeveloperSection.swift | grep -q '^#if DEBUG'; then
  echo "::error file=Kept/Views/Settings/DeveloperSection.swift::DeveloperSection must start with #if DEBUG"
  failed=1
fi

# 2. No crash on a broken data store, no stray prints.
if grep -rn --include='*.swift' 'fatalError(' Kept KeptWidgets Shared; then
  echo "::error::fatalError found: a broken store must be handled, not crash the app"
  failed=1
fi
if grep -rn --include='*.swift' -E '(^|[^A-Za-z_.])print\(' Kept KeptWidgets Shared; then
  echo "::error::print( found: use Logger with a privacy level"
  failed=1
fi

# 3. Logging must not make texts public.
if grep -rn --include='*.swift' 'privacy: .public' Kept KeptWidgets Shared | grep -v 'type(of:'; then
  echo "::error::a log line makes content public"
  failed=1
fi

# 4. Both targets carry a privacy manifest.
for manifest in Kept/PrivacyInfo.xcprivacy KeptWidgets/PrivacyInfo.xcprivacy; do
  [ -f "$manifest" ] || { echo "::error::missing $manifest"; failed=1; }
done

# 5. No secret keys in the repository (it is public), and no door left open in the network settings.
#    The publishable key in ServerConfig.swift is meant to be public; everything below never is.
if git grep -n -I -E 'sb_secret_[A-Za-z0-9_-]{8,}|service_role[^a-z_]*[:=]|eyJ[A-Za-z0-9_-]{30,}\.[A-Za-z0-9_-]{20,}|BEGIN [A-Z ]*PRIVATE KEY|AKIA[0-9A-Z]{16}|gh[pousr]_[A-Za-z0-9]{30,}|sk_(live|test)_[A-Za-z0-9]{10,}' -- . ':!scripts/ci-checks.sh'; then
  echo "::error::something that looks like a secret key is in the repository"
  failed=1
fi
if git ls-files | grep -n -i -E '(^|/)\.env($|\.)|\.p8$|\.p12$|\.pem$|\.mobileprovision$'; then
  echo "::error::a key or environment file is tracked by Git"
  failed=1
fi
if grep -rn 'NSAllowsArbitraryLoads' --include='*.plist' . ; then
  echo "::error::App Transport Security must stay on (no NSAllowsArbitraryLoads)"
  failed=1
fi
if grep -rn --include='*.swift' -E '"http://' Kept KeptWidgets Shared; then
  echo "::error::plain http:// address found: the app talks over https only"
  failed=1
fi

# 6. Reminder only (not a failure yet): developer leftovers to remove before TestFlight.
echo "Developer keys still present: $(grep -rn --include='*.swift' -c 'devShow\|devHealthDemo' Kept | awk -F: '{s+=$2} END {print s+0}')"


# 7. Reminder only (not a failure yet): places in the legal documents that still wait for real details.
echo "Legal documents: places still to fill in: $(grep -c -E '\[(DOPLNIT|OVĚŘIT|TO BE COMPLETED|TO BE VERIFIED)' Kept/Resources/Legal/*.md | awk -F: '{s+=$2} END {print s+0}')"

# 9. Warning only: texts in the string catalogs that have no English yet (fill them in, see scripts/sync-strings.py).
untranslated=$(python3 - <<'PY'
import json
missing = []
for path in ("Kept/Localizable.xcstrings", "KeptWidgets/Localizable.xcstrings"):
    for key, entry in json.load(open(path, encoding="utf-8"))["strings"].items():
        if entry.get("extractionState") != "stale" and entry.get("shouldTranslate", True) \
                and "en" not in entry.get("localizations", {}):
            missing.append(key)
print(len(missing))
for key in missing[:10]:
    print("  " + key)
PY
)
if [ "$(echo "$untranslated" | head -1)" != "0" ]; then
  echo "::warning::Texts without English: $(echo "$untranslated" | head -1)"
  echo "$untranslated" | tail -n +2
else
  echo "Translations: all texts have English"
fi

# 8. Warning only: something changed that the legal documents may have to mention (see docs/LEGAL.md, "Hlídač").
legal_diff=$(scripts/legal-baseline.sh | diff docs/legal-baseline.txt - | grep -E '^[<>]' || true)
if [ -n "$legal_diff" ]; then
  echo "::warning::Legal review needed: check Privacy Policy and Terms, then run scripts/legal-baseline.sh > docs/legal-baseline.txt"
  echo "$legal_diff" | sed -e 's/^>/  new:/' -e 's/^</  gone:/'
else
  echo "Legal baseline: no change"
fi

exit $failed
