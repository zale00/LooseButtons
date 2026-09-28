#!/usr/bin/env bash
set -euo pipefail

if [[ -z ${CF_API_KEY:-} ]]; then
  echo "CF_API_KEY is missing"
  exit 1
fi
echo "CF_API_KEY is set"

version="$(sed -n 's/^## Version:[[:space:]]*\([^[:space:]]*\).*/\1/p' LooseButtons.toc | head -n 1 | tr -d '\r')"
if [[ ! $version =~ ^[0-9][0-9A-Za-z.+-]*$ ]]; then
  echo "TOC version '${version}' is not a release tag"
  exit 1
fi

if git ls-remote --exit-code --tags origin "refs/tags/cf-${version}" >/dev/null 2>&1; then
  echo "skip upload: cf-${version} already exists"
  exit 0
fi

workflow_sha="${GITHUB_SHA:-$(git rev-parse HEAD)}"

token_code="$(curl -sS -o /tmp/cf-versions.json -w "%{http_code}" \
  -H "x-api-token: ${CF_API_KEY}" \
  -H "Accept: application/json" \
  "https://wow.curseforge.com/api/game/versions")"
rm -f /tmp/cf-versions.json
echo "game versions HTTP ${token_code}"
if [[ "$token_code" != "200" ]]; then
  echo "CF_API_KEY was rejected"
  exit 1
fi

project_id="$(sed -n 's/^## X-Curse-Project-ID:[[:space:]]*\([0-9][0-9]*\).*/\1/p' LooseButtons.toc | head -n 1 | tr -d '\r')"
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
        echo "discover ${url} HTTP ${code}" >&2
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
    mapfile -t rows < <(discover_ids | sort -u)
    matches=()
    for row in "${rows[@]}"; do
      [[ -z "$row" ]] && continue
      IFS=$'\t' read -r id name slug <<<"$row"
      [[ "$id" =~ ^[0-9]+$ ]] || continue
      echo "project ${id} ${name} ${slug}" >&2
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
  echo "no CurseForge project id"
  exit 1
fi
echo "using project ${project_id}"

files_body="$(mktemp)"
files_code="$(curl -sS -o "$files_body" -w "%{http_code}" \
  -H "x-api-token: ${CF_API_KEY}" \
  -H "Accept: application/json" \
  "https://wow.curseforge.com/api/projects/${project_id}/files" || true)"
echo "files HTTP ${files_code}"
if [[ "$files_code" == "200" ]] && jq -e . "$files_body" >/dev/null 2>&1; then
  if jq -r '.. | objects | select(.fileName != null or .displayName != null) | "\(.fileName // "") \(.displayName // "")"' "$files_body" | grep -F -q "$version"; then
    rm -f "$files_body"
    echo "skip upload: CurseForge already has ${version}"
    git tag "cf-${version}" "$workflow_sha"
    git push origin "refs/tags/cf-${version}"
    exit 0
  fi
fi
rm -f "$files_body"

git fetch origin "refs/tags/${version}:refs/tags/${version}"
git checkout --detach "$version"

packager="$(mktemp -d)"
git clone --depth 1 --branch v2.6.1 https://github.com/BigWigsMods/packager.git "$packager"

# The packager skips a branch push when a tag already points at HEAD.
log="$(mktemp)"
set +e
env -u GITHUB_ACTIONS CF_API_KEY="$CF_API_KEY" bash "$packager/release.sh" -l -p "$project_id" >"$log" 2>&1
status=$?
set -e
cat "$log"
if [[ "$status" -ne 0 ]] || ! grep -q "Success!" "$log"; then
  echo "CurseForge upload did not succeed"
  exit 1
fi

git tag "cf-${version}" "$workflow_sha"
git push origin "refs/tags/cf-${version}"
echo "uploaded ${version}"
