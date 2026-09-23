#!/bin/sh

sudo dnf update -y
sudo dnf install -y @development-tools
sudo dnf install -y emacs

[ -x ~/.local/bin/mise ] || curl -fsSL https://mise.run | sh
mkdir -p ~/.config/mise
[ -f ~/.config/mise/config.toml ] || curl -fsSL https://raw.githubusercontent.com/chubbyhippo/wsl-fedora-settings/refs/heads/main/mise.toml -o ~/.config/mise/config.toml
~/.local/bin/mise install --yes
eval "$(~/.local/bin/mise activate bash)"

[ -f ~/.bashrc ] && ! grep -qsF 'mise activate bash' ~/.bashrc && echo 'eval "$(~/.local/bin/mise activate bash)"' >> ~/.bashrc

# init.el extras (language servers + debuggers)
curl -fsSL https://raw.githubusercontent.com/chubbyhippo/wsl-fedora-settings/refs/heads/main/init-el-extras.sh | /usr/bin/env sh

rpm -q jet-brains-mono-nerd-fonts >/dev/null 2>&1 || {
    sudo dnf copr enable -y aquacash5/nerd-fonts
    sudo dnf install -y jet-brains-mono-nerd-fonts
}
