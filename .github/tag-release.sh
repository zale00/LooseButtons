#!/usr/bin/env bash
set -euo pipefail

toc_version() {
  sed -n 's/^## Version:[[:space:]]*//p' LooseButtons.toc | tr -d '\r' | head -n1 | sed 's/[[:space:]]*$//'
}

changelog_version() {
  sed -n 's/^## \([^[:space:]]*\).*/\1/p' CHANGELOG.md | tr -d '\r' | head -n1
}

remote_tag_sha() {
  git ls-remote --refs --tags origin "refs/tags/$1" | awk 'NR==1 {print $1}'
}

decide() {
  local version=$1 sha=$2 existing=$3 changelog=$4
  if [[ ! $version =~ ^[0-9][0-9A-Za-z.+-]*$ ]] || ! git check-ref-format "refs/tags/$version"; then
    echo "LooseButtons.toc ## Version: '${version}' is not a valid release tag" >&2
    return 1
  fi
  if [[ -n $existing ]]; then
    echo "skip ${version} already tagged (${existing})"
    return 0
  fi
  if [[ $changelog != "$version" ]]; then
    echo "CHANGELOG.md top heading '${changelog}' does not match TOC version '${version}'" >&2
    return 1
  fi
  echo "tag ${version} ${sha}"
}

main() {
  local version sha decision action name commit
  version=$(toc_version)
  sha=${GITHUB_SHA:-$(git rev-parse HEAD)}
  decision=$(decide "$version" "$sha" "$(remote_tag_sha "$version")" "$(changelog_version)")
  echo "$decision"
  read -r action name commit <<<"$decision"
  [[ $action == tag ]] || return 0
  [[ ${DRY_RUN:-} == 1 ]] && return 0
  git tag "$name" "$commit"
  if git push origin "refs/tags/${name}"; then
    echo "tagged ${name} ${commit}"
    return 0
  fi
  if [[ -n $(remote_tag_sha "$name") ]]; then
    echo "skip ${name} appeared during push"
    return 0
  fi
  echo "could not push ${name}" >&2
  return 1
}

if [[ ${BASH_SOURCE[0]} == "$0" ]]; then
  if [[ ${1:-} == --dry-run ]]; then
    DRY_RUN=1
  fi
  main
fi
