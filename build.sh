#!/usr/bin/env bash
# Adds the latest yonder release to the apt and rpm repositories and signs both.
# Needs: gh-free curl, apt-ftparchive, createrepo_c, gpg with the signing key imported.
set -euo pipefail
tag=$(curl -fsSL https://api.github.com/repos/dpologdvinity/yonder/releases/latest | sed -n 's/.*"tag_name": *"\(v[^"]*\)".*/\1/p')
ver=${tag#v}
if [ "$(cat VERSION 2>/dev/null)" = "$ver" ]; then echo unchanged; exit 0; fi
base="https://github.com/dpologdvinity/yonder/releases/download/$tag"
sums=$(curl -fsSL "$base/checksums.txt")
fetch() {
  curl -fsSL -o "$2/$1" "$base/$1"
  echo "$sums" | awk -v f="$1" '$2==f' | (cd "$2" && sha256sum -c --quiet -)
}
mkdir -p apt rpm
for a in amd64 arm64; do fetch "yonder_${ver}_${a}.deb" apt; done
for a in x86_64 aarch64; do fetch "yonder-${ver}-1.${a}.rpm" rpm; done

# apt: flat repository (deb [signed-by=...] URL ./)
(cd apt
  apt-ftparchive packages . > Packages
  gzip -kf Packages
  apt-ftparchive -o APT::FTPArchive::Release::Origin=yonder -o APT::FTPArchive::Release::Label=yonder release . > Release
  gpg --batch --yes --clearsign -o InRelease Release
  gpg --batch --yes -abs -o Release.gpg Release)

# dnf: repodata with a signed repomd.xml (repo_gpgcheck=1)
createrepo_c --quiet --update rpm
gpg --batch --yes --detach-sign --armor -o rpm/repodata/repomd.xml.asc rpm/repodata/repomd.xml

# pacman: per-arch repos with signed packages and database (releases from 0.4.1 ship .pkg.tar.zst)
for a in x86_64 aarch64; do
  pkg="yonder-${ver}-1-${a}.pkg.tar.zst"
  echo "$sums" | grep -q " $pkg\$" || continue
  mkdir -p "arch/$a"
  fetch "$pkg" "arch/$a"
  gpg --batch --yes --detach-sign -o "arch/$a/$pkg.sig" "arch/$a/$pkg"
  # repo-add only exists on Arch, so run it in a throwaway Arch container as this user.
  docker run --rm --user "$(id -u):$(id -g)" -v "$PWD/arch/$a:/r" -w /r archlinux:latest \
    repo-add -q -R yonder.db.tar.zst "$pkg"
  # Pages does not serve symlinks; replace yonder.db -> yonder.db.tar.zst with copies.
  for db in db files; do
    cp --remove-destination "arch/$a/yonder.$db.tar.zst" "arch/$a/yonder.$db"
    gpg --batch --yes --detach-sign -o "arch/$a/yonder.$db.tar.zst.sig" "arch/$a/yonder.$db.tar.zst"
    cp "arch/$a/yonder.$db.tar.zst.sig" "arch/$a/yonder.$db.sig"
  done
done

echo "$ver" > VERSION
echo "$ver"
