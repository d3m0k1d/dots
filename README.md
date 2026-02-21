# dots

My personal simple setup for [Hyprland](https://github.com/hyprwm/Hyprland) on my Arch Linux

## Overview
![Waybar](./docs/sc1.png)
![Terminal + Fastfetch](./docs/sc2.png)
![NeoVim](./docs/sc3.png)
## Core components
- [Hyprland](https://github.com/hyprwm/Hyprland)
- [Waybar](https://github.com/Alexays/Waybar)
- [Wofi](https://github.com/SimplyCEO/wofi)
- [Hyprlock](https://github.com/hyprwm/hyprlock)
- [NeoVim](https://github.com/neovim/neovim) + [AstroNvim](https://github.com/AstroNvim/AstroNvim)
- [Kitty](https://github.com/kovidgoyal/kitty) + [OhMyZsh](https://github.com/ohmyzsh/ohmyzsh)
- [Hyprshot](https://github.com/another-brother/hyprshot)
- [Fastfetch](https://github.com/fastfetch-cli/fastfetch)
- [Lazygit](https://github.com/jesseduffield/lazygit)
- [Eza](https://github.com/eza-community/eza)
## Installation
I write simple makefile, but i dont test on new system. If you encounter any issues while using it, please create an issue on GitHub or contact me via email [contact@d3m0k1d.ru](mailto:contact@d3m0k1d.ru).
```shell
git clone https://github.com/d3m0k1d/dots.git
cd dots
sudo make backup
sudo make install
```
## Aliases
| Alias | Command |
| ----- | ------- |
| `ff`  | `fastfetch` |
| `ls`  | `eza` |
| `l`  | `lazygit` |
| `upd` | `sudo pacman -Syu` |
| `sn`  | `shutdown now` |
| `re`  | `reboot` |
| `g`   | `git push origin master` |
| `n`   | `nvim` |

## License
This project is licensed under the MIT License.
