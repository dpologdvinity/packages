#!/usr/bin/env bash
# Preserve the existing repository identity and signing key for current users.
set -euo pipefail
cd apt
apt-ftparchive packages . > Packages
gzip -kf Packages
apt-ftparchive -o APT::FTPArchive::Release::Origin=yonder -o APT::FTPArchive::Release::Label=yonder release . > Release
gpg --batch --yes --clearsign -o InRelease Release
gpg --batch --yes -abs -o Release.gpg Release
