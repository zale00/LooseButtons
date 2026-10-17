#!/usr/bin/env bash
set -euo pipefail

# Interface 16001 makes packager v2.6.1 label the build Forever 1.60.1. This script never lets it upload.
forever_name=1.60.1
forever_type=88568
retail_name=12.1.0
retail_type=517

say() {
  echo "$1"
  echo "::notice::$1"
}

die() {
  echo "$1"
  echo "::error::$1"
  exit 1
}

# Duplicate-version check. It reads only public lists: the curseforge.com file list and CFWidget.
# The upload token gets HTTP 403 (errorCode 5100) from /api/projects/<id>/files, so that route is not used.
# A display name hits when it equals the version or "LooseButtons <version>".
# A file name hits when it contains LooseButtons-<version> followed by the end, ".zip", or "-",
# so 0.1.1 matches LooseButtons-0.1.1-forever.zip and not LooseButtons-0.1.10.zip.
# CFWidget files[].version is the game version (1.60.1), so it is never matched.
file_match_jq='
  def display_hit($name):
    if ($name | type) != "string" or $name == "" then false
    else $name == $version or $name == ("LooseButtons " + $version)
    end;
  def file_hit($name):
    if ($name | type) != "string" or $name == "" then false
    else
      ("LooseButtons-" + $version) as $token
      | ($name | index($token)) as $i
      | if $i == null then false
        else
          ($name[$i + ($token | length):]) as $rest
          | ($rest == "" or ($rest | startswith(".zip")) or ($rest | startswith("-")))
        end
    end;
'

public_get() {
  local url=$1 dest=$2
  # No API token on these requests.
  curl -sS --connect-timeout 15 --max-time 30 \
    -H "Accept: application/json" \
    -o "$dest" -w "%{http_code}" \
    "$url" || true
}

http_failure_detail() {
  local code=$1 file=$2 snippet
  if [[ -z $code || $code == "000" ]]; then
    printf 'unreachable'
    return
  fi
  if grep -qi -e '<html' -e 'cloudflare' -e 'Just a moment' "$file" 2>/dev/null; then
    printf 'HTTP %s blocked' "$code"
    return
  fi
  snippet=$(head -c 160 "$file" 2>/dev/null | tr '\n\r' '  ' || true)
  if [[ -n $snippet ]]; then
    printf 'HTTP %s (%s)' "$code" "$snippet"
  else
    printf 'HTTP %s' "$code"
  fi
}

note_hits() {
  local source=$1 hits=$2 any=0 fid dname fname
  if [[ -n $hits ]]; then
    while IFS=$'\t' read -r fid dname fname; do
      [[ -n $fid || -n $dname || -n $fname ]] || continue
      say "duplicate check: ${source}: found ${dup_version} (file ${fid:-unknown}, displayName '${dname}', fileName '${fname}')"
      any=1
      dup_found=1
    done <<<"$hits"
  fi
  [[ $any -eq 1 ]]
}

curseforge_site_check() {
  local project=$1 page=0 seen=0 total count body code hits
  local source="curseforge.com files"
  while true; do
    body=$(mktemp)
    code=$(public_get "https://www.curseforge.com/api/v1/mods/${project}/files?pageIndex=${page}&pageSize=50" "$body")
    if [[ $code != 200 ]]; then
      site_detail=$(http_failure_detail "$code" "$body")
      say "duplicate check: ${source}: ${site_detail}"
      rm -f "$body"
      return 1
    fi
    if ! jq -e '.data | type == "array"' "$body" >/dev/null 2>&1; then
      site_detail="HTTP 200 not a file list"
      say "duplicate check: ${source}: ${site_detail}"
      rm -f "$body"
      return 1
    fi
    count=$(jq '.data | length' "$body")
    if [[ $count -gt 0 ]] && [[ $(jq '[.data[] | select((.displayName | type == "string") or (.fileName | type == "string"))] | length' "$body") -eq 0 ]]; then
      site_detail="HTTP 200 missing displayName and fileName"
      say "duplicate check: ${source}: ${site_detail}"
      rm -f "$body"
      return 1
    fi
    hits=$(jq -r --arg version "$dup_version" "${file_match_jq}"'
      .data[]
      | select(display_hit(.displayName) or file_hit(.fileName))
      | [(.id | tostring), (.displayName // ""), (.fileName // "")]
      | @tsv
    ' "$body")
    total=$(jq -r '.pagination.totalCount // empty' "$body")
    rm -f "$body"
    seen=$((seen + count))
    if note_hits "$source" "$hits"; then
      site_detail="HTTP 200"
      return 0
    fi
    if [[ ! $total =~ ^[0-9]+$ || $seen -ge $total || $count -eq 0 ]]; then
      break
    fi
    page=$((page + 1))
    if [[ $page -ge 20 ]]; then
      site_detail="incomplete after ${seen} of ${total} files"
      say "duplicate check: ${source}: ${site_detail}"
      return 1
    fi
  done
  site_detail="HTTP 200"
  say "duplicate check: ${source}: HTTP 200, ${seen} file(s), ${dup_version} not listed"
  return 0
}

cfwidget_check() {
  local project=$1 body code count hits
  local source="cfwidget"
  body=$(mktemp)
  code=$(public_get "https://api.cfwidget.com/${project}" "$body")
  if [[ $code != 200 ]]; then
    widget_detail=$(http_failure_detail "$code" "$body")
    say "duplicate check: ${source}: ${widget_detail}"
    rm -f "$body"
    return 1
  fi
  if ! jq -e '.files | type == "array"' "$body" >/dev/null 2>&1; then
    widget_detail="HTTP 200 not a file list"
    say "duplicate check: ${source}: ${widget_detail}"
    rm -f "$body"
    return 1
  fi
  count=$(jq '.files | length' "$body")
  if [[ $count -gt 0 ]] && [[ $(jq '[.files[] | select((.display | type == "string") or (.name | type == "string"))] | length' "$body") -eq 0 ]]; then
    widget_detail="HTTP 200 missing display and name"
    say "duplicate check: ${source}: ${widget_detail}"
    rm -f "$body"
    return 1
  fi
  hits=$(jq -r --arg version "$dup_version" "${file_match_jq}"'
    .files[]
    | select(display_hit(.display) or file_hit(.name))
    | [(.id | tostring), (.display // ""), (.name // "")]
    | @tsv
  ' "$body")
  rm -f "$body"
  widget_detail="HTTP 200"
  if note_hits "$source" "$hits"; then
    return 0
  fi
  say "duplicate check: ${source}: HTTP 200, ${count} file(s), ${dup_version} not listed"
  return 0
}

# Exits non-zero when the version is listed, or when neither list could be read
# unless CF_ALLOW_UNVERIFIED_DUPLICATE_CHECK=1.
refuse_duplicate_version() {
  local project=$1 site_ok=0 widget_ok=0
  dup_version=$2
  dup_found=0
  site_detail=""
  widget_detail=""
  say "duplicate check: version ${dup_version} project ${project}"
  if curseforge_site_check "$project"; then
    site_ok=1
  fi
  if cfwidget_check "$project"; then
    widget_ok=1
  fi
  if [[ $dup_found -eq 1 ]]; then
    die "refusing upload: CurseForge project ${project} already has ${dup_version}"
  fi
  if [[ $site_ok -eq 0 && $widget_ok -eq 0 ]]; then
    if [[ ${CF_ALLOW_UNVERIFIED_DUPLICATE_CHECK:-} != 1 ]]; then
      die "refusing upload: neither public file list could be read (curseforge.com files: ${site_detail}; cfwidget: ${widget_detail}). Set CF_ALLOW_UNVERIFIED_DUPLICATE_CHECK=1 to upload anyway."
    fi
    say "WARNING: duplicate check not verified; continuing because CF_ALLOW_UNVERIFIED_DUPLICATE_CHECK=1"
    return 0
  fi
  say "duplicate check: ${dup_version} is not on project ${project}"
}

# bash upload-curseforge.sh --check-duplicate <project id> <version>
# Runs only the public duplicate check. No token, no packaging, no upload.
if [[ ${1:-} == "--check-duplicate" ]]; then
  [[ ${2:-} =~ ^[0-9]+$ && -n ${3:-} ]] || die "usage: upload-curseforge.sh --check-duplicate <project id> <version>"
  refuse_duplicate_version "$2" "$3"
  exit 0
fi

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

forever_id="$(jq -r --arg name "$forever_name" --argjson type "$forever_type" '
  [ .[] | select(.name == $name and .gameVersionTypeID == $type) | .id ] | first // empty
' "$versions_body")"
if [[ ! "$forever_id" =~ ^[0-9]+$ ]]; then
  jq -r --argjson type "$forever_type" '
    .[] | select(.gameVersionTypeID == $type) | "forever row \(.id) \(.name)"
  ' "$versions_body" || true
  die "CurseForge has no Forever game version ${forever_name} type ${forever_type}"
fi
read_name="$(jq -r --argjson id "$forever_id" '[.[] | select(.id == $id)] | first | .name // empty' "$versions_body")"
read_type="$(jq -r --argjson id "$forever_id" '[.[] | select(.id == $id)] | first | .gameVersionTypeID // empty' "$versions_body")"
if [[ "$read_name" == "$retail_name" || "$read_type" == "$retail_type" || "$read_name" != "$forever_name" || "$read_type" != "$forever_type" ]]; then
  die "refusing CurseForge game version ${read_name:-missing} type ${read_type:-missing}"
fi
rm -f "$versions_body"
say "CurseForge game version ${forever_name} id ${forever_id}"

refuse_duplicate_version "$project_id" "$version"

git fetch origin "refs/tags/${version}:refs/tags/${version}"
git checkout --detach "$version"

if [[ -n ${PACKAGER_SH:-} ]]; then
  packager_sh="$PACKAGER_SH"
else
  packager="$(mktemp -d)"
  git clone --depth 1 --branch v2.6.1 https://github.com/BigWigsMods/packager.git "$packager"
  packager_sh="$packager/release.sh"
fi

# -d skips the packager upload. The token is unset so the packager cannot upload if -d is dropped.
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
  --arg displayName "LooseButtons ${version}" \
  --argjson gameVersion "$forever_id" \
  --arg releaseType "$release_type" \
  --rawfile changelog CHANGELOG.md \
  '{displayName: $displayName, gameVersions: [$gameVersion], releaseType: $releaseType, changelog: $changelog, changelogType: "markdown"}' > "$meta"

result="$(mktemp)"
upload_code="$(curl -sS -o "$result" -w "%{http_code}" \
  -H "x-api-token: ${CF_API_KEY}" \
  -F "metadata=<${meta}" \
  -F "file=@${zips[0]}" \
  "https://wow.curseforge.com/api/projects/${project_id}/upload-file" || true)"
say "upload HTTP ${upload_code}"
if [[ "$upload_code" != "200" ]]; then
  body="$(head -c 300 "$result" | tr '\n' ' ' || true)"
  say "upload body ${body}"
  die "CurseForge upload did not succeed"
fi
file_id="$(jq -r '.id // empty' "$result" 2>/dev/null || true)"

git tag "cf-${version}" "$workflow_sha"
git push origin "refs/tags/cf-${version}"
say "uploaded ${version} as Forever ${forever_name} file ${file_id:-unknown}"
