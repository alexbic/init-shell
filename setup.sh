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
GRAY='\033[90m'

# 🎲 Базовые директории
HOME_DIR="$(cd "$HOME" && pwd)"
CURRENT_DIR="$(pwd -P)"
BASE_DIR="$HOME/.myshell"

# 🗄️ Бэкап и архивирование
TIMESTAMP=$(date +"%Y-%m-%d_%H-%M-%S")
BACKUP_DIR="$BASE_DIR/backup"
DATED_BACKUP_DIR="$BACKUP_DIR/backup_$TIMESTAMP"

# 🧹 Шаблоны файлов для очистки
TRASH=".zsh* .tmux* .vim* .oh-my-zsh*"

# 📂 Директории для компонентов
VIM_DIR="$BASE_DIR/vim"
VIM_COLORS_DIR="$VIM_DIR/colors"
VIM_PLUGINS_DIR="$VIM_DIR/plugins"

# 🧩 Пакеты для установки
PACKAGES="git curl zsh vim"

# 🔗 Git-репозитории
GIT_DOTFILES_REPO="https://github.com/alexbic/dotfiles.git"
GIT_TMUX_REPO="https://github.com/gpakosz/.tmux.git"
GIT_OMZ_REPO="https://github.com/ohmyzsh/ohmyzsh.git"
GIT_OMZ_INSTALL_URL="https://raw.githubusercontent.com/ohmyzsh/ohmyzsh/master/tools/install.sh"

# 🔗 Git-репозитории плагинов
GIT_ZSH_AUTOSUGGESTIONS_REPO="https://github.com/zsh-users/zsh-autosuggestions"
GIT_ZSH_SYNTAX_HIGHLIGHTING_REPO="https://github.com/zsh-users/zsh-syntax-highlighting"
GIT_VIM_PAPERCOLOR_REPO="https://github.com/NLKNguyen/papercolor-theme.git"

# 🔣 Версия скрипта
SCRIPT_VERSION="1.0.1"

# Инициализация переменных для интерактивного режима
ACTION=""
SAVE_EXISTING=""

#----------------------------------------------------
# 🛡️ Обработка прерывания (Ctrl+C)
#----------------------------------------------------

# Функция для очистки при прерывании
cleanup_on_interrupt() {
  echo -e "\n${YELLOW}⚠️  Получен сигнал прерывания. Выполняем очистку...${RESET}"
  
  # Проверяем наличие временной директории init-shell и удаляем её
  if [[ -d "$HOME/init-shell" ]]; then
    echo -e "${BLUE}🗑️  Удаляем временную директорию $HOME/init-shell...${RESET}"
    rm -rf "$HOME/init-shell" 2>/dev/null || sudo rm -rf "$HOME/init-shell"
  fi
  
  echo -e "${GREEN}👋 Скрипт прерван. До свидания!${RESET}"
  exit 1
}

# Устанавливаем ловушку для сигнала прерывания
trap cleanup_on_interrupt SIGINT

#----------------------------------------------------
# 🎨 Функции для интерактивного интерфейса
#----------------------------------------------------

# Функция для отображения ASCII-логотипа в цветах российского флага
show_logo() {
  # Цвета российского флага
  WHITE='\033[97m'
  RU_BLUE='\033[34m'
  RU_RED='\033[31m'
  
  # Рисуем логотип в цветах российского флага
  echo -e "${WHITE}"
  echo "  __  ____  _______ __  __________    __"
  echo -e "${RU_BLUE} /  |/  / |/ / ___// / / / ____/ /   / /"
  echo -e " / /|_/ /|   /\\__ \\/ /_/ / __/ / /   / /"
  echo -e "${RU_RED}/ /  / //   /___/ / __  / /___/ /___/ /___"
  echo -e "/_/  /_//_/|_/____/_/ /_/_____/_____/_____/${RESET}"
  
  
  echo -e "${BLUE}💡 Development Environment for ${CYAN}AlexBic.net${RESET} Projects"
  echo -e "${BLUE}📦 Version: ${YELLOW}$SCRIPT_VERSION${RESET}"
  echo -e "${BLUE}🔗 https://github.com/alexbic/init-shell${RESET}\n"
}

# Функция для отображения информации о текущей конфигурации
show_config_info() {
  echo -e "\n${BLUE}🔍 Текущая конфигурация окружения:${RESET}\n"
  
  if [[ -d "$BASE_DIR" ]]; then
    echo -e "  ${GREEN}✅ Окружение ${CYAN}MYSHELL${GREEN} установлено${RESET}"
    
    local base_version=""
    if [[ -f "$BASE_DIR/version" ]]; then
      base_version=$(cat "$BASE_DIR/version")
      echo -e "  ${BLUE}ℹ️  Версия:${RESET} $base_version"
    else
      echo -e "  ${YELLOW}⚠️ Версия не определена${RESET}"
    fi
    
    local install_date=""
    if [[ -d "$BASE_DIR" ]]; then
      install_date=$(stat -c %y "$BASE_DIR" 2>/dev/null | cut -d' ' -f1)
      echo -e "  ${BLUE}📅 Дата установки:${RESET} $install_date"
    fi
    
    echo -e "\n  ${BLUE}📋 Компоненты:${RESET}"
    
    [[ -d "$BASE_DIR/ohmyzsh" ]] && 
      echo -e "  ${GREEN}✅ Oh-My-Zsh${RESET}" || 
      echo -e "  ${RED}❌ Oh-My-Zsh${RESET}"
      
    [[ -d "$BASE_DIR/tmux" ]] && 
      echo -e "  ${GREEN}✅ Tmux${RESET}" || 
      echo -e "  ${RED}❌ Tmux${RESET}"
      
    [[ -d "$BASE_DIR/vim" ]] && 
      echo -e "  ${GREEN}✅ Vim${RESET}" || 
      echo -e "  ${RED}❌ Vim${RESET}"
      
    [[ -d "$BASE_DIR/dotfiles" ]] && 
      echo -e "  ${GREEN}✅ Dotfiles${RESET}" || 
      echo -e "  ${RED}❌ Dotfiles${RESET}"
  else
    echo -e "  ${YELLOW}⚠️ Окружение ${CYAN}MYSHELL${YELLOW} не установлено${RESET}\n"
    
    echo -e "  ${BLUE}🔎 Обнаружены внешние конфигурации:${RESET}"
    
    [[ -f "$HOME/.zshrc" || -d "$HOME/.oh-my-zsh" ]] && 
      echo -e "  ${GREEN}✅ Zsh/Oh-My-Zsh${RESET}" || 
      echo -e "  ${GRAY}❌ Zsh/Oh-My-Zsh${RESET}"
      
    [[ -f "$HOME/.tmux.conf" ]] && 
      echo -e "  ${GREEN}✅ Tmux${RESET}" || 
      echo -e "  ${GRAY}❌ Tmux${RESET}"
      
    [[ -f "$HOME/.vimrc" || -d "$HOME/.vim" ]] && 
      echo -e "  ${GREEN}✅ Vim${RESET}" || 
      echo -e "  ${GRAY}❌ Vim${RESET}"
  fi
  
  echo ""
}

# Функция для отображения меню опций
show_menu() {
  local has_myshell=$([[ -d "$BASE_DIR" ]] && echo "true" || echo "false")
  local choice=""
  local confirm=""
  
  while true; do
    clear
    show_logo
    show_config_info
    
    echo -e "${BLUE}⚙️ Выберите действие:${RESET}\n"
    
    if [[ "$has_myshell" == "true" ]]; then
      echo -e "  ${CYAN}1)${RESET} 🔄 Обновить окружение ${CYAN}MYSHELL${RESET}"
      echo -e "  ${CYAN}2)${RESET} 🔁 Переустановить окружение ${CYAN}MYSHELL${RESET} (с сохранением текущих настроек)"
      echo -e "  ${CYAN}3)${RESET} 🆕 Полная переустановка окружения ${CYAN}MYSHELL${RESET} (без сохранения настроек)"
      echo -e "  ${CYAN}4)${RESET} 🧩 Добавить/обновить только плагины"
      echo -e "  ${CYAN}5)${RESET} 💾 Создать резервную копию настроек"
      echo -e "  ${CYAN}0)${RESET} 🚪 Выход без изменений\n"
    else
      echo -e "  ${CYAN}1)${RESET} 📥 Установить окружение ${CYAN}MYSHELL${RESET}"
      echo -e "  ${CYAN}2)${RESET} 🔐 Установить с сохранением текущих настроек"
      echo -e "  ${CYAN}0)${RESET} 🚪 Выход без изменений\n"
    fi
    
    read -p "🔢 Ваш выбор [0-$([ "$has_myshell" == "true" ] && echo "5" || echo "2")]: " choice
    
    # Проверяем выбор пользователя
    if [[ "$has_myshell" == "true" ]]; then
      case $choice in
        1) # Обновить окружение
          ACTION="update"
          SAVE_EXISTING="y"
          ;;
        2) # Переустановить с сохранением настроек
          ACTION="reinstall"
          SAVE_EXISTING="y"
          ;;
        3) # Полная переустановка
          ACTION="reinstall"
          SAVE_EXISTING="n"
          ;;
        4) # Добавить/обновить плагины
          ACTION="plugins"
          SAVE_EXISTING="y"
          ;;
        5) # Создать резервную копию
          ACTION="backup"
          SAVE_EXISTING="y"
          ;;
        0|q|Q|exit|quit) # Выход
          echo -e "\n${GREEN}👋 До свидания!${RESET}"
          exit 0
          ;;
        *) # Некорректный выбор
          echo -e "\n${RED}❌ Некорректный выбор. Пожалуйста, выберите действие из списка.${RESET}"
          read -p "⏳ Нажмите Enter, чтобы продолжить..." dummy
          continue
          ;;
      esac
    else
      case $choice in
        1) # Установить окружение
          ACTION="install"
          SAVE_EXISTING="n"
          ;;
        2) # Установить с сохранением текущих настроек
          ACTION="install"
          SAVE_EXISTING="y"
          ;;
        0|q|Q|exit|quit) # Выход
          echo -e "\n${GREEN}👋 До свидания!${RESET}"
          exit 0
          ;;
        *) # Некорректный выбор
          echo -e "\n${RED}❌ Некорректный выбор. Пожалуйста, выберите действие из списка.${RESET}"
          read -p "⏳ Нажмите Enter, чтобы продолжить..." dummy
          continue
          ;;
      esac
    fi
    
    # Подтверждение выбора
    echo -e "\n${GREEN}╭─── ${CYAN}$(get_action_description)${RESET}"
    echo -e "${GREEN}│${RESET}"
    echo -en "${GREEN}╰─── ▶  Продолжить? (y/n): ${RESET}"
    read confirm
    
    if [[ "$confirm" =~ ^[Yy]$ ]]; then
      clear
      echo -e "\n${GREEN}⏳ Начинаем выполнение...${RESET}\n"
      break
    else
      # Возвращаемся в меню
      echo -e "\n${YELLOW}⚠️  Действие отменено, возврат в меню...${RESET}"
      sleep 1
      continue
    fi
  done
}

# Функция для получения описания действия (обновленная)
get_action_description() {
  case $ACTION in
    "update") echo "🔄 Окружение MYSHELL будет обновлено до последней версии" ;;
    "reinstall") 
      if [[ "$SAVE_EXISTING" == "y" ]]; then
        echo "🔁 Окружение MYSHELL будет переустановлено с сохранением ваших настроек"
      else
        echo "🆕 Окружение MYSHELL будет полностью переустановлено (существующие настройки будут потеряны)"
      fi
      ;;
    "install")
      if [[ "$SAVE_EXISTING" == "y" ]]; then
        echo "🔐 Окружение MYSHELL будет установлено с сохранением текущих системных настроек"
      else
        echo "📥 Окружение MYSHELL будет установлено чисто (существующие настройки будут заменены)"
      fi
      ;;
    "plugins") echo "🧩 Плагины окружения MYSHELL будут обновлены до последних версий" ;;
    "backup") echo "💾 Будет создана полная резервная копия настроек окружения MYSHELL" ;;
    *) echo "❓ Неизвестное действие" ;;
  esac
}

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
# 🖥️ Запуск интерактивного интерфейса
#----------------------------------------------------

# Выполнение основного интерфейса
main() {
  clear
  show_logo
  show_config_info
  show_menu
  
  # После выхода из меню продолжаем выполнение выбранного действия
  # По логике, сюда попадаем только если пользователь подтвердил выбранное действие
}

# Запуск основной функции
main

#----------------------------------------------------
# 🔍 Архивация предыдущих резервных копий
#----------------------------------------------------

# Функция для архивации предыдущих бэкапов
archive_previous_backups() {
  echo -e "${BLUE}🔍 Проверка наличия предыдущих папок с бэкапами...${RESET}"
  
  # Находим все папки бэкапов, которые не архивированы
  BACKUP_DIRS=()
  while IFS= read -r dir; do
    dir_name=$(basename "$dir")
    # Ищем только папки, начинающиеся с "backup_"
    if [[ -d "$dir" && "$dir" != "$BACKUP_DIR" && "$dir_name" == backup_* ]]; then
      BACKUP_DIRS+=("$dir")
    fi
  done < <(find "$BACKUP_DIR" -mindepth 1 -maxdepth 1 -type d 2>/dev/null || echo "")
  
  # Если найдены предыдущие папки с бэкапами, архивируем их все
  if [[ ${#BACKUP_DIRS[@]} -gt 0 ]]; then
    echo -e "${YELLOW}⚠️ Обнаружено ${#BACKUP_DIRS[@]} предыдущих папок с бэкапами${RESET}"
    
    # Архивируем каждую папку
    for backup_dir in "${BACKUP_DIRS[@]}"; do
      dir_name=$(basename "$backup_dir")
      archive_path="$BACKUP_DIR/$dir_name.tar.gz"
      
      echo -e "${BLUE}📦 Архивируем папку $backup_dir в $archive_path...${RESET}"
      tar -czf "$archive_path" -C "$backup_dir" . || {
        echo -e "${YELLOW}⚠️ Ошибка при архивации. Пробуем с sudo...${RESET}"
        sudo tar -czf "$archive_path" -C "$backup_dir" .
      }
      
      # Удаляем папку после архивации
      rm -rf "$backup_dir" || sudo rm -rf "$backup_dir"
      
      echo -e "${GREEN}✅ Папка с бэкапом архивирована в $archive_path${RESET}"
    done
  else
    echo -e "${GREEN}✅ Предыдущих папок с бэкапами не обнаружено${RESET}"
  fi
}

#----------------------------------------------------
# 🔍 Выполнение специальных действий
#----------------------------------------------------

# Обработка действия backup - только создание резервной копии
if [[ "$ACTION" == "backup" ]]; then
  echo -e "${BLUE}🗂️ Создание резервной копии настроек...${RESET}"
  
  # Проверка наличия директории .myshell
  if [[ ! -d "$BASE_DIR" ]]; then
    echo -e "${RED}❌ Окружение .myshell не найдено. Нечего сохранять.${RESET}"
    exit 1
  fi
  
  # Архивируем предыдущие бэкапы
  archive_previous_backups
  
  # Создаем директорию для резервных копий
  mkdir -p "$BACKUP_DIR" || {
    echo -e "${YELLOW}⚠️ Не удалось создать директорию резервных копий. Пробуем с sudo...${RESET}"
    sudo mkdir -p "$BACKUP_DIR"
  }
  
  # Создаем директорию для текущего бэкапа
  mkdir -p "$DATED_BACKUP_DIR" || {
    echo -e "${YELLOW}⚠️ Не удалось создать директорию для текущего бэкапа. Пробуем с sudo...${RESET}"
    sudo mkdir -p "$DATED_BACKUP_DIR"
  }
  
  # Копируем текущее окружение .myshell (кроме папки backup)
  echo -e "${BLUE}🔄 Копирование текущего окружения в $DATED_BACKUP_DIR...${RESET}"
  rsync -a --exclude 'backup/' "$BASE_DIR/" "$DATED_BACKUP_DIR/" || {
    echo -e "${YELLOW}⚠️ Ошибка при копировании. Пробуем с sudo...${RESET}"
    sudo rsync -a --exclude 'backup/' "$BASE_DIR/" "$DATED_BACKUP_DIR/"
  }
  echo -e "${GREEN}✅ Текущее окружение .myshell сохранено в $DATED_BACKUP_DIR${RESET}"
  
  # Создаем README в директории бэкапа
  echo "# Backup of MYSHELL environment" > "$DATED_BACKUP_DIR/README.md"
  echo "Created: $(date)" >> "$DATED_BACKUP_DIR/README.md"
  echo "Original directory: $BASE_DIR" >> "$DATED_BACKUP_DIR/README.md"
  
  echo -e "${GREEN}🎉 Резервная копия успешно создана!${RESET}"
  exit 0
fi

# Обработка действия plugins - только обновление плагинов
if [[ "$ACTION" == "plugins" ]]; then
  echo -e "${BLUE}🔄 Обновление плагинов...${RESET}"
  
  # Проверка наличия директории .myshell
  if [[ ! -d "$BASE_DIR" ]]; then
    echo -e "${RED}❌ Окружение .myshell не найдено. Сначала установите окружение.${RESET}"
    exit 1
  fi
  
  # Обновление плагинов Zsh
  echo -e "${BLUE}📦 Обновляем плагины для Zsh...${RESET}"
  
  # Обновление zsh-autosuggestions
  if [[ -d "$BASE_DIR/ohmyzsh/custom/plugins/zsh-autosuggestions" ]]; then
    echo -e "${BLUE}🔄 Обновляем zsh-autosuggestions...${RESET}"
    (cd "$BASE_DIR/ohmyzsh/custom/plugins/zsh-autosuggestions" && git pull) || {
      echo -e "${YELLOW}⚠️ Не удалось обновить плагин. Пробуем переустановить...${RESET}"
      rm -rf "$BASE_DIR/ohmyzsh/custom/plugins/zsh-autosuggestions"
      git clone "$GIT_ZSH_AUTOSUGGESTIONS_REPO" "$BASE_DIR/ohmyzsh/custom/plugins/zsh-autosuggestions"
    }
  else
    echo -e "${BLUE}🔄 Устанавливаем zsh-autosuggestions...${RESET}"
    mkdir -p "$BASE_DIR/ohmyzsh/custom/plugins"
    git clone "$GIT_ZSH_AUTOSUGGESTIONS_REPO" "$BASE_DIR/ohmyzsh/custom/plugins/zsh-autosuggestions"
  fi
  
  # Обновление zsh-syntax-highlighting
  if [[ -d "$BASE_DIR/ohmyzsh/custom/plugins/zsh-syntax-highlighting" ]]; then
    echo -e "${BLUE}🔄 Обновляем zsh-syntax-highlighting...${RESET}"
    (cd "$BASE_DIR/ohmyzsh/custom/plugins/zsh-syntax-highlighting" && git pull) || {
      echo -e "${YELLOW}⚠️ Не удалось обновить плагин. Пробуем переустановить...${RESET}"
      rm -rf "$BASE_DIR/ohmyzsh/custom/plugins/zsh-syntax-highlighting"
      git clone "$GIT_ZSH_SYNTAX_HIGHLIGHTING_REPO" "$BASE_DIR/ohmyzsh/custom/plugins/zsh-syntax-highlighting"
    }
  else
    echo -e "${BLUE}🔄 Устанавливаем zsh-syntax-highlighting...${RESET}"
    mkdir -p "$BASE_DIR/ohmyzsh/custom/plugins"
    git clone "$GIT_ZSH_SYNTAX_HIGHLIGHTING_REPO" "$BASE_DIR/ohmyzsh/custom/plugins/zsh-syntax-highlighting"
  fi
  
  # Обновление тем Vim
  echo -e "${BLUE}📦 Обновляем темы для Vim...${RESET}"
  
  # Обновление PaperColor темы
  if [[ -d "$VIM_COLORS_DIR/papercolor-theme" ]]; then
    echo -e "${BLUE}🔄 Обновляем PaperColor тему...${RESET}"
    (cd "$VIM_COLORS_DIR/papercolor-theme" && git pull) || {
      echo -e "${YELLOW}⚠️ Не удалось обновить тему. Пробуем переустановить...${RESET}"
      rm -rf "$VIM_COLORS_DIR/papercolor-theme"
      git clone "$GIT_VIM_PAPERCOLOR_REPO" "$VIM_COLORS_DIR/papercolor-theme"
    }
  else
    echo -e "${BLUE}🔄 Устанавливаем PaperColor тему...${RESET}"
    mkdir -p "$VIM_COLORS_DIR"
    git clone "$GIT_VIM_PAPERCOLOR_REPO" "$VIM_COLORS_DIR/papercolor-theme"
  fi
  
  # Обновление символической ссылки
  ln -sf "$VIM_COLORS_DIR/papercolor-theme/colors/PaperColor.vim" "$VIM_COLORS_DIR/PaperColor.vim" || {
    echo -e "${YELLOW}⚠️ Не удалось создать символическую ссылку. Пробуем с sudo...${RESET}"
    sudo ln -sf "$VIM_COLORS_DIR/papercolor-theme/colors/PaperColor.vim" "$VIM_COLORS_DIR/PaperColor.vim"
  }
  
  echo -e "${GREEN}🎉 Плагины успешно обновлены!${RESET}"
  exit 0
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
  echo -e "${BLUE}📦 Устанавливаем: ${NEEDED_PACKAGES[*]}${RESET}"
  sudo apt update
  sudo apt install -y "${NEEDED_PACKAGES[@]}"
else
  echo -e "${GREEN}✅ Все необходимые пакеты уже установлены.${RESET}"
fi

#----------------------------------------------------
# 🔍 Проверка и обработка существующих конфигураций
#----------------------------------------------------

echo -e "${BLUE}🔍 Проверка наличия окружения и конфигураций...${RESET}"

# Проверяем наличие директории .myshell
if [[ -d "$BASE_DIR" ]]; then
  echo -e "${YELLOW}⚠️ Обнаружено существующее окружение .myshell${RESET}"
  
  if [[ "$SAVE_EXISTING" == "y" ]]; then
    # Архивируем предыдущие бэкапы
    archive_previous_backups
    
    # Создаем новую папку для текущего бэкапа
    echo -e "${BLUE}🗂️ Создание папки для текущего бэкапа: $DATED_BACKUP_DIR${RESET}"
    mkdir -p "$DATED_BACKUP_DIR" || {
      echo -e "${YELLOW}⚠️ Не удалось создать директорию для текущего бэкапа. Пробуем с sudo...${RESET}"
      sudo mkdir -p "$DATED_BACKUP_DIR"
    }
    
    # Копируем текущее окружение .myshell (кроме папки backup)
    echo -e "${BLUE}🔄 Копирование текущего окружения в $DATED_BACKUP_DIR...${RESET}"
    rsync -a --exclude 'backup/' "$BASE_DIR/" "$DATED_BACKUP_DIR/" || {
      echo -e "${YELLOW}⚠️ Ошибка при копировании. Пробуем с sudo...${RESET}"
      sudo rsync -a --exclude 'backup/' "$BASE_DIR/" "$DATED_BACKUP_DIR/"
    }

    echo -e "${GREEN}✅ Текущее окружение .myshell сохранено в $DATED_BACKUP_DIR${RESET}"
  else
    echo -e "${YELLOW}⚠️ Бэкап текущего окружения .myshell не был создан по выбору пользователя.${RESET}"
  fi
else
  # Если .myshell не найден, проверяем наличие отдельных конфигурационных файлов
  echo -e "${BLUE}🔍 Окружение .myshell не найдено, проверяем наличие отдельных конфигураций...${RESET}"
  
  EXISTING_CONFIGS=""
  [[ -f "$HOME/.zshrc" || -d "$HOME/.oh-my-zsh" ]] && EXISTING_CONFIGS="${EXISTING_CONFIGS}ZSH "
  [[ -f "$HOME/.tmux.conf" || -f "$HOME/.tmux.conf.local" ]] && EXISTING_CONFIGS="${EXISTING_CONFIGS}TMUX "
  [[ -f "$HOME/.vimrc" || -d "$HOME/.vim" ]] && EXISTING_CONFIGS="${EXISTING_CONFIGS}VIM "
  
  if [[ -n "$EXISTING_CONFIGS" ]]; then
    echo -e "${YELLOW}⚠️ Обнаружены существующие конфигурации: ${EXISTING_CONFIGS}${RESET}"
  
    if [[ "$SAVE_EXISTING" == "y" ]]; then
      echo -e "${BLUE}🗂️ Создание директорий для бэкапа...${RESET}"
      
      # Сначала создаем базовую директорию .myshell
      mkdir -p "$BASE_DIR" || {
        echo -e "${YELLOW}⚠️ Не удалось создать базовую директорию. Пробуем с sudo...${RESET}"
        sudo mkdir -p "$BASE_DIR"
      }
      
      # Затем создаем директорию для резервных копий
      mkdir -p "$BACKUP_DIR" || {
        echo -e "${YELLOW}⚠️ Не удалось создать директорию резервных копий. Пробуем с sudo...${RESET}"
        sudo mkdir -p "$BACKUP_DIR"
      }
      
      # И наконец, директорию для текущего бэкапа
      mkdir -p "$DATED_BACKUP_DIR" || {
        echo -e "${YELLOW}⚠️ Не удалось создать директорию для текущего бэкапа. Пробуем с sudo...${RESET}"
        sudo mkdir -p "$DATED_BACKUP_DIR"
      }

      # Функция для безопасного копирования файла, разыменовывающая символические ссылки
      copy_with_deref() {
        local src="$1"
        local dst="$2"
        
        if [[ -L "$src" ]]; then
          # Если это символическая ссылка, проверяем, что она не битая
          local target=$(readlink -f "$src")
          if [[ -e "$target" ]]; then
            echo -e "${BLUE}🔄 Копирование файла по ссылке: $src -> $target${RESET}"
            cp -pL "$src" "$dst" || sudo cp -pL "$src" "$dst"
          else
            echo -e "${YELLOW}⚠️ Пропускаем битую символическую ссылку: $src${RESET}"
          fi
        elif [[ -f "$src" ]]; then
          # Если это обычный файл
          if [[ -s "$src" ]]; then  # Проверка на непустой файл
            echo -e "${BLUE}🔄 Копирование файла: $src${RESET}"
            cp -p "$src" "$dst" || sudo cp -p "$src" "$dst"
          else
            echo -e "${YELLOW}⚠️ Пропускаем пустой файл: $src${RESET}"
          fi
        elif [[ -d "$src" ]]; then
          # Если это директория
          echo -e "${BLUE}🔄 Копирование директории: $src${RESET}"
          cp -a "$src" "$dst" || {
            echo -e "${YELLOW}⚠️ Ошибка при копировании. Пробуем с sudo...${RESET}"
            sudo cp -a "$src" "$dst"
          }
        fi
      }
  
      # Копирование конфигурационных файлов и директорий
      if [[ "$EXISTING_CONFIGS" == *"ZSH"* ]]; then
        echo -e "${BLUE}🔄 Сохранение конфигурации ZSH...${RESET}"
        mkdir -p "$DATED_BACKUP_DIR/zsh"
        
        if [[ -e "$HOME/.zshrc" ]]; then
          copy_with_deref "$HOME/.zshrc" "$DATED_BACKUP_DIR/zsh/"
        fi
        
        if [[ -d "$HOME/.oh-my-zsh" ]]; then
          if [[ -L "$HOME/.oh-my-zsh" ]]; then
            echo -e "${BLUE}🔄 Обнаружена символическая ссылка .oh-my-zsh, копируем настоящую директорию${RESET}"
            local omz_target=$(readlink -f "$HOME/.oh-my-zsh")
            if [[ -d "$omz_target" ]]; then
              cp -a "$omz_target" "$DATED_BACKUP_DIR/zsh/oh-my-zsh" || {
                sudo cp -a "$omz_target" "$DATED_BACKUP_DIR/zsh/oh-my-zsh"
              }
            else
              echo -e "${YELLOW}⚠️ Ссылка .oh-my-zsh указывает на несуществующую директорию${RESET}"
            fi
          else
            cp -a "$HOME/.oh-my-zsh" "$DATED_BACKUP_DIR/zsh/" || {
              echo -e "${YELLOW}⚠️ Ошибка при копировании .oh-my-zsh. Пробуем с sudo...${RESET}"
              sudo cp -a "$HOME/.oh-my-zsh" "$DATED_BACKUP_DIR/zsh/"
            }
          fi
        fi
      fi
  
      if [[ "$EXISTING_CONFIGS" == *"TMUX"* ]]; then
        echo -e "${BLUE}🔄 Сохранение конфигурации TMUX...${RESET}"
        mkdir -p "$DATED_BACKUP_DIR/tmux"
        
        [[ -e "$HOME/.tmux.conf" ]] && copy_with_deref "$HOME/.tmux.conf" "$DATED_BACKUP_DIR/tmux/"
        [[ -e "$HOME/.tmux.conf.local" ]] && copy_with_deref "$HOME/.tmux.conf.local" "$DATED_BACKUP_DIR/tmux/"
      fi
  
      if [[ "$EXISTING_CONFIGS" == *"VIM"* ]]; then
        echo -e "${BLUE}🔄 Сохранение конфигурации VIM...${RESET}"
        mkdir -p "$DATED_BACKUP_DIR/vim"
        
        [[ -e "$HOME/.vimrc" ]] && copy_with_deref "$HOME/.vimrc" "$DATED_BACKUP_DIR/vim/"
        
        if [[ -d "$HOME/.vim" || -L "$HOME/.vim" ]]; then
          if [[ -L "$HOME/.vim" ]]; then
            echo -e "${BLUE}🔄 Обнаружена символическая ссылка .vim, копируем настоящую директорию${RESET}"
            local vim_target=$(readlink -f "$HOME/.vim")
            if [[ -d "$vim_target" ]]; then
              cp -a "$vim_target" "$DATED_BACKUP_DIR/vim/vim" || {
                sudo cp -a "$vim_target" "$DATED_BACKUP_DIR/vim/vim"
              }
            else
              echo -e "${YELLOW}⚠️ Ссылка .vim указывает на несуществующую директорию${RESET}"
            fi
          else
            cp -a "$HOME/.vim" "$DATED_BACKUP_DIR/vim/" || {
              echo -e "${YELLOW}⚠️ Ошибка при копировании .vim. Пробуем с sudo...${RESET}"
              sudo cp -a "$HOME/.vim" "$DATED_BACKUP_DIR/vim/"
            }
          fi
        fi
      fi
      
      echo -e "${GREEN}✅ Бэкап сохранен в $DATED_BACKUP_DIR${RESET}"
    else
      echo -e "${YELLOW}⚠️ Бэкап не был создан по выбору пользователя.${RESET}"
    fi
  else
    echo -e "${GREEN}✅ Существующих конфигураций не обнаружено.${RESET}"
  fi
fi

# Пропускаем следующие блоки, если выбранное действие - update (не нужно очищать директорию)
if [[ "$ACTION" != "update" ]]; then
  #----------------------------------------------------
  # 🛠️ Подготовка окружения для установки
  #----------------------------------------------------

  # Очищаем содержимое директории .myshell (кроме директории backup)
  echo -e "${BLUE}🧹 Очищаем содержимое директории $BASE_DIR (кроме бэкапов)...${RESET}"
  if find "$BASE_DIR" -mindepth 1 ! -path "$BACKUP_DIR" ! -path "$BACKUP_DIR/*" -print0 | xargs -0 rm -rf 2>/dev/null; then
    echo -e "${GREEN}✅ Старый контент удален${RESET}"
  else
    echo -e "${YELLOW}⚠️ Не удалось удалить старый контент. Пробуем с sudo...${RESET}"
    sudo find "$BASE_DIR" -mindepth 1 ! -path "$BACKUP_DIR" ! -path "$BACKUP_DIR/*" -print0 | xargs -0 sudo rm -rf
  fi
fi

#----------------------------------------------------
# 📦 Установка и настройка Oh-My-Zsh
#----------------------------------------------------

# Функция для безопасного удаления Oh-My-Zsh
clean_ohmyzsh() {
  echo -e "${YELLOW}🧹 Удаление предыдущей установки Oh-My-Zsh...${RESET}"
  
  if [[ -L "$HOME/.oh-my-zsh" ]]; then
    echo -e "${BLUE}  - 🔗 Обнаружена символическая ссылка, удаляем...${RESET}"
    ( cd "$HOME" && exec /bin/rm -f .oh-my-zsh )
  elif [[ -d "$HOME/.oh-my-zsh" ]]; then
    echo -e "${BLUE}  - 📁 Обнаружена директория, удаляем рекурсивно...${RESET}"
    /bin/rm -rf "$HOME/.oh-my-zsh" || sudo /bin/rm -rf "$HOME/.oh-my-zsh"
  fi
  
  # Проверяем, что удаление прошло успешно
  if [[ -e "$HOME/.oh-my-zsh" ]]; then
    echo -e "${RED}❌ Ошибка: Не удалось удалить Oh-My-Zsh. Попробуйте вручную:${RESET}"
    echo "   rm -f $HOME/.oh-my-zsh"
    return 1
  fi
  
  return 0
}

# Функция для установки Oh-My-Zsh (предполагает, что путь уже чист)
install_ohmyzsh() {
  echo -e "${BLUE}📥 Установка Oh-My-Zsh...${RESET}"
  
  # Очищаем и создаем директорию в нашем окружении
  mkdir -p "$BASE_DIR/ohmyzsh" || sudo mkdir -p "$BASE_DIR/ohmyzsh"
  
  # Клонируем репозиторий Oh-My-Zsh напрямую в наше окружение
  git clone --depth=1 "$GIT_OMZ_REPO" "$BASE_DIR/ohmyzsh" || {
    echo -e "${RED}❌ Ошибка при клонировании репозитория Oh-My-Zsh${RESET}"
    return 1
  }
  
  # Символическая ссылка будет создана позже в блоке настройки окружения
  
  echo -e "${GREEN}✅ Oh-My-Zsh успешно установлен${RESET}"
  return 0
}

# Функция для обновления Oh-My-Zsh
update_ohmyzsh() {
  echo -e "${BLUE}🔄 Обновление Oh-My-Zsh...${RESET}"
  
  if [[ -d "$BASE_DIR/ohmyzsh" ]]; then
    # Если Oh-My-Zsh находится в нашем окружении
    (cd "$BASE_DIR/ohmyzsh" && git pull) || {
      echo -e "${YELLOW}⚠️ Не удалось обновить Oh-My-Zsh. Пробуем с sudo...${RESET}"
      sudo -u "$USER" git -C "$BASE_DIR/ohmyzsh" pull
    }
    echo -e "${GREEN}✅ Oh-My-Zsh успешно обновлен${RESET}"
    return 0
  elif [[ -x "$HOME/.oh-my-zsh/tools/upgrade.sh" ]]; then
    # Если это внешняя установка Oh-My-Zsh
    # Запускаем обновление
    export RUNZSH=no
    export KEEP_ZSHRC=yes
    "$HOME/.oh-my-zsh/tools/upgrade.sh" --unattended && {
      echo -e "${GREEN}✅ Oh-My-Zsh успешно обновлен${RESET}"
      return 0
    }
  fi
  
  # Если обновление не удалось или скрипт отсутствует, сообщаем об ошибке
  echo -e "${YELLOW}⚠️ Не удалось обновить Oh-My-Zsh${RESET}"
  return 1
}

# Основной блок управления Oh-My-Zsh
echo -e "${BLUE}📦 Настройка Oh-My-Zsh...${RESET}"

if [[ "$ACTION" == "update" ]]; then
  # Если выбрано обновление, просто обновляем Oh-My-Zsh
  update_ohmyzsh || {
    echo -e "${YELLOW}⚠️ Не удалось обновить Oh-My-Zsh. Пропускаем...${RESET}"
  }
else
  # Во всех других случаях (установка, переустановка) - очищаем и устанавливаем заново
  clean_ohmyzsh && install_ohmyzsh || exit 1
fi

#----------------------------------------------------
# 🧹 Чистим окружение
#----------------------------------------------------

# Только если это не обновление
if [[ "$ACTION" != "update" ]]; then
  # Функция для безопасного удаления файлов и директорий
  clean_item() {
    local item="$1"
    local target="$HOME/$item"
    
    # Проверяем тип элемента и удаляем соответственно
    if [[ -L "$target" ]]; then
      echo -e "${BLUE}🔗 Удаляем симлинк: ${CYAN}$target${RESET}"
      rm "$target" 2>/dev/null || sudo rm "$target"
    elif [[ -f "$target" ]]; then
      echo -e "${BLUE}📄 Удаляем файл: ${CYAN}$target${RESET}"
      rm "$target" 2>/dev/null || sudo rm "$target"
    elif [[ -d "$target" ]]; then
      echo -e "${BLUE}📁 Удаляем директорию: ${CYAN}$target${RESET}"
      rm -rf "$target" 2>/dev/null || sudo rm -rf "$target"
    else
      echo -e "${BLUE}ℹ️ Пропускаем: ${CYAN}$target${RESET} (не найден)"
    fi
  }

  # Удаление старых конфигов и симлинков
  echo -e "${YELLOW}🧹 Удаляем старые конфиги и симлинки...${RESET}"

  for item in $TRASH; do
    clean_item "$item"
  done

  echo -e "${GREEN}✅ Очистка завершена.${RESET}"
fi

#----------------------------------------------------
# 📥 Клонируем окружение
#----------------------------------------------------

# Для обновления репозиториев мы либо обновляем существующие, либо клонируем новые
update_or_clone_repo() {
  local repo_url="$1"
  local target_dir="$2"
  local repo_name="$3"
  
  if [[ -d "$target_dir" && -d "$target_dir/.git" ]]; then
    # Директория существует и это git-репозиторий, обновляем
    echo -e "${BLUE}🔄 Обновляем $repo_name...${RESET}"
    (cd "$target_dir" && git pull) || {
      echo -e "${YELLOW}⚠️ Не удалось обновить $repo_name. Пробуем с sudo...${RESET}"
      sudo -u "$USER" git -C "$target_dir" pull
    }
  else
    # Директория не существует или не является git-репозиторием, клонируем
    echo -e "${BLUE}📥 Клонируем $repo_name...${RESET}"
    
    # Если директория существует, но не является git-репозиторием, удаляем её
    if [[ -d "$target_dir" ]]; then
      rm -rf "$target_dir" || sudo rm -rf "$target_dir"
    fi
    
    git clone "$repo_url" "$target_dir" || {
      echo -e "${YELLOW}⚠️ Ошибка при клонировании $repo_name. Проверяем права доступа...${RESET}"
      sudo git clone "$repo_url" "$target_dir"
    }
  fi
}

# Обновляем или клонируем tmux конфигурацию
update_or_clone_repo "$GIT_TMUX_REPO" "$BASE_DIR/tmux" "tmux конфигурацию"

# Обновляем или клонируем dotfiles
update_or_clone_repo "$GIT_DOTFILES_REPO" "$BASE_DIR/dotfiles" "dotfiles"

# Создаем директории для vim, если они не существуют
mkdir -p "$VIM_COLORS_DIR" "$VIM_PLUGINS_DIR" || {
  echo -e "${YELLOW}⚠️ Не удалось создать директории для vim. Пробуем с sudo...${RESET}"
  sudo mkdir -p "$VIM_COLORS_DIR" "$VIM_PLUGINS_DIR"
}

# Обновляем или клонируем PaperColor тему
update_or_clone_repo "$GIT_VIM_PAPERCOLOR_REPO" "$VIM_COLORS_DIR/papercolor-theme" "PaperColor тему"

# Создаем символическую ссылку для PaperColor
ln -sf "$VIM_COLORS_DIR/papercolor-theme/colors/PaperColor.vim" "$VIM_COLORS_DIR/PaperColor.vim" || {
  echo -e "${YELLOW}⚠️ Не удалось создать символическую ссылку. Пробуем с sudo...${RESET}"
  sudo ln -sf "$VIM_COLORS_DIR/papercolor-theme/colors/PaperColor.vim" "$VIM_COLORS_DIR/PaperColor.vim"
}

echo -e "${BLUE}📦 Устанавливаем плагины для Zsh...${RESET}"
mkdir -p "$BASE_DIR/ohmyzsh/custom/plugins" || {
  echo -e "${YELLOW}⚠️ Не удалось создать директорию для плагинов. Пробуем с sudo...${RESET}"
  sudo mkdir -p "$BASE_DIR/ohmyzsh/custom/plugins"
}

# Обновляем или клонируем zsh-autosuggestions
update_or_clone_repo "$GIT_ZSH_AUTOSUGGESTIONS_REPO" "$BASE_DIR/ohmyzsh/custom/plugins/zsh-autosuggestions" "zsh-autosuggestions"

# Обновляем или клонируем zsh-syntax-highlighting
update_or_clone_repo "$GIT_ZSH_SYNTAX_HIGHLIGHTING_REPO" "$BASE_DIR/ohmyzsh/custom/plugins/zsh-syntax-highlighting" "zsh-syntax-highlighting"

#----------------------------------------------------
# ⚙️ Настройки окружения
#----------------------------------------------------

echo -e "${BLUE}⚙️ Настраиваем zsh...${RESET}"
ln -sf "$BASE_DIR/dotfiles/.zshrc" "$HOME/.zshrc" || {
  echo -e "${YELLOW}⚠️ Не удалось создать символическую ссылку. Пробуем с sudo...${RESET}"
  sudo ln -sf "$BASE_DIR/dotfiles/.zshrc" "$HOME/.zshrc"
}

echo -e "${BLUE}⚙️ Настраиваем vim...${RESET}"
ln -sf "$BASE_DIR/dotfiles/.vimrc" "$HOME/.vimrc" || sudo ln -sf "$BASE_DIR/dotfiles/.vimrc" "$HOME/.vimrc"
ln -sfn "$VIM_DIR" "$HOME/.vim" || sudo ln -sfn "$VIM_DIR" "$HOME/.vim"

echo -e "${BLUE}⚙️ Настраиваем tmux...${RESET}"
ln -sf "$BASE_DIR/tmux/.tmux.conf" "$HOME/.tmux.conf" || sudo ln -sf "$BASE_DIR/tmux/.tmux.conf" "$HOME/.tmux.conf"
ln -sf "$BASE_DIR/dotfiles/.tmux.conf.local" "$HOME/.tmux.conf.local" || sudo ln -sf "$BASE_DIR/dotfiles/.tmux.conf.local" "$HOME/.tmux.conf.local"

echo -e "${BLUE}⚙️ Настраиваем Oh-My-Zsh...${RESET}"
ln -sfn "$BASE_DIR/ohmyzsh" "$HOME/.oh-my-zsh" || {
  echo -e "${YELLOW}⚠️ Не удалось создать символическую ссылку. Пробуем с sudo...${RESET}"
  sudo ln -sfn "$BASE_DIR/ohmyzsh" "$HOME/.oh-my-zsh"
}

# Создаем файл версии
echo "$SCRIPT_VERSION" > "$BASE_DIR/version" || {
  echo -e "${YELLOW}⚠️ Не удалось создать файл версии. Пробуем с sudo...${RESET}"
  echo "$SCRIPT_VERSION" | sudo tee "$BASE_DIR/version" > /dev/null
}

#----------------------------------------------------
# 🧰 Проверка и установка ZShell по умолчанию
#----------------------------------------------------
if [[ "$(basename "$SHELL")" != "zsh" ]]; then
  echo -e "${BLUE}🔁 Меняем shell на Zsh...${RESET}"
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
  echo -e "${GREEN}✅ Zsh уже установлен как shell по умолчанию.${RESET}"
fi

#----------------------------------------------------
# ✅ Завершение установки
#----------------------------------------------------

# Обновляем владельца всех файлов и директорий
echo -e "${BLUE}🛠️ Установка правильных прав доступа...${RESET}"
sudo chown -R "$USER":"$USER" "$BASE_DIR"

# Проверяем, что символические ссылки существуют перед установкой прав
for link in "$HOME/.oh-my-zsh" "$HOME/.vim" "$HOME/.zshrc" "$HOME/.vimrc" "$HOME/.tmux.conf" "$HOME/.tmux.conf.local"; do
  if [[ -L "$link" ]]; then
    sudo chown -h "$USER":"$USER" "$link" 2>/dev/null
  fi
done

#----------------------------------------------------
# 🗑️ Очистка временной директории
#----------------------------------------------------
rm -rf "$HOME/init-shell" 2>/dev/null || sudo rm -rf "$HOME/init-shell"

#----------------------------------------------------
# ✅ Завершено
#----------------------------------------------------
echo -e "${GREEN}🎉 Установка завершена успешно!${RESET}"

# Сообщаем пользователю о необходимости перезапуска сессии
echo -e "${BLUE}ℹ️ Чтобы изменения вступили в силу, перезапустите терминал или выполните:${RESET}"
echo -e "${CYAN}   exec zsh${RESET}"

# Спрашиваем, хочет ли пользователь перейти в Zsh прямо сейчас
read -p "🚀 Хотите перейти в Zsh прямо сейчас? (y/n): " switch_to_zsh
if [[ "$switch_to_zsh" =~ ^[Yy]$ ]]; then
  echo -e "${GREEN}👋 Переходим в Zsh...${RESET}"
  exec zsh -l
else
  echo -e "${GREEN}👋 До свидания!${RESET}"
fi

