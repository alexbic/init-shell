#!/bin/bash

#----------------------------------------------------
# ⚙️ Переменные
#----------------------------------------------------

# 🎨 Цвета
RESET='\033[0m'
RED='\033[31m'
GREEN='\033[32m'
YELLOW='\033[33m'
BLUE='\033[34m'
CYAN='\033[36m'

HOME_DIR="$(cd "$HOME" && pwd)"
CURRENT_DIR="$(pwd -P)"

BASE_DIR="$HOME/.myshell"
BACKUP_DIR="$BASE_DIR/backup"

VIM_DIR="$HOME/.myshell/vim"
VIM_COLORS_DIR="$VIM_DIR/colors"
VIM_PLUGINS_DIR="$VIM_DIR/plugins"

TIMESTAMP=$(date +"%Y-%m-%d_%H-%M-%S")
TMP_BACKUP_DIR="/tmp/myshell_backup_$TIMESTAMP"
ARCHIVE_NAME="backup_$TIMESTAMP.tar.gz"
PACKAGES="git curl zsh vim"
TRASH=".zsh* .tmux* .vim* .oh-my-zsh*"

GIT_DOTFILES_REPO="https://github.com/alexbic/dotfiles.git"
GIT_TMUX_REPO="https://github.com/gpakosz/.tmux.git"
GIT_OMZ_INSTALL_URL="https://raw.githubusercontent.com/ohmyzsh/ohmyzsh/master/tools/install.sh"

#----------------------------------------------------
# 🛡️ Предварительные проверки
#----------------------------------------------------

# Безопасный режим + ловушка ошибок
set -euo pipefail
trap 'echo -e "${RED}🚨 Произошла ошибка в строке $LINENO. Завершаем.${RESET}"' ERR

# 🔐 Защита от запуска от root
if [[ "$EUID" -eq 0 ]]; then
  echo -e "${RED}❌ Не запускайте скрипт от root. Используйте обычного пользователя с sudo.${RESET}"
  exit 1
fi

# 🧪 Проверка подключения к интернету
if ! ping -c 1 1.1.1.1 &>/dev/null; then
  echo -e "${RED}❌ Нет подключения к интернету. Проверьте сеть.${RESET}"
  exit 1
fi

# 🧪 Проверка доступности GitHub
if ! curl -s -o /dev/null -I -L --fail https://github.com; then
  echo -e "${RED}❌ GitHub недоступен. Проверьте подключение к сети или VPN.${RESET}"
  exit 1
fi

# 🧪 Проверка каталога запуска
if [[ "$CURRENT_DIR" != "$HOME_DIR" ]]; then
  echo -e "${RED}❌ Скрипт должен быть запущен из домашней директории: $HOME_DIR${RESET}"
  echo "📍 Сейчас вы находитесь здесь: $CURRENT_DIR"
  exit 1
fi


#----------------------------------------------------
# 📦 Обновление и установка зависимостей
#----------------------------------------------------

echo -e "${BLUE}📦 Проверка и установка необходимых пакетов...${RESET}"

NEEDED_PACKAGES=()
for pkg in $PACKAGES; do
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

#----------------------------------------------------
# 🗄️ Сохраняем настройки текущего окружения
#----------------------------------------------------

mkdir -p "$TMP_BACKUP_DIR"

if [[ -d "$BASE_DIR" ]]; then
  echo "🗂 Обнаружена предыдущая установка. Делаем резервную копию..."
  mkdir -p "$BACKUP_DIR"
  rsync -a --exclude 'backup/' "$BASE_DIR/" "$TMP_BACKUP_DIR/"
  find "$BASE_DIR" -mindepth 1 ! -path "$BACKUP_DIR" ! -path "$BACKUP_DIR/*" -print0 | xargs -0 rm -rf
else
  echo "📁 Создаём структуру $BASE_DIR..."
  mkdir -p "$BASE_DIR" "$BACKUP_DIR"
  echo "📦 Переносим старые настройки..."
  for file in .zshrc .tmux.conf .tmux.conf.local; do
    [[ -e "$HOME/$file" ]] && mv "$HOME/$file" "$TMP_BACKUP_DIR/" || true
  done
  [[ -d "$HOME/.oh-my-zsh" ]] && cp -a "$HOME/.oh-my-zsh" "$TMP_BACKUP_DIR/" || true
fi

echo -e "${BLUE}📦 Архивируем в $ARCHIVE_NAME...${RESET}"
tar -czf "$BACKUP_DIR/$ARCHIVE_NAME" -C "$TMP_BACKUP_DIR" .
rm -rf "$TMP_BACKUP_DIR"

#----------------------------------------------------
# 🧹 Чистим окружение
#----------------------------------------------------

[[ -d "$HOME/.oh-my-zsh" ]] && {
  echo "♻️ Деинсталляция Oh-My-Zsh..."
  export UNATTENDED=true
  chmod +x "$HOME/.oh-my-zsh/tools/uninstall.sh" 2>/dev/null || true
  "$HOME/.oh-my-zsh/tools/uninstall.sh" || echo "⚠️ Ошибка при деинсталляции, продолжаем..."
}

# Удаление старых конфигов и симлинков
echo -e "${YELLOW}🧹 Удаляем старые конфиги и симлинки...${RESET}"

for item in $TRASH; do
  TARGET="$HOME/$item"
  if [[ -L $TARGET ]]; then
    echo -e "🔗 Удаляем симлинк: ${CYAN}$TARGET${RESET}"
    rm "$TARGET"
  elif [[ -f $TARGET ]]; then
    echo -e "📄 Удаляем файл: ${CYAN}$TARGET${RESET}"
    rm "$TARGET"
  elif [[ -d $TARGET ]]; then
    echo -e "📁 Удаляем директорию: ${CYAN}$TARGET${RESET}"
    rm -rf "$TARGET"
  else
    echo -e "ℹ️  Пропускаем: ${CYAN}$TARGET${RESET} (не найден)"
  fi
done

echo -e "${GREEN}✅ Очистка завершена.${RESET}"

#----------------------------------------------------
# 📥 Клонируем окружение
#----------------------------------------------------

echo -e "${BLUE}📥 Клонируем tmux конфигурацию...${RESET}"
git clone "$GIT_TMUX_REPO" "$BASE_DIR/tmux"

echo -e "${BLUE}📥 Клонируем dotfiles...${RESET}"
git clone "$GIT_DOTFILES_REPO" "$BASE_DIR/dotfiles"

mkdir -p "$VIM_COLORS_DIR" "$VIM_PLUGINS_DIR"

if [[ ! -d "$VIM_COLORS_DIR/papercolor-theme" ]]; then
  echo "${BLUE}📥 Клонируем PaperColor тему...${RESET}"
  git clone "https://github.com/NLKNguyen/papercolor-theme.git" "$VIM_COLORS_DIR/papercolor-theme"
else
  echo "✅ PaperColor уже добавлен"
fi
ln -sf "$VIM_COLORS_DIR/papercolor-theme/colors/PaperColor.vim" "$VIM_COLORS_DIR/PaperColor.vim"

echo -e "${BLUE}📥 Устанавливаем Oh-My-Zsh...${RESET}"
RUNZSH=no KEEP_ZSHRC=yes sh -c "$(curl -fsSL "$GIT_OMZ_INSTALL_URL")"

[[ ! -d "$HOME/.oh-my-zsh" ]] && {
  echo -e "${RED}❌ Ошибка: Oh-My-Zsh не установлен.${RESET}"
  exit 1
}

echo "📦 Устанавливаем плагины для Zsh..."
mkdir -p "$BASE_DIR/ohmyzsh/custom/plugins"
git clone https://github.com/zsh-users/zsh-autosuggestions "$BASE_DIR/ohmyzsh/custom/plugins/zsh-autosuggestions"
git clone https://github.com/zsh-users/zsh-syntax-highlighting "$BASE_DIR/ohmyzsh/custom/plugins/zsh-syntax-highlighting"

#----------------------------------------------------
# ⚙️ Настройки окружения
#----------------------------------------------------
echo "🛠️ Обновляем владельца BASE_DIR"
sudo chown -R "$USER":"$USER" "$BASE_DIR"

echo "⚙️ Настраиваем zsh..."
ln -sf "$BASE_DIR/dotfiles/.zshrc" "$HOME/.zshrc"

echo "⚙️ Настраиваем vim..."
ln -sf "$BASE_DIR/dotfiles/.vimrc" "$HOME/.vimrc"
ln -sfn "$VIM_DIR" "$HOME/.vim"

echo "⚙️ Настраиваем tmux..."
ln -sf "$BASE_DIR/tmux/.tmux.conf" "$HOME/.tmux.conf"
ln -sf "$BASE_DIR/dotfiles/.tmux.conf.local" "$HOME/.tmux.conf.local"

echo "🔁 Перемещаем Oh-My-Zsh в $BASE_DIR..."
mkdir -p "$BASE_DIR/ohmyzsh"
rsync -a --remove-source-files "$HOME/.oh-my-zsh/" "$BASE_DIR/ohmyzsh/"
rm -rf "$HOME/.oh-my-zsh"
ln -sfn "$BASE_DIR/ohmyzsh/.tmux.conf.local" "$HOME/.oh-my-zsh"

#----------------------------------------------------
# 🧰 Проверка и установка ZShell по умолчанию
#----------------------------------------------------
if [[ "$(basename "$SHELL")" != "zsh" ]]; then
  echo "🔁 Меняем shell на Zsh..."
  chsh -s "$(which zsh)"
else
  echo "✅ Zsh уже установлен как shell по умолчанию."
fi

#----------------------------------------------------
# 🗑️ Очистка временной директории
#----------------------------------------------------
rm -rf "$HOME/init-shell" || true

#----------------------------------------------------
# ✅ Завершено
#----------------------------------------------------
echo -e "${GREEN}🎉 Установка завершена успешно!${RESET}"
