#!/bin/bash

# Абсолютный путь к домашней директории
HOME_DIR="$(cd "$HOME" && pwd)"
# Абсолютный путь к текущей директории
CURRENT_DIR="$(pwd -P)"

if [[ "$CURRENT_DIR" != "$HOME_DIR" ]]; then
  echo "❌ Скрипт должен быть запущен ИМЕННО из домашней директории: $HOME_DIR"
  echo "📍 Сейчас вы находитесь здесь: $CURRENT_DIR"
  exit 1
fi

# Безопасный режим
set -euo pipefail

# 📁 Переменные
BASE_DIR="$HOME/.myshell"
BACKUP_DIR="$BASE_DIR/backup"
TIMESTAMP=$(date +"%Y-%m-%d_%H-%M-%S")
TMP_BACKUP_DIR="/tmp/myshell_backup_$TIMESTAMP"
ARCHIVE_NAME="backup_$TIMESTAMP.tar.gz"

GIT_DOTFILES_REPO="https://github.com/alexbic/.dotfiles.git"
GIT_TMUX_REPO="https://github.com/gpakosz/.tmux.git"
GIT_OMZ_INSTALL_URL="https://raw.githubusercontent.com/ohmyzsh/ohmyzsh/master/tools/install.sh"

# 🧪 Проверка системы
if ! command -v apt &>/dev/null; then
  echo "❌ Поддерживаются только apt-системы (Ubuntu/Debian)."
  exit 1
fi

# 📦 Установка базовых пакетов
echo "📦 Обновляем apt и устанавливаем git, curl, zsh..."
sudo apt update
sudo apt install -y git curl zsh

# 🗂 Резервное копирование ~/.myshell (если существует)
if [ -d "$BASE_DIR" ]; then
  echo "🗂 Найдена предыдущая установка .myshell. Делаем резервную копию..."
  mkdir -p "$TMP_BACKUP_DIR"

#  rsync -a --exclude "backup" "$BASE_DIR/" "$TMP_BACKUP_DIR/"
# Перемещаем файлы, исключая директорию backup
  find "$BASE_DIR" -mindepth 1 -not -path "$BASE_DIR/backup*" -exec mv -t "$TMP_BACKUP_DIR" {} +

  if [ ! -d "$BACKUP_DIR" ] || [ -z "$(ls -A "$BACKUP_DIR" 2>/dev/null)" ]; then
    echo "📁 Создаем директорию для резервных копий: $BACKUP_DIR"
    mkdir -p "$BACKUP_DIR"
  else
    echo "📁 Директория резервных копий уже существует и не пуста. Пропускаем создание."
  fi

  tar -czf "$BACKUP_DIR/$ARCHIVE_NAME" -C "$TMP_BACKUP_DIR" .
  echo "✅ Бэкап старых настроек сохранён: $BACKUP_DIR/$ARCHIVE_NAME"
  rm -rf "$TMP_BACKUP_DIR"
fi

# 💾 Создание структуры каталогов
echo "📁 Создаем каталоги в ~/.myshell..."
mkdir -p "$BASE_DIR"
mkdir -p "$BACKUP_DIR"

# 🗂 Резервное копирование старых настроек из $HOME
echo "🗂 Перемещаем старые настройки в $BACKUP_DIR..."
mkdir -p "$TMP_BACKUP_DIR"
for file in .zshrc .tmux.conf .tmux.conf.local; do
  src="$HOME/$file"
  dest="$TMP_BACKUP_DIR/$file"
  if [ -L "$src" ]; then
    echo "🔁 $file — это симлинк. Копируем реальный файл..."
    cp --dereference "$src" "$dest" 2>/dev/null || true
  elif [ -f "$src" ]; then
    echo "📄 $file — обычный файл. Перемещаем..."
    mv "$src" "$dest" 2>/dev/null || true
  fi
done

# 📂 Копируем .oh-my-zsh в временную папку
if [ -d "$HOME/.oh-my-zsh" ]; then
  echo "📂 Копируем .oh-my-zsh в временную папку..."
  cp -a "$HOME/.oh-my-zsh" "$TMP_BACKUP_DIR/.oh-my-zsh" 2>/dev/null || true

  echo "📦 Упаковываем бэкап текущих настроек Zsh, Oh-My-Zsh, tmux..."
  tar -czf "$BACKUP_DIR/$ARCHIVE_NAME" -C "$TMP_BACKUP_DIR" .
  echo "✅ Бэкап сохранён: $BACKUP_DIR/$ARCHIVE_NAME"
  rm -rf "$TMP_BACKUP_DIR"
fi

# 🧽 Удаление старого содержимого в .myshell, кроме каталога backup
echo "🧽 Очищаем старое содержимое .myshell (кроме backup)..."
find "$BASE_DIR" -mindepth 1 -not -path "$BACKUP_DIR" -exec rm -rf {} +

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

# 📥 Клонируем dotfiles
echo "📥 Клонируем dotfiles..."
git clone "$GIT_DOTFILES_REPO" "$BASE_DIR/dotfiles"

# 📥 Клонируем tmux конфигурации
echo "📥 Клонируем tmux конфигурации..."
git clone "$GIT_TMUX_REPO" "$BASE_DIR/tmux"

# 📥 Устанавливаем Oh-My-Zsh
if [[ -d "$HOME/.oh-my-zsh" ]]; then
  echo "♻️ Обнаружен установленный Oh-My-Zsh. Выполняем деинсталляцию..."
  export UNATTENDED=true
  chmod +x "$HOME/.oh-my-zsh/tools/uninstall.sh" 2>/dev/null || true
  "$HOME/.oh-my-zsh/tools/uninstall.sh" || echo "⚠️ Ошибка при деинсталляции, продолжаем..."
fi

# 🧼 Удаляем остатки Oh-My-Zsh
echo "🧼 Удаляем остатки Oh-My-Zsh..."
rm -rf "$HOME/.oh-my-zsh"

# 📥 Устанавливаем свежий Oh-My-Zsh
echo "📥 Устанавливаем свежий Oh-My-Zsh..."
RUNZSH=no KEEP_ZSHRC=yes sh -c "$(curl -fsSL $GIT_OMZ_INSTALL_URL)"

# 🔁 Перемещаем Oh-My-Zsh в $BASE_DIR и создаем симлинк
if [ -d "$HOME/.oh-my-zsh" ]; then
  echo "📂 Перемещаем .oh-my-zsh в $BASE_DIR..."
  mv "$HOME/.oh-my-zsh" "$BASE_DIR/ohmyzsh"
  ln -s "$BASE_DIR/ohmyzsh" "$HOME/.oh-my-zsh"
else
  echo "❌ Не удалось найти .oh-my-zsh после установки."
  exit 1
fi

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

# 🗑️ Удаляем временную папку init-shell
echo "🗑️ Удаляем временную папку init-shell..."
cd ~
rm -rf init-shell
echo "✅ init-shell удалён."

echo "🎉 Установка завершена успешно!"
