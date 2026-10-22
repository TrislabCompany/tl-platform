#!/usr/bin/env bash
# Installs a pinned release of a CLI the workflows use, after checking its
# SHA-256 against the release's checksum file. Copied from
# tl-cloud-infrastructure, with only the tools this repository uses.
#
#   install-tool.sh actionlint <version>
set -euo pipefail
tool=$1 version=$2
case "$tool" in
  actionlint)
    base="https://github.com/rhysd/actionlint/releases/download/v$version"
    asset="actionlint_${version}_linux_amd64.tar.gz" sums="actionlint_${version}_checksums.txt" ;;
  *) echo "unknown tool: $tool" >&2; exit 2 ;;
esac
dir="$RUNNER_TEMP/tools/$tool"
mkdir -p "$dir"
cd "$dir"
curl -fsSL -o "$asset" "$base/$asset"
curl -fsSL -o sums.txt "$base/$sums"
grep " $asset\$" sums.txt | sha256sum -c -
tar -xzf "$asset" "$tool"
echo "$dir" >> "$GITHUB_PATH"
