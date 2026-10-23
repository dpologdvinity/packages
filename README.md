# yonder packages

apt and dnf repository for [yonder](https://github.com/dpologdvinity/yonder). Rebuilt hourly from the latest release.

## Debian / Ubuntu

```sh
sudo curl -fsSLo /usr/share/keyrings/yonder.gpg https://dpologdvinity.github.io/packages/yonder.gpg
echo "deb [signed-by=/usr/share/keyrings/yonder.gpg] https://dpologdvinity.github.io/packages/apt ./" | sudo tee /etc/apt/sources.list.d/yonder.list
sudo apt update && sudo apt install yonder
```

## Fedora / RHEL

```sh
sudo curl -fsSLo /etc/yum.repos.d/yonder.repo https://dpologdvinity.github.io/packages/yonder.repo
sudo dnf install yonder
```

Signing key fingerprint: `282804EB5779EA7EFFCF8308097AF7F74B2F93E5`
