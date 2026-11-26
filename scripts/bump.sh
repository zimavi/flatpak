#!/usr/bin/env bash
# Usage: bump.sh <app-id> <version> <url> <sha256> [branch...]      (RELEASE_DATE=YYYY-MM-DD, default today)
# Without branches: a pre-release (1.0.0-beta.1) goes to beta; a final release goes to stable, and to beta if the app
# has it. With branches: exactly those are updated. A missing stable or beta manifest is created from the other one;
# any other branch needs its <branch>.yml first, so that a typo cannot publish a new branch.
set -euo pipefail
die() { echo "bump.sh: $*" >&2; exit 1; }

[[ $# -ge 4 ]] || die "usage: bump.sh <app-id> <version> <url> <sha256> [branch...]"
app=$1 version=$2 url=$3 sha=$4
shift 4
date=${RELEASE_DATE:-$(date -u +%F)}
[[ $app =~ ^[A-Za-z][A-Za-z0-9_]*(\.[A-Za-z0-9_-]+)+$ ]] || die "bad app id: $app"
[[ $version =~ ^[0-9]+\.[0-9]+\.[0-9]+(-[0-9A-Za-z.]+)?$ ]] || die "bad version: $version"
[[ $url =~ ^https://github\.com/zimavi/[A-Za-z0-9._/-]+$ && $url != *..* ]] || die "bad url: $url"
[[ $sha =~ ^[0-9a-f]{64}$ ]] || die "bad sha256: $sha"
[[ $date =~ ^[0-9]{4}-[0-9]{2}-[0-9]{2}$ ]] || die "bad date: $date"
for branch; do
  [[ $branch =~ ^[A-Za-z0-9_][A-Za-z0-9_.-]*$ ]] || die "bad branch: $branch"
  [[ $branch != stable || $version != *-* ]] || die "pre-release $version cannot go to stable"
done

cd "$(dirname "$0")/../apps/$app" 2>/dev/null || die "no such app: $app"
# The manifest a new stable or beta one is copied from.
if [[ -f beta.yml ]]; then template=beta.yml; else template=stable.yml; fi

# True when $1 is an older version than $2. "~" makes sort -V put 1.0.0-beta before 1.0.0.
older() { [[ $1 != "$2" && $(printf '%s\n' "${1/-/\~}" "${2/-/\~}" | sort -V | head -n1) == "${1/-/\~}" ]]; }
current() { sed -n "s/^ *VERSION: *'\(.*\)'/\1/p" "$1"; }

explicit=$#
if ((explicit)); then
  branches=("$@")
elif [[ $version == *-* ]]; then
  branches=(beta)
else
  branches=(stable)
  [[ ! -f beta.yml ]] || branches+=(beta)
fi

# Check every file before changing any, so that a refusal leaves the app as it was.
targets=()
for branch in "${branches[@]}"; do
  file=$branch.yml
  source=$file
  if [[ ! -f $file ]]; then
    [[ $branch == stable || $branch == beta ]] || die "$app has no $file; create it first"
    source=$template
    [[ -f $source ]] || die "$app has no stable.yml or beta.yml"
  fi
  for field in VERSION RELEASE_DATE url sha256; do
    [[ $(grep -c "^ *$field: " "$source") == 1 ]] || die "$source must have exactly one '$field:' line"
  done
  [[ $(current "$source") ]] || die "VERSION in $source must be in single quotes"
  if [[ -f $file ]] && older "$version" "$(current "$file")"; then
    # A requested branch and the release's own branch never go back; beta may already be ahead of a final release.
    ((!explicit)) && [[ $branch != "${branches[0]}" ]] ||
      die "$version is older than $(current "$file") in $file"
    echo "bump.sh: $file is already newer, left alone"
    continue
  fi
  targets+=("$file")
done

for file in "${targets[@]}"; do
  [[ -f $file ]] || cp "$template" "$file"
  sed -i \
    -e "s|^\( *VERSION: \).*|\1'$version'|" \
    -e "s|^\( *RELEASE_DATE: \).*|\1'$date'|" \
    -e "s|^\( *url: \).*|\1$url|" \
    -e "s|^\( *sha256: \).*|\1$sha|" "$file"
  echo "bump.sh: $app/$file -> $version"
done
