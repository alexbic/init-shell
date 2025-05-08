#!/bin/bash

# Безопасный режим + ловушка ошибок
set -euo pipefail
trap 'echo -e "\033[31m🚨 Произошла ошибка в строке $LINENO. Завершаем.\033[0m"' ERR

# 🔐 Защита от запуска от root
if [[ "$EUID" -eq 0 ]]; then
  echo -e "\033[31m❌ Не запускайте скрипт от root. Используйте обычного пользователя с sudo.\033[0m"
  exit 1
fi

# 🧪 Проверка подключения к интернету
if ! ping -c 1 1.1.1.1 &>/dev/null; then
  echo -e "\033[31m❌ Нет подключения к интернету. Проверьте сеть.\033[0m"
  exit 1
fi

# 🧪 Проверка доступности GitHub
if ! curl -s -o /dev/null -I -L --fail https://github.com; then
  echo -e "\033[31m❌ GitHub недоступен. Проверьте подключение к сети или VPN.\033[0m"
  exit 1
fi

# Пути
HOME_DIR="$(cd "$HOME" && pwd)"
CURRENT_DIR="$(pwd -P)"

if [[ "$CURRENT_DIR" != "$HOME_DIR" ]]; then
  echo -e "\033[31m❌ Скрипт должен быть запущен из домашней директории: $HOME_DIR\033[0m"
  echo "📍 Сейчас вы находитесь здесь: $CURRENT_DIR"
  exit 1
fi

BASE_DIR="$HOME/.myshell"
BACKUP_DIR="$BASE_DIR/backup"
TIMESTAMP=$(date +"%Y-%m-%d_%H-%M-%S")
TMP_BACKUP_DIR="/tmp/myshell_backup_$TIMESTAMP"
ARCHIVE_NAME="backup_$TIMESTAMP.tar.gz"

GIT_DOTFILES_REPO="https://github.com/alexbic/.dotfiles.git"
GIT_TMUX_REPO="https://github.com/gpakosz/.tmux.git"
GIT_OMZ_INSTALL_URL="https://raw.githubusercontent.com/ohmyzsh/ohmyzsh/master/tools/install.sh"

# 📦 Обновление и установка зависимостей (только если их нет)
echo -e "\033[34m📦 Проверка и установка необходимых пакетов...\033[0m"
NEEDED_PACKAGES=()
for pkg in git curl zsh; do
  if ! dpkg -s "$pkg" &>/dev/null; then
    NEEDED_PACKAGES+=("$pkg")
  fi
done
if [[ ${#NEEDED_PACKAGES[@]} -gt 0 ]]; then
  echo "📦 Устанавливаем: ${NEEDED_PACKAGES[*]}"
  sudo apt update
  sudo apt install -y "${NEEDED_PACKAGES[@]}"
else
  echo "✅ Все необходимые пакеты уже установлены."
fi

# 📁 Подготовка резервной копии
mkdir -p "$TMP_BACKUP_DIR"

if [[ -d "$BASE_DIR" ]]; then
  echo "🗂 Обнаружена предыдущая установка. Делаем резервную копию..."
  mkdir -p "$BACKUP_DIR"

#  find "$BASE_DIR" -mindepth 1 -not -path "$BASE_DIR/backup" -exec mv -t "$TMP_BACKUP_DIR" {} + || true

  echo "📦 Копируем содержимое $BASE_DIR в $TMP_BACKUP_DIR (без каталога backup)..."
  rsync -a --exclude 'backup' "$BASE_DIR/" "$TMP_BACKUP_DIR/"

  echo "♻️ Очищаем старую установку (кроме backup)..."
  find "$BASE_DIR" -mindepth 1 -not -path "$BASE_DIR/backup" -exec rm -rf {} + || true

else
  echo "📁 Создаём структуру $BASE_DIR..."
  mkdir -p "$BASE_DIR" "$BACKUP_DIR"
  echo "📦 Переносим старые настройки..."
  for file in .zshrc .tmux.conf .tmux.conf.local; do
    if [[ -e "$HOME/$file" ]]; then
      mv "$HOME/$file" "$TMP_BACKUP_DIR/" 2>/dev/null || true
    fi
  done
  if [[ -d "$HOME/.oh-my-zsh" ]]; then
    cp -a "$HOME/.oh-my-zsh" "$TMP_BACKUP_DIR/" || true
  fi
fi

# 📦 Архивируем
echo -e "\033[34m📦 Архивируем в $ARCHIVE_NAME...\033[0m"
tar -czf "$BACKUP_DIR/$ARCHIVE_NAME" -C "$TMP_BACKUP_DIR" .
rm -rf "$TMP_BACKUP_DIR"

# 🧹 Чистим окружение
echo -e "\033[33m🧹 Удаляем старые конфиги и симлинки...\033[0m"
for file in .zsh* .tmux*; do
  if [[ -e "$HOME/$file" ]]; then
    if [[ -d "$HOME/$file" ]]; then
      rm -rf "$HOME/$file"  # Добавляем -rf для удаления каталогов
    else
      rm -f "$HOME/$file"
    fi
  fi
done

# 📥 Клонируем dotfiles
echo -e "\033[34m📥 Клонируем dotfiles...\033[0m"
git clone "$GIT_DOTFILES_REPO" "$BASE_DIR/dotfiles" || {
  echo -e "\033[31m❌ Ошибка при клонировании dotfiles.\033[0m"
  exit 1
}

# 📥 Клонируем tmux
echo -e "\033[34m📥 Клонируем tmux конфигурацию...\033[0m"
git clone "$GIT_TMUX_REPO" "$BASE_DIR/tmux" || {
  echo -e "\033[31m❌ Ошибка при клонировании tmux.\033[0m"
  exit 1
}

# ♻️ Удаляем старый Oh-My-Zsh
# Проверяем, что .oh-my-zsh существует, и действуем в зависимости от типа
if [[ -e "$HOME/.oh-my-zsh" || -L "$HOME/.oh-my-zsh" ]]; then
  if [[ -L "$HOME/.oh-my-zsh" ]]; then
    # Это символическая ссылка — удаляем её
    echo "♻️ Удаляем символическую ссылку .oh-my-zsh..."
    rm "$HOME/.oh-my-zsh"
    echo "✅ Символическая ссылка .oh-my-zsh успешно удалена."
  elif [[ -d "$HOME/.oh-my-zsh" ]]; then
    # Это каталог — удаляем рекурсивно
    echo "♻️ Удаляем каталог .oh-my-zsh..."
    rm -r "$HOME/.oh-my-zsh"
    echo "✅ Каталог .oh-my-zsh успешно удалён."
  else
    echo "🛠 .oh-my-zsh не является ни каталогом, ни символической ссылкой."
  fi
else
  echo "🛠 .oh-my-zsh не существует, ничего удалять не нужно."
fi

# 📥 Установка нового Oh-My-Zsh
echo -e "\033[34m📥 Устанавливаем Oh-My-Zsh...\033[0m"
RUNZSH=no KEEP_ZSHRC=yes sh -c "$(curl -fsSL "$GIT_OMZ_INSTALL_URL")"

# Проверка установки
if [[ ! -d "$HOME/.oh-my-zsh" ]]; then
  echo -e "\033[31m❌ Ошибка: Oh-My-Zsh не установлен.\033[0m"
  exit 1
fi

# 🔁 Перемещение Oh-My-Zsh в BASE_DIR
echo "🔁 Перемещаем Oh-My-Zsh в $BASE_DIR..."
mv "$HOME/.oh-my-zsh" "$BASE_DIR/ohmyzsh"
ln -s "$BASE_DIR/ohmyzsh" "$HOME/.oh-my-zsh"

# 🛠️ Обновляем владельца BASE_DIR
sudo chown -R "$USER":"$USER" "$BASE_DIR"

# ⚙️ Настройка Zsh
ln -sf "$BASE_DIR/dotfiles/.zshrc" "$HOME/.zshrc"

# 📦 Плагины Zsh
echo "📦 Устанавливаем плагины..."
git clone https://github.com/zsh-users/zsh-autosuggestions "$BASE_DIR/ohmyzsh/custom/plugins/zsh-autosuggestions" || true
git clone https://github.com/zsh-users/zsh-syntax-highlighting "$BASE_DIR/ohmyzsh/custom/plugins/zsh-syntax-highlighting" || true

# ⚙️ Настройка tmux
echo "⚙️ Настраиваем tmux..."
ln -sf "$BASE_DIR/tmux/.tmux.conf" "$HOME/.tmux.conf"
ln -sf "$BASE_DIR/dotfiles/.tmux.conf.local" "$HOME/.tmux.conf.local"

# 🧰 Проверка и установка ZShell по умолчанию
if [[ "$(basename "$SHELL")" != "zsh" ]]; then
  echo "🔧 Устанавливаем ZShell по умолчанию..."
  chsh -s "$(which zsh)"
else
  echo "✅ ZShell уже установлен по умолчанию."
fi

# 🗑️ Очистка временной директории
rm -rf "$HOME/init-shell" || true

# ✅ Завершено
echo -e "\033[32m🎉 Установка завершена успешно!\033[0m"
