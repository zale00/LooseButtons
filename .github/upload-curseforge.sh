#!/usr/bin/env bash
set -euo pipefail

say() {
  echo "$1"
  echo "::notice::$1"
}

die() {
  echo "$1"
  echo "::error::$1"
  exit 1
}

if [[ -z ${CF_API_KEY:-} ]]; then
  die "CF_API_KEY is missing"
fi
say "CF_API_KEY is set"

version="$(sed -n 's/^## Version:[[:space:]]*\([^[:space:]]*\).*/\1/p' LooseButtons.toc | head -n 1 | tr -d '\r')"
if [[ ! $version =~ ^[0-9][0-9A-Za-z.+-]*$ ]]; then
  die "TOC version '${version}' is not a release tag"
fi

if git ls-remote --exit-code --tags origin "refs/tags/cf-${version}" >/dev/null 2>&1; then
  say "skip upload: cf-${version} already exists"
  exit 0
fi

workflow_sha="${GITHUB_SHA:-$(git rev-parse HEAD)}"

accepted=0
for path in /api/game/versions /api/game/wow/versions; do
  token_code="$(curl -sS -o /dev/null -w "%{http_code}" \
    -H "x-api-token: ${CF_API_KEY}" \
    -H "Accept: application/json" \
    "https://wow.curseforge.com${path}" || true)"
  say "game versions HTTP ${token_code} ${path}"
  if [[ "$token_code" == "200" ]]; then
    accepted=1
    break
  fi
  if [[ "$token_code" == "401" || "$token_code" == "403" ]]; then
    die "CF_API_KEY was rejected"
  fi
done
if [[ "$accepted" -ne 1 ]]; then
  die "game versions endpoint did not return 200"
fi

project_id="${CF_PROJECT_ID:-}"
if [[ -z "$project_id" ]]; then
  project_id="$(sed -n 's/^## X-Curse-Project-ID:[[:space:]]*\([0-9][0-9]*\).*/\1/p' LooseButtons.toc | head -n 1 | tr -d '\r')"
fi
if [[ -z "$project_id" ]]; then
  project_id="$(
    discover_ids() {
      local url code body
      for url in \
        "https://wow.curseforge.com/api/projects" \
        "https://wow.curseforge.com/api/author/projects" \
        "https://authors.curseforge.com/api/projects"
      do
        body="$(mktemp)"
        code="$(curl -sS -o "$body" -w "%{http_code}" \
          -H "x-api-token: ${CF_API_KEY}" \
          -H "Accept: application/json" \
          "$url" || true)"
        say "discover ${url} HTTP ${code}" >&2
        if [[ "$code" == "200" ]]; then
          jq -r '
            .. | objects
            | select((.id | type) == "number" and ((.name | type) == "string" or (.slug | type) == "string"))
            | "\(.id)\t\(.name // "")\t\(.slug // "")"
          ' "$body" 2>/dev/null || true
        fi
        rm -f "$body"
      done
    }
    mapfile -t rows < <(discover_ids | sort -u || true)
    matches=()
    for row in "${rows[@]}"; do
      [[ -z "$row" ]] && continue
      IFS=$'\t' read -r id name slug <<<"$row"
      [[ "$id" =~ ^[0-9]+$ ]] || continue
      say "project ${id} ${name} ${slug}" >&2
      folded="$(printf '%s %s' "$name" "$slug" | tr '[:upper:]' '[:lower:]')"
      if [[ "$folded" == *loosebuttons* || "$folded" == *"loose buttons"* || "$folded" == *loose-buttons* ]]; then
        matches+=("$id")
      fi
    done
    if [[ ${#matches[@]} -eq 1 ]]; then
      printf '%s' "${matches[0]}"
    fi
  )"
fi

if [[ ! "$project_id" =~ ^[0-9]+$ ]]; then
  die "no CurseForge project id"
fi
say "using project ${project_id}"

files_body="$(mktemp)"
files_code="$(curl -sS -o "$files_body" -w "%{http_code}" \
  -H "x-api-token: ${CF_API_KEY}" \
  -H "Accept: application/json" \
  "https://wow.curseforge.com/api/projects/${project_id}/files" || true)"
say "files HTTP ${files_code}"
if [[ "$files_code" == "200" ]] && jq -e . "$files_body" >/dev/null 2>&1; then
  if jq -r '.. | objects | select(.fileName != null or .displayName != null) | "\(.fileName // "") \(.displayName // "")"' "$files_body" | grep -F -q "$version"; then
    rm -f "$files_body"
    say "skip upload: CurseForge already has ${version}"
    git tag "cf-${version}" "$workflow_sha"
    git push origin "refs/tags/cf-${version}"
    exit 0
  fi
fi
rm -f "$files_body"

git fetch origin "refs/tags/${version}:refs/tags/${version}"
git checkout --detach "$version"

if [[ -n ${PACKAGER_SH:-} ]]; then
  packager_sh="$PACKAGER_SH"
else
  packager="$(mktemp -d)"
  git clone --depth 1 --branch v2.6.1 https://github.com/BigWigsMods/packager.git "$packager"
  packager_sh="$packager/release.sh"
fi

# -d skips the packager upload. Interface 120100 would be sent as retail 12.1.0.
# -g 1.60.1 aborts on that interface, or rewrites the zip to 16001.
# The token is unset so the packager cannot upload if -d is dropped.
log="$(mktemp)"
set +e
env -u GITHUB_ACTIONS -u CF_API_KEY bash "$packager_sh" -d -l -p "$project_id" >"$log" 2>&1
status=$?
set -e
cat "$log"
if [[ "$status" -ne 0 ]]; then
  die "packager failed"
fi
if grep -q '^Uploading ' "$log"; then
  die "packager uploaded a file"
fi

mapfile -t zips < <(find .release -maxdepth 1 -type f -name '*.zip' | sort)
if [[ ${#zips[@]} -ne 1 ]]; then
  die "expected one package zip, found ${#zips[@]}"
fi

versions_body="$(mktemp)"
versions_code="$(curl -sS -o "$versions_body" -w "%{http_code}" \
  -H "x-api-token: ${CF_API_KEY}" \
  -H "Accept: application/json" \
  "https://wow.curseforge.com/api/game/wow/versions" || true)"
say "game versions HTTP ${versions_code} /api/game/wow/versions"
if [[ "$versions_code" == "401" || "$versions_code" == "403" ]]; then
  die "CF_API_KEY was rejected"
fi
if [[ "$versions_code" != "200" ]]; then
  die "game versions endpoint did not return 200"
fi

# 88568 is the Forever game version type in BigWigs packager v2.6.1.
forever_id="$(jq -r --arg name "1.60.1" --argjson type 88568 '
  [ .[] | select(.name == $name and .gameVersionTypeID == $type) | .id ] | first // empty
' "$versions_body")"
if [[ ! "$forever_id" =~ ^[0-9]+$ ]]; then
  names="$(jq -r --argjson type 88568 '[.[] | select(.gameVersionTypeID == $type) | .name] | join(", ")' "$versions_body" 2>/dev/null || true)"
  die "CurseForge has no Forever game version 1.60.1. Forever names: ${names:-none}"
fi
say "CurseForge game version 1.60.1 id ${forever_id}"

case "${version,,}" in
  *alpha*) release_type=alpha ;;
  *beta*) release_type=beta ;;
  *) release_type=release ;;
esac

if [[ ! -f CHANGELOG.md ]]; then
  die "CHANGELOG.md is missing"
fi
meta="$(mktemp)"
jq -n \
  --arg displayName "$version" \
  --argjson gameVersion "$forever_id" \
  --arg releaseType "$release_type" \
  --rawfile changelog CHANGELOG.md \
  '{displayName: $displayName, gameVersions: [$gameVersion], releaseType: $releaseType, changelog: $changelog, changelogType: "markdown"}' > "$meta"

result="$(mktemp)"
upload_code="$(curl -sS -o "$result" -w "%{http_code}" \
  -H "x-api-token: ${CF_API_KEY}" \
  -F "metadata=@${meta}" \
  -F "file=@${zips[0]}" \
  "https://wow.curseforge.com/api/projects/${project_id}/upload-file" || true)"
say "upload HTTP ${upload_code}"
if [[ "$upload_code" != "200" ]]; then
  die "CurseForge upload did not succeed"
fi
file_id="$(jq -r '.id // empty' "$result" 2>/dev/null || true)"

git tag "cf-${version}" "$workflow_sha"
git push origin "refs/tags/cf-${version}"
say "uploaded ${version} as Forever 1.60.1 file ${file_id:-unknown}"
