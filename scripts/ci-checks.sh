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

# 5. Reminder only (not a failure yet): developer leftovers to remove before TestFlight.
echo "Developer keys still present: $(grep -rn --include='*.swift' -c 'devShow\|devHealthDemo' Kept | awk -F: '{s+=$2} END {print s+0}')"

exit $failed
