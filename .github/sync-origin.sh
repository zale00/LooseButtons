#!/usr/bin/env bash
set -euo pipefail

# These paths are GitHub-only release files and a full tree replace deletes them.
protected=(
  ".pkgmeta"
  "CHANGELOG.md"
  ".github/"
)

is_protected() {
  local rel=$1 entry prefix
  for entry in "${protected[@]}"; do
    if [[ $entry == */ ]]; then
      prefix=${entry%/}
      if [[ $rel == "$prefix" || $rel == "$prefix"/* ]]; then
        return 0
      fi
    elif [[ $rel == "$entry" ]]; then
      return 0
    fi
  done
  return 1
}

toc_version() {
  local file=$1
  if [[ ! -f $file ]]; then
    printf ''
    return 0
  fi
  sed -n 's/^## Version:[[:space:]]*//p' "$file" | tr -d '\r' | head -n1 | sed 's/[[:space:]]*$//'
}

version_older() {
  local -a a b
  local i n av bv
  IFS=. read -r -a a <<<"$1"
  IFS=. read -r -a b <<<"$2"
  n=${#a[@]}
  if ((${#b[@]} > n)); then
    n=${#b[@]}
  fi
  for ((i = 0; i < n; i++)); do
    av=${a[i]:-0}
    bv=${b[i]:-0}
    [[ -z $av ]] && av=0
    [[ -z $bv ]] && bv=0
    if ((10#$av < 10#$bv)); then
      return 0
    fi
    if ((10#$av > 10#$bv)); then
      return 1
    fi
  done
  return 1
}

origin=""
dest=""
do_commit=0
do_push=0

while [[ $# -gt 0 ]]; do
  case "$1" in
    --origin)
      origin=${2:?}
      shift 2
      ;;
    --dest)
      dest=${2:?}
      shift 2
      ;;
    --commit)
      do_commit=1
      shift
      ;;
    --push)
      do_push=1
      do_commit=1
      shift
      ;;
    *)
      echo "unknown argument ${1}" >&2
      exit 1
      ;;
  esac
done

if [[ -z $origin || -z $dest ]]; then
  echo "need --origin and --dest" >&2
  exit 1
fi

origin=${origin%/}
dest=${dest%/}

if [[ ! -d $origin ]]; then
  echo "origin is not a directory" >&2
  exit 1
fi
if [[ ! -d $dest ]]; then
  echo "dest is not a directory" >&2
  exit 1
fi
if [[ ! -d $origin/LooseButtons ]]; then
  echo "origin has no LooseButtons/" >&2
  exit 1
fi
if [[ ! -f $origin/LooseButtons/LooseButtons.toc ]]; then
  echo "origin LooseButtons/LooseButtons.toc is missing" >&2
  exit 1
fi
if [[ $(git -C "$dest" rev-parse --is-inside-work-tree) != true ]]; then
  echo "dest is not a git work tree" >&2
  exit 1
fi

source_root="$origin/LooseButtons"
source_rels=()
declare -A source_set=()

while IFS= read -r -d '' rel; do
  [[ -n $rel ]] || continue
  source_rels+=("$rel")
  source_set["$rel"]=1
done < <(find "$source_root" -type f -printf '%P\0')

for rel in "${source_rels[@]}"; do
  if is_protected "$rel"; then
    echo "protected path ${rel}" >&2
    exit 1
  fi
done

origin_version=$(toc_version "$source_root/LooseButtons.toc")
dest_version=$(toc_version "$dest/LooseButtons.toc")
if version_older "$origin_version" "$dest_version"; then
  echo "origin version ${origin_version} is older than dest version ${dest_version}" >&2
  exit 1
fi

for rel in "${source_rels[@]}"; do
  target="$dest/$rel"
  mkdir -p -- "$(dirname -- "$target")"
  tmp="$(mktemp "$(dirname -- "$target")/.sync.XXXXXX")"
  cp -- "$source_root/$rel" "$tmp"
  # A cut-off copy left a truncated Logic.lua.
  mv -f -- "$tmp" "$target"
done

tracked_deletes=()
while IFS= read -r -d '' rel; do
  [[ -n $rel ]] || continue
  if [[ $rel == .git || $rel == .git/* ]]; then
    continue
  fi
  if is_protected "$rel"; then
    continue
  fi
  if [[ -v source_set[$rel] ]]; then
    continue
  fi
  if git -C "$dest" ls-files --error-unmatch -- "$rel" >/dev/null 2>&1; then
    tracked_deletes+=("$rel")
  fi
  rm -f -- "$dest/$rel"
done < <(find "$dest" \( -path "$dest/.git" -o -path "$dest/.git/*" \) -prune -o -type f -printf '%P\0')

if [[ $do_commit -eq 1 ]]; then
  for rel in "${source_rels[@]}"; do
    git -C "$dest" add -A -- "$rel"
  done
  if [[ ${#tracked_deletes[@]} -gt 0 ]]; then
    for rel in "${tracked_deletes[@]}"; do
      git -C "$dest" add -A -- "$rel"
    done
  fi
  if git -C "$dest" diff --cached --quiet; then
    echo "sync clean"
  else
    origin_sha=$(git -C "$origin" rev-parse HEAD)
    git -C "$dest" commit -m "Mirror LooseButtons from Origin ${origin_sha}"
  fi
fi

if [[ $do_push -eq 1 ]]; then
  git -C "$dest" push origin HEAD:main
fi
