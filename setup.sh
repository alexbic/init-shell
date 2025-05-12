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
      
      print_operation "Архивируем папку $backup_dir" "архивировано" "CYAN"
      
      if ! tar -czf "$archive_path" -C "$backup_dir" .; then
        if sudo tar -czf "$archive_path" -C "$backup_dir" .; then
          print_operation "Архивация с sudo" "успешно" "CYAN"
        else
          print_operation "Архивация" "ошибка" "RED"
          continue
        fi
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
  print_operation "Создание директории для резервных копий" "создано" "CYAN"
  if ! mkdir -p "$BACKUP_DIR"; then
    if sudo mkdir -p "$BACKUP_DIR"; then
      print_operation "Создание директории с sudo" "создано" "CYAN"
    else
      print_operation "Создание директории" "ошибка" "RED"
      exit 1
    fi
  fi
  
  # Создаем директорию для текущего бэкапа
  print_operation "Создание директории для текущего бэкапа" "создано" "CYAN"
  if ! mkdir -p "$DATED_BACKUP_DIR"; then
    if sudo mkdir -p "$DATED_BACKUP_DIR"; then
      print_operation "Создание директории с sudo" "создано" "CYAN"
    else
      print_operation "Создание директории" "ошибка" "RED"
      exit 1
    fi
  fi
  
  # Копируем текущее окружение .myshell (кроме папки backup)
  print_operation "Копирование текущего окружения" "скопировано" "CYAN"
  if ! rsync -a --exclude 'backup/' "$BASE_DIR/" "$DATED_BACKUP_DIR/"; then
    if sudo rsync -a --exclude 'backup/' "$BASE_DIR/" "$DATED_BACKUP_DIR/"; then
      print_operation "Копирование с sudo" "скопировано" "CYAN"
    else
      print_operation "Копирование" "ошибка" "RED"
      exit 1
    fi
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
  print_group_header "🔄 Обновление плагинов"
  
  # Проверка наличия директории .myshell
  if [[ ! -d "$BASE_DIR" ]]; then
    echo -e "${RED}❌ Окружение .myshell не найдено. Сначала установите окружение.${RESET}"
    exit 1
  fi
  
  print_group_header "📦 Обновляем плагины для Zsh"
  
  # Обновление zsh-autosuggestions
  if [[ -d "$BASE_DIR/ohmyzsh/custom/plugins/zsh-autosuggestions" ]]; then
    print_operation "Обновляем zsh-autosuggestions" "обновлено" "CYAN"
    if ! (cd "$BASE_DIR/ohmyzsh/custom/plugins/zsh-autosuggestions" && git pull -q); then
      print_operation "Ошибка обновления, переустанавливаем" "переустановка" "YELLOW"
      rm -rf "$BASE_DIR/ohmyzsh/custom/plugins/zsh-autosuggestions"
      if git clone -q "$GIT_ZSH_AUTOSUGGESTIONS_REPO" "$BASE_DIR/ohmyzsh/custom/plugins/zsh-autosuggestions"; then
        print_operation "Переустановка" "успешно" "CYAN"
      else
        print_operation "Переустановка" "ошибка" "RED"
      fi
    fi
  else
    print_operation "Устанавливаем zsh-autosuggestions" "установлено" "CYAN"
    mkdir -p "$BASE_DIR/ohmyzsh/custom/plugins"
    if git clone -q "$GIT_ZSH_AUTOSUGGESTIONS_REPO" "$BASE_DIR/ohmyzsh/custom/plugins/zsh-autosuggestions"; then
      print_operation "Установка" "успешно" "CYAN"
    else
      print_operation "Установка" "ошибка" "RED"
    fi
  fi
  
  # Обновление zsh-syntax-highlighting
  if [[ -d "$BASE_DIR/ohmyzsh/custom/plugins/zsh-syntax-highlighting" ]]; then
    print_operation "Обновляем zsh-syntax-highlighting" "обновлено" "CYAN"
    if ! (cd "$BASE_DIR/ohmyzsh/custom/plugins/zsh-syntax-highlighting" && git pull -q); then
      print_operation "Ошибка обновления, переустанавливаем" "переустановка" "YELLOW"
      rm -rf "$BASE_DIR/ohmyzsh/custom/plugins/zsh-syntax-highlighting"
      if git clone -q "$GIT_ZSH_SYNTAX_HIGHLIGHTING_REPO" "$BASE_DIR/ohmyzsh/custom/plugins/zsh-syntax-highlighting"; then
        print_operation "Переустановка" "успешно" "CYAN"
      else
        print_operation "Переустановка" "ошибка" "RED"
      fi
    fi
  else
    print_operation "Устанавливаем zsh-syntax-highlighting" "установлено" "CYAN"
    mkdir -p "$BASE_DIR/ohmyzsh/custom/plugins"
    if git clone -q "$GIT_ZSH_SYNTAX_HIGHLIGHTING_REPO" "$BASE_DIR/ohmyzsh/custom/plugins/zsh-syntax-highlighting"; then
      print_operation "Установка" "успешно" "CYAN"
    else
      print_operation "Установка" "ошибка" "RED"
    fi
  fi
  
  print_group_header "📦 Обновляем темы для Vim"
  
  # Обновление PaperColor темы
  if [[ -d "$VIM_COLORS_DIR/papercolor-theme" ]]; then
    print_operation "Обновляем PaperColor тему" "обновлено" "CYAN"
    if ! (cd "$VIM_COLORS_DIR/papercolor-theme" && git pull -q); then
      print_operation "Ошибка обновления, переустанавливаем" "переустановка" "YELLOW"
      rm -rf "$VIM_COLORS_DIR/papercolor-theme"
      if git clone -q "$GIT_VIM_PAPERCOLOR_REPO" "$VIM_COLORS_DIR/papercolor-theme"; then
        print_operation "Переустановка" "успешно" "CYAN"
      else
        print_operation "Переустановка" "ошибка" "RED"
      fi
      fi
  else
    print_operation "Устанавливаем PaperColor тему" "установлено" "CYAN"
    mkdir -p "$VIM_COLORS_DIR"
    if git clone -q "$GIT_VIM_PAPERCOLOR_REPO" "$VIM_COLORS_DIR/papercolor-theme"; then
      print_operation "Установка" "успешно" "CYAN"
    else
      print_operation "Установка" "ошибка" "RED"
    fi
  fi
  
  # Обновление символической ссылки
  print_operation "Обновляем символическую ссылку для PaperColor" "обновлено" "CYAN"
  if ! ln -sf "$VIM_COLORS_DIR/papercolor-theme/colors/PaperColor.vim" "$VIM_COLORS_DIR/PaperColor.vim"; then
    if sudo ln -sf "$VIM_COLORS_DIR/papercolor-theme/colors/PaperColor.vim" "$VIM_COLORS_DIR/PaperColor.vim"; then
      print_operation "Обновление с sudo" "успешно" "CYAN"
    else
      print_operation "Обновление" "ошибка" "RED"
    fi
  fi
  
  echo -e "${GREEN}🎉 Плагины успешно обновлены!${RESET}"
  exit 0
fi

#----------------------------------------------------
# 📦 Обновление и установка зависимостей
#----------------------------------------------------

print_group_header "📦 Проверка и установка необходимых пакетов"

NEEDED_PACKAGES=()
for pkg in $PACKAGES; do
  if ! dpkg -s "$pkg" &>/dev/null; then
    NEEDED_PACKAGES+=("$pkg")
  fi
done

if [[ ${#NEEDED_PACKAGES[@]} -gt 0 ]]; then
  print_operation "Устанавливаем: ${NEEDED_PACKAGES[*]}" "установка" "CYAN"
  if sudo apt update && sudo apt install -y "${NEEDED_PACKAGES[@]}"; then
    print_operation "Установка пакетов" "успешно" "CYAN"
  else
    print_operation "Установка пакетов" "ошибка" "RED"
    echo -e "${RED}❌ Не удалось установить необходимые пакеты. Проверьте соединение и права sudo.${RESET}"
    exit 1
  fi
else
  print_operation "Проверка необходимых пакетов" "актуальная версия" "GREEN"
fi

#----------------------------------------------------
# 🔍 Проверка и обработка существующих конфигураций
#----------------------------------------------------

print_group_header "🔍 Проверка наличия окружения и конфигураций"

# Проверяем наличие директории .myshell
if [[ -d "$BASE_DIR" ]]; then
  print_operation "Обнаружено окружение" ".myshell" "YELLOW"
  
  if [[ "$SAVE_EXISTING" == "y" ]]; then
    # Архивируем предыдущие бэкапы
    archive_previous_backups
    
    # Создаем новую папку для текущего бэкапа
    print_operation "Создание папки для текущего бэкапа" "создано" "CYAN"
    if ! mkdir -p "$DATED_BACKUP_DIR"; then
      if sudo mkdir -p "$DATED_BACKUP_DIR"; then
        print_operation "Создание с sudo" "создано" "CYAN"
      else
        print_operation "Создание" "ошибка" "RED"
        exit 1
      fi
    fi
    
    # Копируем текущее окружение .myshell (кроме папки backup)
    print_operation "Копирование текущего окружения" "скопировано" "CYAN"
    if ! rsync -a --exclude 'backup/' "$BASE_DIR/" "$DATED_BACKUP_DIR/"; then
      if sudo rsync -a --exclude 'backup/' "$BASE_DIR/" "$DATED_BACKUP_DIR/"; then
        print_operation "Копирование с sudo" "скопировано" "CYAN"
      else
        print_operation "Копирование" "ошибка" "RED"
        exit 1
      fi
    fi
  else
    print_warning "Бэкап текущего окружения .myshell" "не создан по выбору пользователя"
  fi
else
  # Если .myshell не найден, проверяем наличие отдельных конфигурационных файлов
  echo -e "${BLUE}🔍 Окружение .myshell не найдено, проверяем наличие отдельных конфигураций...${RESET}"
  
  EXISTING_CONFIGS=""
  [[ -f "$HOME/.zshrc" || -d "$HOME/.oh-my-zsh" ]] && EXISTING_CONFIGS="${EXISTING_CONFIGS}ZSH "
  [[ -f "$HOME/.tmux.conf" || -f "$HOME/.tmux.conf.local" ]] && EXISTING_CONFIGS="${EXISTING_CONFIGS}TMUX "
  [[ -f "$HOME/.vimrc" || -d "$HOME/.vim" ]] && EXISTING_CONFIGS="${EXISTING_CONFIGS}VIM "
  
  if [[ -n "$EXISTING_CONFIGS" ]]; then
    print_warning "Обнаружены существующие конфигурации" "${EXISTING_CONFIGS}"
  
    if [[ "$SAVE_EXISTING" == "y" ]]; then
      print_operation "Создание директорий для бэкапа" "создано" "CYAN"
      
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
            print_operation "Копирование файла по ссылке: $src -> $target" "скопировано" "CYAN"
            if ! cp -pL "$src" "$dst"; then
              if sudo cp -pL "$src" "$dst"; then
                print_operation "Копирование с sudo" "успешно" "CYAN"
              else
                print_operation "Копирование" "ошибка" "RED"
              fi
            fi
          else
            print_warning "Пропускаем битую символическую ссылку" "$src"
          fi
        elif [[ -f "$src" ]]; then
          # Если это обычный файл
          if [[ -s "$src" ]]; then  # Проверка на непустой файл
            print_operation "Копирование файла: $src" "скопировано" "CYAN"
            if ! cp -p "$src" "$dst"; then
              if sudo cp -p "$src" "$dst"; then
                print_operation "Копирование с sudo" "успешно" "CYAN"
              else
                print_operation "Копирование" "ошибка" "RED"
              fi
            fi
          else
            print_warning "Пропускаем пустой файл" "$src"
          fi
        elif [[ -d "$src" ]]; then
          # Если это директория
          print_operation "Копирование директории: $src" "скопировано" "CYAN"
          if ! cp -a "$src" "$dst"; then
            if sudo cp -a "$src" "$dst"; then
              print_operation "Копирование с sudo" "успешно" "CYAN"
            else
              print_operation "Копирование" "ошибка" "RED"
            fi
          fi
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
              print_operation "Копирование .oh-my-zsh -> $omz_target" "скопировано" "CYAN"
              if ! cp -a "$omz_target" "$DATED_BACKUP_DIR/zsh/oh-my-zsh"; then
                if sudo cp -a "$omz_target" "$DATED_BACKUP_DIR/zsh/oh-my-zsh"; then
                  print_operation "Копирование с sudo" "успешно" "CYAN"
                else
                  print_operation "Копирование" "ошибка" "RED"
                fi
              fi
            else
              print_warning "Ссылка .oh-my-zsh указывает на несуществующую директорию" "$omz_target"
            fi
          else
            print_operation "Копирование .oh-my-zsh" "скопировано" "CYAN"
            if ! cp -a "$HOME/.oh-my-zsh" "$DATED_BACKUP_DIR/zsh/"; then
              if sudo cp -a "$HOME/.oh-my-zsh" "$DATED_BACKUP_DIR/zsh/"; then
                print_operation "Копирование с sudo" "успешно" "CYAN"
              else
                print_operation "Копирование" "ошибка" "RED"
              fi
            fi
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
              print_operation "Копирование .vim -> $vim_target" "скопировано" "CYAN"
              if ! cp -a "$vim_target" "$DATED_BACKUP_DIR/vim/vim"; then
                if sudo cp -a "$vim_target" "$DATED_BACKUP_DIR/vim/vim"; then
                  print_operation "Копирование с sudo" "успешно" "CYAN"
                else
                  print_operation "Копирование" "ошибка" "RED"
                fi
              fi
            else
              print_warning "Ссылка .vim указывает на несуществующую директорию" "$vim_target"
            fi
          else
            print_operation "Копирование .vim" "скопировано" "CYAN"
            if ! cp -a "$HOME/.vim" "$DATED_BACKUP_DIR/vim/"; then
              if sudo cp -a "$HOME/.vim" "$DATED_BACKUP_DIR/vim/"; then
                print_operation "Копирование с sudo" "успешно" "CYAN"
              else
                print_operation "Копирование" "ошибка" "RED"
              fi
            fi
          fi
        fi
      fi
      
      echo -e "${GREEN}✅ Бэкап сохранен в $DATED_BACKUP_DIR${RESET}"
    else
      print_warning "Бэкап не создан" "по выбору пользователя"
    fi
  else
    print_operation "Существующие конфигурации" "не обнаружены" "GREEN"
  fi
fi

# Пропускаем следующие блоки, если выбранное действие - update (не нужно очищать директорию)
if [[ "$ACTION" != "update" ]]; then
  #----------------------------------------------------
  # 🛠️ Подготовка окружения для установки
  #----------------------------------------------------

  # Очищаем содержимое директории .myshell (кроме директории backup)
  print_operation "Очищаем содержимое директории $BASE_DIR (кроме бэкапов)" "очищено" "CYAN"
  if ! find "$BASE_DIR" -mindepth 1 ! -path "$BACKUP_DIR" ! -path "$BACKUP_DIR/*" -print0 | xargs -0 rm -rf 2>/dev/null; then
    if sudo find "$BASE_DIR" -mindepth 1 ! -path "$BACKUP_DIR" ! -path "$BACKUP_DIR/*" -print0 | xargs -0 sudo rm -rf; then
      print_operation "Очистка с sudo" "успешно" "CYAN"
    else
      print_operation "Очистка" "ошибка" "RED"
    fi
  fi
fi

#----------------------------------------------------
# 📦 Установка и настройка Oh-My-Zsh
#----------------------------------------------------

# Функция для безопасного удаления Oh-My-Zsh
clean_ohmyzsh() {
  print_group_header "🧹 Удаление предыдущей установки Oh-My-Zsh"
  
  if [[ -L "$HOME/.oh-my-zsh" ]]; then
    print_operation "Удаляем символическую ссылку .oh-my-zsh" "удалено" "CYAN"
    if ! ( cd "$HOME" && exec /bin/rm -f .oh-my-zsh ); then
      if sudo rm -f "$HOME/.oh-my-zsh"; then
        print_operation "Удаление с sudo" "успешно" "CYAN"
      else
        print_operation "Удаление" "ошибка" "RED"
        return 1
      fi
    fi
  elif [[ -d "$HOME/.oh-my-zsh" ]]; then
    print_operation "Удаляем директорию .oh-my-zsh" "удалено" "CYAN"
    if ! /bin/rm -rf "$HOME/.oh-my-zsh"; then
      if sudo /bin/rm -rf "$HOME/.oh-my-zsh"; then
        print_operation "Удаление с sudo" "успешно" "CYAN"
      else
        print_operation "Удаление" "ошибка" "RED"
        return 1
      fi
    fi
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
  print_operation "Установка Oh-My-Zsh" "установлено" "CYAN"
  
  # Очищаем и создаем директорию в нашем окружении
  mkdir -p "$BASE_DIR/ohmyzsh" || sudo mkdir -p "$BASE_DIR/ohmyzsh"
  
  # Клонируем репозиторий Oh-My-Zsh напрямую в наше окружение
  if git clone --depth=1 -q "$GIT_OMZ_REPO" "$BASE_DIR/ohmyzsh"; then
    print_operation "Клонирование репозитория" "успешно" "CYAN"
    return 0
  else
    print_operation "Клонирование репозитория" "ошибка" "RED"
    echo -e "${RED}❌ Ошибка при клонировании репозитория Oh-My-Zsh${RESET}"
    return 1
  fi
}

# Функция для обновления Oh-My-Zsh
update_ohmyzsh() {
  print_operation "Обновление Oh-My-Zsh" "обновлено" "CYAN"
  
  if [[ -d "$BASE_DIR/ohmyzsh" ]]; then
    # Если Oh-My-Zsh находится в нашем окружении
    # Сначала выполняем fetch, чтобы получить информацию об изменениях
    if ! (cd "$BASE_DIR/ohmyzsh" && git fetch -q); then
      sudo -u "$USER" git -C "$BASE_DIR/ohmyzsh" fetch -q
    fi
    
    # Проверяем, есть ли изменения
    if (cd "$BASE_DIR/ohmyzsh" && git diff --quiet HEAD origin/HEAD); then
      print_operation "Статус Oh-My-Zsh" "актуальная версия" "GREEN"
      return 0
    else
      if ! (cd "$BASE_DIR/ohmyzsh" && git pull -q); then
        if sudo -u "$USER" git -C "$BASE_DIR/ohmyzsh" pull -q; then
          print_operation "Обновление с sudo" "успешно" "CYAN"
          return 0
        else
          print_operation "Обновление" "ошибка" "RED"
          return 1
        fi
      else
        print_operation "Обновление" "успешно" "CYAN"
        return 0
      fi
    fi
  elif [[ -x "$HOME/.oh-my-zsh/tools/upgrade.sh" ]]; then
    # Если это внешняя установка Oh-My-Zsh
    # Запускаем обновление
    export RUNZSH=no
    export KEEP_ZSHRC=yes
    
    if "$HOME/.oh-my-zsh/tools/upgrade.sh" --unattended &>/dev/null; then
      print_operation "Обновление внешней установки" "успешно" "CYAN"
      return 0
    else
      print_operation "Обновление внешней установки" "ошибка" "RED"
      return 1
    fi
  fi
  
  print_operation "Обновление Oh-My-Zsh" "невозможно" "RED"
  return 1
}

# Основной блок управления Oh-My-Zsh
print_group_header "📦 Настройка Oh-My-Zsh"

if [[ "$ACTION" == "update" ]]; then
  # Если выбрано обновление, просто обновляем Oh-My-Zsh
  update_ohmyzsh || {
    print_warning "Не удалось обновить Oh-My-Zsh" "пропускаем"
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
      print_operation "Удаляем симлинк: $target" "удалено" "CYAN"
      if ! rm "$target" 2>/dev/null; then
        if sudo rm "$target"; then
          print_operation "Удаление с sudo" "успешно" "CYAN"
        else
          print_operation "Удаление" "ошибка" "RED"
        fi
      fi
    elif [[ -f "$target" ]]; then
      print_operation "Удаляем файл: $target" "удалено" "CYAN"
      if ! rm "$target" 2>/dev/null; then
        if sudo rm "$target"; then
          print_operation "Удаление с sudo" "успешно" "CYAN"
        else
          print_operation "Удаление" "ошибка" "RED"
        fi
      fi
    elif [[ -d "$target" ]]; then
      print_operation "Удаляем директорию: $target" "удалено" "CYAN"
      if ! rm -rf "$target" 2>/dev/null; then
        if sudo rm -rf "$target"; then
          print_operation "Удаление с sudo" "успешно" "CYAN"
        else
          print_operation "Удаление" "ошибка" "RED"
        fi
      fi
    else
      print_operation "Пропускаем: $target (не найден)" "пропущено" "GREEN"
    fi
  }

  # Удаление старых конфигов и симлинков
  print_group_header "🧹 Удаляем старые конфиги и симлинки"

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
    # Директория существует и это git-репозиторий
    print_operation "Обновляем $repo_name" "обновлено" "CYAN"
    
    # Сначала выполняем fetch, чтобы получить информацию об изменениях
    if ! (cd "$target_dir" && git fetch -q); then
      sudo -u "$USER" git -C "$target_dir" fetch -q
    fi
    
    # Проверяем, есть ли изменения
    if (cd "$target_dir" && git diff --quiet HEAD origin/HEAD); then
      print_operation "Статус $repo_name" "актуальная версия" "GREEN"
    else
      if ! (cd "$target_dir" && git pull -q); then
        if sudo -u "$USER" git -C "$target_dir" pull -q; then
          print_operation "Обновление с sudo" "успешно" "CYAN"
        else
          print_operation "Обновление" "ошибка" "RED"
        fi
      else
        print_operation "Обновление" "успешно" "CYAN"
      fi
    fi
  else
    # Директория не существует или не является git-репозиторием, клонируем
    print_operation "Клонируем $repo_name" "клонировано" "CYAN"
    
    # Если директория существует, но не является git-репозиторием, удаляем её
    if [[ -d "$target_dir" ]]; then
      rm -rf "$target_dir" || sudo rm -rf "$target_dir"
    fi
    
    if git clone -q "$repo_url" "$target_dir"; then
      print_operation "Клонирование" "успешно" "CYAN"
    else
      if sudo git clone -q "$repo_url" "$target_dir"; then
        print_operation "Клонирование с sudo" "успешно" "CYAN"
      else
        print_operation "Клонирование" "ошибка" "RED"
      fi
    fi
  fi
}

# Обновляем или клонируем tmux конфигурацию
update_or_clone_repo "$GIT_TMUX_REPO" "$BASE_DIR/tmux" "tmux конфигурацию"

# Обновляем или клонируем dotfiles
update_or_clone_repo "$GIT_DOTFILES_REPO" "$BASE_DIR/dotfiles" "dotfiles"

# Создаем директории для vim, если они не существуют
print_operation "Создание директорий для vim" "создано" "CYAN"
if ! mkdir -p "$VIM_COLORS_DIR" "$VIM_PLUGINS_DIR"; then
  if sudo mkdir -p "$VIM_COLORS_DIR" "$VIM_PLUGINS_DIR"; then
    print_operation "Создание с sudo" "успешно" "CYAN"
  else
    print_operation "Создание" "ошибка" "RED"
  fi
fi

# Обновляем или клонируем PaperColor тему
update_or_clone_repo "$GIT_VIM_PAPERCOLOR_REPO" "$VIM_COLORS_DIR/papercolor-theme" "PaperColor тему"

# Создаем символическую ссылку для PaperColor
print_operation "Создание символической ссылки для PaperColor" "создано" "CYAN"
if ! ln -sf "$VIM_COLORS_DIR/papercolor-theme/colors/PaperColor.vim" "$VIM_COLORS_DIR/PaperColor.vim"; then
  if sudo ln -sf "$VIM_COLORS_DIR/papercolor-theme/colors/PaperColor.vim" "$VIM_COLORS_DIR/PaperColor.vim"; then
    print_operation "Создание с sudo" "успешно" "CYAN"
  else
    print_operation "Создание" "ошибка" "RED"
  fi
fi

print_group_header "📦 Устанавливаем плагины для Zsh"

print_operation "Создание директории для плагинов" "создано" "CYAN"
if ! mkdir -p "$BASE_DIR/ohmyzsh/custom/plugins"; then
  if sudo mkdir -p "$BASE_DIR/ohmyzsh/custom/plugins"; then
    print_operation "Создание с sudo" "успешно" "CYAN"
  else
    print_operation "Создание" "ошибка" "RED"
  fi
fi

# Обновляем или клонируем zsh-autosuggestions
update_or_clone_repo "$GIT_ZSH_AUTOSUGGESTIONS_REPO" "$BASE_DIR/ohmyzsh/custom/plugins/zsh-autosuggestions" "zsh-autosuggestions"

# Обновляем или клонируем zsh-syntax-highlighting
update_or_clone_repo "$GIT_ZSH_SYNTAX_HIGHLIGHTING_REPO" "$BASE_DIR/ohmyzsh/custom/plugins/zsh-syntax-highlighting" "zsh-syntax-highlighting"

#----------------------------------------------------
# ⚙️ Настройки окружения
#----------------------------------------------------

print_group_header "⚙️ Настраиваем окружение"

print_operation "Настраиваем zsh" "настроено" "CYAN"
if ! ln -sf "$BASE_DIR/dotfiles/.zshrc" "$HOME/.zshrc"; then
  if sudo ln -sf "$BASE_DIR/dotfiles/.zshrc" "$HOME/.zshrc"; then
    print_operation "Настройка с sudo" "успешно" "CYAN"
  else
    print_operation "Настройка" "ошибка" "RED"
  fi
fi

print_operation "Настраиваем vim" "настроено" "CYAN"
if ! (ln -sf "$BASE_DIR/dotfiles/.vimrc" "$HOME/.vimrc" && ln -sfn "$VIM_DIR" "$HOME/.vim"); then
  if sudo ln -sf "$BASE_DIR/dotfiles/.vimrc" "$HOME/.vimrc" && sudo ln -sfn "$VIM_DIR" "$HOME/.vim"; then
    print_operation "Настройка с sudo" "успешно" "CYAN"
  else
    print_operation "Настройка" "ошибка" "RED"
  fi
fi

print_operation "Настраиваем tmux" "настроено" "CYAN"
if ! (ln -sf "$BASE_DIR/tmux/.tmux.conf" "$HOME/.tmux.conf" && ln -sf "$BASE_DIR/dotfiles/.tmux.conf.local" "$HOME/.tmux.conf.local"); then
  if sudo ln -sf "$BASE_DIR/tmux/.tmux.conf" "$HOME/.tmux.conf" && sudo ln -sf "$BASE_DIR/dotfiles/.tmux.conf.local" "$HOME/.tmux.conf.local"; then
    print_operation "Настройка с sudo" "успешно" "CYAN"
  else
    print_operation "Настройка" "ошибка" "RED"
  fi
fi

print_operation "Настраиваем Oh-My-Zsh" "настроено" "CYAN"
if ! ln -sfn "$BASE_DIR/ohmyzsh" "$HOME/.oh-my-zsh"; then
  if sudo ln -sfn "$BASE_DIR/ohmyzsh" "$HOME/.oh-my-zsh"; then
    print_operation "Настройка с sudo" "успешно" "CYAN"
  else
    print_operation "Настройка" "ошибка" "RED"
  fi
fi

# Создаем файл версии
print_operation "Создание файла версии" "создано" "CYAN"
if ! echo "$SCRIPT_VERSION" > "$BASE_DIR/version"; then
  if echo "$SCRIPT_VERSION" | sudo tee "$BASE_DIR/version" > /dev/null; then
    print_operation "Создание с sudo" "успешно" "CYAN"
  else
    print_operation "Создание" "ошибка" "RED"
  fi
fi

#----------------------------------------------------
# 🧰 Проверка и установка ZShell по умолчанию
#----------------------------------------------------

if [[ "$(basename "$SHELL")" != "zsh" ]]; then
  print_group_header "🔁 Меняем shell на Zsh"
  
  ZSH_PATH=$(which zsh)
  # Проверяем, есть ли уже zsh в /etc/shells
  if ! grep -q "$ZSH_PATH" /etc/shells; then
    print_operation "Проверка наличия zsh в /etc/shells" "требуется добавление" "YELLOW"
    if echo "$ZSH_PATH" | sudo tee -a /etc/shells > /dev/null; then
      print_operation "Добавление zsh в /etc/shells" "добавлено" "CYAN"
    else
      print_operation "Добавление zsh" "ошибка" "RED"
    fi
  else
    print_operation "Проверка наличия zsh в /etc/shells" "уже добавлен" "GREEN"
  fi
  
  # Меняем оболочку по умолчанию с проверкой
  print_operation "Меняем shell на Zsh для пользователя $USER" "изменено" "CYAN"
  if ! chsh -s "$ZSH_PATH" 2>/dev/null; then
    if sudo chsh -s "$ZSH_PATH" "$USER"; then
      print_operation "Изменение с sudo" "успешно" "CYAN"
    else
      print_operation "Изменение" "ошибка" "RED"
    fi
  fi
else
  print_operation "Проверка текущего shell" "актуальная версия" "GREEN"
fi

#----------------------------------------------------
# 🧰 Проверка и установка ZShell по умолчанию
#----------------------------------------------------

if [[ "$(basename "$SHELL")" != "zsh" ]]; then
  print_group_header "🔁 Меняем shell на Zsh"
  
  ZSH_PATH=$(which zsh)
  # Проверяем, есть ли уже zsh в /etc/shells
  if ! grep -q "$ZSH_PATH" /etc/shells; then
    print_operation "Проверка наличия zsh в /etc/shells" "требуется добавление" "YELLOW"
    if echo "$ZSH_PATH" | sudo tee -a /etc/shells > /dev/null; then
      print_operation "Добавление zsh в /etc/shells" "добавлено" "CYAN"
    else
      print_operation "Добавление zsh" "ошибка" "RED"
    fi
  else
    print_operation "Проверка наличия zsh в /etc/shells" "уже добавлен" "GREEN"
  fi
  
  # Меняем оболочку по умолчанию с проверкой
  print_operation "Меняем shell на Zsh для пользователя $USER" "изменено" "CYAN"
  if ! chsh -s "$ZSH_PATH" 2>/dev/null; then
    if sudo chsh -s "$ZSH_PATH" "$USER"; then
      print_operation "Изменение с sudo" "успешно" "CYAN"
    else
      print_operation "Изменение" "ошибка" "RED"
    fi
  fi
else
  print_operation "Проверка текущего shell" "актуальная версия" "GREEN"
fi




      
