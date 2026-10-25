# Packages

Signed APT packages for [yonder](https://github.com/dpologdvinity/yonder) and
[flaky](https://github.com/dpologdvinity/flaky), plus dnf and pacman packages for
yonder. Rebuilt hourly from the latest releases. The existing yonder signing key
and repository identity are preserved for compatibility.

## Debian / Ubuntu

```sh
sudo curl -fsSLo /usr/share/keyrings/yonder.gpg https://dpologdvinity.github.io/packages/yonder.gpg
echo "deb [signed-by=/usr/share/keyrings/yonder.gpg] https://dpologdvinity.github.io/packages/apt ./" | sudo tee /etc/apt/sources.list.d/yonder.list
sudo apt update && sudo apt install yonder
```

With the repository configured, install Flaky on amd64 or arm64:

```sh
sudo apt update && sudo apt install flaky
```

Flaky imports verify release SHA-256 checksums and Debian metadata before signing
the shared index. The `Update Flaky APT packages` workflow can also be dispatched
manually. Publication is serialized with yonder updates so neither overwrites
the other's index. Each publishing workflow explicitly requests a Pages build
after committing so the public repository updates even with `GITHUB_TOKEN`.

## Fedora / RHEL

```sh
sudo curl -fsSLo /etc/yum.repos.d/yonder.repo https://dpologdvinity.github.io/packages/yonder.repo
sudo dnf install yonder
```

## Arch Linux

```sh
curl -fsSL https://dpologdvinity.github.io/packages/yonder.asc | sudo pacman-key --add -
sudo pacman-key --lsign-key 282804EB5779EA7EFFCF8308097AF7F74B2F93E5
printf '\n[yonder]\nServer = https://dpologdvinity.github.io/packages/arch/$arch\n' | sudo tee -a /etc/pacman.conf
sudo pacman -Sy yonder
```

Signing key fingerprint: `282804EB5779EA7EFFCF8308097AF7F74B2F93E5`
