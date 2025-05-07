#!/bin/bash

set -e

echo "🔧 Начинаем инициализацию окружения..."

# Путь к директории, откуда был запущен скрипт
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# Установка зависимостей
echo "📦 Проверка и установка необходимых пакетов..."
if command -v apt &> /dev/null; then
  sudo apt update
  sudo apt install -y git curl zsh
else
  echo "❌ Поддерживаются только apt-системы (Ubuntu/Debian)."
  exit 1
fi

# Проверка наличия zsh
if ! command -v zsh &> /dev/null; then
  echo "❌ Ошибка установки ZSH."
  exit 1
else
  echo "✅ ZSH установлен."
fi

# Установка Oh My Zsh
if [ ! -d "${HOME}/.oh-my-zsh" ]; then
  echo "✨ Устанавливаем Oh My Zsh..."
  RUNZSH=no CHSH=no KEEP_ZSHRC=yes \
  sh -c "$(curl -fsSL https://raw.githubusercontent.com/ohmyzsh/ohmyzsh/master/tools/install.sh)"
else
  echo "✅ Oh My Zsh уже установлен."
fi

# Установка tmux
if [ ! -d "${HOME}/.tmux" ]; then
  echo "📦 Клонируем gpakosz/.tmux..."
  git clone --single-branch https://github.com/gpakosz/.tmux.git ~/.tmux
  ln -s -f ~/.tmux/.tmux.conf ~/.tmux.conf
else
  echo "✅ .tmux уже склонирован."
fi

# Клонирование dotfiles
DOTFILES_DIR="${HOME}/.dotfiles"
if [ ! -d "$DOTFILES_DIR" ]; then
  echo "📁 Клонируем твой репозиторий .dotfiles..."
  git clone https://github.com/alexbic/.dotfiles.git "$DOTFILES_DIR"
else
  echo "✅ .dotfiles уже присутствует."
fi

# Подключение конфигов
echo "🔗 Подключаем конфиги..."
ln -sf "$DOTFILES_DIR/.zshrc" ~/.zshrc
ln -sf "$DOTFILES_DIR/tmux.conf.local" ~/.tmux.conf.local

echo "✅ Готово! Перезапусти терминал или выполни 'exec zsh'"

# Удаление папки init-shell
if [[ "$SCRIPT_DIR" == */init-shell ]]; then
  echo "🧹 Удаляем временную папку init-shell..."
  cd ~
  rm -rf "$SCRIPT_DIR"
  echo "🗑️ init-shell удалён."
fi
