#!/bin/bash

# ──────────────────────────────────────────────────────────────
# 📁 Переменные
BASE_DIR="$HOME/.myshell"
BACKUP_DIR="$BASE_DIR/backup"
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# GIT: Репозиторий с dotfiles
GIT_DOTFILES_REPO="https://github.com/alexbic/.dotfiles.git"
# GIT: Репозиторий с конфигурацией tmux
GIT_TMUX_REPO="https://github.com/gpakosz/.tmux.git"
# GIT: Установка Oh My Zsh
GIT_OMZ_INSTALL_URL="https://raw.githubusercontent.com/ohmyzsh/ohmyzsh/master/tools/install.sh"

# ──────────────────────────────────────────────────────────────
# 🧪 Проверка системы
if ! command -v apt &>/dev/null; then
  echo "❌ Поддерживаются только apt-системы (Ubuntu/Debian)."
  exit 1
fi

# 📦 Установка базовых пакетов
echo "📦 Обновляем apt и устанавливаем git, curl, zsh..."
sudo apt update
sudo apt install -y git curl zsh

# ──────────────────────────────────────────────────────────────
# 🧼 Удаляем старую директорию ~/.myshell, если она есть
echo "🧼 Удаляем старую директорию $BASE_DIR (если есть)..."
rm -rf "$BASE_DIR"

# 💾 Создание структуры каталогов
echo "📁 Создаем каталоги в ~/.myshell..."
mkdir -p "$BASE_DIR"
mkdir -p "$BACKUP_DIR"

# 🔁 Переход в рабочую директорию
cd "$BASE_DIR" || { echo "❌ Не удалось перейти в $BASE_DIR"; exit 1; }

# 🗂 Резервное копирование старых настроек
echo "🗂 Перемещаем старые настройки в $BACKUP_DIR..."
for file in .zshrc .tmux.conf .tmux.conf.local; do
  src="$HOME/$file"
  dest="$BACKUP_DIR/$file"
  if [ -L "$src" ]; then
    echo "🔁 $file — это симлинк. Копируем реальный файл..."
    cp --dereference "$src" "$dest" 2>/dev/null || true
  elif [ -f "$src" ]; then
    echo "📄 $file — обычный файл. Перемещаем..."
    mv "$src" "$dest" 2>/dev/null || true
  fi
done

# Копируем .oh-my-zsh вместо перемещения
cp -a "$HOME/.oh-my-zsh" "$BACKUP_DIR/.oh-my-zsh" 2>/dev/null || true

# 🧹 Удаление симлинков и временных файлов
echo "🧹 Удаляем старые симлинки и временные файлы..."
find "$HOME" -maxdepth 1 -type f \( \
  -name ".zshrc" -o \
  -name ".zshrc.pre-oh-my-zsh" -o \
  -name ".zsh_history" -o \
  -name ".zlogin" -o \
  -name ".zlogout" -o \
  -name ".zprofile" -o \
  -name ".zshenv" -o \
  -name ".zsh*" -o \
  -name ".tmux.conf" -o \
  -name ".tmux.conf.local" -o \
  -name ".tmux*" \
\) -exec rm -f {} \;

# ──────────────────────────────────────────────────────────────
# 📥 Клонируем dotfiles
echo "📥 Клонируем dotfiles..."
git clone "$GIT_DOTFILES_REPO" "dotfiles"

# 📥 Клонируем tmux конфигурации
echo "📥 Клонируем tmux конфигурации..."
git clone "$GIT_TMUX_REPO" "tmux"

# 📥 Устанавливаем Oh My Zsh
if [[ -d "$HOME/.oh-my-zsh" ]]; then
  echo "♻️ Обнаружен установленный Oh My Zsh. Выполняем деинсталляцию..."
  export UNATTENDED=true
  "$HOME/.oh-my-zsh/tools/uninstall.sh" || echo "⚠️ Ошибка при деинсталляции, продолжаем..."
fi

# 🧼 Удаляем остатки Oh My Zsh
echo "🧼 Удаляем остатки Oh My Zsh..."
rm -rf "$HOME/.oh-my-zsh"

# 📥 Устанавливаем свежий Oh My Zsh
echo "📥 Устанавливаем свежий Oh My Zsh..."
RUNZSH=no KEEP_ZSHRC=yes sh -c "$(curl -fsSL $GIT_OMZ_INSTALL_URL)"

# ⚙️ Настройка Zsh
echo "⚙️ Настраиваем Zsh..."
ln -sf "$BASE_DIR/dotfiles/.zshrc" "$HOME/.zshrc"

# 📦 Установка плагинов для Zsh
echo "📦 Устанавливаем плагины для Zsh..."
git clone https://github.com/zsh-users/zsh-autosuggestions "$BASE_DIR/ohmyzsh/custom/plugins/zsh-autosuggestions"
git clone https://github.com/zsh-users/zsh-syntax-highlighting "$BASE_DIR/ohmyzsh/custom/plugins/zsh-syntax-highlighting"

# ⚙️ Настройка tmux
echo "⚙️ Настраиваем tmux..."
ln -sf "$BASE_DIR/tmux/.tmux.conf" "$HOME/.tmux.conf"
ln -sf "$BASE_DIR/dotfiles/.tmux.conf.local" "$HOME/.tmux.conf.local"

# 🗑️ Удаляем временную папку init-shell, если запускались из неё
if [[ "$SCRIPT_DIR" == */init-shell ]]; then
  echo "🗑️ Удаляем временную папку init-shell..."
  cd ~
  rm -rf "$SCRIPT_DIR"
  echo "✅ init-shell удалён."
fi

echo "🎉 Установка завершена успешно!"
