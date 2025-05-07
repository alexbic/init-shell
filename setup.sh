#!/bin/bash

set -e

echo "🔧 Начинаем инициализацию окружения..."

for cmd in git curl; do
  if ! command -v $cmd &> /dev/null; then
    echo "❌ Не найдено: $cmd. Пожалуйста, установите его и повторите."
    exit 1
  fi
done

if ! command -v zsh &> /dev/null; then
  echo "ℹ️ ZSH не найден. Устанавливаем..."
  if command -v apt &> /dev/null; then
    sudo apt update
    sudo apt install -y zsh
  else
    echo "❌ Поддерживается только apt-системы (Ubuntu/Debian)."
    exit 1
  fi
else
  echo "✅ ZSH уже установлен."
fi

if [ ! -d "${HOME}/.oh-my-zsh" ]; then
  echo "✨ Устанавливаем Oh My Zsh..."
  RUNZSH=no CHSH=no KEEP_ZSHRC=yes \
  sh -c "$(curl -fsSL https://raw.githubusercontent.com/ohmyzsh/ohmyzsh/master/tools/install.sh)"
else
  echo "✅ Oh My Zsh уже установлен."
fi

if [ ! -d "${HOME}/.tmux" ]; then
  echo "📦 Клонируем gpakosz/.tmux..."
  git clone --single-branch https://github.com/gpakosz/.tmux.git ~/.tmux
  ln -s -f ~/.tmux/.tmux.conf ~/.tmux.conf
else
  echo "✅ .tmux уже склонирован."
fi

DOTFILES_DIR="${HOME}/.dotfiles"

if [ ! -d "$DOTFILES_DIR" ]; then
  echo "📁 Клонируем твой репозиторий .dotfiles..."
  git clone https://github.com/alexbic/.dotfiles.git "$DOTFILES_DIR"
fi

echo "🔗 Подключаем конфиги..."
ln -sf "$DOTFILES_DIR/.zshrc" ~/.zshrc
ln -sf "$DOTFILES_DIR/tmux.conf.local" ~/.tmux.conf.local

echo "✅ Готово! Перезапусти терминал или выполни 'exec zsh'"
