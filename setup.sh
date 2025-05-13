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

# Константы для управления резервными копиями
MAX_BACKUPS=10  # Максимальное количество хранимых копий (не включая первоначальную)
INITIAL_BACKUP_NAME="initial_backup"  # Имя для первоначальной копии

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
SCRIPT_VERSION="1.0.2"

# Инициализация переменных для интерактивного режима
ACTION=""
SAVE_EXISTING=""

# Файл для хранения логов ошибок
LOG_FILE="$HOME/.myshell_install_error.log"

# Инициализация лог-файла
> "$LOG_FILE"

#----------------------------------------------------
# 🎨 Функции для стилизованного вывода
#----------------------------------------------------

# Функция для записи ошибок в лог
log_error() {
  local message="$1"
  echo "$(date '+%Y-%m-%d %H:%M:%S') - ERROR: $message" >> "$LOG_FILE"
}

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
  local message="$1"
  local result="$2"
  
  # Записываем ошибку в лог
  log_error "$message: $result"
  
  # Выводим сообщение об ошибке
  print_message_with_dots "└─→" "$message" "$result" "RED" "  "
}

# Простая функция для центрирования текста
center_text() {
  local text="$1"
  local width=70 # Ширина содержимого внутри рамки
  local padding=$(( (width - ${#text}) / 2 ))
  
  # Проверка на отрицательное значение padding
  if (( padding < 0 )); then
    padding=0
  fi
  
  printf "%${padding}s%s%${padding}s" "" "$text" ""
}

#----------------------------------------------------
# 🛡️ Обработка прерывания (Ctrl+C)
#----------------------------------------------------

# Функция для очистки при прерывании
cleanup_on_interrupt() {
  echo -e "\n${YELLOW}⚠️  Получен сигнал прерывания. Выполняем очистку...${RESET}"
  
  # Проверяем наличие временной директории и удаляем её
  for tmp_dir in "$HOME/init-shell" "$BACKUP_DIR/tmp_extract" "$BACKUP_DIR/tmp_backup_before_restore"; do
    if [[ -d "$tmp_dir" ]]; then
      echo -e "${BLUE}🗑️  Удаляем временную директорию $tmp_dir...${RESET}"
      rm -rf "$tmp_dir" 2>/dev/null || sudo rm -rf "$tmp_dir"
    fi
  done
  
  echo -e "${GREEN}👋 Скрипт прерван. До свидания!${RESET}"
  exit 1
}

# Устанавливаем ловушку для сигнала прерывания
trap cleanup_on_interrupt SIGINT SIGTERM

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
  echo -e ""
  echo -e "${BLUE}💡 Терминальное окружение для ${CYAN}Linux${RESET} (Debian)"

  echo -e "${WHITE}Zsh + Oh-My-Zsh${RESET} ${RU_BLUE}Tmux${RESET} ${RU_RED}Vim${RESET} " 

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

# Функция для отображения информации о существующем окружении
show_environment_status() {
  local result=""
  
  if [[ -d "$BASE_DIR" ]]; then
    result="${result}${GREEN}✓ Окружение MYSHELL установлено${RESET}\n"
    
    # Информация о версии
    if [[ -f "$BASE_DIR/version" ]]; then
      local version=$(cat "$BASE_DIR/version")
      result="${result}${GREEN}✓ Версия: $version${RESET}\n"
    else
      result="${result}${YELLOW}⚠️ Версия не определена${RESET}\n"
    fi
    
    # Информация о компонентах
    result="${result}${BLUE}📋 Установленные компоненты:${RESET}\n"
    [[ -d "$BASE_DIR/ohmyzsh" ]] && result="${result}  ${GREEN}✓ Oh-My-Zsh${RESET}\n" || result="${result}  ${RED}✗ Oh-My-Zsh (отсутствует)${RESET}\n"
    [[ -d "$BASE_DIR/tmux" ]] && result="${result}  ${GREEN}✓ Tmux${RESET}\n" || result="${result}  ${RED}✗ Tmux (отсутствует)${RESET}\n"
    [[ -d "$BASE_DIR/vim" ]] && result="${result}  ${GREEN}✓ Vim${RESET}\n" || result="${result}  ${RED}✗ Vim (отсутствует)${RESET}\n"
    [[ -d "$BASE_DIR/dotfiles" ]] && result="${result}  ${GREEN}✓ Dotfiles${RESET}\n" || result="${result}  ${RED}✗ Dotfiles (отсутствуют)${RESET}\n"
  else
    result="${result}${YELLOW}⚠️ Окружение MYSHELL не установлено${RESET}\n"
    
    # Информация о существующих конфигурациях
    result="${result}${BLUE}📋 Обнаружены конфигурации:${RESET}\n"
    [[ -f "$HOME/.zshrc" || -d "$HOME/.oh-my-zsh" ]] && result="${result}  ${GREEN}✓ Zsh/Oh-My-Zsh${RESET}\n" || result="${result}  ${GRAY}✗ Zsh/Oh-My-Zsh${RESET}\n"
    [[ -f "$HOME/.tmux.conf" ]] && result="${result}  ${GREEN}✓ Tmux${RESET}\n" || result="${result}  ${GRAY}✗ Tmux${RESET}\n"
    [[ -f "$HOME/.vimrc" || -d "$HOME/.vim" ]] && result="${result}  ${GREEN}✓ Vim${RESET}\n" || result="${result}  ${GRAY}✗ Vim${RESET}\n"
  fi
  
  echo -e "$result"
}

# Функция для отображения информации о резервных копиях
show_backup_info() {
  local result=""
  
  # Проверка наличия первоначальной копии
  if [[ -d "$BACKUP_DIR/$INITIAL_BACKUP_NAME" || -f "$BACKUP_DIR/${INITIAL_BACKUP_NAME}.tar.gz" ]]; then
    result="${result}${GREEN}✓ Первоначальная резервная копия (до установки MYSHELL)${RESET}\n"
  else
    result="${result}${YELLOW}⚠️ Первоначальная резервная копия отсутствует${RESET}\n"
  fi
  
  # Подсчет обычных резервных копий
  local backup_count=0
  local latest_backup=""
  
  # Директории бэкапов
  if [[ -d "$BACKUP_DIR" ]]; then
    while IFS= read -r dir; do
      dir_name=$(basename "$dir")
      if [[ -d "$dir" && "$dir_name" != "$INITIAL_BACKUP_NAME" && "$dir_name" == backup_* ]]; then
        backup_count=$((backup_count + 1))
        latest_backup="$dir_name"
      fi
    done < <(find "$BACKUP_DIR" -mindepth 1 -maxdepth 1 -type d 2>/dev/null || echo "")
    
    # Архивы бэкапов
    while IFS= read -r archive; do
      archive_name=$(basename "$archive" .tar.gz)
      if [[ -f "$archive" && "$archive_name" != "$INITIAL_BACKUP_NAME" && "$archive_name" == backup_* ]]; then
        backup_count=$((backup_count + 1))
      fi
    done < <(find "$BACKUP_DIR" -mindepth 1 -maxdepth 1 -name "*.tar.gz" 2>/dev/null || echo "")
  fi
  
  if [[ $backup_count -gt 0 ]]; then
    result="${result}${GREEN}✓ Найдено $backup_count резервных копий${RESET}\n"
    [[ -n "$latest_backup" ]] && result="${result}${GREEN}✓ Последняя копия: $latest_backup${RESET}\n"
  else
    result="${result}${YELLOW}⚠️ Резервные копии отсутствуют${RESET}\n"
  fi
  
  echo -e "$result"
}

# Функция для проверки доступного места на диске
check_disk_space() {
  local target_dir="$1"
  local required_space="$2" # в МБ
  
  # Получаем доступное место в байтах и переводим в МБ
  local available_space
  available_space=$(df -P "$(dirname "$target_dir")" | awk 'NR==2 {print $4}')
  available_space=$((available_space / 1024)) # Перевод в МБ
  
  if [[ $available_space -lt $required_space ]]; then
    return 1 # Недостаточно места
  else
    return 0 # Место есть
  fi
}

# Улучшенная функция для управления резервными копиями
manage_backups() {
  # Проверка наличия директории $BACKUP_DIR и создание её при необходимости
  if [[ ! -d "$BACKUP_DIR" ]]; then
    if ! mkdir -p "$BACKUP_DIR"; then
      if sudo mkdir -p "$BACKUP_DIR"; then
        print_operation "Создание директории для резервных копий" "успешно" "GREEN"
      else
        print_error "Создание директории для резервных копий" "ошибка"
        return 1
      fi
    fi
  fi
  
  # Проверяем, существует ли первоначальная копия
  local has_initial_backup=$([[ -d "$BACKUP_DIR/$INITIAL_BACKUP_NAME" || -f "$BACKUP_DIR/${INITIAL_BACKUP_NAME}.tar.gz" ]] && echo "true" || echo "false")
  
  # Если это первая установка и первоначальная копия не существует
  if [[ "$ACTION" == "install" && "$has_initial_backup" == "false" ]]; then
    # Проверка доступного места
    if ! check_disk_space "$BACKUP_DIR" 500; then
      print_warning "Мало места на диске для создания резервной копии" "продолжаем без бэкапа"
      return 0
    fi
    
    # Создаем первоначальную копию для возможности возврата к исходным настройкам
    if ! mkdir -p "$BACKUP_DIR/$INITIAL_BACKUP_NAME"; then
      if sudo mkdir -p "$BACKUP_DIR/$INITIAL_BACKUP_NAME"; then
        print_operation "Создание директории для первоначальной копии" "успешно" "GREEN"
      else
        print_error "Создание директории для первоначальной копии" "ошибка"
        return 1
      fi
    fi
    
    # Сохраняем все найденные конфигурационные файлы
    local found_configs=false
    
    for item in $TRASH; do
      for target in $HOME/$item; do
        if [[ -e "$target" || -L "$target" ]]; then
          found_configs=true
          # Копируем файл или директорию
          if [[ -L "$target" ]]; then
            # Для символических ссылок сохраняем как исходную ссылку, так и её содержимое
            local link_target=$(readlink -f "$target")
            local base_name=$(basename "$target")
            
            # Сохраняем информацию о ссылке
            echo "SYMLINK: $target -> $link_target" > "$BACKUP_DIR/$INITIAL_BACKUP_NAME/${base_name}.symlink_info"
            
            # Копируем содержимое, если оно существует
            if [[ -e "$link_target" ]]; then
              if [[ -d "$link_target" ]]; then
                # Для директорий используем rsync для сохранения прав доступа и атрибутов
                if ! rsync -a "$link_target/" "$BACKUP_DIR/$INITIAL_BACKUP_NAME/$base_name/"; then
                  if sudo rsync -a "$link_target/" "$BACKUP_DIR/$INITIAL_BACKUP_NAME/$base_name/"; then
                    print_operation "Копирование содержимого ссылки $base_name" "успешно" "GREEN"
                  else
                    print_error "Копирование содержимого ссылки $base_name" "ошибка"
                  fi
                else
                  print_operation "Копирование содержимого ссылки $base_name" "успешно" "GREEN"
                fi
              else
                # Для файлов используем cp с сохранением атрибутов
                if ! cp -a "$link_target" "$BACKUP_DIR/$INITIAL_BACKUP_NAME/$base_name"; then
                  if sudo cp -a "$link_target" "$BACKUP_DIR/$INITIAL_BACKUP_NAME/$base_name"; then
                    print_operation "Копирование файла по ссылке $base_name" "успешно" "GREEN"
                  else
                    print_error "Копирование файла по ссылке $base_name" "ошибка"
                  fi
                else
                  print_operation "Копирование файла по ссылке $base_name" "успешно" "GREEN"
                fi
              fi
            else
              print_warning "Ссылка $base_name указывает на несуществующий объект" "пропущено"
            fi
          } else if [[ -d "$target" ]]; then
            # Для директорий используем rsync
            if ! rsync -a "$target/" "$BACKUP_DIR/$INITIAL_BACKUP_NAME/$(basename "$target")/"; then
              if sudo rsync -a "$target/" "$BACKUP_DIR/$INITIAL_BACKUP_NAME/$(basename "$target")/"; then
                print_operation "Копирование директории $(basename "$target")" "успешно" "GREEN"
              else
                print_error "Копирование директории $(basename "$target")" "ошибка"
              fi
            else
              print_operation "Копирование директории $(basename "$target")" "успешно" "GREEN"
            fi
          else
            # Для обычных файлов
            if ! cp -a "$target" "$BACKUP_DIR/$INITIAL_BACKUP_NAME/"; then
              if sudo cp -a "$target" "$BACKUP_DIR/$INITIAL_BACKUP_NAME/"; then
                print_operation "Копирование файла $(basename "$target")" "успешно" "GREEN"
              else
                print_error "Копирование файла $(basename "$target")" "ошибка"
              fi
            else
              print_operation "Копирование файла $(basename "$target")" "успешно" "GREEN"
            fi
          fi
        fi
      done
    done
    
    if $found_configs; then
      # Добавляем README в первоначальную копию
      cat > "$BACKUP_DIR/$INITIAL_BACKUP_NAME/README.md" << EOF
# Initial backup of system configuration before MYSHELL installation
Created: $(date)
This backup contains the original system configuration and can be used to restore all settings if you decide to remove MYSHELL.

## Backed up files and directories:
$(find "$BACKUP_DIR/$INITIAL_BACKUP_NAME" -type f -not -path "*/\.*" | sort)
EOF
      
      print_operation "Создание первоначальной резервной копии" "успешно" "GREEN"
    else
      print_operation "Создание первоначальной резервной копии" "нет конфигураций" "YELLOW"
      # Удаляем пустую директорию, так как копировать было нечего
      rm -rf "$BACKUP_DIR/$INITIAL_BACKUP_NAME"
    fi
  fi
  
  # Подсчитываем количество обычных резервных копий (исключая первоначальную)
  local backup_dirs=()
  while IFS= read -r dir; do
    dir_name=$(basename "$dir")
    # Исключаем первоначальную копию и временные директории, ищем только папки, начинающиеся с "backup_"
    if [[ -d "$dir" && "$dir_name" != "$INITIAL_BACKUP_NAME" && "$dir_name" != "tmp_"* && "$dir_name" == backup_* ]]; then
      backup_dirs+=("$dir")
    fi
  done < <(find "$BACKUP_DIR" -mindepth 1 -maxdepth 1 -type d 2>/dev/null || echo "")
  
  # Сортируем директории по имени (они содержат временные метки, поэтому сортировка даст нам порядок по времени)
  IFS=$'\n' backup_dirs=($(for d in "${backup_dirs[@]}"; do echo "$d"; done | sort))
  unset IFS
  
  # Если превышено максимальное количество копий, архивируем и удаляем самые старые
  if [[ ${#backup_dirs[@]} -ge $MAX_BACKUPS ]]; then
    # Подсчитываем, сколько нужно удалить
    local to_remove=$((${#backup_dirs[@]} - $MAX_BACKUPS + 1))  # +1 для создания новой копии
    
    print_operation "Обнаружено превышение лимита резервных копий" "$to_remove для удаления" "YELLOW"
    
    # Удаляем самые старые копии
    for ((i=0; i<$to_remove; i++)); do
      local old_dir="${backup_dirs[$i]}"
      local dir_name=$(basename "$old_dir")
      local archive_path="$BACKUP_DIR/$dir_name.tar.gz"
      
      # Проверка доступного места для архивации
      local dir_size=$(du -sm "$old_dir" | cut -f1)
      if ! check_disk_space "$BACKUP_DIR" $((dir_size + 100)); then
        print_warning "Недостаточно места для архивации $dir_name" "удаляем без архивации"
        # Просто удаляем директорию без архивации
        if ! rm -rf "$old_dir"; then
          if sudo rm -rf "$old_dir"; then
            print_operation "Удаление старой копии $dir_name" "успешно" "GREEN"
          else
            print_error "Удаление старой копии $dir_name" "ошибка"
          fi
        else
       print_operation "Удаление старой копии $dir_name" "успешно" "GREEN"
        fi
        continue
      }
      
      # Архивируем перед удалением
      if ! tar -czf "$archive_path" -C "$old_dir" .; then
        if sudo tar -czf "$archive_path" -C "$old_dir" .; then
          print_operation "Архивация старой копии $dir_name" "успешно" "GREEN"
        else
          print_error "Архивация старой копии $dir_name" "ошибка"
          continue
        fi
      else
        print_operation "Архивация старой копии $dir_name" "успешно" "GREEN"
      fi
      
      # Удаляем директорию
      if ! rm -rf "$old_dir"; then
        if sudo rm -rf "$old_dir"; then
          print_operation "Удаление старой копии $dir_name" "успешно" "GREEN"
        else
          print_error "Удаление старой копии $dir_name" "ошибка"
        fi
      else
        print_operation "Удаление старой копии $dir_name" "успешно" "GREEN"
      fi
    done
  fi
  
  return 0
}

# Функция для создания новой резервной копии
create_backup() {
  clear
  print_group_header "💾 Создание новой резервной копии"
  
  # Проверка наличия директории .myshell
  if [[ ! -d "$BASE_DIR" ]]; then
    echo -e "${RED}❌ Окружение .myshell не найдено. Нечего сохранять.${RESET}"
    read -p "⏳ Нажмите Enter, чтобы продолжить..." dummy
    return 1
  fi
  
  # Проверка доступного места
  local myshell_size=$(du -sm "$BASE_DIR" | cut -f1)
  if ! check_disk_space "$BACKUP_DIR" $((myshell_size + 200)); then
    echo -e "${RED}❌ Недостаточно места на диске для создания резервной копии.${RESET}"
    echo -e "${YELLOW}⚠️ Требуется примерно $((myshell_size + 200)) МБ свободного места.${RESET}"
    read -p "⏳ Нажмите Enter, чтобы продолжить..." dummy
    return 1
  fi
  
  # Управление резервными копиями (ограничение количества)
  manage_backups || return 1
  
  # Создаем директорию для резервных копий, если она не существует
  if ! mkdir -p "$BACKUP_DIR"; then
    if sudo mkdir -p "$BACKUP_DIR"; then
      print_operation "Создание директории для резервных копий" "успешно" "GREEN"
    else
      print_error "Создание директории для резервных копий" "ошибка"
      read -p "⏳ Нажмите Enter, чтобы продолжить..." dummy
      return 1
    fi
  else
    print_operation "Проверка директории для резервных копий" "успешно" "GREEN"
  fi
  
  # Создаем директорию для текущего бэкапа
  if ! mkdir -p "$DATED_BACKUP_DIR"; then
    if sudo mkdir -p "$DATED_BACKUP_DIR"; then
      print_operation "Создание директории для текущего бэкапа" "успешно" "GREEN"
    else
      print_error "Создание директории для текущего бэкапа" "ошибка"
      read -p "⏳ Нажмите Enter, чтобы продолжить..." dummy
      return 1
    fi
  else
    print_operation "Создание директории для текущего бэкапа" "успешно" "GREEN"
  fi
  
  # Копируем текущее окружение .myshell (кроме папки backup)
  if ! rsync -a --exclude 'backup/' "$BASE_DIR/" "$DATED_BACKUP_DIR/"; then
    if sudo rsync -a --exclude 'backup/' "$BASE_DIR/" "$DATED_BACKUP_DIR/"; then
      print_operation "Копирование текущего окружения" "успешно" "GREEN"
    else
      print_error "Копирование текущего окружения" "ошибка"
      
      # Очистка в случае ошибки
      rm -rf "$DATED_BACKUP_DIR" 2>/dev/null || sudo rm -rf "$DATED_BACKUP_DIR"
      
      read -p "⏳ Нажмите Enter, чтобы продолжить..." dummy
      return 1
    fi
  else
    print_operation "Копирование текущего окружения" "успешно" "GREEN"
  fi
  
  # Создаем README в директории бэкапа
  cat > "$DATED_BACKUP_DIR/README.md" << EOF
# Backup of MYSHELL environment
Created: $(date)
Original directory: $BASE_DIR

## Contents:
$(find "$DATED_BACKUP_DIR" -type d -mindepth 1 -maxdepth 1 | sort | sed 's/^/- /')
EOF
  
  print_success "Резервная копия успешно создана" "$DATED_BACKUP_DIR"
  read -p "⏳ Нажмите Enter, чтобы продолжить..." dummy
  return 0
}

# Функция для архивации предыдущих бэкапов
archive_previous_backups() {
  print_operation "Проверка наличия предыдущих папок с бэкапами" "выполнено" "GREEN"
  
  # Находим все папки бэкапов, которые не архивированы
  local BACKUP_DIRS=()
  if [[ -d "$BACKUP_DIR" ]]; then
    while IFS= read -r dir; do
      dir_name=$(basename "$dir")
      # Ищем только папки, начинающиеся с "backup_" и исключаем временные
      if [[ -d "$dir" && "$dir_name" != "tmp_"* && "$dir_name" == backup_* ]]; then
        BACKUP_DIRS+=("$dir")
      fi
    done < <(find "$BACKUP_DIR" -mindepth 1 -maxdepth 1 -type d 2>/dev/null || echo "")
  fi
  
  # Если найдены предыдущие папки с бэкапами, архивируем их все
  if [[ ${#BACKUP_DIRS[@]} -gt 0 ]]; then
    print_operation "Найдены предыдущие бэкапы" "${#BACKUP_DIRS[@]} папок" "YELLOW"
    
    # Архивируем каждую папку
    for backup_dir in "${BACKUP_DIRS[@]}"; do
      dir_name=$(basename "$backup_dir")
      archive_path="$BACKUP_DIR/$dir_name.tar.gz"
      
      # Проверка доступного места
      local dir_size=$(du -sm "$backup_dir" | cut -f1)
      if ! check_disk_space "$BACKUP_DIR" $((dir_size + 100)); then
        print_warning "Недостаточно места для архивации $dir_name" "пропущено"
        continue
      fi
      
      if ! tar -czf "$archive_path" -C "$backup_dir" .; then
        if sudo tar -czf "$archive_path" -C "$backup_dir" .; then
          print_operation "Архивируем папку $dir_name" "успешно" "GREEN"
        else
          print_error "Архивируем папку $dir_name" "ошибка"
          continue
        fi
      else
        print_operation "Архивируем папку $dir_name" "успешно" "GREEN"
      fi
      
      # Удаляем папку после архивации
      if ! rm -rf "$backup_dir"; then
        if sudo rm -rf "$backup_dir"; then
          print_operation "Удаление после архивации $dir_name" "успешно" "GREEN"
        else
          print_error "Удаление после архивации $dir_name" "ошибка"
        fi
      else
        print_operation "Удаление после архивации $dir_name" "успешно" "GREEN"
      fi
    done
  else
    print_operation "Предыдущие бэкапы" "не найдены" "GREEN"
  fi
}

# Функция для архивации резервных копий
archive_backup() {
  clear
  print_group_header "🗜️ Архивация резервных копий"
  
  # Получаем список неархивированных копий
  local backup_dirs=()
  
  if [[ -d "$BACKUP_DIR" ]]; then
    while IFS= read -r dir; do
        dir_name=$(basename "$dir")
        if [[ -d "$dir" && "$dir_name" != "$INITIAL_BACKUP_NAME" && "$dir_name" != "tmp_"* && "$dir_name" == backup_* ]]; then
          local dir_date=$(stat -c %y "$dir" | cut -d' ' -f1)
          backup_dirs+=("$dir_name|$dir_date|dir")
        fi
      done < <(find "$BACKUP_DIR" -mindepth 1 -maxdepth 1 -type d 2>/dev/null || echo "")
  fi
  
  # Сортируем по дате (сначала старые)
  IFS=$'\n' backup_dirs=($(for d in "${backup_dirs[@]}"; do
    local name=$(echo "$d" | cut -d'|' -f1)
    local date=$(echo "$d" | cut -d'|' -f2)
    local type=$(echo "$d" | cut -d'|' -f3)
    echo "$date|$name|$type"
  done | sort | awk -F'|' '{print $2"|"$1"|"$3}'))
  unset IFS
  
  # Если нет копий для архивации
  if [[ ${#backup_dirs[@]} -eq 0 ]]; then
    echo -e "${YELLOW}⚠️ Нет резервных копий для архивации.${RESET}"
    read -p "⏳ Нажмите Enter, чтобы продолжить..." dummy
    return 1
  fi
  
  # Выводим список копий для архивации
  echo -e "${CYAN}Резервные копии, доступные для архивации:${RESET}\n"
  
  for ((i=0; i<${#backup_dirs[@]}; i++)); do
    local name=$(echo "${backup_dirs[$i]}" | cut -d'|' -f1)
    local date=$(echo "${backup_dirs[$i]}" | cut -d'|' -f2)
    echo -e "  ${CYAN}$((i+1)))${RESET} ${GREEN}$name${RESET} - $date"
  done
  
  echo -e "  ${CYAN}a)${RESET} ${YELLOW}Архивировать все копии${RESET}"
  echo -e "  ${CYAN}0)${RESET} ${GRAY}Отмена${RESET}"
  
  # Запрашиваем выбор пользователя
  local max_choice=${#backup_dirs[@]}
  local choice=""
  
  while true; do
    read -p "🔢 Выберите копию для архивации или 'a' для всех [0-$max_choice/a]: " choice
    
    if [[ -z "$choice" ]]; then
      echo -e "${RED}❌ Пустой ввод. Пожалуйста, введите число от 0 до $max_choice или 'a'.${RESET}"
    elif [[ "$choice" =~ ^[0-9]+$ && "$choice" -ge 0 && "$choice" -le "$max_choice" ]]; then
      break
    elif [[ "$choice" == "a" || "$choice" == "A" ]]; then
      break
    else
      echo -e "${RED}❌ Некорректный выбор. Пожалуйста, введите число от 0 до $max_choice или 'a'.${RESET}"
    fi
  done
  
  # Если выбрана отмена
  if [[ "$choice" -eq 0 ]]; then
    echo -e "${YELLOW}⚠️ Архивация отменена.${RESET}"
    read -p "⏳ Нажмите Enter, чтобы продолжить..." dummy
    return 0
  fi
  
  # Архивируем выбранные копии
  if [[ "$choice" == "a" || "$choice" == "A" ]]; then
    # Архивируем все копии
    print_operation "Архивация всех резервных копий" "выполняется" "CYAN"
    
    local success_count=0
    local error_count=0
    
    for ((i=0; i<${#backup_dirs[@]}; i++)); do
      local name=$(echo "${backup_dirs[$i]}" | cut -d'|' -f1)
      local archive_path="$BACKUP_DIR/$name.tar.gz"
      
      # Проверка доступного места
      local dir_size=$(du -sm "$BACKUP_DIR/$name" | cut -f1)
      if ! check_disk_space "$BACKUP_DIR" $((dir_size + 100)); then
        print_warning "Недостаточно места для архивации $name" "пропущено"
        error_count=$((error_count + 1))
        continue
      fi
      
      # Архивируем копию
      if ! tar -czf "$archive_path" -C "$BACKUP_DIR/$name" .; then
        if sudo tar -czf "$archive_path" -C "$BACKUP_DIR/$name" .; then
          print_operation "Архивация $name" "успешно" "GREEN"
          success_count=$((success_count + 1))
          
          # Удаляем исходную директорию
          if ! rm -rf "$BACKUP_DIR/$name"; then
            if sudo rm -rf "$BACKUP_DIR/$name"; then
              print_operation "Удаление после архивации $name" "успешно" "GREEN"
            else
              print_error "Удаление после архивации $name" "ошибка"
            fi
          else
            print_operation "Удаление после архивации $name" "успешно" "GREEN"
          fi
        else
          print_error "Архивация $name" "ошибка"
          error_count=$((error_count + 1))
        fi
      else
        print_operation "Архивация $name" "успешно" "GREEN"
        success_count=$((success_count + 1))
        
        # Удаляем исходную директорию
        if ! rm -rf "$BACKUP_DIR/$name"; then
          if sudo rm -rf "$BACKUP_DIR/$name"; then
            print_operation "Удаление после архивации $name" "успешно" "GREEN"
          else
            print_error "Удаление после архивации $name" "ошибка"
          fi
        else
          print_operation "Удаление после архивации $name" "успешно" "GREEN"
        fi
      fi
    done
    
    echo -e "\n${GREEN}✅ Архивация завершена: ${success_count} успешно, ${error_count} с ошибками${RESET}"
  else
    # Архивируем выбранную копию
    local selected_idx=$((choice-1))
    local selected_name=$(echo "${backup_dirs[$selected_idx]}" | cut -d'|' -f1)
    local archive_path="$BACKUP_DIR/$selected_name.tar.gz"
    
    print_operation "Архивация резервной копии $selected_name" "выполняется" "CYAN"
    
    # Проверка доступного места
    local dir_size=$(du -sm "$BACKUP_DIR/$selected_name" | cut -f1)
    if ! check_disk_space "$BACKUP_DIR" $((dir_size + 100)); then
      print_error "Недостаточно места для архивации $selected_name" "операция прервана"
      read -p "⏳ Нажмите Enter, чтобы продолжить..." dummy
      return 1
    fi
    
    # Архивируем выбранную копию
    if ! tar -czf "$archive_path" -C "$BACKUP_DIR/$selected_name" .; then
      if sudo tar -czf "$archive_path" -C "$BACKUP_DIR/$selected_name" .; then
        print_operation "Архивация $selected_name" "успешно" "GREEN"
        
        # Удаляем исходную директорию
        if ! rm -rf "$BACKUP_DIR/$selected_name"; then
          if sudo rm -rf "$BACKUP_DIR/$selected_name"; then
            print_operation "Удаление после архивации $selected_name" "успешно" "GREEN"
          else
            print_error "Удаление после архивации $selected_name" "ошибка"
          fi
        else
          print_operation "Удаление после архивации $selected_name" "успешно" "GREEN"
        fi
      else
        print_error "Архивация $selected_name" "ошибка"
        read -p "⏳ Нажмите Enter, чтобы продолжить..." dummy
        return 1
      fi
    else
      print_operation "Архивация $selected_name" "успешно" "GREEN"
      
      # Удаляем исходную директорию
      if ! rm -rf "$BACKUP_DIR/$selected_name"; then
        if sudo rm -rf "$BACKUP_DIR/$selected_name"; then
          print_operation "Удаление после архивации $selected_name" "успешно" "GREEN"
        else
          print_error "Удаление после архивации $selected_name" "ошибка"
        fi
      else
        print_operation "Удаление после архивации $selected_name" "успешно" "GREEN"
      fi
    fi
    
    echo -e "\n${GREEN}✅ Резервная копия ${YELLOW}$selected_name${GREEN} успешно архивирована${RESET}"
  fi
  
  read -p "⏳ Нажмите Enter, чтобы продолжить..." dummy
  return 0
}

# Функция для удаления резервных копий
delete_backup() {
  clear
  print_group_header "🗑️ Удаление резервных копий"
  
  # Получаем список всех копий (кроме первоначальной)
  local available_backups=()
  
  if [[ ! -d "$BACKUP_DIR" ]]; then
    echo -e "${YELLOW}⚠️ Директория резервных копий не существует.${RESET}"
    read -p "⏳ Нажмите Enter, чтобы продолжить..." dummy
    return 1
  fi
  
  # Директории
  while IFS= read -r dir; do
    dir_name=$(basename "$dir")
    if [[ -d "$dir" && "$dir_name" != "$INITIAL_BACKUP_NAME" && "$dir_name" != "tmp_"* && "$dir_name" == backup_* ]]; then
      local dir_date=$(stat -c %y "$dir" | cut -d' ' -f1)
      available_backups+=("$dir_name|$dir_date|dir|Резервная копия от $dir_date")
    fi
  done < <(find "$BACKUP_DIR" -mindepth 1 -maxdepth 1 -type d 2>/dev/null || echo "")
  
  # Архивы
  while IFS= read -r archive; do
    archive_name=$(basename "$archive" .tar.gz)
    if [[ -f "$archive" && "$archive_name" != "$INITIAL_BACKUP_NAME" && "$archive_name" == backup_* ]]; then
      local archive_date=$(stat -c %y "$archive" | cut -d' ' -f1)
      available_backups+=("$archive_name|$archive_date|archive|Резервная копия от $archive_date (архив)")
    fi
  done < <(find "$BACKUP_DIR" -mindepth 1 -maxdepth 1 -name "*.tar.gz" 2>/dev/null || echo "")
  
  # Сортируем по дате (сначала старые)
  IFS=$'\n' available_backups=($(for d in "${available_backups[@]}"; do
    local name=$(echo "$d" | cut -d'|' -f1)
    local date=$(echo "$d" | cut -d'|' -f2)
    local type=$(echo "$d" | cut -d'|' -f3)
    local desc=$(echo "$d" | cut -d'|' -f4)
    echo "$date|$name|$type|$desc"
  done | sort | awk -F'|' '{print $2"|"$1"|"$3"|"$4}'))
  unset IFS
  
  # Если нет копий для удаления
  if [[ ${#available_backups[@]} -eq 0 ]]; then
    echo -e "${YELLOW}⚠️ Нет резервных копий для удаления.${RESET}"
    read -p "⏳ Нажмите Enter, чтобы продолжить..." dummy
    return 1
  fi
  
  # Выводим список копий для удаления
  echo -e "${CYAN}Резервные копии, доступные для удаления:${RESET}\n"
  
  for ((i=0; i<${#available_backups[@]}; i++)); do
    local name=$(echo "${available_backups[$i]}" | cut -d'|' -f1)
    local date=$(echo "${available_backups[$i]}" | cut -d'|' -f2)
    local type=$(echo "${available_backups[$i]}" | cut -d'|' -f3)
    local desc=$(echo "${available_backups[$i]}" | cut -d'|' -f4)
    
    if [[ "$type" == "dir" ]]; then
      echo -e "  ${CYAN}$((i+1)))${RESET} ${GREEN}$desc${RESET} - $date"
    else
      echo -e "  ${CYAN}$((i+1)))${RESET} ${YELLOW}$desc${RESET} - $date"
    fi
  done
  
  echo -e "  ${CYAN}a)${RESET} ${RED}Удалить все копии${RESET}"
  echo -e "  ${CYAN}0)${RESET} ${GRAY}Отмена${RESET}"
  
  # Запрашиваем выбор пользователя
  local max_choice=${#available_backups[@]}
  local choice=""
  
  while true; do
    read -p "🔢 Выберите копию для удаления или 'a' для всех [0-$max_choice/a]: " choice
    
    if [[ -z "$choice" ]]; then
      echo -e "${RED}❌ Пустой ввод. Пожалуйста, введите число от 0 до $max_choice или 'a'.${RESET}"
    elif [[ "$choice" =~ ^[0-9]+$ && "$choice" -ge 0 && "$choice" -le "$max_choice" ]]; then
      break
    elif [[ "$choice" == "a" || "$choice" == "A" ]]; then
      break
    else
      echo -e "${RED}❌ Некорректный выбор. Пожалуйста, введите число от 0 до $max_choice или 'a'.${RESET}"
    fi
  done
  
  # Если выбрана отмена
  if [[ "$choice" -eq 0 ]]; then
    echo -e "${YELLOW}⚠️ Удаление отменено.${RESET}"
    read -p "⏳ Нажмите Enter, чтобы продолжить..." dummy
    return 0
  fi
  
  # Удаляем выбранные копии
  if [[ "$choice" == "a" || "$choice" == "A" ]]; then
    # Запрашиваем дополнительное подтверждение для удаления всех копий
    echo -e "\n${RED}⚠️ ВНИМАНИЕ!${RESET} Вы собираетесь удалить ${RED}ВСЕ${RESET} резервные копии (${#available_backups[@]} шт.)."
    read -p "Вы АБСОЛЮТНО уверены? Это действие НЕВОЗМОЖНО отменить! (введите 'yes'): " confirm
    
    if [[ "$confirm" != "yes" ]]; then
      echo -e "${YELLOW}⚠️ Удаление отменено.${RESET}"
      read -p "⏳ Нажмите Enter, чтобы продолжить..." dummy
      return 0
    fi
    
    # Удаляем все копии
    print_operation "Удаление всех резервных копий" "выполняется" "RED"
    
    local success_count=0
    local error_count=0
    
    for ((i=0; i<${#available_backups[@]}; i++)); do
      local name=$(echo "${available_backups[$i]}" | cut -d'|' -f1)
      local type=$(echo "${available_backups[$i]}" | cut -d'|' -f3)
      
      if [[ "$type" == "dir" ]]; then
        # Удаляем директорию
        if ! rm -rf "$BACKUP_DIR/$name"; then
          if sudo rm -rf "$BACKUP_DIR/$name"; then
            print_operation "Удаление директории $name" "успешно" "GREEN"
            success_count=$((success_count + 1))
          else
            print_error "Удаление директории $name" "ошибка"
            error_count=$((error_count + 1))
          fi
        else
          print_operation "Удаление директории $name" "успешно" "GREEN"
          success_count=$((success_count + 1))
        fi
      else
        # Удаляем архив
        if ! rm -f "$BACKUP_DIR/$name.tar.gz"; then
          if sudo rm -f "$BACKUP_DIR/$name.tar.gz"; then
            print_operation "Удаление архива $name.tar.gz" "успешно" "GREEN"
            success_count=$((success_count + 1))
          else
            print_error "Удаление архива $name.tar.gz" "ошибка"
            error_count=$((error_count + 1))
          fi
        else
          print_operation "Удаление архива $name.tar.gz" "успешно" "GREEN"
          success_count=$((success_count + 1))
        fi
      fi
    done
    
    echo -e "\n${GREEN}✅ Удаление завершено: ${success_count} успешно, ${error_count} с ошибками${RESET}"
  else
    # Удаляем выбранную копию
    local selected_idx=$((choice-1))
    local selected_name=$(echo "${available_backups[$selected_idx]}" | cut -d'|' -f1)
    local selected_type=$(echo "${available_backups[$selected_idx]}" | cut -d'|' -f3)
    local selected_desc=$(echo "${available_backups[$selected_idx]}" | cut -d'|' -f4)
    
    # Запрашиваем подтверждение
    echo -e "\n${YELLOW}⚠️ Внимание!${RESET} Вы собираетесь удалить резервную копию:"
    echo -e "${GREEN}$selected_desc${RESET}"
    
    read -p "Вы уверены? Это действие невозможно отменить! (y/n): " confirm
    
    if [[ ! "$confirm" =~ ^[Yy]$ ]]; then
      echo -e "${YELLOW}⚠️ Удаление отменено.${RESET}"
      read -p "⏳ Нажмите Enter, чтобы продолжить..." dummy
      return 0
    fi
    
    if [[ "$selected_type" == "dir" ]]; then
      # Удаляем директорию
      print_operation "Удаление директории $selected_name" "выполняется" "CYAN"
      
      if ! rm -rf "$BACKUP_DIR/$selected_name"; then
        if sudo rm -rf "$BACKUP_DIR/$selected_name"; then
          print_operation "Удаление директории $selected_name" "успешно" "GREEN"
        else
          print_error "Удаление директории $selected_name" "ошибка"
          read -p "⏳ Нажмите Enter, чтобы продолжить..." dummy
          return 1
        fi
      else
        print_operation "Удаление директории $selected_name" "успешно" "GREEN"
      fi
    else
      # Удаляем архив
      print_operation "Удаление архива $selected_name.tar.gz" "выполняется" "CYAN"
      
      if ! rm -f "$BACKUP_DIR/$selected_name.tar.gz"; then
        if sudo rm -f "$BACKUP_DIR/$selected_name.tar.gz"; then
          print_operation "Удаление архива $selected_name.tar.gz" "успешно" "GREEN"
        else
          print_error "Удаление архива $selected_name.tar.gz" "ошибка"
          read -p "⏳ Нажмите Enter, чтобы продолжить..." dummy
          return 1
        fi
      else
        print_operation "Удаление архива $selected_name.tar.gz" "успешно" "GREEN"
      fi
    fi
    
    echo -e "\n${GREEN}✅ Резервная копия ${YELLOW}$selected_desc${GREEN} успешно удалена${RESET}"
  fi
  
  read -p "⏳ Нажмите Enter, чтобы продолжить..." dummy
  return 0
}

# Функция для настройки параметров резервного копирования
configure_backup() {
  clear
  print_group_header "⚙️ Настройка параметров резервного копирования"
  
  # Верхняя часть рамки
  echo -e "${CYAN}┌────────────────────────────────────────────────────────────────────┐${RESET}"
  echo -e "${CYAN}│${RESET}               ${YELLOW}🔧 НАСТРОЙКА РЕЗЕРВНОГО КОПИРОВАНИЯ${RESET}               ${CYAN}│${RESET}"
  echo -e "${CYAN}└────────────────────────────────────────────────────────────────────┘${RESET}"
  echo -e ""

  # Текущие настройки без боковых рамок
  echo ""
  echo -e "  • Максимальное количество хранимых копий: ${YELLOW}$MAX_BACKUPS${RESET}"
  echo -e "  • Директория резервных копий: ${YELLOW}$BACKUP_DIR${RESET}"
  echo ""
  
  # Разделитель
  echo -e "${CYAN}────────────────────────────────────────────────────────────────────${RESET}"
  
  # Доступные настройки без боковых рамок
  echo ""
  echo -e "  ${CYAN}1)${RESET} Изменить максимальное количество хранимых копий"
  echo -e "  ${CYAN}2)${RESET} Изменить директорию для резервных копий"
  echo -e "  ${CYAN}0)${RESET} Вернуться назад"
  echo ""
  
  # Нижняя линия рамки
  echo -e "${CYAN}────────────────────────────────────────────────────────────────────${RESET}"
  
  # Отступ после рамки
  echo ""
  
  # Запрос выбора
  local choice=""
  read -p "🔢 Ваш выбор [0-2]: " choice
  
  case $choice in
    1) # Изменить максимальное количество копий
      local new_max=""
      echo -e "\n${BLUE}📊 Текущее максимальное количество копий: ${YELLOW}$MAX_BACKUPS${RESET}"
      
      while true; do
        read -p "Введите новое значение (1-100, рекомендуется 5-10): " new_max
        
        if [[ -z "$new_max" ]]; then
          echo -e "${RED}❌ Пустой ввод. Пожалуйста, введите число от 1 до 100.${RESET}"
        elif [[ "$new_max" =~ ^[0-9]+$ && "$new_max" -ge 1 && "$new_max" -le 100 ]]; then
          # Создаем директорию, если она не существует
          if [[ ! -d "$BASE_DIR" ]]; then
            if ! mkdir -p "$BASE_DIR"; then
              if sudo mkdir -p "$BASE_DIR"; then
                print_operation "Создание директории .myshell" "успешно" "GREEN"
              else
                print_error "Создание директории .myshell" "ошибка"
                read -p "⏳ Нажмите Enter, чтобы продолжить..." dummy
                return 1
              fi
            fi
          fi
          
          # Сохраняем в конфигурационный файл
          echo "MAX_BACKUPS=$new_max" > "$BASE_DIR/backup_config"
          MAX_BACKUPS=$new_max
          
          print_success "Максимальное количество копий изменено" "$new_max"
          break
        else
          echo -e "${RED}❌ Некорректное значение. Пожалуйста, введите число от 1 до 100.${RESET}"
        fi
      done
      ;;
      
    2) # Изменить директорию для резервных копий
      local new_dir=""
      echo -e "\n${BLUE}📂 Текущая директория для резервных копий: ${YELLOW}$BACKUP_DIR${RESET}"
      echo -e "${YELLOW}⚠️ ВНИМАНИЕ!${RESET} Изменение директории не перемещает существующие копии."
      
      read -p "Введите новый путь (абсолютный) или пустую строку для отмены: " new_dir
      
      if [[ -n "$new_dir" ]]; then
        # Проверяем, что путь абсолютный
        if [[ "$new_dir" != /* ]]; then
          echo -e "${RED}❌ Путь должен быть абсолютным (начинаться с /).${RESET}"
        else
          # Создаем директорию, если она не существует
          if ! mkdir -p "$new_dir"; then
            if sudo mkdir -p "$new_dir"; then
              print_operation "Создание новой директории" "успешно" "GREEN"
            else
              print_error "Создание новой директории" "ошибка"
              read -p "⏳ Нажмите Enter, чтобы продолжить..." dummy
              return 1
            fi
          else
            print_operation "Создание/проверка новой директории" "успешно" "GREEN"
          fi
          
          # Проверяем права на запись
          if ! touch "$new_dir/.test_write" &>/dev/null; then
            if sudo touch "$new_dir/.test_write" &>/dev/null; then
              sudo rm -f "$new_dir/.test_write"
              print_warning "У вас нет прав на запись в эту директорию" "требуются sudo права"
            else
              print_error "Нет возможности записи в указанную директорию" "выберите другую"
              read -p "⏳ Нажмите Enter, чтобы продолжить..." dummy
              return 1
            fi
          else
            rm -f "$new_dir/.test_write"
          fi
          
          # Устанавливаем правильные права доступа
          if ! sudo chown -R "$USER":"$USER" "$new_dir"; then
            print_warning "Не удалось установить права доступа к директории" "может потребоваться sudo"
          else
            print_operation "Установка прав доступа" "успешно" "GREEN"
          fi
          
          # Создаем директорию .myshell, если она не существует
          if [[ ! -d "$BASE_DIR" ]]; then
            if ! mkdir -p "$BASE_DIR"; then
              if sudo mkdir -p "$BASE_DIR"; then
                print_operation "Создание директории .myshell" "успешно" "GREEN"
              else
                print_error "Создание директории .myshell" "ошибка"
                read -p "⏳ Нажмите Enter, чтобы продолжить..." dummy
                return 1
              fi
            fi
          fi
          
          # Сохраняем в конфигурационный файл
          if [[ ! -f "$BASE_DIR/backup_config" ]]; then
            echo "MAX_BACKUPS=$MAX_BACKUPS" > "$BASE_DIR/backup_config"
          fi
          echo "BACKUP_DIR=$new_dir" >> "$BASE_DIR/backup_config"
          BACKUP_DIR=$new_dir
          DATED_BACKUP_DIR="$BACKUP_DIR/backup_$TIMESTAMP" # Обновляем путь к текущему бэкапу
          
          print_success "Директория для резервных копий изменена" "$new_dir"
        fi
      else
        echo -e "${YELLOW}⚠️ Операция отменена.${RESET}"
      fi
      ;;
      
    0|"") # Вернуться назад
      return 0
      ;;
      
    *) # Некорректный выбор
      echo -e "${RED}❌ Некорректный выбор.${RESET}"
      ;;
  esac
  
  read -p "⏳ Нажмите Enter, чтобы продолжить..." dummy
  return 0
}

# Функция для восстановления из резервной копии
restore_backup() {
  clear
  print_group_header "🔄 Восстановление из резервной копии"
  
  # Получаем список всех доступных резервных копий
  if [[ ! -d "$BACKUP_DIR" ]]; then
    echo -e "${YELLOW}⚠️ Директория резервных копий не существует.${RESET}"
    read -p "⏳ Нажмите Enter, чтобы продолжить..." dummy
    return 1
  fi
  
  local available_backups=()
  
  # Добавляем первоначальную копию, если она существует
  if [[ -d "$BACKUP_DIR/$INITIAL_BACKUP_NAME" ]]; then
    local initial_date=$(stat -c %y "$BACKUP_DIR/$INITIAL_BACKUP_NAME" | cut -d' ' -f1)
    available_backups+=("$INITIAL_BACKUP_NAME|$initial_date|dir|Первоначальная копия (до установки MYSHELL)")
  elif [[ -f "$BACKUP_DIR/${INITIAL_BACKUP_NAME}.tar.gz" ]]; then
    local initial_date=$(stat -c %y "$BACKUP_DIR/${INITIAL_BACKUP_NAME}.tar.gz" | cut -d' ' -f1)
    available_backups+=("$INITIAL_BACKUP_NAME|$initial_date|archive|Первоначальная копия (архив)")
  fi
  
  # Добавляем обычные резервные копии
  while IFS= read -r dir; do
    dir_name=$(basename "$dir")
    if [[ -d "$dir" && "$dir_name" != "$INITIAL_BACKUP_NAME" && "$dir_name" != "tmp_"* && "$dir_name" == backup_* ]]; then
      local dir_date=$(stat -c %y "$dir" | cut -d' ' -f1)
      available_backups+=("$dir_name|$dir_date|dir|Резервная копия от $dir_date")
    fi
  done < <(find "$BACKUP_DIR" -mindepth 1 -maxdepth 1 -type d 2>/dev/null || echo "")
  
  # Добавляем архивы
  while IFS= read -r archive; do
    archive_name=$(basename "$archive" .tar.gz)
    if [[ -f "$archive" && "$archive_name" != "$INITIAL_BACKUP_NAME" && "$archive_name" == backup_* ]]; then
      local archive_date=$(stat -c %y "$archive" | cut -d' ' -f1)
      available_backups+=("$archive_name|$archive_date|archive|Резервная копия от $archive_date (архив)")
    fi
  done < <(find "$BACKUP_DIR" -mindepth 1 -maxdepth 1 -name "*.tar.gz" 2>/dev/null || echo "")
  
  # Сортируем по дате (сначала новые)
  IFS=$'\n' available_backups=($(for d in "${available_backups[@]}"; do
    local name=$(echo "$d" | cut -d'|' -f1)
    local date=$(echo "$d" | cut -d'|' -f2)
    local type=$(echo "$d" | cut -d'|' -f3)
    local desc=$(echo "$d" | cut -d'|' -f4)
    echo "$date|$name|$type|$desc"
  done | sort -r | awk -F'|' '{print $2"|"$1"|"$3"|"$4}'))
  unset IFS
  
  # Если нет копий для восстановления
  if [[ ${#available_backups[@]} -eq 0 ]]; then
    echo -e "${YELLOW}⚠️ Нет доступных резервных копий для восстановления.${RESET}"
    read -p "⏳ Нажмите Enter, чтобы продолжить..." dummy
    return 1
  fi
  
  # Выводим список доступных копий
  echo -e "${CYAN}Доступные резервные копии:${RESET}\n"
  
  for ((i=0; i<${#available_backups[@]}; i++)); do
    local name=$(echo "${available_backups[$i]}" | cut -d'|' -f1)
    local date=$(echo "${available_backups[$i]}" | cut -d'|' -f2)
    local type=$(echo "${available_backups[$i]}" | cut -d'|' -f3)
    local desc=$(echo "${available_backups[$i]}" | cut -d'|' -f4)
    
    if [[ "$type" == "dir" ]]; then
      echo -e "  ${CYAN}$((i+1)))${RESET} ${GREEN}$desc${RESET} - $date"
    else
      echo -e "  ${CYAN}$((i+1)))${RESET} ${YELLOW}$desc${RESET} - $date"
    fi
  done
  
  echo -e "  ${CYAN}0)${RESET} ${GRAY}Отмена${RESET}"
  
  # Запрашиваем выбор пользователя
  local max_choice=${#available_backups[@]}
  local choice=""
  
  while true; do
    read -p "🔢 Выберите копию для восстановления [0-$max_choice]: " choice
    
    if [[ -z "$choice" ]]; then
      echo -e "${RED}❌ Пустой ввод. Пожалуйста, введите число от 0 до $max_choice.${RESET}"
    elif [[ "$choice" =~ ^[0-9]+$ && "$choice" -ge 0 && "$choice" -le "$max_choice" ]]; then
      break
    else
      echo -e "${RED}❌ Некорректный выбор. Пожалуйста, введите число от 0 до $max_choice.${RESET}"
    fi
  done
  
  # Если выбрана отмена
  if [[ "$choice" -eq 0 ]]; then
    echo -e "${YELLOW}⚠️ Восстановление отменено.${RESET}"
    read -p "⏳ Нажмите Enter, чтобы продолжить..." dummy
    return 0
  fi
  
  # Получаем данные о выбранной копии
  local selected_idx=$((choice-1))
  local selected_name=$(echo "${available_backups[$selected_idx]}" | cut -d'|' -f1)
  local selected_type=$(echo "${available_backups[$selected_idx]}" | cut -d'|' -f3)
  local selected_desc=$(echo "${available_backups[$selected_idx]}" | cut -d'|' -f4)

  # Запрашиваем подтверждение
  echo -e "\n${YELLOW}⚠️ Внимание!${RESET} Восстановление из резервной копии заменит текущие настройки."
  echo -e "Вы выбрали: ${GREEN}$selected_desc${RESET}"
  
  read -p "Вы уверены, что хотите продолжить? (y/n): " confirm
  
  if [[ ! "$confirm" =~ ^[Yy]$ ]]; then
    echo -e "${YELLOW}⚠️ Восстановление отменено.${RESET}"
    read -p "⏳ Нажмите Enter, чтобы продолжить..." dummy
    return 0
  fi
  
  # Проверка наличия директории .myshell
  if [[ ! -d "$BASE_DIR" ]]; then
    if ! mkdir -p "$BASE_DIR"; then
      if sudo mkdir -p "$BASE_DIR"; then
        print_operation "Создание директории .myshell" "успешно" "GREEN"
      else
        print_error "Создание директории .myshell" "ошибка"
        read -p "⏳ Нажмите Enter, чтобы продолжить..." dummy
        return 1
      fi
    fi
  fi
  
  # Создаем временную резервную копию текущего состояния
  local tmp_backup_dir="$BACKUP_DIR/tmp_backup_before_restore"
  print_operation "Создание временной копии текущего состояния" "выполняется" "CYAN"
  
  # Удаляем временную директорию, если она существует
  if [[ -d "$tmp_backup_dir" ]]; then
    if ! rm -rf "$tmp_backup_dir"; then
      if sudo rm -rf "$tmp_backup_dir"; then
        print_operation "Очистка предыдущей временной директории" "успешно" "GREEN"
      else
        print_error "Очистка предыдущей временной директории" "ошибка"
        read -p "⏳ Нажмите Enter, чтобы продолжить..." dummy
        return 1
      fi
    fi
  fi
  
  # Создаем временную директорию для бэкапа
  if ! mkdir -p "$tmp_backup_dir"; then
    if sudo mkdir -p "$tmp_backup_dir"; then
      print_operation "Создание временной директории" "успешно" "GREEN"
    else
      print_error "Создание временной директории" "ошибка"
      read -p "⏳ Нажмите Enter, чтобы продолжить..." dummy
      return 1
    fi
  fi
  
  # Копируем текущее окружение во временную директорию (если оно существует)
  if [[ -d "$BASE_DIR" && "$(find "$BASE_DIR" -mindepth 1 -not -path "$BACKUP_DIR*" -print -quit 2>/dev/null)" ]]; then
    if ! rsync -a --exclude 'backup/' "$BASE_DIR/" "$tmp_backup_dir/"; then
      if sudo rsync -a --exclude 'backup/' "$BASE_DIR/" "$tmp_backup_dir/"; then
        print_operation "Создание временной копии" "успешно" "GREEN"
      else
        print_error "Создание временной копии" "ошибка"
        read -p "⏳ Нажмите Enter, чтобы продолжить..." dummy
        return 1
      fi
    else
      print_operation "Создание временной копии" "успешно" "GREEN"
    fi
  else
    print_operation "Создание временной копии" "нет данных для бэкапа" "YELLOW"
  fi
  
  # Процесс восстановления зависит от типа выбранной копии
  if [[ "$selected_type" == "dir" ]]; then
    # Восстановление из директории
    print_operation "Восстановление из директории $selected_name" "выполняется" "CYAN"
    
    # Проверка наличия директории исходной копии
    if [[ ! -d "$BACKUP_DIR/$selected_name" ]]; then
      print_error "Директория $selected_name" "не найдена"
      
      # Восстанавливаем из временной копии, если она существует
      if [[ -d "$tmp_backup_dir" && "$(find "$tmp_backup_dir" -mindepth 1 -print -quit 2>/dev/null)" ]]; then
        print_operation "Восстановление из временной копии" "выполняется" "CYAN"
        if ! rsync -a "$tmp_backup_dir/" "$BASE_DIR/"; then
          sudo rsync -a "$tmp_backup_dir/" "$BASE_DIR/"
        fi
      fi
      
      read -p "⏳ Нажмите Enter, чтобы продолжить..." dummy
      return 1
    fi
    
    # Очищаем текущую директорию .myshell (кроме backup)
    if ! find "$BASE_DIR" -mindepth 1 ! -path "$BACKUP_DIR" ! -path "$BACKUP_DIR/*" -print0 | xargs -0 rm -rf 2>/dev/null; then
      if sudo find "$BASE_DIR" -mindepth 1 ! -path "$BACKUP_DIR" ! -path "$BACKUP_DIR/*" -print0 | xargs -0 sudo rm -rf; then
        print_operation "Очистка текущей директории" "успешно" "GREEN"
      else
        print_error "Очистка текущей директории" "ошибка"
        print_error "Восстановление прервано" "ошибка при очистке"
        read -p "⏳ Нажмите Enter, чтобы продолжить..." dummy
        return 1
      fi
    else
      print_operation "Очистка текущей директории" "успешно" "GREEN"
    fi
    
    # Копируем содержимое резервной копии
    if ! rsync -a "$BACKUP_DIR/$selected_name/" "$BASE_DIR/"; then
      if sudo rsync -a "$BACKUP_DIR/$selected_name/" "$BASE_DIR/"; then
        print_operation "Копирование из резервной копии" "успешно" "GREEN"
      else
        # В случае ошибки восстанавливаем из временной копии
        print_error "Копирование из резервной копии" "ошибка"
        print_operation "Откат к предыдущему состоянию" "выполняется" "CYAN"
        
        if [[ -d "$tmp_backup_dir" && "$(find "$tmp_backup_dir" -mindepth 1 -print -quit 2>/dev/null)" ]]; then
          if ! rsync -a "$tmp_backup_dir/" "$BASE_DIR/"; then
            sudo rsync -a "$tmp_backup_dir/" "$BASE_DIR/"
          fi
        fi
        
        print_error "Восстановление прервано" "ошибка при копировании"
        read -p "⏳ Нажмите Enter, чтобы продолжить..." dummy
        return 1
      fi
    else
      print_operation "Копирование из резервной копии" "успешно" "GREEN"
    fi
  else
    # Восстановление из архива
    print_operation "Восстановление из архива $selected_name.tar.gz" "выполняется" "CYAN"
    
    # Проверка наличия архива
    if [[ ! -f "$BACKUP_DIR/$selected_name.tar.gz" ]]; then
      print_error "Архив $selected_name.tar.gz" "не найден"
      
      # Восстанавливаем из временной копии, если она существует
      if [[ -d "$tmp_backup_dir" && "$(find "$tmp_backup_dir" -mindepth 1 -print -quit 2>/dev/null)" ]]; then
        print_operation "Восстановление из временной копии" "выполняется" "CYAN"
        if ! rsync -a "$tmp_backup_dir/" "$BASE_DIR/"; then
          sudo rsync -a "$tmp_backup_dir/" "$BASE_DIR/"
        fi
      fi
      
      read -p "⏳ Нажмите Enter, чтобы продолжить..." dummy
      return 1
    fi
    
    # Создаем временную директорию для распаковки архива
    local extract_dir="$BACKUP_DIR/tmp_extract"
    
    # Удаляем временную директорию, если она существует
    if [[ -d "$extract_dir" ]]; then
      if ! rm -rf "$extract_dir"; then
        if sudo rm -rf "$extract_dir"; then
          print_operation "Очистка предыдущей временной директории" "успешно" "GREEN"
        else
          print_error "Очистка предыдущей временной директории" "ошибка"
          read -p "⏳ Нажмите Enter, чтобы продолжить..." dummy
          return 1
        fi
      fi
    fi
    
    if ! mkdir -p "$extract_dir"; then
      if sudo mkdir -p "$extract_dir"; then
        print_operation "Создание временной директории для распаковки" "успешно" "GREEN"
      else
        print_error "Создание временной директории для распаковки" "ошибка"
        read -p "⏳ Нажмите Enter, чтобы продолжить..." dummy
        return 1
      fi
    else
      print_operation "Создание временной директории для распаковки" "успешно" "GREEN"
    fi
    
    # Распаковываем архив
    if ! tar -xzf "$BACKUP_DIR/$selected_name.tar.gz" -C "$extract_dir"; then
      if sudo tar -xzf "$BACKUP_DIR/$selected_name.tar.gz" -C "$extract_dir"; then
        print_operation "Распаковка архива" "успешно" "GREEN"
      else
        print_error "Распаковка архива" "ошибка"
        
        # Удаляем временную директорию
        rm -rf "$extract_dir" 2>/dev/null || sudo rm -rf "$extract_dir"
        
        read -p "⏳ Нажмите Enter, чтобы продолжить..." dummy
        return 1
      fi
    else
      print_operation "Распаковка архива" "успешно" "GREEN"
    fi
    
    # Очищаем текущую директорию .myshell (кроме backup)
    if ! find "$BASE_DIR" -mindepth 1 ! -path "$BACKUP_DIR" ! -path "$BACKUP_DIR/*" -print0 | xargs -0 rm -rf 2>/dev/null; then
      if sudo find "$BASE_DIR" -mindepth 1 ! -path "$BACKUP_DIR" ! -path "$BACKUP_DIR/*" -print0 | xargs -0 sudo rm -rf; then
        print_operation "Очистка текущей директории" "успешно" "GREEN"
      else
        print_error "Очистка текущей директории" "ошибка"
        print_error "Восстановление прервано" "ошибка при очистке"
        
        # Удаляем временную директорию
        rm -rf "$extract_dir" 2>/dev/null || sudo rm -rf "$extract_dir"
        
        read -p "⏳ Нажмите Enter, чтобы продолжить..." dummy
        return 1
      fi
    else
      print_operation "Очистка текущей директории" "успешно" "GREEN"
    fi
    
    # Копируем распакованное содержимое
    if ! rsync -a "$extract_dir/" "$BASE_DIR/"; then
      if sudo rsync -a "$extract_dir/" "$BASE_DIR/"; then
        print_operation "Копирование распакованных файлов" "успешно" "GREEN"
      else
        # В случае ошибки восстанавливаем из временной копии
        print_error "Копирование распакованных файлов" "ошибка"
        print_operation "Откат к предыдущему состоянию" "выполняется" "CYAN"
        
        if [[ -d "$tmp_backup_dir" && "$(find "$tmp_backup_dir" -mindepth 1 -print -quit 2>/dev/null)" ]]; then
          if ! rsync -a "$tmp_backup_dir/" "$BASE_DIR/"; then
            sudo rsync -a "$tmp_backup_dir/" "$BASE_DIR/"
          fi
        fi
        
        print_error "Восстановление прервано" "ошибка при копировании"
        
        # Удаляем временную директорию
        rm -rf "$extract_dir" 2>/dev/null || sudo rm -rf "$extract_dir"
        
        read -p "⏳ Нажмите Enter, чтобы продолжить..." dummy
        return 1
      fi
    else
      print_operation "Копирование распакованных файлов" "успешно" "GREEN"
    fi
    
    # Удаляем временную директорию для распаковки
    if ! rm -rf "$extract_dir"; then
      if sudo rm -rf "$extract_dir"; then
        print_operation "Удаление временной директории" "успешно" "GREEN"
      else
        print_warning "Удаление временной директории" "ошибка"
      fi
    else
      print_operation "Удаление временной директории" "успешно" "GREEN"
    fi
  fi
  
  # Удаляем временную резервную копию
  if ! rm -rf "$tmp_backup_dir"; then
    if sudo rm -rf "$tmp_backup_dir"; then
      print_operation "Удаление временной копии" "успешно" "GREEN"
    else
      print_warning "Удаление временной копии" "ошибка"
    fi
  else
    print_operation "Удаление временной копии" "успешно" "GREEN"
  fi
  
  # Устанавливаем правильные права доступа
  if ! sudo chown -R "$USER":"$USER" "$BASE_DIR"; then
    print_warning "Не удалось установить права доступа к директории" "пропущено"
  else
    print_operation "Установка прав доступа" "успешно" "GREEN"
  fi
  
  # Обновляем символические ссылки
  update_symlinks
  
  print_success "Восстановление из резервной копии" "успешно завершено"
  echo -e "${GREEN}✅ Настройки успешно восстановлены из резервной копии: ${YELLOW}$selected_desc${RESET}"
  read -p "⏳ Нажмите Enter, чтобы продолжить..." dummy
  return 0
}

# Функция для обновления символических ссылок
update_symlinks() {
  local any_error=false
  
  # Проверяем наличие директорий и файлов перед созданием символических ссылок
  if [[ -d "$BASE_DIR/dotfiles" && -f "$BASE_DIR/dotfiles/.zshrc" ]]; then
    if ! ln -sf "$BASE_DIR/dotfiles/.zshrc" "$HOME/.zshrc"; then
      if sudo ln -sf "$BASE_DIR/dotfiles/.zshrc" "$HOME/.zshrc"; then
        print_operation "Обновление символической ссылки .zshrc" "успешно" "GREEN"
      else
        print_error "Обновление символической ссылки .zshrc" "ошибка"
        any_error=true
      fi
    else
      print_operation "Обновление символической ссылки .zshrc" "успешно" "GREEN"
    fi
  else
    print_warning "Обновление символической ссылки .zshrc" "исходный файл не найден"
    any_error=true
  fi
  
  if [[ -d "$BASE_DIR/tmux" && -f "$BASE_DIR/tmux/.tmux.conf" ]]; then
    if ! ln -sf "$BASE_DIR/tmux/.tmux.conf" "$HOME/.tmux.conf"; then
      if sudo ln -sf "$BASE_DIR/tmux/.tmux.conf" "$HOME/.tmux.conf"; then
        print_operation "Обновление символической ссылки .tmux.conf" "успешно" "GREEN"
      else
        print_error "Обновление символической ссылки .tmux.conf" "ошибка"
        any_error=true
      fi
    else
      print_operation "Обновление символической ссылки .tmux.conf" "успешно" "GREEN"
    fi
  else
    print_warning "Обновление символической ссылки .tmux.conf" "исходный файл не найден"
    any_error=true
  fi
  
  if [[ -d "$BASE_DIR/dotfiles" && -f "$BASE_DIR/dotfiles/.tmux.conf.local" ]]; then
    if ! ln -sf "$BASE_DIR/dotfiles/.tmux.conf.local" "$HOME/.tmux.conf.local"; then
      if sudo ln -sf "$BASE_DIR/dotfiles/.tmux.conf.local" "$HOME/.tmux.conf.local"; then
        print_operation "Обновление символической ссылки .tmux.conf.local" "успешно" "GREEN"
      else
        print_error "Обновление символической ссылки .tmux.conf.local" "ошибка"
        any_error=true
      fi
    else
      print_operation "Обновление символической ссылки .tmux.conf.local" "успешно" "GREEN"
    fi
  else
    print_warning "Обновление символической ссылки .tmux.conf.local" "исходный файл не найден"
    any_error=true
  fi
  
  if [[ -d "$BASE_DIR/dotfiles" && -f "$BASE_DIR/dotfiles/.vimrc" ]]; then
    if ! ln -sf "$BASE_DIR/dotfiles/.vimrc" "$HOME/.vimrc"; then
      if sudo ln -sf "$BASE_DIR/dotfiles/.vimrc" "$HOME/.vimrc"; then
        print_operation "Обновление символической ссылки .vimrc" "успешно" "GREEN"
      else
        print_error "Обновление символической ссылки .vimrc" "ошибка"
        any_error=true
      fi
    else
      print_operation "Обновление символической ссылки .vimrc" "успешно" "GREEN"
    fi
  else
    print_warning "Обновление символической ссылки .vimrc" "исходный файл не найден"
    any_error=true
  fi
  
  if [[ -d "$BASE_DIR/vim" ]]; then
    if ! ln -sfn "$BASE_DIR/vim" "$HOME/.vim"; then
      if sudo ln -sfn "$BASE_DIR/vim" "$HOME/.vim"; then
        print_operation "Обновление символической ссылки .vim" "успешно" "GREEN"
      else
        print_error "Обновление символической ссылки .vim" "ошибка"
        any_error=true
      fi
    else
      print_operation "Обновление символической ссылки .vim" "успешно" "GREEN"
    fi
  else
    print_warning "Обновление символической ссылки .vim" "исходная директория не найдена"
    any_error=true
  fi
  
  if [[ -d "$BASE_DIR/ohmyzsh" ]]; then
    if ! ln -sfn "$BASE_DIR/ohmyzsh" "$HOME/.oh-my-zsh"; then
      if sudo ln -sfn "$BASE_DIR/ohmyzsh" "$HOME/.oh-my-zsh"; then
        print_operation "Обновление символической ссылки .oh-my-zsh" "успешно" "GREEN"
      else
        print_error "Обновление символической ссылки .oh-my-zsh" "ошибка"
        any_error=true
      fi
    else
      print_operation "Обновление символической ссылки .oh-my-zsh" "успешно" "GREEN"
    fi
  else
    print_warning "Обновление символической ссылки .oh-my-zsh" "исходная директория не найдена"
    any_error=true
  fi
  
  if $any_error; then
    print_warning "Не все символические ссылки были обновлены" "проверьте лог"
    return 1
  else
    print_success "Все символические ссылки обновлены" "успешно"
    return 0
  fi
}

# Функция для меню резервного копирования
backup_menu() {
  local choice=""
  
  while true; do
    clear
    show_logo
    
    # Верхняя часть рамки - только верхняя линия
    echo -e "${CYAN}┌────────────────────────────────────────────────────────────────────┐${RESET}"
    echo -e "${CYAN}│${RESET}               ${YELLOW}УПРАВЛЕНИЕ РЕЗЕРВНЫМИ КОПИЯМИ${RESET}               ${CYAN}│${RESET}"
    echo -e "${CYAN}└────────────────────────────────────────────────────────────────────┘${RESET}"
    echo -e ""
    # Информация о резервных копиях без боковых рамок
    
    # Проверка наличия директории для бэкапов
    if [[ ! -d "$BACKUP_DIR" ]]; then
      echo -e "${YELLOW}⚠️  Директория для резервных копий отсутствует${RESET}"
      echo -e "${YELLOW}⚠️  Необходимо сначала создать хотя бы одну резервную копию${RESET}"
    else
      # Проверка наличия первоначальной копии
      if [[ -d "$BACKUP_DIR/$INITIAL_BACKUP_NAME" ]]; then
        local initial_date=$(stat -c %y "$BACKUP_DIR/$INITIAL_BACKUP_NAME" | cut -d' ' -f1)
        echo -e "${GREEN}✓ Первоначальная копия${RESET} - $initial_date"
      elif [[ -f "$BACKUP_DIR/${INITIAL_BACKUP_NAME}.tar.gz" ]]; then
        local initial_date=$(stat -c %y "$BACKUP_DIR/${INITIAL_BACKUP_NAME}.tar.gz" | cut -d' ' -f1)
        echo -e "${GREEN}✓ Первоначальная копия${RESET} - $initial_date (архив)"
      fi
      
      # Получаем список обычных резервных копий
      local backup_dirs=()
      while IFS= read -r dir; do
        dir_name=$(basename "$dir")
        if [[ -d "$dir" && "$dir_name" != "$INITIAL_BACKUP_NAME" && "$dir_name" != "tmp_"* && "$dir_name" == backup_* ]]; then
          local dir_date=$(stat -c %y "$dir" | cut -d' ' -f1)
          backup_dirs+=("$dir_name|$dir_date|dir")
        fi
      done < <(find "$BACKUP_DIR" -mindepth 1 -maxdepth 1 -type d 2>/dev/null || echo "")
      
      # Добавляем архивы
      while IFS= read -r archive; do
        archive_name=$(basename "$archive" .tar.gz)
        if [[ -f "$archive" && "$archive_name" != "$INITIAL_BACKUP_NAME" && "$archive_name" == backup_* ]]; then
          local archive_date=$(stat -c %y "$archive" | cut -d' ' -f1)
          backup_dirs+=("$archive_name|$archive_date|archive")
        fi
      done < <(find "$BACKUP_DIR" -mindepth 1 -maxdepth 1 -name "*.tar.gz" 2>/dev/null || echo "")
      
      # Сортируем копии по дате (сначала новые)
      IFS=$'\n' backup_dirs=($(for d in "${backup_dirs[@]}"; do
        local name=$(echo "$d" | cut -d'|' -f1)
        local date=$(echo "$d" | cut -d'|' -f2)
        local type=$(echo "$d" | cut -d'|' -f3)
        echo "$date|$name|$type"
      done | sort -r | awk -F'|' '{print $2"|"$1"|"$3}'))
      unset IFS
      
      # Выводим информацию о копиях
      if [[ ${#backup_dirs[@]} -gt 0 ]]; then
        echo -e "${GREEN}✓ Найдено ${#backup_dirs[@]} резервных копий:${RESET}"
        
        # Выводим максимум 5 копий
        local max_show=$((${#backup_dirs[@]} > 5 ? 5 : ${#backup_dirs[@]}))
        for ((i=0; i<$max_show; i++)); do
          local name=$(echo "${backup_dirs[$i]}" | cut -d'|' -f1)
          local date=$(echo "${backup_dirs[$i]}" | cut -d'|' -f2)
          local type=$(echo "${backup_dirs[$i]}" | cut -d'|' -f3)
          
          if [[ "$type" == "dir" ]]; then
            echo -e "  ${GREEN}•${RESET} $name - $date"
          else
            echo -e "  ${YELLOW}•${RESET} $name - $date (архив)"
          fi
        done
        
        # Если больше 5 копий, показываем сообщение о других
        if [[ ${#backup_dirs[@]} -gt 5 ]]; then
          local remaining=$((${#backup_dirs[@]} - 5))
          echo -e "  ${GRAY}...и еще $remaining копий${RESET}"
        fi
      else
        echo -e "${YELLOW}⚠️  Резервные копии отсутствуют${RESET}"
      fi
    fi
    
    # Разделитель
    echo -e "${CYAN}────────────────────────────────────────────────────────────────────${RESET}"
    
    # Меню доступных действий без боковых рамок
    echo -e "${BLUE}📋 Доступные действия:${RESET}"
    echo ""
    echo -e "  ${CYAN}1)${RESET} 📥 Создать новую резервную копию"
    
    # Пункт восстановления активен только если есть копии
    if [[ ${#backup_dirs[@]} -gt 0 || -d "$BACKUP_DIR/$INITIAL_BACKUP_NAME" || -f "$BACKUP_DIR/${INITIAL_BACKUP_NAME}.tar.gz" ]]; then
      echo -e "  ${CYAN}2)${RESET} 🔄 Восстановить из резервной копии"
    else
      echo -e "  ${GRAY}2)${RESET} ${GRAY}🔄 Восстановить из резервной копии (недоступно)${RESET}"
    fi
    
    # Пункт архивации доступен, если есть неархивированные копии
    if [[ ${#backup_dirs[@]} -gt 0 ]]; then
      echo -e "  ${CYAN}3)${RESET} 🗜️  Архивировать старые копии"
      echo -e "  ${CYAN}4)${RESET} 🗑️  Удалить выбранные копии"
    else
      echo -e "  ${GRAY}3)${RESET} ${GRAY}🗜️  Архивировать старые копии (недоступно)${RESET}"
      echo -e "  ${GRAY}4)${RESET} ${GRAY}🗑️  Удалить выбранные копии (недоступно)${RESET}"
    fi
    
    echo -e "  ${CYAN}5)${RESET} ⚙️  Настроить параметры резервного копирования"
    echo -e "  ${CYAN}0)${RESET} 🔙 Вернуться в главное меню"
    
    # Нижняя линия рамки
    echo -e "${CYAN}────────────────────────────────────────────────────────────────────${RESET}"
    
    # Отступ после меню
    echo ""
    
    # Запрос выбора
    choice=""
    read -p "🔢 Ваш выбор [0-5]: " choice
    
    case $choice in
      1) # Создать новую резервную копию
        create_backup
        ;;
      2) # Восстановить из копии
        if [[ ${#backup_dirs[@]} -gt 0 || -d "$BACKUP_DIR/$INITIAL_BACKUP_NAME" || -f "$BACKUP_DIR/${INITIAL_BACKUP_NAME}.tar.gz" ]]; then
          restore_backup
        else
          echo -e "\n${YELLOW}⚠️ Нет доступных резервных копий для восстановления.${RESET}"
          read -p "⏳ Нажмите Enter, чтобы продолжить..." dummy
        fi
        ;;
      3) # Архивировать копии
        if [[ ${#backup_dirs[@]} -gt 0 ]]; then
          archive_backup
        else
          echo -e "\n${YELLOW}⚠️ Нет резервных копий для архивации.${RESET}"
          read -p "⏳ Нажмите Enter, чтобы продолжить..." dummy
        fi
        ;;
      4) # Удалить копии
        if [[ ${#backup_dirs[@]} -gt 0 ]]; then
          delete_backup
        else
          echo -e "\n${YELLOW}⚠️ Нет резервных копий для удаления.${RESET}"
          read -p "⏳ Нажмите Enter, чтобы продолжить..." dummy
        fi
        ;;
      5) # Настройки резервного копирования
        configure_backup
        ;;
      0|q|Q|exit|quit) # Выход в главное меню
        return 0
        ;;
      *) # Некорректный выбор
        echo -e "\n${RED}❌ Некорректный выбор. Пожалуйста, выберите действие из списка.${RESET}"
        read -p "⏳ Нажмите Enter, чтобы продолжить..." dummy
        ;;
    esac
  done
}

# Обновленная функция отображения меню опций
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
      echo -e "  ${CYAN}5)${RESET} 💾 Управление резервными копиями"
      echo -e "  ${CYAN}0)${RESET} 🚪 Выход без изменений\n"
    else
      echo -e "  ${CYAN}1)${RESET} 📥 Установить окружение ${CYAN}MYSHELL${RESET}"
      echo -e "  ${CYAN}2)${RESET} 🔐 Установить с сохранением текущих настроек"
      echo -e "  ${CYAN}0)${RESET} 🚪 Выход без изменений\n"
    fi
    
    choice=""
    read -p "🔢 Ваш выбор [0-$([ "$has_myshell" == "true" ] && echo "5" || echo "2")]: " choice
    
    # Обработка пустого ввода
    if [[ -z "$choice" ]]; then
      echo -e "\n${RED}❌ Пустой ввод. Пожалуйста, выберите действие из списка.${RESET}"
      read -p "⏳ Нажмите Enter, чтобы продолжить..." dummy
      continue
    fi
    
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
        5) # Управление резервными копиями
          ACTION="backup"
          SAVE_EXISTING="y"
          # Сразу вызываем backup_menu вместо подтверждения
          backup_menu
          continue
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

    # Создаем красивую рамку с информацией о выбранном действии
    clear
    show_logo
    
    # Получаем описание действия 
    local action_desc=$(get_action_description)
    
    # Определяем заголовок рамки в зависимости от выбранного действия
    local action_title=""
    case $ACTION in
      "update") 
        action_title="ОБНОВЛЕНИЕ ОКРУЖЕНИЯ MYSHELL"
        ;;
      "reinstall") 
        if [[ "$SAVE_EXISTING" == "y" ]]; then
          action_title="ПЕРЕУСТАНОВКА С СОХРАНЕНИЕМ НАСТРОЕК"
        else
          action_title="ПОЛНАЯ ПЕРЕУСТАНОВКА ОКРУЖЕНИЯ"
        fi
        ;;
      "install")
        if [[ "$SAVE_EXISTING" == "y" ]]; then
          action_title="УСТАНОВКА С СОХРАНЕНИЕМ НАСТРОЕК"
        else
          action_title="ЧИСТАЯ УСТАНОВКА ОКРУЖЕНИЯ"
        fi
        ;;
      "plugins") 
        action_title="ОБНОВЛЕНИЕ ПЛАГИНОВ"
        ;;
      "backup") 
        action_title="СОЗДАНИЕ РЕЗЕРВНОЙ КОПИИ"
        ;;
    esac
    
    # Верхняя часть рамки
    echo -e "${CYAN}┌────────────────────────────────────────────────────────────────────┐${RESET}"
    echo -e "${CYAN}│${RESET}               ${YELLOW}$action_title${RESET}               ${CYAN}│${RESET}"
    echo -e "${CYAN}└────────────────────────────────────────────────────────────────────┘${RESET}"
    echo -e ""
    echo -e "${YELLOW}$(center_text "$action_desc")${RESET}"
    echo -e ""
    echo -e "${CYAN}────────────────────────────────────────────────────────────────────${RESET}"
    echo -e ""


    # В зависимости от действия, добавляем разные блоки информации в рамку
    case $ACTION in
      "update") 
        echo -e "${BLUE}📊 Текущее состояние системы:${RESET}"                              
        IFS=$'\n'
        for line in $(show_environment_status); do
          echo -e "$line" | sed 's/\\n//g'
        done
        unset IFS
        echo -e ""                              
        echo -e "${BLUE}ℹ️  Информация об обновлении:${RESET}"
        echo -e "• Все компоненты будут обновлены до последних версий с GitHub."
        echo -e "• Ваши настройки будут сохранены."
        echo -e "• Все изменения будут применены сразу же."
        ;;
        
      "reinstall") 
        echo -e "${BLUE}📊 Текущее состояние системы:${RESET}"
        IFS=$'\n'
        for line in $(show_environment_status); do
          echo -e "$line" | sed 's/\\n//g'
        done
        unset IFS
        
        echo -e ""
        echo -e "${BLUE}ℹ️  Информация о переустановке:${RESET}"
        if [[ "$SAVE_EXISTING" == "y" ]]; then
          echo -e "• Резервная копия текущих настроек будет сохранена."
          echo -e "• Окружение MYSHELL будет полностью переустановлено."
          echo -e "• Ваши настройки и плагины будут восстановлены."
        else
          echo -e "${RED}⚠️  Резервная копия НЕ будет создана!${RESET}"
          echo -e "${RED}⚠️  Все ваши текущие настройки будут потеряны!${RESET}"
          echo -e "${RED}⚠️  Окружение будет установлено с нуля!${RESET}"
        fi
        ;;
        
      "install")
        echo -e "${BLUE}📊 Текущее состояние системы:${RESET}"
        IFS=$'\n'
        for line in $(show_environment_status); do
          echo -e "$line" | sed 's/\\n//g'
        done
        unset IFS
        
        echo -e ""
        echo -e "${BLUE}ℹ️  Информация об установке:${RESET}"
        if [[ "$SAVE_EXISTING" == "y" ]]; then
          echo -e "• Будет создана резервная копия ваших текущих настроек."
          echo -e "• Окружение MYSHELL будет установлено с сохранением настроек."
          echo -e "• По окончании можно будет переключиться на Zsh."
        else
          echo -e "${RED}⚠️  Резервная копия НЕ будет создана!${RESET}"
          echo -e "${RED}⚠️  Все ваши текущие настройки будут заменены!${RESET}"
          echo -e "• Окружение MYSHELL будет установлено с настройками по умолчанию."
        fi
        ;;
        
      "plugins") 
        echo -e "${BLUE}📊 Информация о плагинах:${RESET}"
        echo -e ""
        
        # Проверим наличие плагинов и их версии
        if [[ -d "$BASE_DIR/ohmyzsh/custom/plugins/zsh-autosuggestions" ]]; then
          local asg_version=$(cd "$BASE_DIR/ohmyzsh/custom/plugins/zsh-autosuggestions" && git describe --tags 2>/dev/null || echo "неизвестно")
          echo -e "${GREEN}✓ zsh-autosuggestions${RESET} - версия: $asg_version"
        else
          echo -e "${RED}✗ zsh-autosuggestions${RESET} - будет установлен"
        fi
        
        if [[ -d "$BASE_DIR/ohmyzsh/custom/plugins/zsh-syntax-highlighting" ]]; then
          local syn_version=$(cd "$BASE_DIR/ohmyzsh/custom/plugins/zsh-syntax-highlighting" && git describe --tags 2>/dev/null || echo "неизвестно")
          echo -e "${GREEN}✓ zsh-syntax-highlighting${RESET} - версия: $syn_version"
        else
          echo -e "${RED}✗ zsh-syntax-highlighting${RESET} - будет установлен"
        fi
        
        if [[ -d "$VIM_COLORS_DIR/papercolor-theme" ]]; then
          local pc_version=$(cd "$VIM_COLORS_DIR/papercolor-theme" && git describe --tags 2>/dev/null || echo "неизвестно")
          echo -e "${GREEN}✓ PaperColor${RESET} - версия: $pc_version"
        else
          echo -e "${RED}✗ PaperColor${RESET} - будет установлен"
        fi
        
        echo -e ""
        echo -e "${BLUE}ℹ️  Операция обновления плагинов:${RESET}"
        echo -e "• Все плагины будут обновлены до последних версий."
        echo -e "• Основные компоненты останутся без изменений."
        echo -e "• Обновление безопасно и не затронет ваши настройки."
        ;;
        
      "backup") 
        echo -e "${BLUE}📊 Информация о резервных копиях:${RESET}"
        IFS=$'\n'
        for line in $(show_backup_info); do
          echo -e "$line" | sed 's/\\n//g'
        done
        unset IFS
        
        echo -e ""
        echo -e "${BLUE}ℹ️  Информация о создании резервной копии:${RESET}"
        echo -e "• Будет создана полная копия текущего окружения MYSHELL."
        echo -e "• Копия будет сохранена в директории:"
        echo -e "$DATED_BACKUP_DIR"
        echo -e "Старые копии будут архивированы при достижении лимита ($MAX_BACKUPS)."
        ;;
    esac
    
    # Информация о компонентах
    echo -e "${CYAN}────────────────────────────────────────────────────────────────────${RESET}"
    echo -e "${BLUE}📋 Затрагиваемые компоненты:${RESET}"

    case $ACTION in
      "update"|"reinstall"|"install")
        echo -e "  ${GREEN}✓${RESET} Zsh/Oh-My-Zsh"
        echo -e "  ${GREEN}✓${RESET} Tmux"
        echo -e "  ${GREEN}✓${RESET} Vim"
        echo -e "  ${GREEN}✓${RESET} Dotfiles"
        echo -e "  ${GREEN}✓${RESET} Плагины"
        ;;
      "plugins")
        echo -e "  ${GREEN}✓${RESET} Плагины Zsh"
        echo -e "  ${GREEN}✓${RESET} Темы Vim"
        echo -e "  ${GRAY}✗${RESET} Основные компоненты (не изменяются)"
        ;;
      "backup")
        echo -e "  ${GREEN}✓${RESET} Все настройки окружения"
        echo -e "  ${GREEN}✓${RESET} Файлы конфигурации"
        echo -e "  ${GREEN}✓${RESET} Плагины и расширения"
        ;;
    esac

    # Нижняя часть рамки и предупреждение
    echo -e "${CYAN}────────────────────────────────────────────────────────────────────${RESET}"
    echo ""

    echo -e "${YELLOW}Предупреждение:${RESET} Перед продолжением убедитесь, что все данные,"
    echo -e "которые вам важны, сохранены. В случае проблем вы всегда можете"
    echo -e "восстановить настройки из резервной копии."
    echo ""
    echo -e "${CYAN}────────────────────────────────────────────────────────────────────${RESET}"
    
    # Запрашиваем подтверждение
    echo ""
    echo -en "${GREEN}▶  Вы уверены, что хотите продолжить? (y/n): ${RESET}"
    confirm=""
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

# Функция для проверки доступности репозитория
check_repo_availability() {
  local repo_url="$1"
  local repo_name="$2"
  
  # Извлекаем домен из URL
  local domain=$(echo "$repo_url" | sed -E 's|^https?://([^/]+).*|\1|')
  
  # Проверяем доступность домена
  if ! ping -c 1 -W 3 "$domain" &>/dev/null; then
    print_warning "Домен $domain для репозитория $repo_name" "недоступен"
    return 1
  fi
  
  # Проверяем доступность самого репозитория
  if ! git ls-remote --quiet --exit-code "$repo_url" HEAD &>/dev/null; then
    print_warning "Репозиторий $repo_name" "недоступен"
    return 1
  fi
  
  return 0
}

# Безопасный режим + ловушка ошибок
set -euo pipefail
trap 'echo -e "${RED}🚨 Произошла ошибка в строке $LINENO. Завершаем.${RESET}"; log_error "Ошибка в строке $LINENO"' ERR

# 🔐 Защита от запуска от root
if [[ "$EUID" -eq 0 ]]; then
  echo -e "${RED}❌ Не запускайте скрипт от root. Используйте обычного пользователя с sudo.${RESET}"
  exit 1
fi

# 🧪 Проверка подключения к интернету
if ! ping -c 1 -W 3 1.1.1.1 &>/dev/null; then
  echo -e "${RED}❌ Нет подключения к интернету. Проверьте сеть.${RESET}"
  exit 1
fi

# 🧪 Проверка доступности GitHub
if ! curl -s -o /dev/null -I -L --fail --connect-timeout 5 https://github.com; then
  echo -e "${RED}❌ GitHub недоступен. Проверьте подключение к сети или VPN.${RESET}"
  exit 1
fi

# 🧪 Проверка доступности всех используемых репозиториев
print_group_header "🔗 Проверка доступности репозиториев"

# Создаем ассоциативный массив: url => name
declare -A repos=(
  ["$GIT_DOTFILES_REPO"]="Dotfiles"
  ["$GIT_TMUX_REPO"]="Tmux"
  ["$GIT_OMZ_REPO"]="Oh-My-Zsh"
  ["$GIT_ZSH_AUTOSUGGESTIONS_REPO"]="ZSH Autosuggestions"
  ["$GIT_ZSH_SYNTAX_HIGHLIGHTING_REPO"]="ZSH Syntax Highlighting"
  ["$GIT_VIM_PAPERCOLOR_REPO"]="Vim PaperColor Theme"
)

# Проверяем каждый репозиторий
repo_errors=0
for repo_url in "${!repos[@]}"; do
  repo_name="${repos[$repo_url]}"
  if check_repo_availability "$repo_url" "$repo_name"; then
    print_operation "Проверка репозитория $repo_name" "доступен" "GREEN"
  else
    print_error "Проверка репозитория $repo_name" "недоступен"
    repo_errors=$((repo_errors + 1))
  fi
done

# Если есть недоступные репозитории, предупреждаем пользователя
if [[ $repo_errors -gt 0 ]]; then
  echo -e "\n${YELLOW}⚠️ Некоторые репозитории недоступны ($repo_errors из ${#repos[@]})${RESET}"
  echo -e "${YELLOW}⚠️ Это может привести к ошибкам при установке/обновлении.${RESET}"
  read -p "Хотите продолжить несмотря на предупреждения? (y/n): " continue_anyway
  
  if [[ ! "$continue_anyway" =~ ^[Yy]$ ]]; then
    echo -e "${RED}❌ Установка прервана пользователем.${RESET}"
    exit 1
  fi
  
  echo -e "${YELLOW}⚠️ Продолжаем установку, но могут возникнуть ошибки...${RESET}"
fi

# 🧪 Проверка каталога запуска
if [[ "$CURRENT_DIR" != "$HOME_DIR" ]]; then
  echo -e "${RED}❌ Скрипт должен быть запущен из домашней директории: $HOME_DIR${RESET}"
  echo -e "📍 Сейчас вы находитесь здесь: $CURRENT_DIR"
  echo -e "ℹ️ Выполните команду: cd $HOME_DIR и запустите скрипт снова."
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
echo -e "${GREEN}✅ Права sudo доступны${RESET}"

# Загрузка пользовательских настроек, если они есть
if [[ -f "$BASE_DIR/backup_config" ]]; then
  source "$BASE_DIR/backup_config"
  print_operation "Загрузка пользовательских настроек" "успешно" "GREEN"
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
  # Проверка наличия директории .myshell
  if [[ ! -d "$BASE_DIR" ]]; then
    echo -e "${RED}❌ Окружение .myshell не найдено. Нечего сохранять.${RESET}"
    exit 1
  fi
  
  # Загружаем пользовательские настройки, если они есть
  if [[ -f "$BASE_DIR/backup_config" ]]; then
    source "$BASE_DIR/backup_config"
  fi
  
  # Вызываем меню управления резервными копиями
  backup_menu
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
        print_error "Переустановка zsh-autosuggestions" "ошибка"
      fi
    else
      print_operation "Обновление zsh-autosuggestions" "успешно" "GREEN"
    fi
  else
    mkdir -p "$BASE_DIR/ohmyzsh/custom/plugins"
    if git clone -q "$GIT_ZSH_AUTOSUGGESTIONS_REPO" "$BASE_DIR/ohmyzsh/custom/plugins/zsh-autosuggestions"; then
      print_operation "Установка zsh-autosuggestions" "успешно" "GREEN"
    else
      print_error "Установка zsh-autosuggestions" "ошибка"
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
        print_error "Переустановка zsh-syntax-highlighting" "ошибка"
      fi
    else
      print_operation "Обновление zsh-syntax-highlighting" "успешно" "GREEN"
    fi
  else
    mkdir -p "$BASE_DIR/ohmyzsh/custom/plugins"
    if git clone -q "$GIT_ZSH_SYNTAX_HIGHLIGHTING_REPO" "$BASE_DIR/ohmyzsh/custom/plugins/zsh-syntax-highlighting"; then
      print_operation "Установка zsh-syntax-highlighting" "успешно" "GREEN"
    else
      print_error "Установка zsh-syntax-highlighting" "ошибка"
    fi
  fi
  
  print_group_header "📦 Обновляем темы для Vim"
  
  # Создание директорий для vim, если они не существуют
  if ! mkdir -p "$VIM_COLORS_DIR" "$VIM_PLUGINS_DIR"; then
    if sudo mkdir -p "$VIM_COLORS_DIR" "$VIM_PLUGINS_DIR"; then
      print_operation "Создание директорий для Vim" "успешно" "GREEN"
    else
      print_error "Создание директорий для Vim" "ошибка"
    fi
  fi
  
  # Обновление PaperColor темы
  if [[ -d "$VIM_COLORS_DIR/papercolor-theme" ]]; then
    if ! (cd "$VIM_COLORS_DIR/papercolor-theme" && git pull -q); then
      print_operation "Ошибка обновления, переустанавливаем PaperColor тему" "переустановка" "YELLOW"
      rm -rf "$VIM_COLORS_DIR/papercolor-theme"
      if git clone -q "$GIT_VIM_PAPERCOLOR_REPO" "$VIM_COLORS_DIR/papercolor-theme"; then
        print_operation "Переустановка PaperColor темы" "успешно" "GREEN"
      else
       print_error "Переустановка PaperColor темы" "ошибка"
      fi
    else
      print_operation "Обновление PaperColor темы" "успешно" "GREEN"
    fi
  else
    mkdir -p "$VIM_COLORS_DIR"
    if git clone -q "$GIT_VIM_PAPERCOLOR_REPO" "$VIM_COLORS_DIR/papercolor-theme"; then
      print_operation "Установка PaperColor темы" "успешно" "GREEN"
    else
      print_error "Установка PaperColor темы" "ошибка"
    fi
  fi
  
  # Обновление символической ссылки
  if ! ln -sf "$VIM_COLORS_DIR/papercolor-theme/colors/PaperColor.vim" "$VIM_COLORS_DIR/PaperColor.vim"; then
    if sudo ln -sf "$VIM_COLORS_DIR/papercolor-theme/colors/PaperColor.vim" "$VIM_COLORS_DIR/PaperColor.vim"; then
      print_operation "Обновление символической ссылки для PaperColor" "успешно" "GREEN"
    else
      print_error "Обновление символической ссылки для PaperColor" "ошибка"
    fi
  else
    print_operation "Обновление символической ссылки для PaperColor" "успешно" "GREEN"
  fi
  
  # Устанавливаем правильные права доступа
  if ! sudo chown -R "$USER":"$USER" "$BASE_DIR"; then
    print_warning "Не удалось установить права доступа" "может потребоваться ручная настройка"
  else
    print_operation "Установка прав доступа" "успешно" "GREEN"
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
  print_operation "Требуется установка пакетов" "${NEEDED_PACKAGES[*]}" "YELLOW"
  
  # Обновление индексов пакетов
  print_operation "Обновление индексов пакетов" "apt update" "CYAN"
  if ! sudo apt update; then
    print_error "Обновление индексов пакетов" "ошибка"
    echo -e "${RED}❌ Не удалось обновить индексы пакетов. Проверьте соединение и права sudo.${RESET}"
    exit 1
  fi
  
  # Установка необходимых пакетов
  print_operation "Установка пакетов" "${NEEDED_PACKAGES[*]}" "CYAN"
  if ! sudo apt install -y "${NEEDED_PACKAGES[@]}"; then
    print_error "Установка пакетов" "ошибка"
    echo -e "${RED}❌ Не удалось установить необходимые пакеты. Проверьте соединение и права sudo.${RESET}"
    exit 1
  else
    print_operation "Установка пакетов" "успешно" "GREEN"
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
        print_error "Создание папки для текущего бэкапа" "ошибка"
        exit 1
      fi
    else
      print_operation "Создание папки для текущего бэкапа" "успешно" "GREEN"
    fi
    
    # Проверка доступного места
    local myshell_size=$(du -sm "$BASE_DIR" 2>/dev/null | cut -f1 || echo "100")
    if ! check_disk_space "$BACKUP_DIR" $((myshell_size + 200)); then
      print_warning "Недостаточно места для создания резервной копии" "пропущено"
    else
      # Копируем текущее окружение .myshell (кроме папки backup)
      if ! rsync -a --exclude 'backup/' "$BASE_DIR/" "$DATED_BACKUP_DIR/"; then
        if sudo rsync -a --exclude 'backup/' "$BASE_DIR/" "$DATED_BACKUP_DIR/"; then
          print_operation "Копирование текущего окружения" "успешно" "GREEN"
        else
          print_error "Копирование текущего окружения" "ошибка"
          exit 1
        fi
      else
        print_operation "Копирование текущего окружения" "успешно" "GREEN"
      fi
      
      # Добавляем README в бэкап
      cat > "$DATED_BACKUP_DIR/README.md" << EOF
# Backup of MYSHELL environment
Created: $(date)
Original directory: $BASE_DIR

## Contents:
$(find "$DATED_BACKUP_DIR" -type d -mindepth 1 -maxdepth 1 | sort | sed 's/^/- /')
EOF
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
        if sudo mkdir -p "$BASE_DIR"; then
          print_operation "Создание директории .myshell" "успешно" "GREEN"
        else
          print_error "Создание директории .myshell" "ошибка"
          exit 1
        fi
      else
        print_operation "Создание директории .myshell" "успешно" "GREEN"
      fi
      
      # Затем создаем директорию для резервных копий
      if ! mkdir -p "$BACKUP_DIR"; then
        if sudo mkdir -p "$BACKUP_DIR"; then
          print_operation "Создание директории для резервных копий" "успешно" "GREEN"
        else
          print_error "Создание директории для резервных копий" "ошибка"
          exit 1
        fi
      else
        print_operation "Создание директории для резервных копий" "успешно" "GREEN"
      fi
      
      # И наконец, директорию для текущего бэкапа
      if ! mkdir -p "$DATED_BACKUP_DIR"; then
        if sudo mkdir -p "$DATED_BACKUP_DIR"; then
          print_operation "Создание директории для текущего бэкапа" "успешно" "GREEN"
        else
          print_error "Создание директории для текущего бэкапа" "ошибка"
          exit 1
        fi
      else
        print_operation "Создание директории для текущего бэкапа" "успешно" "GREEN"
      fi

# Функция для безопасного копирования файлов
copy_with_deref() {
  local src="$1"
  local dst="$2"
  
  # Проверка существования исходного файла
  if [[ ! -e "$src" && ! -L "$src" ]]; then
    print_warning "Исходный файл не существует" "$src"
    return 1
  fi
  
  # Обработка разных типов файлов
  if [[ -L "$src" ]]; then
    # Это символическая ссылка
    local target=$(readlink -f "$src")
    if [[ ! -e "$target" ]]; then
      print_warning "Битая символическая ссылка" "$src"
      return 1
    fi
    
    if [[ -d "$target" ]]; then
      # Директория, на которую указывает ссылка
      if ! cp -a "$target/." "$dst/"; then
        if sudo cp -a "$target/." "$dst/"; then
          print_operation "Копирование директории по ссылке" "$src" "GREEN"
          return 0
        else
          print_error "Копирование директории по ссылке" "$src"
          return 1
        fi
      else
        print_operation "Копирование директории по ссылке" "$src" "GREEN"
        return 0
      fi
    elif [[ -f "$target" ]]; then
      # Файл, на который указывает ссылка
      if [[ ! -s "$target" ]]; then
        print_warning "Пустой файл по ссылке" "$src"
        return 1
      fi
      
      if ! cp -a "$target" "$dst"; then
        if sudo cp -a "$target" "$dst"; then
          print_operation "Копирование файла по ссылке" "$src" "GREEN"
          return 0
        else
          print_error "Копирование файла по ссылке" "$src"
          return 1
        fi
      else
        print_operation "Копирование файла по ссылке" "$src" "GREEN"
        return 0
      fi
    else
      print_warning "Неизвестный тип файла по ссылке" "$src"
      return 1
    fi
  elif [[ -d "$src" ]]; then
    # Это директория
    if ! cp -a "$src/." "$dst/"; then
      if sudo cp -a "$src/." "$dst/"; then
        print_operation "Копирование директории" "$src" "GREEN"
        return 0
      else
        print_error "Копирование директории" "$src"
        return 1
      fi
    else
      print_operation "Копирование директории" "$src" "GREEN"
      return 0
    fi
  elif [[ -f "$src" ]]; then
    # Это файл
    if [[ ! -s "$src" ]]; then
      print_warning "Пустой файл" "$src"
      return 1
    fi
    
    if ! cp -a "$src" "$dst"; then
      if sudo cp -a "$src" "$dst"; then
        print_operation "Копирование файла" "$src" "GREEN"
        return 0
      else
        print_error "Копирование файла" "$src"
        return 1
      fi
    else
      print_operation "Копирование файла" "$src" "GREEN"
      return 0
    fi
  else
    print_warning "Неизвестный тип файла" "$src"
    return 1
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
                  print_error "Копирование .oh-my-zsh -> $omz_target" "ошибка"
                fi
              else
                print_operation "Копирование .oh-my-zsh -> $omz_target" "успешно" "GREEN"
              fi
            else
              print_warning "Ссылка .oh-my-zsh указывает на несуществующую директорию" "$omz_target"
            fi
          else
            if ! cp -a "$HOME/.oh-my-zsh" "$DATED_BACKUP_DIR/zsh/"; then
              if sudo cp -a "$HOME/.oh-my-zsh" "$DATED_BACKUP_DIR/zsh/"; then
                print_operation "Копирование .oh-my-zsh" "успешно" "GREEN"
              else
                print_error "Копирование .oh-my-zsh" "ошибка"
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
                  print_error "Копирование .vim -> $vim_target" "ошибка"
                fi
              else
                print_operation "Копирование .vim -> $vim_target" "успешно" "GREEN"
              fi
            else
              print_warning "Ссылка .vim указывает на несуществующую директорию" "$vim_target"
            fi
          else
            if ! cp -a "$HOME/.vim" "$DATED_BACKUP_DIR/vim/"; then
              if sudo cp -a "$HOME/.vim" "$DATED_BACKUP_DIR/vim/"; then
                print_operation "Копирование .vim" "успешно" "GREEN"
              else
               print_error "Копирование .vim" "ошибка"
              fi
            else
              print_operation "Копирование .vim" "успешно" "GREEN"
            fi
          fi
        fi
        print_operation "Сохранение конфигурации VIM" "завершено" "GREEN"
      fi
      
      # Добавляем README в сохраненную копию
      cat > "$DATED_BACKUP_DIR/README.md" << EOF
# Backup of original configuration files before MYSHELL installation
Created: $(date)

## Contents:
$(find "$DATED_BACKUP_DIR" -type d -mindepth 1 -maxdepth 1 | sort | sed 's/^/- /')
EOF
      
      print_success "Создание резервной копии существующих конфигураций" "успешно"
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
      print_error "Создание базовой директории .myshell" "ошибка"
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
      print_error "Очистка директории .myshell" "ошибка"
    fi
  else
    print_operation "Очистка директории .myshell" "успешно" "GREEN"
  fi
  
  # Функция для безопасного удаления файлов и директорий
  clean_item() {
    local item="$1"
    local target="$HOME/$item"
    
    # Пропускаем несуществующие файлы
    if [[ ! -e "$target" && ! -L "$target" ]]; then
      return 0
    fi
    
    # Проверка прав доступа перед удалением
    if [[ -w "$(dirname "$target")" ]]; then
      use_sudo=false
    else
      use_sudo=true
      print_warning "Нет прав на запись в директорию $(dirname "$target")" "будет использован sudo"
    fi
    
    # Проверяем тип элемента и удаляем соответственно
    if [[ -L "$target" ]]; then
      if $use_sudo; then
        if sudo rm "$target"; then
          print_operation "Удаление символической ссылки: $item" "успешно" "GREEN"
        else
          print_error "Удаление символической ссылки: $item" "ошибка"
        fi
      else
        if rm "$target"; then
          print_operation "Удаление символической ссылки: $item" "успешно" "GREEN"
        else
          print_error "Удаление символической ссылки: $item" "ошибка"
        fi
      fi
    elif [[ -f "$target" ]]; then
      if $use_sudo; then
        if sudo rm "$target"; then
          print_operation "Удаление файла: $item" "успешно" "GREEN"
        else
          print_error "Удаление файла: $item" "ошибка"
        fi
      else
        if rm "$target"; then
          print_operation "Удаление файла: $item" "успешно" "GREEN"
        else
          print_error "Удаление файла: $item" "ошибка"
        fi
      fi
    elif [[ -d "$target" ]]; then
      if $use_sudo; then
        if sudo rm -rf "$target"; then
          print_operation "Удаление директории: $item" "успешно" "GREEN"
        else
          print_error "Удаление директории: $item" "ошибка"
        fi
      else
        if rm -rf "$target"; then
          print_operation "Удаление директории: $item" "успешно" "GREEN"
        else
          print_error "Удаление директории: $item" "ошибка"
        fi
      fi
    else
      print_warning "Неизвестный тип элемента: $item" "пропущено"
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

# Улучшенная функция для обновления или клонирования репозитория
update_or_clone_repo() {
  local repo_url="$1"
  local target_dir="$2"
  local repo_name="$3"
  local depth_param="$4" # Опциональный параметр для глубины клонирования
  
  # Проверка доступности репозитория
  if ! git ls-remote --quiet --exit-code "$repo_url" HEAD &>/dev/null; then
    print_warning "Репозиторий $repo_name недоступен" "пропуск"
    return 1
  fi
  
  if [[ -d "$target_dir" && -d "$target_dir/.git" ]]; then
    # Директория существует и это git-репозиторий
    
    # Сначала выполняем fetch, чтобы получить информацию об изменениях
    if ! (cd "$target_dir" && git fetch --quiet); then
      if ! sudo -u "$USER" git -C "$target_dir" fetch --quiet; then
        print_warning "Не удалось выполнить fetch для $repo_name" "попытка pull"
        # Продолжаем, так как возможны временные проблемы с сетью
      fi
    fi
    
    # Проверяем, отстаёт ли локальная ветка от удалённой
    local local_commit=$(cd "$target_dir" && git rev-parse HEAD 2>/dev/null || echo "")
    local remote_commit=$(cd "$target_dir" && git rev-parse FETCH_HEAD 2>/dev/null || echo "")
    
    if [[ "$local_commit" == "$remote_commit" && -n "$local_commit" ]]; then
      # Если изменений нет, просто выводим статус об актуальности
      print_operation "Проверка $repo_name" "актуальная версия" "GREEN"
    else
      # Если есть изменения или не удалось определить, обновляем
      if ! (cd "$target_dir" && git pull --quiet); then
        if sudo -u "$USER" git -C "$target_dir" pull --quiet; then
          print_operation "Обновление $repo_name" "успешно" "GREEN"
        else
          print_error "Обновление $repo_name" "ошибка"
          
          # В случае серьезной ошибки, пытаемся переустановить
          print_operation "Попытка переустановки $repo_name" "удаление старой версии" "YELLOW"
          rm -rf "$target_dir" || sudo rm -rf "$target_dir"
          
          # Клонируем заново
          local depth_option=""
          [[ -n "$depth_param" ]] && depth_option="--depth=$depth_param"
          
          if git clone $depth_option --quiet "$repo_url" "$target_dir"; then
            print_operation "Переустановка $repo_name" "успешно" "GREEN"
          else
            if sudo git clone $depth_option --quiet "$repo_url" "$target_dir"; then
              print_operation "Переустановка $repo_name с sudo" "успешно" "GREEN"
            else
              print_error "Переустановка $repo_name" "ошибка"
              return 1
            fi
          fi
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
    
    # Создаем родительскую директорию, если она не существует
    local parent_dir=$(dirname "$target_dir")
    if [[ ! -d "$parent_dir" ]]; then
      if ! mkdir -p "$parent_dir"; then
        if ! sudo mkdir -p "$parent_dir"; then
          print_error "Создание директории $parent_dir" "ошибка"
          return 1
        fi
      fi
    fi
    
    # Клонируем репозиторий
    local depth_option=""
    [[ -n "$depth_param" ]] && depth_option="--depth=$depth_param"
    
    if git clone $depth_option --quiet "$repo_url" "$target_dir"; then
      print_operation "Клонирование $repo_name" "успешно" "GREEN"
    else
      if sudo git clone $depth_option --quiet "$repo_url" "$target_dir"; then
        print_operation "Клонирование $repo_name с sudo" "успешно" "GREEN"
        # Устанавливаем правильные права доступа
        sudo chown -R "$USER":"$USER" "$target_dir"
      else
        print_error "Клонирование $repo_name" "ошибка"
        return 1
      fi
    fi
  fi
  
  return 0
}

# Установка Oh-My-Zsh
if [[ "$ACTION" == "update" ]]; then
  # Обновление Oh-My-Zsh
  if [[ -d "$BASE_DIR/ohmyzsh" ]]; then
    if (cd "$BASE_DIR/ohmyzsh" && git pull --quiet); then
      print_operation "Обновление Oh-My-Zsh" "успешно" "GREEN"
    else
      print_error "Обновление Oh-My-Zsh" "ошибка"
      
      # В случае ошибки пытаемся переустановить
      print_operation "Переустановка Oh-My-Zsh" "начало" "YELLOW"
      rm -rf "$BASE_DIR/ohmyzsh" || sudo rm -rf "$BASE_DIR/ohmyzsh"
      
      if ! mkdir -p "$BASE_DIR/ohmyzsh"; then
        if sudo mkdir -p "$BASE_DIR/ohmyzsh"; then
          print_operation "Создание директории для Oh-My-Zsh" "успешно" "GREEN"
        else
          print_error "Создание директории для Oh-My-Zsh" "ошибка"
        fi
      fi
      
      if git clone --depth=1 --quiet "$GIT_OMZ_REPO" "$BASE_DIR/ohmyzsh"; then
        print_operation "Переустановка Oh-My-Zsh" "успешно" "GREEN"
      else
        print_error "Переустановка Oh-My-Zsh" "ошибка"
      fi
    fi
  else
    print_operation "Директория Oh-My-Zsh не найдена" "будет установлена" "YELLOW"
    mkdir -p "$BASE_DIR/ohmyzsh" || sudo mkdir -p "$BASE_DIR/ohmyzsh"
    if git clone --depth=1 --quiet "$GIT_OMZ_REPO" "$BASE_DIR/ohmyzsh"; then
      print_operation "Установка Oh-My-Zsh" "успешно" "GREEN"
    else
      print_error "Установка Oh-My-Zsh" "ошибка"
    fi
  fi
else
  # Новая установка Oh-My-Zsh
  mkdir -p "$BASE_DIR/ohmyzsh" || sudo mkdir -p "$BASE_DIR/ohmyzsh"
  if git clone --depth=1 --quiet "$GIT_OMZ_REPO" "$BASE_DIR/ohmyzsh"; then
    print_operation "Установка Oh-My-Zsh" "успешно" "GREEN"
  else
    print_error "Установка Oh-My-Zsh" "ошибка"
  fi
fi

# Клонирование/обновление репозиториев
update_or_clone_repo "$GIT_TMUX_REPO" "$BASE_DIR/tmux" "tmux конфигурации" "1"
update_or_clone_repo "$GIT_DOTFILES_REPO" "$BASE_DIR/dotfiles" "dotfiles" "1"

# Создание директорий для vim
if mkdir -p "$VIM_COLORS_DIR" "$VIM_PLUGINS_DIR"; then
  print_operation "Создание директорий для vim" "успешно" "GREEN"
else
  if sudo mkdir -p "$VIM_COLORS_DIR" "$VIM_PLUGINS_DIR"; then
    print_operation "Создание директорий для vim с sudo" "успешно" "GREEN"
  else
    print_error "Создание директорий для vim" "ошибка"
  fi
fi

# Клонирование/обновление PaperColor темы
update_or_clone_repo "$GIT_VIM_PAPERCOLOR_REPO" "$VIM_COLORS_DIR/papercolor-theme" "PaperColor темы" "1"

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
    print_error "Создание директории для плагинов Zsh" "ошибка"
  fi
fi

# Установка/обновление плагинов Zsh
update_or_clone_repo "$GIT_ZSH_AUTOSUGGESTIONS_REPO" "$BASE_DIR/ohmyzsh/custom/plugins/zsh-autosuggestions" "плагина zsh-autosuggestions" "1"
update_or_clone_repo "$GIT_ZSH_SYNTAX_HIGHLIGHTING_REPO" "$BASE_DIR/ohmyzsh/custom/plugins/zsh-syntax-highlighting" "плагина zsh-syntax-highlighting" "1"

#----------------------------------------------------
# ⚙️ Настройка окружения
#----------------------------------------------------

print_group_header "⚙️ Настройка окружения"

# Создание символической ссылки для PaperColor
if [[ -d "$VIM_COLORS_DIR/papercolor-theme" && -f "$VIM_COLORS_DIR/papercolor-theme/colors/PaperColor.vim" ]]; then
  if ! ln -sf "$VIM_COLORS_DIR/papercolor-theme/colors/PaperColor.vim" "$VIM_COLORS_DIR/PaperColor.vim"; then
    if sudo ln -sf "$VIM_COLORS_DIR/papercolor-theme/colors/PaperColor.vim" "$VIM_COLORS_DIR/PaperColor.vim"; then
      print_operation "Создание символической ссылки для PaperColor" "успешно" "GREEN"
    else
      print_error "Создание символической ссылки для PaperColor" "ошибка"
    fi
  else
    print_operation "Создание символической ссылки для PaperColor" "успешно" "GREEN"
  fi
else
  print_warning "Файл PaperColor.vim не найден" "символическая ссылка не создана"
fi

# Обновление всех символических ссылок
update_symlinks

# Создание файла версии
if echo "$SCRIPT_VERSION" > "$BASE_DIR/version"; then
  print_operation "Создание файла версии" "успешно" "GREEN"
else
  if echo "$SCRIPT_VERSION" | sudo tee "$BASE_DIR/version" > /dev/null; then
    print_operation "Создание файла версии с sudo" "успешно" "GREEN"
  else
    print_error "Создание файла версии" "ошибка"
  fi
fi

# Сохранение версий компонентов в файл
{
  echo "# MYSHELL Components Versions"
  echo "# Generated: $(date)"
  echo "MYSHELL_VERSION=\"$SCRIPT_VERSION\""
  
  if [[ -d "$BASE_DIR/ohmyzsh" ]]; then
    local omz_ver=$(cd "$BASE_DIR/ohmyzsh" && git describe --tags 2>/dev/null || echo "unknown")
    echo "OH_MY_ZSH_VERSION=\"$omz_ver\""
  fi
  
  if [[ -d "$BASE_DIR/tmux" ]]; then
    local tmux_ver=$(cd "$BASE_DIR/tmux" && git describe --tags 2>/dev/null || echo "unknown")
    echo "TMUX_CONFIG_VERSION=\"$tmux_ver\""
  fi
  
  if [[ -d "$BASE_DIR/dotfiles" ]]; then
    local dotfiles_ver=$(cd "$BASE_DIR/dotfiles" && git describe --tags 2>/dev/null || echo "unknown")
    echo "DOTFILES_VERSION=\"$dotfiles_ver\""
  fi
  
  if [[ -d "$BASE_DIR/ohmyzsh/custom/plugins/zsh-autosuggestions" ]]; then
    local asg_ver=$(cd "$BASE_DIR/ohmyzsh/custom/plugins/zsh-autosuggestions" && git describe --tags 2>/dev/null || echo "unknown")
    echo "ZSH_AUTOSUGGESTIONS_VERSION=\"$asg_ver\""
  fi
  
  if [[ -d "$BASE_DIR/ohmyzsh/custom/plugins/zsh-syntax-highlighting" ]]; then
    local syn_ver=$(cd "$BASE_DIR/ohmyzsh/custom/plugins/zsh-syntax-highlighting" && git describe --tags 2>/dev/null || echo "unknown")
    echo "ZSH_SYNTAX_HIGHLIGHTING_VERSION=\"$syn_ver\""
  fi
  
  if [[ -d "$VIM_COLORS_DIR/papercolor-theme" ]]; then
    local pc_ver=$(cd "$VIM_COLORS_DIR/papercolor-theme" && git describe --tags 2>/dev/null || echo "unknown")
    echo "VIM_PAPERCOLOR_VERSION=\"$pc_ver\""
  fi
} > "$BASE_DIR/components_versions"

print_operation "Сохранение версий компонентов" "успешно" "GREEN"

#----------------------------------------------------
# 🧰 Настройка ZShell как оболочки по умолчанию
#----------------------------------------------------

print_group_header "🧰 Настройка ZShell как оболочки по умолчанию"

if [[ "$(basename "$SHELL")" != "zsh" ]]; then
  ZSH_PATH=$(which zsh 2>/dev/null)
  
  if [[ -z "$ZSH_PATH" ]]; then
    print_error "Исполняемый файл zsh" "не найден"
    print_warning "Настройка Zsh по умолчанию" "пропущено"
  else
    # Проверяем, есть ли уже zsh в /etc/shells
    if ! grep -q "$ZSH_PATH" /etc/shells; then
      if echo "$ZSH_PATH" | sudo tee -a /etc/shells > /dev/null; then
        print_operation "Добавление zsh в /etc/shells" "успешно" "GREEN"
      else
        print_error "Добавление zsh в /etc/shells" "ошибка"
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
        print_error "Установка Zsh по умолчанию" "ошибка"
      fi
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
  print_error "Установка прав доступа для директории .myshell" "ошибка"
fi

# Проверяем, что символические ссылки существуют перед установкой прав
for link in "$HOME/.oh-my-zsh" "$HOME/.vim" "$HOME/.zshrc" "$HOME/.vimrc" "$HOME/.tmux.conf" "$HOME/.tmux.conf.local"; do
  if [[ -L "$link" ]]; then
    if sudo chown -h "$USER":"$USER" "$link" 2>/dev/null; then
      print_operation "Установка прав доступа для $link" "успешно" "GREEN"
    else
      print_warning "Установка прав доступа для $link" "ошибка"
    fi
  fi
done

# Очистка временной директории
if rm -rf "$HOME/init-shell" 2>/dev/null || sudo rm -rf "$HOME/init-shell"; then
  print_operation "Очистка временной директории" "успешно" "GREEN"
else
  print_warning "Очистка временной директории" "ошибка"
fi

#----------------------------------------------------
# 🏁 Финальное сообщение
#----------------------------------------------------

# Красивое завершение
echo ""
echo -e "${GREEN}┌────────────────────────────────────────────────────────────────────┐${RESET}"
echo -e "${GREEN}│${RESET}$(center_text "${GREEN}🎉  Установка завершена успешно!  🎉${RESET}")${GREEN}│${RESET}"
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
switch_to_zsh=""
read switch_to_zsh
echo -e "${BLUE}└────────────────────────────────────────────────────────────────────┘${RESET}"
echo ""

if [[ "$switch_to_zsh" =~ ^[Yy]$ ]]; then
  echo -e "${GREEN}👋 Переходим в Zsh...${RESET}"
  exec zsh -l
else
  echo -e "${GREEN}👋 До свидания!${RESET}"
fi



                

  

          
