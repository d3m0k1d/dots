HOME_DIR := $(HOME)
CONFIG_DIR := $(HOME)/.config
DOTFILES := $(shell pwd)

.PHONY: all backup install deps dotfiles help

all: help

backup:
	@echo "Backup your dotfiles..."
	mkdir -p $(HOME_DIR)/.dotbackup	
	cp -r $(CONFIG_DIR) $(HOME_DIR)/.dotbackup/ 2>/dev/null || true
	@echo "✓ Backup done at $(HOME_DIR)/.dotbackup"

deps:
	@echo "Installing dependencies..."
	sudo pacman -S --needed hyprland nvim kitty lazygit swww hyprshot hyprlock waybar wofi fastfetch zsh curl git eza
	@echo "✓ Dependencies installed"

install-zsh:
	@echo "Installing oh-my-zsh..."
	@if [ ! -d "$(HOME_DIR)/.oh-my-zsh" ]; then \
		sh -c "$$(curl -fsSL https://raw.githubusercontent.com/ohmyzsh/ohmyzsh/master/tools/install.sh)" "" --unattended; \
	else \
		echo "oh-my-zsh already installed"; \
	fi
	@if [ "$(shell echo $$SHELL)" != "$(shell which zsh)" ]; then \
		chsh -s $$(which zsh); \
		echo "✓ Shell changed to zsh (relogin required)"; \
	fi

dotfiles:
	@echo "Deleting old dotfiles..."
	rm -rf $(CONFIG_DIR)/wofi
	rm -rf $(CONFIG_DIR)/waybar
	rm -rf $(CONFIG_DIR)/kitty
	rm -rf $(CONFIG_DIR)/hyprland
	rm -rf $(CONFIG_DIR)/lazygit
	rm -rf $(CONFIG_DIR)/fastfetch
	rm -rf $(CONFIG_DIR)/nvim
	@echo "✓ Old configs removed"
	
	@echo "Installing dotfiles..." 
	# Hyprland
	mkdir -p $(CONFIG_DIR)/hyprland
	cp -r $(DOTFILES)/config/hyprland/* $(CONFIG_DIR)/hyprland/
	
	# Waybar
	mkdir -p $(CONFIG_DIR)/waybar
	cp -r $(DOTFILES)/config/waybar/* $(CONFIG_DIR)/waybar/
	
	# Wofi
	mkdir -p $(CONFIG_DIR)/wofi
	cp -r $(DOTFILES)/config/wofi/* $(CONFIG_DIR)/wofi/
	
	# Kitty
	mkdir -p $(CONFIG_DIR)/kitty
	cp -r $(DOTFILES)/config/kitty/* $(CONFIG_DIR)/kitty/
	
	# Neovim
	mkdir -p $(CONFIG_DIR)/nvim
	cp -r $(DOTFILES)/config/nvim/* $(CONFIG_DIR)/nvim/
	
	# Lazygit
	mkdir -p $(CONFIG_DIR)/lazygit
	cp -r $(DOTFILES)/config/lazygit/* $(CONFIG_DIR)/lazygit/
	
	# Fastfetch
	mkdir -p $(CONFIG_DIR)/fastfetch
	cp -r $(DOTFILES)/config/fastfetch/* $(CONFIG_DIR)/fastfetch/
	

	@if [ -f "$(DOTFILES)/config/zsh/.zshrc" ]; then \
		cp $(DOTFILES)/config/zsh/.zshrc $(HOME_DIR)/.zshrc; \
	fi
	
	# Make scripts executable
	chmod +x $(CONFIG_DIR)/hyprland/scripts/*.sh 2>/dev/null || true
	chmod +x $(CONFIG_DIR)/waybar/scripts/*.sh 2>/dev/null || true
	
	@echo "✓ Dotfiles installation complete!"

install: backup deps install-zsh dotfiles
	@echo ""
	@echo "=========================================="
	@echo "✓ Installation complete!"
	@echo "=========================================="
	@echo ""
	@echo "Next steps:"
	@echo "  1. Relogin to apply zsh changes"
	@echo "  2. Reload Hyprland (SUPER+SHIFT+R)"
	@echo "  3. Enjoy your new setup! 🎉(if my setup bad for you use the "sudo make clear ")"
	@echo ""

clean:
	@echo "Removing installed dotfiles..."
	rm -rf $(CONFIG_DIR)/hyprland
	rm -rf $(CONFIG_DIR)/waybar
	rm -rf $(CONFIG_DIR)/wofi
	rm -rf $(CONFIG_DIR)/kitty
	rm -rf $(CONFIG_DIR)/nvim
	rm -rf $(CONFIG_DIR)/lazygit
	rm -rf $(CONFIG_DIR)/fastfetch
	@echo "✓ Dotfiles removed"

help:
	@echo "Dotfiles Makefile by d3m0k1d"
	@echo ""
	@echo "Usage:"
	@echo "  make install     - Full installation (backup + deps + dotfiles)"
	@echo "  make backup      - Backup existing configs only"
	@echo "  make deps        - Install dependencies only"
	@echo "  make dotfiles    - Install dotfiles only"
	@echo "  make install-zsh - Install oh-my-zsh only"
	@echo "  make clean       - Remove installed dotfiles"
	@echo "  make help        - Show this help"
