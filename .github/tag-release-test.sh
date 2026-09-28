#!/usr/bin/env bash
set -euo pipefail

script_dir="$(cd "$(dirname "$0")" && pwd)"
script="$script_dir/tag-release.sh"

source "$script"

out="$(decide 0.1.0 abc123 "" 0.1.0)"
[[ "$out" == "tag 0.1.0 abc123" ]]

out="$(decide 0.1.0 abc123 deadbeef 0.1.0)"
[[ "$out" == "skip 0.1.0 already tagged (deadbeef)" ]]

set +e
out=$(decide v0.2.0 abc123 "" v0.2.0 2>&1)
status=$?
set -e
[[ $status -eq 1 ]]
[[ "$out" == "LooseButtons.toc ## Version: 'v0.2.0' is not a valid release tag" ]]

set +e
out=$(decide 0.2.0 abc123 "" 0.1.0 2>&1)
status=$?
set -e
[[ $status -eq 1 ]]
[[ "$out" == "CHANGELOG.md top heading '0.1.0' does not match TOC version '0.2.0'" ]]

root="$(mktemp -d)"
bare="$root/origin.git"
src="$root/src"
git init --bare -q "$bare"
git init -q -b main "$src"
git -C "$src" config user.email "t@example.com"
git -C "$src" config user.name "t"
cp "$script" "$src/tag-release.sh"
printf '## Version: 0.1.0\n' > "$src/LooseButtons.toc"
printf '## 0.1.0\n- first\n' > "$src/CHANGELOG.md"
git -C "$src" add LooseButtons.toc CHANGELOG.md tag-release.sh
git -C "$src" commit -q -m "init"
git -C "$src" remote add origin "$bare"
git -C "$src" push -q -u origin main
tip="$(git -C "$src" rev-parse HEAD)"

dry="$(cd "$src" && bash ./tag-release.sh --dry-run)"
[[ "$dry" == "tag 0.1.0 ${tip}" ]]
if git --git-dir="$bare" rev-parse -q --verify refs/tags/0.1.0 >/dev/null; then
  echo "dry-run pushed a tag" >&2
  exit 1
fi

first="$(cd "$src" && bash ./tag-release.sh)"
[[ "$first" == $'tag 0.1.0 '"${tip}"$'\ntagged 0.1.0 '"${tip}" ]]
[[ "$(git --git-dir="$bare" rev-parse refs/tags/0.1.0)" == "$tip" ]]

second="$(cd "$src" && bash ./tag-release.sh)"
[[ "$second" == "skip 0.1.0 already tagged (${tip})" ]]

echo "more" >> "$src/LooseButtons.toc"
git -C "$src" add LooseButtons.toc
git -C "$src" commit -q -m "no bump"
git -C "$src" push -q origin main
unbumped="$(cd "$src" && bash ./tag-release.sh)"
[[ "$unbumped" == "skip 0.1.0 already tagged (${tip})" ]]
[[ "$(git --git-dir="$bare" rev-parse refs/tags/0.1.0)" == "$tip" ]]

printf '## Version: 0.2.0\n' > "$src/LooseButtons.toc"
printf '## 0.1.0\n- stale\n' > "$src/CHANGELOG.md"
git -C "$src" add LooseButtons.toc CHANGELOG.md
git -C "$src" commit -q -m "toc only"
git -C "$src" push -q origin main
set +e
stale=$(cd "$src" && bash ./tag-release.sh 2>&1)
status=$?
set -e
[[ $status -eq 1 ]]
[[ "$stale" == "CHANGELOG.md top heading '0.1.0' does not match TOC version '0.2.0'" ]]
if git --git-dir="$bare" rev-parse -q --verify refs/tags/0.2.0 >/dev/null; then
  echo "changelog mismatch created a tag" >&2
  exit 1
fi

printf '## 0.2.0\n- bumped\n' > "$src/CHANGELOG.md"
git -C "$src" add CHANGELOG.md
git -C "$src" commit -q -m "bump"
git -C "$src" push -q origin main
tip2="$(git -C "$src" rev-parse HEAD)"
bumped="$(cd "$src" && bash ./tag-release.sh)"
[[ "$bumped" == $'tag 0.2.0 '"${tip2}"$'\ntagged 0.2.0 '"${tip2}" ]]
[[ "$(git --git-dir="$bare" rev-parse refs/tags/0.2.0)" == "$tip2" ]]
[[ "$(git --git-dir="$bare" rev-parse refs/tags/0.1.0)" == "$tip" ]]

echo ok
