#!/usr/bin/env bash
# Scheduled Forever compatibility check. Prints one "decision ..." line.
# Writes the TOC, changelog, and upload target only for bump or retarget.
# Pushes and dispatches tag-release only when GITHUB_ACTIONS is set.
set -euo pipefail

# ponytail: Forever game versions stay below major 10. Retail Midnight is 12.x.
# If a Forever version major reaches 10, this guard refuses the run. Replace it
# with a check that does not use the major.
forever_major_limit=10
forever_type=88568

die() {
  printf 'decision refuse %s\n' "$1"
  exit 1
}

root_of() {
  if [[ -n ${FOREVER_REPO:-} ]]; then
    printf '%s\n' "$FOREVER_REPO"
  else
    cd "$(dirname "$0")/.." && pwd
  fi
}

game_of() {
  local text=$1
  [[ $text =~ ^([0-9]+)\.([0-9]+)\.([0-9]+)(\.[0-9]+)?$ ]] || return 1
  printf '%s.%s.%s\n' "${BASH_REMATCH[1]}" "${BASH_REMATCH[2]}" "${BASH_REMATCH[3]}"
}

interface_of() {
  local major minor patch
  IFS=. read -r major minor patch <<<"$1"
  printf '%s\n' $((10#$major * 10000 + 10#$minor * 100 + 10#$patch))
}

patch_bump() {
  local major minor patch
  [[ $1 =~ ^([0-9]+)\.([0-9]+)\.([0-9]+)$ ]] || return 1
  major=${BASH_REMATCH[1]}
  minor=${BASH_REMATCH[2]}
  patch=${BASH_REMATCH[3]}
  printf '%s.%s.%s\n' "$major" "$minor" $((10#$patch + 1))
}

wiki_line() {
  local key=$1 file=$2
  grep -E "^[[:space:]]*\\|${key}\\|" "$file" | head -n 1
}

wiki_game_interface() {
  local line=$1 rest game iface
  rest=${line#*\\!\\!}
  rest=${rest#*\\!\\!}
  game=${rest%%\\!\\!*}
  rest=${rest#*\\!\\!}
  iface=${rest%%\\!\\!*}
  [[ $game =~ ^[0-9]+\.[0-9]+\.[0-9]+$ ]] || return 1
  [[ $iface =~ ^[0-9]+$ ]] || return 1
  printf '%s %s\n' "$game" "$iface"
}

toc_field() {
  local key=$1 file=$2
  sed -n "s/^## ${key}:[[:space:]]*\\([^[:space:]]*\\).*/\\1/p" "$file" | head -n 1 | tr -d '\r'
}

script_game() {
  sed -n 's/^forever_name=//p' "$1" | head -n 1 | tr -d '\r'
}

load_cf_names() {
  local file=$1 retail=$2
  jq -r --argjson type "$forever_type" --arg retail "$retail" '
    .[] | select(.gameVersionTypeID == $type and .name != $retail) | .name
  ' "$file" | sort -u
}

has_name() {
  local needle=$1 name
  shift
  for name in "$@"; do
    [[ $name == "$needle" ]] && return 0
  done
  return 1
}

cf_tag_exists() {
  local version=$1
  git ls-remote --exit-code --tags origin "refs/tags/cf-${version}" >/dev/null 2>&1
}

decide() {
  local toc_iface=$1 toc_ver=$2 wiki_game=$3 wiki_iface=$4 retail_iface=$5 gethe_game=$6 script=$7 tag_exists=$8
  shift 8
  local -a names=("$@")
  local major new_ver

  major=${wiki_game%%.*}
  if (( major >= forever_major_limit )) || [[ $wiki_iface == "$retail_iface" ]]; then
    printf 'decision refuse retail\n'
    return 0
  fi
  if [[ $wiki_iface != "$(interface_of "$wiki_game")" ]]; then
    printf 'decision refuse wiki-interface\n'
    return 0
  fi
  if [[ $gethe_game != "$wiki_game" ]]; then
    printf 'decision refuse disagree\n'
    return 0
  fi

  if [[ $toc_iface != "$wiki_iface" ]]; then
    new_ver=$(patch_bump "$toc_ver") || {
      printf 'decision refuse version\n'
      return 0
    }
    if has_name "$wiki_game" "${names[@]+"${names[@]}"}"; then
      printf 'decision bump %s %s %s upload\n' "$wiki_iface" "$new_ver" "$wiki_game"
    else
      printf 'decision bump %s %s %s hold\n' "$wiki_iface" "$new_ver" "$wiki_game"
    fi
    return 0
  fi

  if has_name "$wiki_game" "${names[@]+"${names[@]}"}" && [[ $script != "$wiki_game" ]]; then
    if [[ $tag_exists == 1 ]]; then
      printf 'decision retarget %s\n' "$wiki_game"
    else
      printf 'decision retarget %s upload\n' "$wiki_game"
    fi
    return 0
  fi

  if ! has_name "$script" "${names[@]+"${names[@]}"}"; then
    if [[ ${#names[@]} -eq 1 ]]; then
      printf 'decision retarget %s\n' "${names[0]}"
      return 0
    fi
    printf 'decision refuse cf-target\n'
    return 0
  fi

  if [[ $tag_exists == 0 && $script == "$wiki_game" ]] && has_name "$wiki_game" "${names[@]+"${names[@]}"}"; then
    printf 'decision retry-upload %s\n' "$wiki_game"
    return 0
  fi

  printf 'decision noop\n'
}
