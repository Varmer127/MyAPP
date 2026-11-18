#!/usr/bin/env bash
# Lists everything that changes what the legal documents must say: iPhone permissions, entitlements, Apple frameworks,
# outside packages, servers the app talks to, database tables and columns, server functions, privacy manifests.
# ci-checks.sh compares this list with docs/legal-baseline.txt. After a legal review, accept the new state with:
#   scripts/legal-baseline.sh > docs/legal-baseline.txt
set -u
cd "$(dirname "$0")/.."
export LC_ALL=C

{
  grep -ohE 'INFOPLIST_KEY_NS[A-Za-z]+UsageDescription' Kept.xcodeproj/project.pbxproj | sed 's/^INFOPLIST_KEY_/permission: /'
  find Kept KeptWidgets Shared -name '*.plist' -print0 2>/dev/null | xargs -0 grep -ohE 'NS[A-Za-z]+UsageDescription' 2>/dev/null | sed 's/^/permission: /'
  for f in *.entitlements; do
    grep -oE '<key>[^<]+</key>' "$f" | sed -E "s#<key>(.*)</key>#entitlement: $f \1#"
  done
  grep -rhoE --include='*.swift' '^(@preconcurrency )?import [A-Za-z_]+' Kept KeptWidgets Shared | sed -E 's/^(@preconcurrency )?import /framework: /'
  grep -ohE 'repositoryURL = "[^"]+"' Kept.xcodeproj/project.pbxproj | sed -E 's/repositoryURL = "(.*)"/package: \1/'
  grep -rhoE --include='*.swift' 'https://[A-Za-z0-9.-]+' Kept KeptWidgets Shared | sed 's#https://#host: #'
  cat supabase/migrations/*.sql | grep -oiE 'create table (if not exists )?(public\.)?[a-z_]+' | sed -E 's/.* (public\.)?([a-z_]+)$/table: \2/'
  cat supabase/migrations/*.sql | tr '\n' ' ' | grep -oiE 'alter table (public\.)?[a-z_]+ add column (if not exists )?[a-z_]+' \
    | sed -E 's/alter table (public\.)?([a-z_]+) add column (if not exists )?([a-z_]+)/column: \2.\4/'
  cat supabase/migrations/*.sql | grep -oiE 'create (or replace )?function (public\.)?[a-z_]+' | sed -E 's/.* (public\.)?([a-z_]+)$/function: \2/'
  [ -d supabase/functions ] && ls supabase/functions | sed 's/^/edge-function: /'
  for manifest in Kept/PrivacyInfo.xcprivacy KeptWidgets/PrivacyInfo.xcprivacy; do
    echo "privacy-manifest: $manifest $(git hash-object "$manifest")"
  done
} | sort -u
