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
# 🎨 Функции для стилизованного вывода
#----------------------------------------------------

# Функция для вывода заголовка группы операций
print_group_header() {
  local title="$1"
  echo -e "\n${BLUE}${title}${RESET}"
}

# Единая функция для вывода сообщений с анимированными точками
print_message_with_dots() {
  local prefix="$1"      # Префикс сообщения (например, "└─→" или "⚠️ ")
  local message="$2"     # Основное сообщение
  local result="$3"      # Результат (например, "актуальная версия")
  local result_color="$4"  # Цвет результата (GREEN, CYAN, YELLOW, RED)
  local indent="$5"      # Отступ
  local width=80         # Общая ширина строки
  local pfx_msg_length=${#prefix}
  local msg_length=${#message}
  local result_length=${#result}
  local total_length=$((pfx_msg_length + msg_length + 2)) # +2 для пробелов
  local dots_count=$((width - total_length - result_length))
  
  # Выводим префикс и сообщение с отступом
  echo -en "${indent}${BLUE}${prefix}${RESET} ${message}"
  
  # Выводим точки с небольшой задержкой для анимации
  for ((i=1; i<=dots_count; i++)); do
    echo -en "${GRAY}.${RESET}"
    sleep 0.01
  done
  
  # Выводим результат в указанном цвете
  echo -e " ${!result_color}${result}${RESET}"
}

# Функция для вывода операции с анимированными точками
print_operation() {
  print_message_with_dots "└─→" "$1" "$2" "$3" "  "
}

# Функция для вывода информационного сообщения (в том же формате, что и операции)
print_info() {
  print_message_with_dots "└─→" "$1" "$2" "$3" "  "
}

# Функция для вывода предупреждения (в том же формате, что и операции)
print_warning() {
  print_message_with_dots "└─→" "$1" "$2" "YELLOW" "  "
}

# Функция для вывода успешного сообщения (в том же формате, что и операции)
print_success() {
  print_message_with_dots "└─→" "$1" "$2" "GREEN" "  "
}

# Функция для вывода ошибки (в том же формате, что и операции)
print_error() {
  print_message_with_dots "└─→" "$1" "$2" "RED" "  "
}

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
    print_warning "Окружение MYSHELL" "не установлено"
    
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

# Функция для получения описания действия
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

#----------------------------------------------------
# 🔍 Архивация предыдущих резервных копий
#----------------------------------------------------

# Функция для архивации предыдущих бэкапов
archive_previous_backups() {
  print_operation "Проверка наличия предыдущих папок с бэкапами" "выполнено" "GREEN"
  
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
    print_operation "Найдены предыдущие бэкапы" "${#BACKUP_DIRS[@]} папок" "YELLOW"
    
    # Архивируем каждую папку
    for backup_dir in "${BACKUP_DIRS[@]}"; do
      dir_name=$(basename "$backup_dir")
      archive_path="$BACKUP_DIR/$dir_name.tar.gz"
      
      if ! tar -czf "$archive_path" -C "$backup_dir" .; then
        if sudo tar -czf "$archive_path" -C "$backup_dir" .; then
          print_operation "Архивируем папку $dir_name" "успешно" "GREEN"
        else
          print_operation "Архивируем папку $dir_name" "ошибка" "RED"
          continue
        fi
      else
        print_operation "Архивируем папку $dir_name" "успешно" "GREEN"
      fi
      
      # Удаляем папку после архивации
      if ! rm -rf "$backup_dir"; then
        sudo rm -rf "$backup_dir"
      fi
    done
  else
    print_operation "Предыдущие бэкапы" "не найдены" "GREEN"
  fi
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
# 🔍 Выполнение специальных действий
#----------------------------------------------------

# Обработка действия backup - только создание резервной копии
if [[ "$ACTION" == "backup" ]]; then
  print_group_header "🗂️ Создание резервной копии настроек"
  
  # Проверка наличия директории .myshell
  if [[ ! -d "$BASE_DIR" ]]; then
    echo -e "${RED}❌ Окружение .myshell не найдено. Нечего сохранять.${RESET}"
    exit 1
  fi
  
  # Архивируем предыдущие бэкапы
  archive_previous_backups
  
  # Создаем директорию для резервных копий
  if ! mkdir -p "$BACKUP_DIR"; then
    if sudo mkdir -p "$BACKUP_DIR"; then
      print_operation "Создание директории для резервных копий" "успешно" "GREEN"
    else
      print_operation "Создание директории для резервных копий" "ошибка" "RED"
      exit 1
    fi
  else
    print_operation "Создание директории для резервных копий" "успешно" "GREEN"
  fi
  
  # Создаем директорию для текущего бэкапа
  if ! mkdir -p "$DATED_BACKUP_DIR"; then
    if sudo mkdir -p "$DATED_BACKUP_DIR"; then
      print_operation "Создание директории для текущего бэкапа" "успешно" "GREEN"
    else
      print_operation "Создание директории для текущего бэкапа" "ошибка" "RED"
      exit 1
    fi
  else
    print_operation "Создание директории для текущего бэкапа" "успешно" "GREEN"
  fi
  
  # Копируем текущее окружение .myshell (кроме папки backup)
  if ! rsync -a --exclude 'backup/' "$BASE_DIR/" "$DATED_BACKUP_DIR/"; then
    if sudo rsync -a --exclude 'backup/' "$BASE_DIR/" "$DATED_BACKUP_DIR/"; then
      print_operation "Копирование текущего окружения" "успешно" "GREEN"
    else
      print_operation "Копирование текущего окружения" "ошибка" "RED"
      exit 1
    fi
  else
    print_operation "Копирование текущего окружения" "успешно" "GREEN"
  fi
  
  # Создаем README в директории бэкапа
  echo "# Backup of MYSHELL environment" > "$DATED_BACKUP_DIR/README.md"
  echo "Created: $(date)" >> "$DATED_BACKUP_DIR/README.md"
  echo "Original directory: $BASE_DIR" >> "$DATED_BACKUP_DIR/README.md"
  
  echo -e "${GREEN}🎉 Резервная копия успешно создана!${RESET}"
  exit 0
fi

# Обработка действия plugins - только обновление плагинов
if [[ "$ACTION" == "plugins" ]]; then
  print_group_header "🧩 Обновление плагинов"
  
  # Проверка наличия директории .myshell
  if [[ ! -d "$BASE_DIR" ]]; then
    echo -e "${RED}❌ Окружение .myshell не найдено. Сначала установите окружение.${RESET}"
    exit 1
  fi
  
  print_group_header "📦 Обновляем плагины для Zsh"
  
  # Обновление zsh-autosuggestions
  if [[ -d "$BASE_DIR/ohmyzsh/custom/plugins/zsh-autosuggestions" ]]; then
    if ! (cd "$BASE_DIR/ohmyzsh/custom/plugins/zsh-autosuggestions" && git pull -q); then
      print_operation "Ошибка обновления, переустанавливаем zsh-autosuggestions" "переустановка" "YELLOW"
      rm -rf "$BASE_DIR/ohmyzsh/custom/plugins/zsh-autosuggestions"
      if git clone -q "$GIT_ZSH_AUTOSUGGESTIONS_REPO" "$BASE_DIR/ohmyzsh/custom/plugins/zsh-autosuggestions"; then
        print_operation "Переустановка zsh-autosuggestions" "успешно" "GREEN"
      else
        print_operation "Переустановка zsh-autosuggestions" "ошибка" "RED"
      fi
    else
      print_operation "Обновление zsh-autosuggestions" "успешно" "GREEN"
    fi
  else
    mkdir -p "$BASE_DIR/ohmyzsh/custom/plugins"
    if git clone -q "$GIT_ZSH_AUTOSUGGESTIONS_REPO" "$BASE_DIR/ohmyzsh/custom/plugins/zsh-autosuggestions"; then
      print_operation "Установка zsh-autosuggestions" "успешно" "GREEN"
    else
      print_operation "Установка zsh-autosuggestions" "ошибка" "RED"
    fi
  fi
  
  # Обновление zsh-syntax-highlighting
  if [[ -d "$BASE_DIR/ohmyzsh/custom/plugins/zsh-syntax-highlighting" ]]; then
    if ! (cd "$BASE_DIR/ohmyzsh/custom/plugins/zsh-syntax-highlighting" && git pull -q); then
      print_operation "Ошибка обновления, переустанавливаем zsh-syntax-highlighting" "переустановка" "YELLOW"
      rm -rf "$BASE_DIR/ohmyzsh/custom/plugins/zsh-syntax-highlighting"
      if git clone -q "$GIT_ZSH_SYNTAX_HIGHLIGHTING_REPO" "$BASE_DIR/ohmyzsh/custom/plugins/zsh-syntax-highlighting"; then
        print_operation "Переустановка zsh-syntax-highlighting" "успешно" "GREEN"
      else
        print_operation "Переустановка zsh-syntax-highlighting" "ошибка" "RED"
      fi
    else
      print_operation "Обновление zsh-syntax-highlighting" "успешно" "GREEN"
    fi
  else
    mkdir -p "$BASE_DIR/ohmyzsh/custom/plugins"
    if git clone -q "$GIT_ZSH_SYNTAX_HIGHLIGHTING_REPO" "$BASE_DIR/ohmyzsh/custom/plugins/zsh-syntax-highlighting"; then
      print_operation "Установка zsh-syntax-highlighting" "успешно" "GREEN"
    else
      print_operation "Установка zsh-syntax-highlighting" "ошибка" "RED"
    fi
  fi
  
  print_group_header "📦 Обновляем темы для Vim"
  
  # Обновление PaperColor темы
  if [[ -d "$VIM_COLORS_DIR/papercolor-theme" ]]; then
    if ! (cd "$VIM_COLORS_DIR/papercolor-theme" && git pull -q); then
      print_operation "Ошибка обновления, переустанавливаем PaperColor тему" "переустановка" "YELLOW"
      rm -rf "$VIM_COLORS_DIR/papercolor-theme"
      if git clone -q "$GIT_VIM_PAPERCOLOR_REPO" "$VIM_COLORS_DIR/papercolor-theme"; then
        print_operation "Переустановка PaperColor темы" "успешно" "GREEN"
      else
       print_operation "Переустановка PaperColor темы" "ошибка" "RED"
      fi
    else
      print_operation "Обновление PaperColor темы" "успешно" "GREEN"
    fi
  else
    mkdir -p "$VIM_COLORS_DIR"
    if git clone -q "$GIT_VIM_PAPERCOLOR_REPO" "$VIM_COLORS_DIR/papercolor-theme"; then
      print_operation "Установка PaperColor темы" "успешно" "GREEN"
    else
      print_operation "Установка PaperColor темы" "ошибка" "RED"
    fi
  fi
  
  # Обновление символической ссылки
  if ! ln -sf "$VIM_COLORS_DIR/papercolor-theme/colors/PaperColor.vim" "$VIM_COLORS_DIR/PaperColor.vim"; then
    if sudo ln -sf "$VIM_COLORS_DIR/papercolor-theme/colors/PaperColor.vim" "$VIM_COLORS_DIR/PaperColor.vim"; then
      print_operation "Обновление символической ссылки для PaperColor" "успешно" "GREEN"
    else
      print_operation "Обновление символической ссылки для PaperColor" "ошибка" "RED"
    fi
  else
    print_operation "Обновление символической ссылки для PaperColor" "успешно" "GREEN"
  fi
  
  echo -e "${GREEN}🎉 Плагины успешно обновлены!${RESET}"
  exit 0
fi

#----------------------------------------------------
# 🛠️ Подготовка окружения
#----------------------------------------------------

print_group_header "🛠️ Подготовка окружения"

# Проверка необходимых пакетов
NEEDED_PACKAGES=()
for pkg in $PACKAGES; do
  if ! dpkg -s "$pkg" &>/dev/null; then
    NEEDED_PACKAGES+=("$pkg")
  fi
done

if [[ ${#NEEDED_PACKAGES[@]} -gt 0 ]]; then
  if sudo apt update && sudo apt install -y "${NEEDED_PACKAGES[@]}"; then
    print_operation "Установка пакетов: ${NEEDED_PACKAGES[*]}" "успешно" "GREEN"
  else
    print_operation "Установка пакетов: ${NEEDED_PACKAGES[*]}" "ошибка" "RED"
    echo -e "${RED}❌ Не удалось установить необходимые пакеты. Проверьте соединение и права sudo.${RESET}"
    exit 1
  fi
else
  print_operation "Проверка необходимых пакетов" "актуальная версия" "GREEN"
fi

# Проверка наличия окружения и конфигураций
print_operation "Проверка наличия окружения .myshell" "выполнено" "CYAN"
if [[ -d "$BASE_DIR" ]]; then
  print_operation "Обнаружено окружение .myshell" "требуется обработка" "YELLOW"
  
  if [[ "$SAVE_EXISTING" == "y" ]]; then
    # Архивируем предыдущие бэкапы
    archive_previous_backups
    
    # Создаем новую папку для текущего бэкапа
    if ! mkdir -p "$DATED_BACKUP_DIR"; then
      if sudo mkdir -p "$DATED_BACKUP_DIR"; then
        print_operation "Создание папки для текущего бэкапа" "успешно" "GREEN"
      else
        print_operation "Создание папки для текущего бэкапа" "ошибка" "RED"
        exit 1
      fi
    else
      print_operation "Создание папки для текущего бэкапа" "успешно" "GREEN"
    fi
    
    # Копируем текущее окружение .myshell (кроме папки backup)
    if ! rsync -a --exclude 'backup/' "$BASE_DIR/" "$DATED_BACKUP_DIR/"; then
      if sudo rsync -a --exclude 'backup/' "$BASE_DIR/" "$DATED_BACKUP_DIR/"; then
        print_operation "Копирование текущего окружения" "успешно" "GREEN"
      else
        print_operation "Копирование текущего окружения" "ошибка" "RED"
        exit 1
      fi
    else
      print_operation "Копирование текущего окружения" "успешно" "GREEN"
    fi
  else
    print_operation "Создание резервной копии" "пропущено" "YELLOW"
  fi
else
  print_operation "Окружение .myshell не обнаружено" "будет создано" "CYAN"
  
  # Проверка существующих конфигураций
  EXISTING_CONFIGS=""
  [[ -f "$HOME/.zshrc" || -d "$HOME/.oh-my-zsh" ]] && EXISTING_CONFIGS="${EXISTING_CONFIGS}ZSH "
  [[ -f "$HOME/.tmux.conf" || -f "$HOME/.tmux.conf.local" ]] && EXISTING_CONFIGS="${EXISTING_CONFIGS}TMUX "
  [[ -f "$HOME/.vimrc" || -d "$HOME/.vim" ]] && EXISTING_CONFIGS="${EXISTING_CONFIGS}VIM "
  
  if [[ -n "$EXISTING_CONFIGS" ]]; then
    print_operation "Обнаружены существующие конфигурации" "$EXISTING_CONFIGS" "YELLOW"
    
    if [[ "$SAVE_EXISTING" == "y" ]]; then
      # Сначала создаем базовую директорию .myshell
      if ! mkdir -p "$BASE_DIR"; then
        sudo mkdir -p "$BASE_DIR"
      fi
      
      # Затем создаем директорию для резервных копий
      if ! mkdir -p "$BACKUP_DIR"; then
        sudo mkdir -p "$BACKUP_DIR"
      fi
      
      # И наконец, директорию для текущего бэкапа
      if ! mkdir -p "$DATED_BACKUP_DIR"; then
        sudo mkdir -p "$DATED_BACKUP_DIR"
      fi

      # Функция для безопасного копирования файла, разыменовывающая символические ссылки
      copy_with_deref() {
        local src="$1"
        local dst="$2"
        
        if [[ -L "$src" ]]; then
          # Если это символическая ссылка, проверяем, что она не битая
          local target=$(readlink -f "$src")
          if [[ -e "$target" ]]; then
            if ! cp -pL "$src" "$dst"; then
              if sudo cp -pL "$src" "$dst"; then
                print_operation "Копирование файла по ссылке: $src -> $target" "успешно" "GREEN"
              else
                print_operation "Копирование файла по ссылке: $src -> $target" "ошибка" "RED"
              fi
            else
              print_operation "Копирование файла по ссылке: $src -> $target" "успешно" "GREEN"
            fi
          else
            print_operation "Пропуск битой символической ссылки" "$src" "YELLOW"
          fi
        elif [[ -f "$src" ]]; then
          # Если это обычный файл
          if [[ -s "$src" ]]; then  # Проверка на непустой файл
            if ! cp -p "$src" "$dst"; then
              if sudo cp -p "$src" "$dst"; then
                print_operation "Копирование файла: $src" "успешно" "GREEN"
              else
                print_operation "Копирование файла: $src" "ошибка" "RED"
              fi
            else
              print_operation "Копирование файла: $src" "успешно" "GREEN"
            fi
          else
            print_operation "Пропуск пустого файла" "$src" "YELLOW"
          fi
        elif [[ -d "$src" ]]; then
          # Если это директория
          if ! cp -a "$src" "$dst"; then
            if sudo cp -a "$src" "$dst"; then
              print_operation "Копирование директории: $src" "успешно" "GREEN"
            else
              print_operation "Копирование директории: $src" "ошибка" "RED"
            fi
          else
            print_operation "Копирование директории: $src" "успешно" "GREEN"
          fi
        fi
      }

      # Копирование конфигурационных файлов и директорий
      if [[ "$EXISTING_CONFIGS" == *"ZSH"* ]]; then
        print_operation "Сохранение конфигурации ZSH" "выполняется" "CYAN"
        mkdir -p "$DATED_BACKUP_DIR/zsh"
        
        if [[ -e "$HOME/.zshrc" ]]; then
          copy_with_deref "$HOME/.zshrc" "$DATED_BACKUP_DIR/zsh/"
        fi
        
        if [[ -d "$HOME/.oh-my-zsh" ]]; then
          if [[ -L "$HOME/.oh-my-zsh" ]]; then
            local omz_target=$(readlink -f "$HOME/.oh-my-zsh")
            if [[ -d "$omz_target" ]]; then
              if ! cp -a "$omz_target" "$DATED_BACKUP_DIR/zsh/oh-my-zsh"; then
                if sudo cp -a "$omz_target" "$DATED_BACKUP_DIR/zsh/oh-my-zsh"; then
                  print_operation "Копирование .oh-my-zsh -> $omz_target" "успешно" "GREEN"
                else
                  print_operation "Копирование .oh-my-zsh -> $omz_target" "ошибка" "RED"
                fi
              else
                print_operation "Копирование .oh-my-zsh -> $omz_target" "успешно" "GREEN"
              fi
            else
              print_operation "Ссылка .oh-my-zsh указывает на несуществующую директорию" "$omz_target" "YELLOW"
            fi
          else
            if ! cp -a "$HOME/.oh-my-zsh" "$DATED_BACKUP_DIR/zsh/"; then
              if sudo cp -a "$HOME/.oh-my-zsh" "$DATED_BACKUP_DIR/zsh/"; then
                print_operation "Копирование .oh-my-zsh" "успешно" "GREEN"
              else
                print_operation "Копирование .oh-my-zsh" "ошибка" "RED"
              fi
            else
              print_operation "Копирование .oh-my-zsh" "успешно" "GREEN"
            fi
          fi
        fi
        print_operation "Сохранение конфигурации ZSH" "завершено" "GREEN"
      fi
  
      if [[ "$EXISTING_CONFIGS" == *"TMUX"* ]]; then
        print_operation "Сохранение конфигурации TMUX" "выполняется" "CYAN"
        mkdir -p "$DATED_BACKUP_DIR/tmux"
        
        [[ -e "$HOME/.tmux.conf" ]] && copy_with_deref "$HOME/.tmux.conf" "$DATED_BACKUP_DIR/tmux/"
        [[ -e "$HOME/.tmux.conf.local" ]] && copy_with_deref "$HOME/.tmux.conf.local" "$DATED_BACKUP_DIR/tmux/"
        print_operation "Сохранение конфигурации TMUX" "завершено" "GREEN"
      fi
  
      if [[ "$EXISTING_CONFIGS" == *"VIM"* ]]; then
        print_operation "Сохранение конфигурации VIM" "выполняется" "CYAN"
        mkdir -p "$DATED_BACKUP_DIR/vim"
        
        [[ -e "$HOME/.vimrc" ]] && copy_with_deref "$HOME/.vimrc" "$DATED_BACKUP_DIR/vim/"
        
        if [[ -d "$HOME/.vim" || -L "$HOME/.vim" ]]; then
          if [[ -L "$HOME/.vim" ]]; then
            local vim_target=$(readlink -f "$HOME/.vim")
            if [[ -d "$vim_target" ]]; then
              if ! cp -a "$vim_target" "$DATED_BACKUP_DIR/vim/vim"; then
                if sudo cp -a "$vim_target" "$DATED_BACKUP_DIR/vim/vim"; then
                  print_operation "Копирование .vim -> $vim_target" "успешно" "GREEN"
                else
                  print_operation "Копирование .vim -> $vim_target" "ошибка" "RED"
                fi
              else
                print_operation "Копирование .vim -> $vim_target" "успешно" "GREEN"
              fi
            else
              print_operation "Ссылка .vim указывает на несуществующую директорию" "$vim_target" "YELLOW"
            fi
          else
            if ! cp -a "$HOME/.vim" "$DATED_BACKUP_DIR/vim/"; then
              if sudo cp -a "$HOME/.vim" "$DATED_BACKUP_DIR/vim/"; then
                print_operation "Копирование .vim" "успешно" "GREEN"
              else
                print_operation "Копирование .vim" "ошибка" "RED"
              fi
            else
              print_operation "Копирование .vim" "успешно" "GREEN"
            fi
          fi
        fi
        print_operation "Сохранение конфигурации VIM" "завершено" "GREEN"
      fi
      
      print_operation "Создание резервной копии существующих конфигураций" "успешно" "GREEN"
    else
      print_operation "Создание резервной копии" "пропущено" "YELLOW"
    fi
  else
    print_operation "Существующие конфигурации" "не обнаружены" "GREEN"
  fi
  
  # Создание базовых директорий
  if ! mkdir -p "$BASE_DIR"; then
    if sudo mkdir -p "$BASE_DIR"; then
      print_operation "Создание базовой директории .myshell" "успешно" "GREEN"
    else
      print_operation "Создание базовой директории .myshell" "ошибка" "RED"
      exit 1
    fi
  else
    print_operation "Создание базовой директории .myshell" "успешно" "GREEN"
  fi
fi

#----------------------------------------------------
# 🧹 Очистка окружения
#----------------------------------------------------

# Пропускаем следующие блоки, если выбранное действие - update (не нужно очищать директорию)
if [[ "$ACTION" != "update" ]]; then
  print_group_header "🧹 Очистка окружения"
  
  # Очищаем содержимое директории .myshell (кроме директории backup)
  if ! find "$BASE_DIR" -mindepth 1 ! -path "$BACKUP_DIR" ! -path "$BACKUP_DIR/*" -print0 | xargs -0 rm -rf 2>/dev/null; then
    if sudo find "$BASE_DIR" -mindepth 1 ! -path "$BACKUP_DIR" ! -path "$BACKUP_DIR/*" -print0 | xargs -0 sudo rm -rf; then
      print_operation "Очистка директории .myshell" "успешно" "GREEN"
    else
      print_operation "Очистка директории .myshell" "ошибка" "RED"
    fi
  else
    print_operation "Очистка директории .myshell" "успешно" "GREEN"
  fi
  
  # Функция для безопасного удаления файлов и директорий
  clean_item() {
    local item="$1"
    local target="$HOME/$item"
    
    # Проверяем тип элемента и удаляем соответственно
    if [[ -L "$target" ]]; then
      if ! rm "$target" 2>/dev/null; then
        if sudo rm "$target"; then
          print_operation "Удаление символической ссылки: $item" "успешно" "GREEN"
        else
          print_operation "Удаление символической ссылки: $item" "ошибка" "RED"
        fi
      else
        print_operation "Удаление символической ссылки: $item" "успешно" "GREEN"
      fi
    elif [[ -f "$target" ]]; then
      if ! rm "$target" 2>/dev/null; then
        if sudo rm "$target"; then
          print_operation "Удаление файла: $item" "успешно" "GREEN"
        else
          print_operation "Удаление файла: $item" "ошибка" "RED"
        fi
      else
        print_operation "Удаление файла: $item" "успешно" "GREEN"
      fi
    elif [[ -d "$target" ]]; then
      if ! rm -rf "$target" 2>/dev/null; then
        if sudo rm -rf "$target"; then
          print_operation "Удаление директории: $item" "успешно" "GREEN"
        else
          print_operation "Удаление директории: $item" "ошибка" "RED"
        fi
      else
        print_operation "Удаление директории: $item" "успешно" "GREEN"
      fi
    else
      print_operation "Проверка $item" "не найдено" "YELLOW"
    fi
  }
  
# Удаление старых конфигов и симлинков
echo -e "  ${BLUE}└─→ Удаляем старые конфигурационные файлы:${RESET}"

# Подсчитываем, сколько всего файлов надо удалить
declare -a files_to_remove=()
for item in $TRASH; do
  for target in $HOME/$item; do
    if [[ -e "$target" || -L "$target" ]]; then
      files_to_remove+=("$(basename "$target")")
    fi
  done
done

# Если нет файлов для удаления
if [ ${#files_to_remove[@]} -eq 0 ]; then
  print_operation "Старые конфигурационные файлы" "не найдены" "GREEN"
else
  # Удаляем каждый файл с подробным логированием
  for base_item in "${files_to_remove[@]}"; do
    clean_item "$base_item"
  done
  
  # В конце выводим итоговое сообщение
  print_operation "Всего удалено файлов" "${#files_to_remove[@]}" "GREEN"
fi

fi

#----------------------------------------------------
# 📦 Установка компонентов
#----------------------------------------------------

print_group_header "📦 Установка компонентов"

# Обновление или клонирование репозитория
update_or_clone_repo() {
  local repo_url="$1"
  local target_dir="$2"
  local repo_name="$3"
  
  if [[ -d "$target_dir" && -d "$target_dir/.git" ]]; then
    # Директория существует и это git-репозиторий
    
    # Сначала выполняем fetch, чтобы получить информацию об изменениях
    if ! (cd "$target_dir" && git fetch -q); then
      sudo -u "$USER" git -C "$target_dir" fetch -q
    fi
    
    # Проверяем, есть ли изменения
    if (cd "$target_dir" && git diff --quiet HEAD origin/HEAD); then
      # Если изменений нет, просто выводим статус об актуальности
      print_operation "Проверка $repo_name" "актуальная версия" "GREEN"
    else
      # Если есть изменения, пытаемся обновить
      if ! (cd "$target_dir" && git pull -q); then
        if sudo -u "$USER" git -C "$target_dir" pull -q; then
          print_operation "Обновление $repo_name" "успешно" "GREEN"
        else
          print_operation "Обновление $repo_name" "ошибка" "RED"
        fi
      else
        print_operation "Обновление $repo_name" "успешно" "GREEN"
      fi
    fi
  else
    # Директория не существует или не является git-репозиторием, клонируем
    
    # Если директория существует, но не является git-репозиторием, удаляем её
    if [[ -d "$target_dir" ]]; then
      rm -rf "$target_dir" || sudo rm -rf "$target_dir"
    fi
    
    if git clone -q "$repo_url" "$target_dir"; then
      print_operation "Клонирование $repo_name" "успешно" "GREEN"
    else
      if sudo git clone -q "$repo_url" "$target_dir"; then
        print_operation "Клонирование $repo_name" "успешно" "GREEN"
      else
        print_operation "Клонирование $repo_name" "ошибка" "RED"
      fi
    fi
  fi
}

# Установка Oh-My-Zsh
if [[ "$ACTION" == "update" ]]; then
  # Обновление Oh-My-Zsh
  if [[ -d "$BASE_DIR/ohmyzsh" ]]; then
    if (cd "$BASE_DIR/ohmyzsh" && git pull -q); then
      print_operation "Обновление Oh-My-Zsh" "успешно" "GREEN"
    else
      print_operation "Обновление Oh-My-Zsh" "ошибка" "RED"
    fi
  else
    print_operation "Директория Oh-My-Zsh не найдена" "будет установлена" "YELLOW"
    mkdir -p "$BASE_DIR/ohmyzsh" || sudo mkdir -p "$BASE_DIR/ohmyzsh"
    if git clone --depth=1 -q "$GIT_OMZ_REPO" "$BASE_DIR/ohmyzsh"; then
      print_operation "Установка Oh-My-Zsh" "успешно" "GREEN"
    else
      print_operation "Установка Oh-My-Zsh" "ошибка" "RED"
    fi
  fi
else
  # Новая установка Oh-My-Zsh
  mkdir -p "$BASE_DIR/ohmyzsh" || sudo mkdir -p "$BASE_DIR/ohmyzsh"
  if git clone --depth=1 -q "$GIT_OMZ_REPO" "$BASE_DIR/ohmyzsh"; then
    print_operation "Установка Oh-My-Zsh" "успешно" "GREEN"
  else
    print_operation "Установка Oh-My-Zsh" "ошибка" "RED"
  fi
fi

# Клонирование/обновление репозиториев
update_or_clone_repo "$GIT_TMUX_REPO" "$BASE_DIR/tmux" "tmux конфигурации"
update_or_clone_repo "$GIT_DOTFILES_REPO" "$BASE_DIR/dotfiles" "dotfiles"

# Создание директорий для vim
if mkdir -p "$VIM_COLORS_DIR" "$VIM_PLUGINS_DIR"; then
  print_operation "Создание директорий для vim" "успешно" "GREEN"
else
  if sudo mkdir -p "$VIM_COLORS_DIR" "$VIM_PLUGINS_DIR"; then
    print_operation "Создание директорий для vim с sudo" "успешно" "GREEN"
  else
    print_operation "Создание директорий для vim" "ошибка" "RED"
  fi
fi

# Клонирование/обновление PaperColor темы
update_or_clone_repo "$GIT_VIM_PAPERCOLOR_REPO" "$VIM_COLORS_DIR/papercolor-theme" "PaperColor темы"

#----------------------------------------------------
# 🧩 Установка плагинов
#----------------------------------------------------

print_group_header "🧩 Установка плагинов"

# Создание директории для плагинов Zsh
if mkdir -p "$BASE_DIR/ohmyzsh/custom/plugins"; then
  print_operation "Создание директории для плагинов Zsh" "успешно" "GREEN"
else
  if sudo mkdir -p "$BASE_DIR/ohmyzsh/custom/plugins"; then
    print_operation "Создание директории для плагинов Zsh с sudo" "успешно" "GREEN"
  else
    print_operation "Создание директории для плагинов Zsh" "ошибка" "RED"
  fi
fi

# Установка/обновление плагинов Zsh
update_or_clone_repo "$GIT_ZSH_AUTOSUGGESTIONS_REPO" "$BASE_DIR/ohmyzsh/custom/plugins/zsh-autosuggestions" "плагина zsh-autosuggestions"
update_or_clone_repo "$GIT_ZSH_SYNTAX_HIGHLIGHTING_REPO" "$BASE_DIR/ohmyzsh/custom/plugins/zsh-syntax-highlighting" "плагина zsh-syntax-highlighting"

#----------------------------------------------------
# ⚙️ Настройка окружения
#----------------------------------------------------

print_group_header "⚙️ Настройка окружения"

# Создание символической ссылки для PaperColor
if ln -sf "$VIM_COLORS_DIR/papercolor-theme/colors/PaperColor.vim" "$VIM_COLORS_DIR/PaperColor.vim"; then
  print_operation "Создание символической ссылки для PaperColor" "успешно" "GREEN"
else
  if sudo ln -sf "$VIM_COLORS_DIR/papercolor-theme/colors/PaperColor.vim" "$VIM_COLORS_DIR/PaperColor.vim"; then
    print_operation "Создание символической ссылки для PaperColor с sudo" "успешно" "GREEN"
  else
    print_operation "Создание символической ссылки для PaperColor" "ошибка" "RED"
  fi
fi

# Настройка zsh
if ln -sf "$BASE_DIR/dotfiles/.zshrc" "$HOME/.zshrc"; then
  print_operation "Настройка zsh" "успешно" "GREEN"
else
  if sudo ln -sf "$BASE_DIR/dotfiles/.zshrc" "$HOME/.zshrc"; then
    print_operation "Настройка zsh с sudo" "успешно" "GREEN"
  else
    print_operation "Настройка zsh" "ошибка" "RED"
  fi
fi

# Настройка vim
if ln -sf "$BASE_DIR/dotfiles/.vimrc" "$HOME/.vimrc" && ln -sfn "$VIM_DIR" "$HOME/.vim"; then
  print_operation "Настройка vim" "успешно" "GREEN"
else
  if sudo ln -sf "$BASE_DIR/dotfiles/.vimrc" "$HOME/.vimrc" && sudo ln -sfn "$VIM_DIR" "$HOME/.vim"; then
    print_operation "Настройка vim с sudo" "успешно" "GREEN"
  else
    print_operation "Настройка vim" "ошибка" "RED"
  fi
fi

# Настройка tmux
if ln -sf "$BASE_DIR/tmux/.tmux.conf" "$HOME/.tmux.conf" && ln -sf "$BASE_DIR/dotfiles/.tmux.conf.local" "$HOME/.tmux.conf.local"; then
  print_operation "Настройка tmux" "успешно" "GREEN"
else
  if sudo ln -sf "$BASE_DIR/tmux/.tmux.conf" "$HOME/.tmux.conf" && sudo ln -sf "$BASE_DIR/dotfiles/.tmux.conf.local" "$HOME/.tmux.conf.local"; then
    print_operation "Настройка tmux с sudo" "успешно" "GREEN"
  else
    print_operation "Настройка tmux" "ошибка" "RED"
  fi
fi

# Настройка Oh-My-Zsh
if ln -sfn "$BASE_DIR/ohmyzsh" "$HOME/.oh-my-zsh"; then
  print_operation "Настройка Oh-My-Zsh" "успешно" "GREEN"
else
  if sudo ln -sfn "$BASE_DIR/ohmyzsh" "$HOME/.oh-my-zsh"; then
    print_operation "Настройка Oh-My-Zsh с sudo" "успешно" "GREEN"
  else
    print_operation "Настройка Oh-My-Zsh" "ошибка" "RED"
  fi
fi

# Создание файла версии
if echo "$SCRIPT_VERSION" > "$BASE_DIR/version"; then
  print_operation "Создание файла версии" "успешно" "GREEN"
else
  if echo "$SCRIPT_VERSION" | sudo tee "$BASE_DIR/version" > /dev/null; then
    print_operation "Создание файла версии с sudo" "успешно" "GREEN"
  else
    print_operation "Создание файла версии" "ошибка" "RED"
  fi
fi

#----------------------------------------------------
# 🧰 Настройка ZShell как оболочки по умолчанию
#----------------------------------------------------

print_group_header "🧰 Настройка ZShell как оболочки по умолчанию"

if [[ "$(basename "$SHELL")" != "zsh" ]]; then
  ZSH_PATH=$(which zsh)
  # Проверяем, есть ли уже zsh в /etc/shells
  if ! grep -q "$ZSH_PATH" /etc/shells; then
    if echo "$ZSH_PATH" | sudo tee -a /etc/shells > /dev/null; then
      print_operation "Добавление zsh в /etc/shells" "успешно" "GREEN"
    else
      print_operation "Добавление zsh в /etc/shells" "ошибка" "RED"
    fi
  else
    print_operation "Проверка наличия zsh в /etc/shells" "уже добавлен" "GREEN"
  fi
  
  # Меняем оболочку по умолчанию с проверкой
  if chsh -s "$ZSH_PATH" 2>/dev/null; then
    print_operation "Установка Zsh по умолчанию" "успешно" "GREEN"
  else
    if sudo chsh -s "$ZSH_PATH" "$USER"; then
      print_operation "Установка Zsh по умолчанию с sudo" "успешно" "GREEN"
    else
      print_operation "Установка Zsh по умолчанию" "ошибка" "RED"
    fi
  fi
else
  print_operation "Проверка текущей оболочки" "Zsh уже используется" "GREEN"
fi

#----------------------------------------------------
# ✅ Завершение установки
#----------------------------------------------------

print_group_header "✅ Завершение установки"

# Установка правильных прав доступа
if sudo chown -R "$USER":"$USER" "$BASE_DIR"; then
  print_operation "Установка прав доступа для директории .myshell" "успешно" "GREEN"
else
  print_operation "Установка прав доступа для директории .myshell" "ошибка" "RED"
fi

# Проверяем, что символические ссылки существуют перед установкой прав
for link in "$HOME/.oh-my-zsh" "$HOME/.vim" "$HOME/.zshrc" "$HOME/.vimrc" "$HOME/.tmux.conf" "$HOME/.tmux.conf.local"; do
  if [[ -L "$link" ]]; then
    if sudo chown -h "$USER":"$USER" "$link" 2>/dev/null; then
      print_operation "Установка прав доступа для $link" "успешно" "GREEN"
    else
      print_operation "Установка прав доступа для $link" "ошибка" "RED"
    fi
  fi
done

# Очистка временной директории
if rm -rf "$HOME/init-shell" 2>/dev/null || sudo rm -rf "$HOME/init-shell"; then
  print_operation "Очистка временной директории" "успешно" "GREEN"
else
  print_operation "Очистка временной директории" "ошибка" "RED"
fi

#----------------------------------------------------
# 🏁 Финальное сообщение
#----------------------------------------------------

# Простая функция для центрирования текста
center_text() {
  local text="$1"
  local width=80
  local padding=$(( (width - ${#text}) / 2 ))
  printf "%${padding}s%s%${padding}s\n" "" "$text" ""
}

# Красивое завершение
echo ""
echo -e "${GREEN}┌────────────────────────────────────────────────────────────────────┐${RESET}"
center_text "${GREEN}🎉  Установка завершена успешно!  🎉${RESET}"
echo -e "${GREEN}└────────────────────────────────────────────────────────────────────┘${RESET}"
echo ""

# Инструкции для пользователя и приглашение в одной рамке
echo -e "${BLUE}┌────────────────────────────────────────────────────────────────────┐${RESET}"
echo -e "${BLUE}│  ℹ️  Чтобы изменения вступили в силу:                               │${RESET}"
echo -e "${BLUE}│                                                                    │${RESET}"
echo -e "${BLUE}│  • Перезапустите терминал                                          │${RESET}"
echo -e "${BLUE}│             или                                                    │${RESET}"
echo -e "${BLUE}│  • Выполните команду: ${CYAN}exec zsh${BLUE}                                  │${RESET}"
echo -e "${BLUE}│                                                                    │${RESET}"
echo -e "${BLUE}│  🚀 Хотите перейти в Zsh прямо сейчас? (y/n): ${RESET}"
read switch_to_zsh
echo -e "${BLUE}└────────────────────────────────────────────────────────────────────┘${RESET}"
echo ""

if [[ "$switch_to_zsh" =~ ^[Yy]$ ]]; then
  echo -e "${GREEN}👋 Переходим в Zsh...${RESET}"
  exec zsh -l
else
  echo -e "${GREEN}👋 До свидания!${RESET}"
fi
