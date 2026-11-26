#!/usr/bin/env bash
# Usage: bump.sh <app-id> <version> <url> <sha256>      (RELEASE_DATE=YYYY-MM-DD, default today)
# A pre-release (1.0.0-beta.1) goes to beta.yml; a final release goes to stable.yml and beta.yml.
set -euo pipefail
die() { echo "bump.sh: $*" >&2; exit 1; }

[[ $# == 4 ]] || die "usage: bump.sh <app-id> <version> <url> <sha256>"
app=$1 version=$2 url=$3 sha=$4
date=${RELEASE_DATE:-$(date -u +%F)}
[[ $app =~ ^[A-Za-z][A-Za-z0-9_]*(\.[A-Za-z0-9_-]+)+$ ]] || die "bad app id: $app"
[[ $version =~ ^[0-9]+\.[0-9]+\.[0-9]+(-[0-9A-Za-z.]+)?$ ]] || die "bad version: $version"
[[ $url =~ ^https://github\.com/zimavi/[A-Za-z0-9._/-]+$ && $url != *..* ]] || die "bad url: $url"
[[ $sha =~ ^[0-9a-f]{64}$ ]] || die "bad sha256: $sha"
[[ $date =~ ^[0-9]{4}-[0-9]{2}-[0-9]{2}$ ]] || die "bad date: $date"

cd "$(dirname "$0")/../apps/$app" 2>/dev/null || die "no such app: $app"
[[ -f beta.yml ]] || die "$app has no beta.yml"

# True when $1 is an older version than $2. "~" makes sort -V put 1.0.0-beta before 1.0.0.
older() { [[ $1 != "$2" && $(printf '%s\n' "${1/-/\~}" "${2/-/\~}" | sort -V | head -n1) == "${1/-/\~}" ]]; }
current() { sed -n "s/^ *VERSION: *'\(.*\)'/\1/p" "$1"; }

if [[ $version == *-* ]]; then channels=(beta); else channels=(stable beta); fi

targets=()
for channel in "${channels[@]}"; do
  file=$channel.yml
  if [[ -f $file ]] && older "$version" "$(current "$file")"; then
    # The release's own channel never goes back; beta may already be ahead of a final release.
    [[ $channel != "${channels[0]}" ]] || die "$version is older than $(current "$file") in $file"
    echo "bump.sh: $file is already newer, left alone"
    continue
  fi
  targets+=("$file")
done

for file in "${targets[@]}"; do
  [[ -f $file ]] || cp beta.yml "$file"
  for field in VERSION RELEASE_DATE url sha256; do
    [[ $(grep -c "^ *$field: " "$file") == 1 ]] || die "$file must have exactly one '$field:' line"
  done
  sed -i \
    -e "s|^\( *VERSION: \).*|\1'$version'|" \
    -e "s|^\( *RELEASE_DATE: \).*|\1'$date'|" \
    -e "s|^\( *url: \).*|\1$url|" \
    -e "s|^\( *sha256: \).*|\1$sha|" "$file"
  echo "bump.sh: $app/$file -> $version"
done
