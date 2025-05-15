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

# 🧩 Пакеты для установки - будут уточнены в зависимости от системы
PACKAGES="git curl zsh vim"

# 🔗 Git-репозитории
GIT_DOTFILES_REPO="https://github.com/alexbic/dotfiles.git"
GIT_TMUX_REPO="https://github.com/gpakosz/.tmux.git"
GIT_OMZ_REPO="https://github.com/ohmyzsh/ohmyzsh.git"
GIT_OMZ_INSTALL_URL="https://raw.githubusercontent.com/ohmyzsh/ohmyzsh/master/tools/install.sh"

#----------------------------------------------------
# 🧠 Определение операционной системы
#----------------------------------------------------

# Определяем операционную систему
OS_TYPE="unknown"
if [[ "$OSTYPE" == "linux-gnu"* ]]; then
    OS_TYPE="linux"
    # Дополнительно определяем дистрибутив Linux
    if [[ -f /etc/debian_version ]]; then
        DISTRO="debian"
    elif [[ -f /etc/redhat-release ]]; then
        DISTRO="redhat"
    else
        DISTRO="other"
    fi
elif [[ "$OSTYPE" == "darwin"* ]]; then
    OS_TYPE="macos"
else
    echo -e "${RED}❌ Неподдерживаемая операционная система: $OSTYPE${RESET}"
    exit 1
fi

echo -e "${BLUE}🖥️ Обнаружена операционная система: ${GREEN}$OS_TYPE${RESET}"
if [[ "$OS_TYPE" == "linux" ]]; then
    echo -e "${BLUE}🐧 Дистрибутив Linux: ${GREEN}$DISTRO${RESET}"
fi

# Определяем пакетный менеджер в зависимости от системы
PACKAGE_MANAGER=""
INSTALL_CMD=""

if [[ "$OS_TYPE" == "linux" ]]; then
    if [[ "$DISTRO" == "debian" ]]; then
        PACKAGE_MANAGER="apt"
        INSTALL_CMD="sudo apt update && sudo apt install -y"
    elif [[ "$DISTRO" == "redhat" ]]; then
        PACKAGE_MANAGER="dnf"
        INSTALL_CMD="sudo dnf install -y"
    else
        echo -e "${YELLOW}⚠️ Не удалось определить пакетный менеджер. Попробуйте установить пакеты вручную.${RESET}"
    fi
elif [[ "$OS_TYPE" == "macos" ]]; then
    # Проверяем наличие Homebrew
    if command -v brew &>/dev/null; then
        PACKAGE_MANAGER="brew"
        INSTALL_CMD="brew install"
    else
        echo -e "${YELLOW}⚠️ Homebrew не установлен. Выполняем установку...${RESET}"
        /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"
        
        # Проверяем результат установки Homebrew
        if command -v brew &>/dev/null; then
            PACKAGE_MANAGER="brew"
            INSTALL_CMD="brew install"
            echo -e "${GREEN}✅ Homebrew успешно установлен${RESET}"
        else
            echo -e "${RED}❌ Не удалось установить Homebrew. Пожалуйста, установите его вручную:${RESET}"
            echo -e "   /bin/bash -c \"\$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)\""
            exit 1
        fi
    fi
fi

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

# 🧪 Проверка доступа sudo (только для Linux)
if [[ "$OS_TYPE" == "linux" ]]; then
  echo -e "${BLUE}🔐 Проверка прав sudo...${RESET}"
  if ! sudo -n true 2>/dev/null; then
    echo -e "${YELLOW}⚠️ Для продолжения требуются права sudo.${RESET}"
    sudo -v || {
      echo -e "${RED}❌ Не удалось получить права sudo. Проверьте, есть ли у вас такие права.${RESET}"
      exit 1
    }
  fi
fi

#----------------------------------------------------
# 📦 Обновление и установка зависимостей
#----------------------------------------------------

echo -e "${BLUE}📦 Проверка и установка необходимых пакетов...${RESET}"

# Настраиваем список пакетов в зависимости от операционной системы
if [[ "$OS_TYPE" == "macos" ]]; then
    # На macOS некоторые утилиты могут быть предустановлены или иметь другие названия
    PACKAGES="git curl zsh vim tmux"
fi

# Функция для проверки наличия пакета
check_package() {
    local pkg="$1"
    
    if [[ "$OS_TYPE" == "linux" ]]; then
        if [[ "$DISTRO" == "debian" ]]; then
            dpkg -s "$pkg" &>/dev/null
        elif [[ "$DISTRO" == "redhat" ]]; then
            rpm -q "$pkg" &>/dev/null
        else
            command -v "$pkg" &>/dev/null
        fi
    elif [[ "$OS_TYPE" == "macos" ]]; then
        # На macOS проверяем сначала через brew, затем по наличию команды
        brew list "$pkg" &>/dev/null || command -v "$pkg" &>/dev/null
    fi
}

NEEDED_PACKAGES=()
for pkg in $PACKAGES; do
  if ! check_package "$pkg"; then
    NEEDED_PACKAGES+=("$pkg")
  fi
done

if [[ ${#NEEDED_PACKAGES[@]} -gt 0 ]]; then
  echo "📦 Устанавливаем: ${NEEDED_PACKAGES[*]}"
  
  if [[ -n "$INSTALL_CMD" ]]; then
    # Используем соответствующую команду для установки
    if [[ "$OS_TYPE" == "linux" ]]; then
      if [[ "$DISTRO" == "debian" ]]; then
        sudo apt update
        sudo apt install -y "${NEEDED_PACKAGES[@]}"
      elif [[ "$DISTRO" == "redhat" ]]; then
        sudo dnf install -y "${NEEDED_PACKAGES[@]}"
      fi
    elif [[ "$OS_TYPE" == "macos" ]]; then
      brew install "${NEEDED_PACKAGES[@]}"
    fi
  else
    echo -e "${RED}❌ Не удалось определить команду для установки пакетов.${RESET}"
    exit 1
  fi
else
  echo "✅ Все необходимые пакеты уже установлены."
fi

#----------------------------------------------------
# 🔍 Проверка и обработка существующих конфигураций
#----------------------------------------------------

echo -e "${BLUE}🔍 Проверка наличия окружения и конфигураций...${RESET}"

# Проверяем наличие директории .myshell
if [[ -d "$BASE_DIR" ]]; then
  echo -e "${YELLOW}⚠️ Обнаружено существующее окружение .myshell${RESET}"
  read -p "📋 Хотите сохранить текущую конфигурацию перед обновлением? (y/n): " SAVE_EXISTING
  
  if [[ "$SAVE_EXISTING" =~ ^[Yy]$ ]]; then
    # Проверяем наличие предыдущих незаархивированных папок с бэкапами
    echo -e "${BLUE}🔍 Проверка наличия предыдущей папки с бэкапом...${RESET}"
    
    # Ищем папки в директории бэкапов, начинающиеся с "backup_"
    PREV_BACKUP_DIRS=()
    while IFS= read -r dir; do
      # Проверяем, начинается ли имя папки с "backup_"
      dir_name=$(basename "$dir")
      if [[ -d "$dir" && "$dir" != "$BACKUP_DIR" && "$dir_name" == backup_* ]]; then
        PREV_BACKUP_DIRS+=("$dir")
      fi
    done < <(find "$BACKUP_DIR" -mindepth 1 -maxdepth 1 -type d 2>/dev/null || echo "")
    
    # Если найдена предыдущая папка с бэкапом, архивируем её
    if [[ ${#PREV_BACKUP_DIRS[@]} -gt 0 ]]; then
      echo -e "${YELLOW}⚠️ Обнаружена предыдущая папка с бэкапом${RESET}"
      
      # Архивируем только первую найденную папку (должна быть только одна)
      backup_dir="${PREV_BACKUP_DIRS[0]}"
      dir_name=$(basename "$backup_dir")
      archive_path="$BACKUP_DIR/$dir_name.tar.gz"
      
      echo -e "${BLUE}📦 Архивируем папку $backup_dir в $archive_path...${RESET}"
      tar -czf "$archive_path" -C "$backup_dir" . || {
        echo -e "${YELLOW}⚠️ Ошибка при архивации. Пробуем с sudo...${RESET}"
        if [[ "$OS_TYPE" == "linux" ]]; then
          sudo tar -czf "$archive_path" -C "$backup_dir" .
        else
          tar -czf "$archive_path" -C "$backup_dir" .
        fi
      }
      
      # Удаляем папку после архивации
      if [[ "$OS_TYPE" == "linux" ]]; then
        rm -rf "$backup_dir" || sudo rm -rf "$backup_dir"
      else
        rm -rf "$backup_dir"
      fi
      
      echo -e "${GREEN}✅ Папка с бэкапом архивирована в $archive_path${RESET}"
      
      # Если по какой-то причине найдено больше одной папки, выводим предупреждение
      if [[ ${#PREV_BACKUP_DIRS[@]} -gt 1 ]]; then
        echo -e "${YELLOW}⚠️ Внимание: Найдено ${#PREV_BACKUP_DIRS[@]} папок с бэкапами, но обработана только первая.${RESET}"
      fi
    else
      echo -e "${GREEN}✅ Предыдущих папок с бэкапами не обнаружено${RESET}"
    fi
    
    # Создаем новую папку для текущего бэкапа
    echo -e "${BLUE}🗂️ Создание папки для текущего бэкапа: $DATED_BACKUP_DIR${RESET}"
    mkdir -p "$DATED_BACKUP_DIR" || {
      echo -e "${YELLOW}⚠️ Не удалось создать директорию для текущего бэкапа. Пробуем с sudo...${RESET}"
      if [[ "$OS_TYPE" == "linux" ]]; then
        sudo mkdir -p "$DATED_BACKUP_DIR"
      else
        mkdir -p "$DATED_BACKUP_DIR"
      fi
    }
    
    # Копируем текущее окружение .myshell (кроме папки backup)
    echo -e "${BLUE}🔄 Копирование текущего окружения в $DATED_BACKUP_DIR...${RESET}"
    rsync -a --exclude 'backup/' "$BASE_DIR/" "$DATED_BACKUP_DIR/" || {
      echo -e "${YELLOW}⚠️ Ошибка при копировании. Пробуем с sudo...${RESET}"
      if [[ "$OS_TYPE" == "linux" ]]; then
        sudo rsync -a --exclude 'backup/' "$BASE_DIR/" "$DATED_BACKUP_DIR/"
      else
        # На macOS используем cp если rsync не работает
        cp -R "$BASE_DIR"/* "$DATED_BACKUP_DIR/" 2>/dev/null || echo "Ошибка при копировании, но продолжаем..."
      fi
    }
    echo -e "${GREEN}✅ Текущее окружение .myshell сохранено в $DATED_BACKUP_DIR${RESET}"
  else
    echo -e "${YELLOW}⚠️ Бэкап текущего окружения .myshell не был создан по выбору пользователя.${RESET}"
  fi
else
  # Проверяем наличие отдельных конфигурационных файлов
  echo -e "${BLUE}🔍 Окружение .myshell не найдено, проверяем наличие отдельных конфигураций...${RESET}"
  
  EXISTING_CONFIGS=""
  [[ -f "$HOME/.zshrc" || -d "$HOME/.oh-my-zsh" ]] && EXISTING_CONFIGS="${EXISTING_CONFIGS}ZSH "
  [[ -f "$HOME/.tmux.conf" || -f "$HOME/.tmux.conf.local" ]] && EXISTING_CONFIGS="${EXISTING_CONFIGS}TMUX "
  [[ -f "$HOME/.vimrc" || -d "$HOME/.vim" ]] && EXISTING_CONFIGS="${EXISTING_CONFIGS}VIM "
  
  if [[ -n "$EXISTING_CONFIGS" ]]; then
    echo -e "${YELLOW}⚠️ Обнаружены существующие конфигурации: ${EXISTING_CONFIGS}${RESET}"
    read -p "📋 Хотите сохранить предыдущие настройки? (y/n): " SAVE_CONFIG
  
    if [[ "$SAVE_CONFIG" =~ ^[Yy]$ ]]; then
      echo -e "${BLUE}🗂️ Создание директорий для бэкапа...${RESET}"
      
      # Функция для создания директории с обработкой ошибок
      create_dir_safe() {
        local dir="$1"
        mkdir -p "$dir" || {
          echo -e "${YELLOW}⚠️ Не удалось создать директорию $dir. Пробуем с sudo...${RESET}"
          if [[ "$OS_TYPE" == "linux" ]]; then
            sudo mkdir -p "$dir"
          else
            mkdir -p "$dir"
          fi
        }
      }
      
      # Создаем необходимые директории
      create_dir_safe "$BASE_DIR"
      create_dir_safe "$BACKUP_DIR"
      create_dir_safe "$DATED_BACKUP_DIR"
      
      # Функция для безопасного копирования файла, разыменовывающая символические ссылки
      copy_with_deref() {
        local src="$1"
        local dst="$2"
        
        if [[ -L "$src" ]]; then
          # Если это символическая ссылка, проверяем, что она не битая
          local target=$(readlink -f "$src" 2>/dev/null || readlink "$src")
          if [[ -e "$target" ]]; then
            echo "🔄 Копирование файла по ссылке: $src -> $target"
            if [[ "$OS_TYPE" == "linux" ]]; then
              cp -pL "$src" "$dst" || sudo cp -pL "$src" "$dst"
            else
              cp -RL "$src" "$dst"
            fi
          else
            echo -e "${YELLOW}⚠️ Пропускаем битую символическую ссылку: $src${RESET}"
          fi
        elif [[ -f "$src" ]]; then
          # Если это обычный файл
          if [[ -s "$src" ]]; then  # Проверка на непустой файл
            echo "🔄 Копирование файла: $src"
            if [[ "$OS_TYPE" == "linux" ]]; then
              cp -p "$src" "$dst" || sudo cp -p "$src" "$dst"
            else
              cp -p "$src" "$dst"
            fi
          else
            echo -e "${YELLOW}⚠️ Пропускаем пустой файл: $src${RESET}"
          fi
        elif [[ -d "$src" ]]; then
          # Если это директория
          echo "🔄 Копирование директории: $src"
          if [[ "$OS_TYPE" == "linux" ]]; then
            cp -a "$src" "$dst" || sudo cp -a "$src" "$dst"
          else
            cp -R "$src" "$dst"
          fi
        fi
      }
      
      # Копирование конфигурационных файлов и директорий
      if [[ "$EXISTING_CONFIGS" == *"ZSH"* ]]; then
        echo "🔄 Сохранение конфигурации ZSH..."
        create_dir_safe "$DATED_BACKUP_DIR/zsh"
        
        if [[ -e "$HOME/.zshrc" ]]; then
          copy_with_deref "$HOME/.zshrc" "$DATED_BACKUP_DIR/zsh/"
        fi
        
        if [[ -d "$HOME/.oh-my-zsh" ]]; then
          if [[ -L "$HOME/.oh-my-zsh" ]]; then
            echo "🔄 Обнаружена символическая ссылка .oh-my-zsh, копируем настоящую директорию"
            local omz_target=$(readlink -f "$HOME/.oh-my-zsh" 2>/dev/null || readlink "$HOME/.oh-my-zsh")
            if [[ -d "$omz_target" ]]; then
              if [[ "$OS_TYPE" == "linux" ]]; then
                cp -a "$omz_target" "$DATED_BACKUP_DIR/zsh/oh-my-zsh" || sudo cp -a "$omz_target" "$DATED_BACKUP_DIR/zsh/oh-my-zsh"
              else
                cp -R "$omz_target" "$DATED_BACKUP_DIR/zsh/oh-my-zsh"
              fi
            else
              echo -e "${YELLOW}⚠️ Ссылка .oh-my-zsh указывает на несуществующую директорию${RESET}"
            fi
          else
            if [[ "$OS_TYPE" == "linux" ]]; then
              cp -a "$HOME/.oh-my-zsh" "$DATED_BACKUP_DIR/zsh/" || sudo cp -a "$HOME/.oh-my-zsh" "$DATED_BACKUP_DIR/zsh/"
            else
              cp -R "$HOME/.oh-my-zsh" "$DATED_BACKUP_DIR/zsh/"
            fi
          fi
        fi
      fi
  
      if [[ "$EXISTING_CONFIGS" == *"TMUX"* ]]; then
        echo "🔄 Сохранение конфигурации TMUX..."
        create_dir_safe "$DATED_BACKUP_DIR/tmux"
        
        [[ -e "$HOME/.tmux.conf" ]] && copy_with_deref "$HOME/.tmux.conf" "$DATED_BACKUP_DIR/tmux/"
        [[ -e "$HOME/.tmux.conf.local" ]] && copy_with_deref "$HOME/.tmux.conf.local" "$DATED_BACKUP_DIR/tmux/"
      fi
  
      if [[ "$EXISTING_CONFIGS" == *"VIM"* ]]; then
        echo "🔄 Сохранение конфигурации VIM..."
        create_dir_safe "$DATED_BACKUP_DIR/vim"
        
        [[ -e "$HOME/.vimrc" ]] && copy_with_deref "$HOME/.vimrc" "$DATED_BACKUP_DIR/vim/"
        
        if [[ -d "$HOME/.vim" || -L "$HOME/.vim" ]]; then
          if [[ -L "$HOME/.vim" ]]; then
            echo "🔄 Обнаружена символическая ссылка .vim, копируем настоящую директорию"
            local vim_target=$(readlink -f "$HOME/.vim" 2>/dev/null || readlink "$HOME/.vim")
            if [[ -d "$vim_target" ]]; then
              if [[ "$OS_TYPE" == "linux" ]]; then
                cp -a "$vim_target" "$DATED_BACKUP_DIR/vim/vim" || sudo cp -a "$vim_target" "$DATED_BACKUP_DIR/vim/vim"
              else
                cp -R "$vim_target" "$DATED_BACKUP_DIR/vim/vim"
              fi
            else
              echo -e "${YELLOW}⚠️ Ссылка .vim указывает на несуществующую директорию${RESET}"
            fi
          else
            if [[ "$OS_TYPE" == "linux" ]]; then
              cp -a "$HOME/.vim" "$DATED_BACKUP_DIR/vim/" || sudo cp -a "$HOME/.vim" "$DATED_BACKUP_DIR/vim/"
            else
              cp -R "$HOME/.vim" "$DATED_BACKUP_DIR/vim/"
            fi
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

#----------------------------------------------------
# 🛠️ Подготовка окружения для установки
#----------------------------------------------------

# Очищаем содержимое директории .myshell (кроме директории backup)
echo -e "${BLUE}🧹 Очищаем содержимое директории $BASE_DIR (кроме бэкапов)...${RESET}"

# Безопасная очистка в зависимости от ОС
if [[ "$OS_TYPE" == "linux" ]]; then
  if find "$BASE_DIR" -mindepth 1 ! -path "$BACKUP_DIR" ! -path "$BACKUP_DIR/*" -print0 | xargs -0 rm -rf 2>/dev/null; then
    echo "✅ Старый контент удален"
  else
    echo -e "${YELLOW}⚠️ Не удалось удалить старый контент. Пробуем с sudo...${RESET}"
    sudo find "$BASE_DIR" -mindepth 1 ! -path "$BACKUP_DIR" ! -path "$BACKUP_DIR/*" -print0 | xargs -0 sudo rm -rf
  fi
else
  # На macOS используем немного другой подход
  for item in "$BASE_DIR"/*; do
    if [[ "$item" != "$BACKUP_DIR" ]]; then
      rm -rf "$item" 2>/dev/null
    fi
  done
  echo "✅ Старый контент удален"
fi

#----------------------------------------------------
# 📦 Установка и настройка Oh-My-Zsh
#----------------------------------------------------

# Функция для безопасного удаления Oh-My-Zsh
clean_ohmyzsh() {
  echo -e "${YELLOW}🧹 Удаление предыдущей установки Oh-My-Zsh...${RESET}"
  
  if [[ -L "$HOME/.oh-my-zsh" ]]; then
    echo "  - Обнаружена символическая ссылка, удаляем..."
    ( cd "$HOME" && exec /bin/rm -f .oh-my-zsh )
  elif [[ -d "$HOME/.oh-my-zsh" ]]; then
    echo "  - Обнаружена директория, удаляем рекурсивно..."
    if [[ "$OS_TYPE" == "linux" ]]; then
      /bin/rm -rf "$HOME/.oh-my-zsh" || sudo /bin/rm -rf "$HOME/.oh-my-zsh"
    else
      /bin/rm -rf "$HOME/.oh-my-zsh"
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
  echo -e "${BLUE}📥 Установка Oh-My-Zsh...${RESET}"
  
  # Очищаем и создаем директорию в нашем окружении
  if [[ "$OS_TYPE" == "linux" ]]; then
    mkdir -p "$BASE_DIR/ohmyzsh" || sudo mkdir -p "$BASE_DIR/ohmyzsh"
  else
    mkdir -p "$BASE_DIR/ohmyzsh"
  fi
  
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
  
  # Проверяем наличие скрипта обновления
  if [[ -x "$HOME/.oh-my-zsh/tools/upgrade.sh" ]]; then
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

if [[ -d "$HOME/.oh-my-zsh" && ! -L "$HOME/.oh-my-zsh" ]]; then
  # Если существует директория (не ссылка), пробуем обновить
  update_ohmyzsh || {
    # Если обновление не удалось, очищаем и устанавливаем заново
    echo -e "${YELLOW}⚠️ Выполняем переустановку Oh-My-Zsh...${RESET}"
    clean_ohmyzsh && install_ohmyzsh || exit 1
  }
else
  # Если это ссылка или отсутствует, очищаем и устанавливаем заново
  clean_ohmyzsh && install_ohmyzsh || exit 1
fi

#----------------------------------------------------
# 🧹 Чистим окружение
#----------------------------------------------------

# Функция для безопасного удаления файлов и директорий
clean_item() {
 local item="$1"
 local target="$HOME/$item"
 
 # Проверяем тип элемента и удаляем соответственно
 if [[ -L "$target" ]]; then
   echo -e "🔗 Удаляем симлинк: ${CYAN}$target${RESET}"
   rm "$target" 2>/dev/null || {
     if [[ "$OS_TYPE" == "linux" ]]; then
       sudo rm "$target"
     else
       rm -f "$target"
     fi
   }
 elif [[ -f "$target" ]]; then
   echo -e "📄 Удаляем файл: ${CYAN}$target${RESET}"
   rm "$target" 2>/dev/null || {
     if [[ "$OS_TYPE" == "linux" ]]; then
       sudo rm "$target"
     else
       rm -f "$target"
     fi
   }
 elif [[ -d "$target" ]]; then
   echo -e "📁 Удаляем директорию: ${CYAN}$target${RESET}"
   rm -rf "$target" 2>/dev/null || {
     if [[ "$OS_TYPE" == "linux" ]]; then
       sudo rm -rf "$target"
     else
       rm -rf "$target"
     fi
   }
 else
   echo -e "ℹ️  Пропускаем: ${CYAN}$target${RESET} (не найден)"
 fi
}

# Удаление старых конфигов и симлинков
echo -e "${YELLOW}🧹 Удаляем старые конфиги и симлинки...${RESET}"

for item in $TRASH; do
 clean_item "$item"
done

echo -e "${GREEN}✅ Очистка завершена.${RESET}"

#----------------------------------------------------
# 📥 Клонируем окружение
#----------------------------------------------------

# Функция для клонирования репозитория с обработкой ошибок
clone_repo() {
 local repo_url="$1"
 local target_dir="$2"
 
 echo -e "${BLUE}📥 Клонируем $repo_url в $target_dir...${RESET}"
 
 git clone "$repo_url" "$target_dir" || {
   echo -e "${YELLOW}⚠️ Ошибка при клонировании. Проверяем права доступа...${RESET}"
   if [[ "$OS_TYPE" == "linux" ]]; then
     sudo git clone "$repo_url" "$target_dir"
   else
     rm -rf "$target_dir" 2>/dev/null
     git clone "$repo_url" "$target_dir"
   fi
 }
}

# Функция для создания каталога с проверкой прав
create_dir() {
 local dir="$1"
 
 mkdir -p "$dir" || {
   echo -e "${YELLOW}⚠️ Не удалось создать директорию $dir. Пробуем с sudo...${RESET}"
   if [[ "$OS_TYPE" == "linux" ]]; then
     sudo mkdir -p "$dir"
   else
     mkdir -p "$dir"
   fi
 }
}

clone_repo "$GIT_TMUX_REPO" "$BASE_DIR/tmux"
clone_repo "$GIT_DOTFILES_REPO" "$BASE_DIR/dotfiles"

create_dir "$VIM_COLORS_DIR"
create_dir "$VIM_PLUGINS_DIR"

if [[ ! -d "$VIM_COLORS_DIR/papercolor-theme" ]]; then
 clone_repo "https://github.com/NLKNguyen/papercolor-theme.git" "$VIM_COLORS_DIR/papercolor-theme"
else
 echo -e "${GREEN}✅ PaperColor уже добавлен${RESET}"
fi

# Создание символической ссылки с проверкой ОС
create_symlink() {
 local src="$1"
 local dst="$2"
 
 ln -sf "$src" "$dst" || {
   echo -e "${YELLOW}⚠️ Не удалось создать символическую ссылку. Пробуем с sudo...${RESET}"
   if [[ "$OS_TYPE" == "linux" ]]; then
     sudo ln -sf "$src" "$dst"
   else
     rm -f "$dst" 2>/dev/null
     ln -sf "$src" "$dst"
   fi
 }
}

create_symlink "$VIM_COLORS_DIR/papercolor-theme/colors/PaperColor.vim" "$VIM_COLORS_DIR/PaperColor.vim"

echo "📦 Устанавливаем плагины для Zsh..."
create_dir "$BASE_DIR/ohmyzsh/custom/plugins"

clone_repo "https://github.com/zsh-users/zsh-autosuggestions" "$BASE_DIR/ohmyzsh/custom/plugins/zsh-autosuggestions"
clone_repo "https://github.com/zsh-users/zsh-syntax-highlighting" "$BASE_DIR/ohmyzsh/custom/plugins/zsh-syntax-highlighting"

#----------------------------------------------------
# ⚙️ Настройки окружения
#----------------------------------------------------

echo "⚙️ Настраиваем zsh..."
create_symlink "$BASE_DIR/dotfiles/.zshrc" "$HOME/.zshrc"

echo "⚙️ Настраиваем vim..."
create_symlink "$BASE_DIR/dotfiles/.vimrc" "$HOME/.vimrc"
create_symlink "$VIM_DIR" "$HOME/.vim"

echo "⚙️ Настраиваем tmux..."
create_symlink "$BASE_DIR/tmux/.tmux.conf" "$HOME/.tmux.conf"
create_symlink "$BASE_DIR/dotfiles/.tmux.conf.local" "$HOME/.tmux.conf.local"

echo "⚙️ Настраиваем Oh-My-Zsh..."
create_symlink "$BASE_DIR/ohmyzsh" "$HOME/.oh-my-zsh"

#----------------------------------------------------
# 🧰 Проверка и установка ZShell по умолчанию
#----------------------------------------------------
if [[ "$(basename "$SHELL")" != "zsh" ]]; then
 echo "🔁 Меняем shell на Zsh..."
 ZSH_PATH=$(which zsh)
 
 # Различия для Linux и macOS
 if [[ "$OS_TYPE" == "linux" ]]; then
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
 elif [[ "$OS_TYPE" == "macos" ]]; then
   # На macOS проверяем иначе
   if ! grep -q "$ZSH_PATH" /etc/shells; then
     echo -e "${YELLOW}⚠️ Добавляем $ZSH_PATH в /etc/shells...${RESET}"
     echo "$ZSH_PATH" | sudo tee -a /etc/shells > /dev/null
   fi
   
   # На macOS chsh работает немного иначе
   chsh -s "$ZSH_PATH" || {
     echo -e "${YELLOW}⚠️ Не удалось изменить оболочку. Попробуйте вручную:${RESET}"
     echo "chsh -s $ZSH_PATH"
   }
 fi
 
 echo -e "${GREEN}✅ Zsh установлен как оболочка по умолчанию. Изменения вступят в силу после перезапуска терминала.${RESET}"
else
 echo "✅ Zsh уже установлен как shell по умолчанию."
fi

#----------------------------------------------------
# ✅ Завершение установки
#----------------------------------------------------

# Обновляем владельца всех файлов и директорий
echo -e "${BLUE}🛠️ Установка правильных прав доступа...${RESET}"

if [[ "$OS_TYPE" == "linux" ]]; then
 # Для Linux оставляем как было, так как это работало
 sudo chown -R "$USER":"$USER" "$BASE_DIR"
 
 # Проверяем, что символические ссылки существуют перед установкой прав
 for link in "$HOME/.oh-my-zsh" "$HOME/.vim" "$HOME/.zshrc" "$HOME/.vimrc" "$HOME/.tmux.conf" "$HOME/.tmux.conf.local"; do
   if [[ -L "$link" ]]; then
     sudo chown -h "$USER":"$USER" "$link" 2>/dev/null
   fi
 done
elif [[ "$OS_TYPE" == "macos" ]]; then
 # На macOS используем группу "staff", которая является стандартной группой пользователей
 chown -R "$USER:staff" "$BASE_DIR" 2>/dev/null || {
   # Если не сработало, пробуем без указания группы
   echo -e "${YELLOW}⚠️ Не удалось установить владельца с группой staff. Пробуем без группы...${RESET}"
   chown -R "$USER" "$BASE_DIR" 2>/dev/null
 }
 
 # Проверяем символические ссылки
 for link in "$HOME/.oh-my-zsh" "$HOME/.vim" "$HOME/.zshrc" "$HOME/.vimrc" "$HOME/.tmux.conf" "$HOME/.tmux.conf.local"; do
   if [[ -L "$link" ]]; then
     chown -h "$USER:staff" "$link" 2>/dev/null || chown -h "$USER" "$link" 2>/dev/null
   fi
 done
fi

#----------------------------------------------------
# 🗑️ Очистка временной директории
#----------------------------------------------------
if [[ "$OS_TYPE" == "linux" ]]; then
 rm -rf "$HOME/init-shell" 2>/dev/null || sudo rm -rf "$HOME/init-shell"
else
 rm -rf "$HOME/init-shell" 2>/dev/null
fi

#----------------------------------------------------
# ✅ Завершено
#----------------------------------------------------
echo -e "${GREEN}🎉 Установка завершена успешно!${RESET}"

# Информация о системе
if [[ "$OS_TYPE" == "macos" ]]; then
 echo -e "${BLUE}ℹ️  Информация о macOS:${RESET}"
 echo "  📱 Версия macOS: $(sw_vers -productVersion)"
 echo "  🔄 Архитектура: $(uname -m)"
 echo "  🧩 Компоненты были установлены с помощью Homebrew"
elif [[ "$OS_TYPE" == "linux" ]]; then
 echo -e "${BLUE}ℹ️  Информация о Linux:${RESET}"
 echo "  🐧 Дистрибутив: $DISTRO"
 echo "  🔄 Архитектура: $(uname -m)"
 if [[ -f /etc/os-release ]]; then
   source /etc/os-release
   echo "  📱 Версия: $NAME $VERSION_ID"
 fi
fi

echo -e "${YELLOW}⚠️ Важно:${RESET} Для применения всех изменений может потребоваться перезапуск терминала"
echo -e "${BLUE}🔍 Проверьте работу команд zsh, vim и tmux${RESET}"


