#!/usr/bin/env bash
# Self-check of bump.sh on a made-up app in a temporary folder.
set -euo pipefail
here=$(cd "$(dirname "$0")" && pwd)
tmp=$(mktemp -d)
trap 'rm -rf "$tmp"' EXIT
mkdir -p "$tmp/scripts" "$tmp/apps/org.example.App"
cp "$here/bump.sh" "$tmp/scripts/"
cd "$tmp/apps/org.example.App"
printf "%s\n" "  VERSION: '1.0.0-beta.3'" "  RELEASE_DATE: '2026-01-01'" "  url: x" "  sha256: y" >beta.yml

sha=$(printf 'a%.0s' {1..64})
url=https://github.com/zimavi/App/releases/download/v/app.tar.gz
bump() { bash "$tmp/scripts/bump.sh" org.example.App "$@" >/dev/null 2>&1; }
has() { grep -qF "VERSION: '$2'" "$1" || { echo "FAIL: $1 is not at $2" >&2; exit 1; }; }
refused() { if bump "$@"; then echo "FAIL: accepted $*" >&2; exit 1; fi; }

RELEASE_DATE=2026-02-02 bump 1.0.0-beta.10 "$url" "$sha" # 10 is newer than 3
has beta.yml 1.0.0-beta.10
grep -qF "url: $url" beta.yml
grep -qF "sha256: $sha" beta.yml
grep -qF "RELEASE_DATE: '2026-02-02'" beta.yml
[[ ! -e stable.yml ]]

bump 1.0.0 "$url" "$sha" # first final release creates stable, and beta follows
has stable.yml 1.0.0
has beta.yml 1.0.0

bump 1.1.0-beta.1 "$url" "$sha"
bump 1.0.1 "$url" "$sha" # a patch release leaves a newer beta alone
has stable.yml 1.0.1
has beta.yml 1.1.0-beta.1

refused 1.0.0 "$url" "$sha"        # downgrade of stable
refused 1.0.1-beta.1 "$url" "$sha" # downgrade of beta
refused 'v2.0.0' "$url" "$sha"
refused 2.0.0 https://example.com/app.tar.gz "$sha"
refused 2.0.0 https://github.com/zimavi/../other/app.tar.gz "$sha"
refused 2.0.0 "$url" abc
has stable.yml 1.0.1
has beta.yml 1.1.0-beta.1

# Chosen branches: only those change.
bump 1.2.0 "$url" "$sha" stable
has stable.yml 1.2.0
has beta.yml 1.1.0-beta.1
refused 1.0.0 "$url" "$sha" beta          # a chosen branch never goes back
refused 1.3.0-beta.1 "$url" "$sha" stable # no pre-release in stable
refused 1.3.0 "$url" "$sha" nightly       # an unknown branch is not created
refused 1.3.0 "$url" "$sha" ../beta
refused 1.3.0 "$url" "$sha" stable nightly
has stable.yml 1.2.0 # nothing changed, although stable alone was fine
[[ ! -e nightly.yml ]]
cp beta.yml nightly.yml
bump 1.3.0-nightly.1 "$url" "$sha" nightly
has nightly.yml 1.3.0-nightly.1
has beta.yml 1.1.0-beta.1

# A bad file stops the whole release.
sed -i '/sha256:/d' beta.yml
refused 2.0.0 "$url" "$sha"
has stable.yml 1.2.0

# An app with only stable gets no beta from a final release, but does from a pre-release.
rm beta.yml nightly.yml
bump 1.4.0 "$url" "$sha"
has stable.yml 1.4.0
[[ ! -e beta.yml ]]
bump 1.5.0-beta.1 "$url" "$sha"
has beta.yml 1.5.0-beta.1
has stable.yml 1.4.0

rm beta.yml stable.yml
refused 2.0.0 "$url" "$sha" # nothing to start from
echo "bump.sh: all checks passed"
