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

# 🧪 Проверка доступа sudo
echo -e "${BLUE}🔐 Проверка прав sudo...${RESET}"
if ! sudo -n true 2>/dev/null; then
  echo -e "${YELLOW}⚠️ Для продолжения требуются права sudo.${RESET}"
  sudo -v || {
    echo -e "${RED}❌ Не удалось получить права sudo. Проверьте, есть ли у вас такие права.${RESET}"
    exit 1
  }
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

mkdir -p "$TMP_BACKUP_DIR" || {
  echo -e "${YELLOW}⚠️ Не удалось создать временную директорию. Пробуем с sudo...${RESET}"
  sudo mkdir -p "$TMP_BACKUP_DIR"
  # TMP_BACKUP_DIR находится вне $BASE_DIR, поэтому нужен chown
  sudo chown "$USER":"$USER" "$TMP_BACKUP_DIR"
}

if [[ -d "$BASE_DIR" ]]; then
  echo "🗂 Обнаружена предыдущая установка. Делаем резервную копию..."
  mkdir -p "$BACKUP_DIR" || {
    echo -e "${YELLOW}⚠️ Не удалось создать директорию для резервных копий. Пробуем с sudo...${RESET}"
    sudo mkdir -p "$BACKUP_DIR"
    # Права назначаются централизованно в конце скрипта
  }
  rsync -a --exclude 'backup/' "$BASE_DIR/" "$TMP_BACKUP_DIR/" || {
    echo -e "${YELLOW}⚠️ Ошибка при копировании. Проверяем права доступа...${RESET}"
    sudo rsync -a --exclude 'backup/' "$BASE_DIR/" "$TMP_BACKUP_DIR/"
    # TMP_BACKUP_DIR находится вне $BASE_DIR, поэтому нужен chown
    sudo chown -R "$USER":"$USER" "$TMP_BACKUP_DIR/"
  }
  
  # Удаляем старый контент с проверкой прав
  if find "$BASE_DIR" -mindepth 1 ! -path "$BACKUP_DIR" ! -path "$BACKUP_DIR/*" -print0 | xargs -0 rm -rf 2>/dev/null; then
    echo "✅ Старый контент удален"
  else
    echo -e "${YELLOW}⚠️ Не удалось удалить старый контент. Пробуем с sudo...${RESET}"
    sudo find "$BASE_DIR" -mindepth 1 ! -path "$BACKUP_DIR" ! -path "$BACKUP_DIR/*" -print0 | xargs -0 sudo rm -rf
  fi
else
  echo "📁 Создаём структуру $BASE_DIR..."
  mkdir -p "$BASE_DIR" "$BACKUP_DIR" || {
    echo -e "${YELLOW}⚠️ Не удалось создать директории. Пробуем с sudo...${RESET}"
    sudo mkdir -p "$BASE_DIR" "$BACKUP_DIR"
    # Права назначаются централизованно в конце скрипта
  }
  echo "📦 Переносим старые настройки..."
  for file in .zshrc .tmux.conf .tmux.conf.local; do
    [[ -e "$HOME/$file" ]] && mv "$HOME/$file" "$TMP_BACKUP_DIR/" || true
  done
  if [[ -d "$HOME/.oh-my-zsh" ]]; then 
    cp -a "$HOME/.oh-my-zsh" "$TMP_BACKUP_DIR/" || {
      echo -e "${YELLOW}⚠️ Ошибка при копировании .oh-my-zsh. Пробуем с sudo...${RESET}"
      sudo cp -a "$HOME/.oh-my-zsh" "$TMP_BACKUP_DIR/"
      # TMP_BACKUP_DIR находится вне $BASE_DIR, поэтому нужен chown
      sudo chown -R "$USER":"$USER" "$TMP_BACKUP_DIR/.oh-my-zsh"
    }
  fi
fi

echo -e "${BLUE}📦 Архивируем в $ARCHIVE_NAME...${RESET}"
tar -czf "$BACKUP_DIR/$ARCHIVE_NAME" -C "$TMP_BACKUP_DIR" . || {
  echo -e "${YELLOW}⚠️ Ошибка при создании архива. Пробуем с sudo...${RESET}"
  sudo tar -czf "$BACKUP_DIR/$ARCHIVE_NAME" -C "$TMP_BACKUP_DIR" .
  # TMP_BACKUP_DIR/ARCHIVE_NAME находится вне $BASE_DIR до перемещения
  sudo chown "$USER":"$USER" "$BACKUP_DIR/$ARCHIVE_NAME"
}
rm -rf "$TMP_BACKUP_DIR" || sudo rm -rf "$TMP_BACKUP_DIR"

#----------------------------------------------------
# 🧹 Чистим окружение
#----------------------------------------------------

[[ -d "$HOME/.oh-my-zsh" ]] && {
  echo "♻️ Деинсталляция Oh-My-Zsh..."
  export UNATTENDED=true
  if [[ -x "$HOME/.oh-my-zsh/tools/uninstall.sh" ]]; then
    "$HOME/.oh-my-zsh/tools/uninstall.sh" || echo "⚠️ Ошибка при деинсталляции, продолжаем..."
  else 
    chmod +x "$HOME/.oh-my-zsh/tools/uninstall.sh" 2>/dev/null || sudo chmod +x "$HOME/.oh-my-zsh/tools/uninstall.sh" 2>/dev/null 
    "$HOME/.oh-my-zsh/tools/uninstall.sh" || echo "⚠️ Ошибка при деинсталляции, продолжаем..."
  fi
}

# Удаление старых конфигов и симлинков
echo -e "${YELLOW}🧹 Удаляем старые конфиги и симлинки...${RESET}"

for item in $TRASH; do
  TARGET="$HOME/$item"
  if [[ -L $TARGET ]]; then
    echo -e "🔗 Удаляем симлинк: ${CYAN}$TARGET${RESET}"
    rm "$TARGET" 2>/dev/null || sudo rm "$TARGET"
  elif [[ -f $TARGET ]]; then
    echo -e "📄 Удаляем файл: ${CYAN}$TARGET${RESET}"
    rm "$TARGET" 2>/dev/null || sudo rm "$TARGET"
  elif [[ -d $TARGET ]]; then
    echo -e "📁 Удаляем директорию: ${CYAN}$TARGET${RESET}"
    rm -rf "$TARGET" 2>/dev/null || sudo rm -rf "$TARGET"
  else
    echo -e "ℹ️  Пропускаем: ${CYAN}$TARGET${RESET} (не найден)"
  fi
done

echo -e "${GREEN}✅ Очистка завершена.${RESET}"

#----------------------------------------------------
# 📥 Клонируем окружение
#----------------------------------------------------

echo -e "${BLUE}📥 Клонируем tmux конфигурацию...${RESET}"
git clone "$GIT_TMUX_REPO" "$BASE_DIR/tmux" || {
  echo -e "${YELLOW}⚠️ Ошибка при клонировании tmux. Проверяем права доступа...${RESET}"
  sudo git clone "$GIT_TMUX_REPO" "$BASE_DIR/tmux"
  # Права назначаются централизованно в конце скрипта
}

echo -e "${BLUE}📥 Клонируем dotfiles...${RESET}"
git clone "$GIT_DOTFILES_REPO" "$BASE_DIR/dotfiles" || {
  echo -e "${YELLOW}⚠️ Ошибка при клонировании dotfiles. Проверяем права доступа...${RESET}"
  sudo git clone "$GIT_DOTFILES_REPO" "$BASE_DIR/dotfiles"
  # Права назначаются централизованно в конце скрипта
}

mkdir -p "$VIM_COLORS_DIR" "$VIM_PLUGINS_DIR" || {
  echo -e "${YELLOW}⚠️ Не удалось создать директории для vim. Пробуем с sudo...${RESET}"
  sudo mkdir -p "$VIM_COLORS_DIR" "$VIM_PLUGINS_DIR"
  # Права назначаются централизованно в конце скрипта
}

if [[ ! -d "$VIM_COLORS_DIR/papercolor-theme" ]]; then
  echo "${BLUE}📥 Клонируем PaperColor тему...${RESET}"
  git clone "https://github.com/NLKNguyen/papercolor-theme.git" "$VIM_COLORS_DIR/papercolor-theme" || {
    echo -e "${YELLOW}⚠️ Ошибка при клонировании темы. Проверяем права доступа...${RESET}"
    sudo git clone "https://github.com/NLKNguyen/papercolor-theme.git" "$VIM_COLORS_DIR/papercolor-theme"
    # Права назначаются централизованно в конце скрипта
  }
else
  echo "✅ PaperColor уже добавлен"
fi

ln -sf "$VIM_COLORS_DIR/papercolor-theme/colors/PaperColor.vim" "$VIM_COLORS_DIR/PaperColor.vim" || {
  echo -e "${YELLOW}⚠️ Не удалось создать символическую ссылку. Пробуем с sudo...${RESET}"
  sudo ln -sf "$VIM_COLORS_DIR/papercolor-theme/colors/PaperColor.vim" "$VIM_COLORS_DIR/PaperColor.vim"
}

echo -e "${BLUE}📥 Устанавливаем Oh-My-Zsh...${RESET}"
RUNZSH=no KEEP_ZSHRC=yes sh -c "$(curl -fsSL "$GIT_OMZ_INSTALL_URL")"

[[ ! -d "$HOME/.oh-my-zsh" ]] && {
  echo -e "${RED}❌ Ошибка: Oh-My-Zsh не установлен.${RESET}"
  exit 1
}

echo "📦 Устанавливаем плагины для Zsh..."
mkdir -p "$BASE_DIR/ohmyzsh/custom/plugins" || {
  echo -e "${YELLOW}⚠️ Не удалось создать директорию для плагинов. Пробуем с sudo...${RESET}"
  sudo mkdir -p "$BASE_DIR/ohmyzsh/custom/plugins"
  # Права назначаются централизованно в конце скрипта
}

git clone https://github.com/zsh-users/zsh-autosuggestions "$BASE_DIR/ohmyzsh/custom/plugins/zsh-autosuggestions" || {
  echo -e "${YELLOW}⚠️ Ошибка при клонировании плагина. Проверяем права доступа...${RESET}"
  sudo git clone https://github.com/zsh-users/zsh-autosuggestions "$BASE_DIR/ohmyzsh/custom/plugins/zsh-autosuggestions"
  # Права назначаются централизованно в конце скрипта
}

git clone https://github.com/zsh-users/zsh-syntax-highlighting "$BASE_DIR/ohmyzsh/custom/plugins/zsh-syntax-highlighting" || {
  echo -e "${YELLOW}⚠️ Ошибка при клонировании плагина. Проверяем права доступа...${RESET}"
  sudo git clone https://github.com/zsh-users/zsh-syntax-highlighting "$BASE_DIR/ohmyzsh/custom/plugins/zsh-syntax-highlighting"
  # Права назначаются централизованно в конце скрипта
}

#----------------------------------------------------
# ⚙️ Настройки окружения
#----------------------------------------------------
echo "🛠️ Обновляем владельца BASE_DIR"
sudo chown -R "$USER":"$USER" "$BASE_DIR"

echo "⚙️ Настраиваем zsh..."
ln -sf "$BASE_DIR/dotfiles/.zshrc" "$HOME/.zshrc" || {
  echo -e "${YELLOW}⚠️ Не удалось создать символическую ссылку. Пробуем с sudo...${RESET}"
  sudo ln -sf "$BASE_DIR/dotfiles/.zshrc" "$HOME/.zshrc"
  # Симлинк вне $BASE_DIR, но chown не нужен для симлинков
}

echo "⚙️ Настраиваем vim..."
ln -sf "$BASE_DIR/dotfiles/.vimrc" "$HOME/.vimrc" || sudo ln -sf "$BASE_DIR/dotfiles/.vimrc" "$HOME/.vimrc"
ln -sfn "$VIM_DIR" "$HOME/.vim" || sudo ln -sfn "$VIM_DIR" "$HOME/.vim"

echo "⚙️ Настраиваем tmux..."
ln -sf "$BASE_DIR/tmux/.tmux.conf" "$HOME/.tmux.conf" || sudo ln -sf "$BASE_DIR/tmux/.tmux.conf" "$HOME/.tmux.conf"
ln -sf "$BASE_DIR/dotfiles/.tmux.conf.local" "$HOME/.tmux.conf.local" || sudo ln -sf "$BASE_DIR/dotfiles/.tmux.conf.local" "$HOME/.tmux.conf.local"

echo "🔁 Перемещаем Oh-My-Zsh в $BASE_DIR..."
mkdir -p "$BASE_DIR/ohmyzsh" || sudo mkdir -p "$BASE_DIR/ohmyzsh"

# Проверяем права на rsync
if ! rsync -a --remove-source-files "$HOME/.oh-my-zsh/" "$BASE_DIR/ohmyzsh/" 2>/dev/null; then
  echo -e "${YELLOW}⚠️ Проблемы с правами при rsync. Используем sudo...${RESET}"
  sudo rsync -a --remove-source-files "$HOME/.oh-my-zsh/" "$BASE_DIR/ohmyzsh/"
  # Права назначаются централизованно в конце скрипта
fi

# Удаляем директорию с проверкой прав
rm -rf "$HOME/.oh-my-zsh" 2>/dev/null || sudo rm -rf "$HOME/.oh-my-zsh"

# Создаем символическую ссылку с проверкой прав
ln -sfn "$BASE_DIR/ohmyzsh/" "$HOME/.oh-my-zsh" || {
  echo -e "${YELLOW}⚠️ Не удалось создать символическую ссылку. Пробуем с sudo...${RESET}"
  sudo ln -sfn "$BASE_DIR/ohmyzsh/" "$HOME/.oh-my-zsh"
  sudo chown -h "$USER":"$USER" "$HOME/.oh-my-zsh"
}

#----------------------------------------------------
# 🧰 Проверка и установка ZShell по умолчанию
#----------------------------------------------------
if [[ "$(basename "$SHELL")" != "zsh" ]]; then
  echo "🔁 Меняем shell на Zsh..."
  ZSH_PATH=$(which zsh)
  # Проверяем, есть ли уже zsh в /etc/shells
  if ! grep -q "$ZSH_PATH" /etc/shells; then
    echo -e "${YELLOW}⚠️ Добавляем $ZSH_PATH в /etc/shells...${RESET}"
    echo "$ZSH_PATH" | sudo tee -a /etc/shells > /dev/null
  fi
  
  # Меняем оболочку по умолчанию с проверкой
  if ! chsh -s "$ZSH_PATH" 2>/dev/null; then
    echo -e "${YELLOW}⚠️ Не удалось изменить оболочку. Пробуем с sudo...${RESET}"
    sudo chsh -s "$ZSH_PATH" "$USER"
  fi
else
  echo "✅ Zsh уже установлен как shell по умолчанию."
fi

#----------------------------------------------------
# 🗑️ Очистка временной директории
#----------------------------------------------------
rm -rf "$HOME/init-shell" 2>/dev/null || sudo rm -rf "$HOME/init-shell"

#----------------------------------------------------
# ✅ Завершено
#----------------------------------------------------
echo -e "${GREEN}🎉 Установка завершена успешно!${RESET}"
