#!/usr/bin/env bash
# Import released Debian packages; stdout is only the published version.
set -euo pipefail
exec 3>&1 1>&2
tag=$(curl -fsSL https://api.github.com/repos/dpologdvinity/flaky/releases/latest | jq -er .tag_name)
[[ "$tag" =~ ^v[0-9]+\.[0-9]+\.[0-9]+$ ]] || { echo 'Invalid Flaky release version' >&2; exit 1; }
version=${tag#v}
if [[ "$(cat .flaky-version 2>/dev/null || true)" = "$version" ]]; then
  echo unchanged >&3
  exit 0
fi
temp_dir=$(mktemp -d)
trap 'rm -rf "$temp_dir"' EXIT
base="https://github.com/dpologdvinity/flaky/releases/download/$tag"
curl --retry 3 -fsSL -o "$temp_dir/checksums.txt" "$base/checksums.txt"
for arch in amd64 arm64; do
  package="flaky_${version}_${arch}.deb"
  expected=$(awk -v name="$package" '$2 == name { print $1 }' "$temp_dir/checksums.txt")
  [[ "$expected" =~ ^[a-fA-F0-9]{64}$ ]] || { echo "Missing checksum: $package" >&2; exit 1; }
  curl --retry 3 -fsSL -o "$temp_dir/$package" "$base/$package"
  printf '%s  %s\n' "$expected" "$package" | (cd "$temp_dir" && sha256sum -c -)
  [[ "$(dpkg-deb -f "$temp_dir/$package" Package)" = flaky ]]
  [[ "$(dpkg-deb -f "$temp_dir/$package" Version)" = "$version" ]]
  [[ "$(dpkg-deb -f "$temp_dir/$package" Architecture)" = "$arch" ]]
done
mkdir -p apt
cp "$temp_dir/"*.deb apt/
./build-apt.sh
printf '%s\n' "$version" > .flaky-version
printf '%s\n' "$version" >&3
