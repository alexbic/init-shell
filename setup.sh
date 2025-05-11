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

# 🧩 Пакеты для установки
PACKAGES="git curl zsh vim"

# 🔗 Git-репозитории
GIT_DOTFILES_REPO="https://github.com/alexbic/dotfiles.git"
GIT_TMUX_REPO="https://github.com/gpakosz/.tmux.git"
GIT_OMZ_REPO="https://github.com/ohmyzsh/ohmyzsh.git"
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
        sudo tar -czf "$archive_path" -C "$backup_dir" .
      }
      
      # Удаляем папку после архивации
      rm -rf "$backup_dir" || sudo rm -rf "$backup_dir"
      
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
    read -p "📋 Хотите сохранить предыдущие настройки? (y/n): " SAVE_CONFIG
  
    if [[ "$SAVE_CONFIG" =~ ^[Yy]$ ]]; then
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
            echo "🔄 Копирование файла по ссылке: $src -> $target"
            cp -pL "$src" "$dst" || sudo cp -pL "$src" "$dst"
          else
            echo -e "${YELLOW}⚠️ Пропускаем битую символическую ссылку: $src${RESET}"
          fi
        elif [[ -f "$src" ]]; then
          # Если это обычный файл
          if [[ -s "$src" ]]; then  # Проверка на непустой файл
            echo "🔄 Копирование файла: $src"
            cp -p "$src" "$dst" || sudo cp -p "$src" "$dst"
          else
            echo -e "${YELLOW}⚠️ Пропускаем пустой файл: $src${RESET}"
          fi
        elif [[ -d "$src" ]]; then
          # Если это директория
          echo "🔄 Копирование директории: $src"
          cp -a "$src" "$dst" || {
            echo -e "${YELLOW}⚠️ Ошибка при копировании. Пробуем с sudo...${RESET}"
            sudo cp -a "$src" "$dst"
          }
        fi
      }
  
      # Копирование конфигурационных файлов и директорий
      if [[ "$EXISTING_CONFIGS" == *"ZSH"* ]]; then
        echo "🔄 Сохранение конфигурации ZSH..."
        mkdir -p "$DATED_BACKUP_DIR/zsh"
        
        if [[ -e "$HOME/.zshrc" ]]; then
          copy_with_deref "$HOME/.zshrc" "$DATED_BACKUP_DIR/zsh/"
        fi
        
        if [[ -d "$HOME/.oh-my-zsh" ]]; then
          if [[ -L "$HOME/.oh-my-zsh" ]]; then
            echo "🔄 Обнаружена символическая ссылка .oh-my-zsh, копируем настоящую директорию"
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
        echo "🔄 Сохранение конфигурации TMUX..."
        mkdir -p "$DATED_BACKUP_DIR/tmux"
        
        [[ -e "$HOME/.tmux.conf" ]] && copy_with_deref "$HOME/.tmux.conf" "$DATED_BACKUP_DIR/tmux/"
        [[ -e "$HOME/.tmux.conf.local" ]] && copy_with_deref "$HOME/.tmux.conf.local" "$DATED_BACKUP_DIR/tmux/"
      fi
  
      if [[ "$EXISTING_CONFIGS" == *"VIM"* ]]; then
        echo "🔄 Сохранение конфигурации VIM..."
        mkdir -p "$DATED_BACKUP_DIR/vim"
        
        [[ -e "$HOME/.vimrc" ]] && copy_with_deref "$HOME/.vimrc" "$DATED_BACKUP_DIR/vim/"
        
        if [[ -d "$HOME/.vim" || -L "$HOME/.vim" ]]; then
          if [[ -L "$HOME/.vim" ]]; then
            echo "🔄 Обнаружена символическая ссылка .vim, копируем настоящую директорию"
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

#----------------------------------------------------
# 🛠️ Подготовка окружения для установки
#----------------------------------------------------

# Очищаем содержимое директории .myshell (кроме директории backup)
echo -e "${BLUE}🧹 Очищаем содержимое директории $BASE_DIR (кроме бэкапов)...${RESET}"
if find "$BASE_DIR" -mindepth 1 ! -path "$BACKUP_DIR" ! -path "$BACKUP_DIR/*" -print0 | xargs -0 rm -rf 2>/dev/null; then
  echo "✅ Старый контент удален"
else
  echo -e "${YELLOW}⚠️ Не удалось удалить старый контент. Пробуем с sudo...${RESET}"
  sudo find "$BASE_DIR" -mindepth 1 ! -path "$BACKUP_DIR" ! -path "$BACKUP_DIR/*" -print0 | xargs -0 sudo rm -rf
fi

#----------------------------------------------------
# 📦 Установка и настройка Oh-My-Zsh
#----------------------------------------------------

# Функция для установки Oh-My-Zsh
install_ohmyzsh() {
  echo -e "${BLUE}📥 Подготовка к установке Oh-My-Zsh...${RESET}"
  
  # Удаляем предыдущую установку, если она существует
  if [[ -e "$HOME/.oh-my-zsh" ]]; then
    echo -e "${YELLOW}🧹 Удаляем предыдущую установку Oh-My-Zsh${RESET}"
    if [[ -L "$HOME/.oh-my-zsh" ]]; then
      echo "  - Обнаружена символическая ссылка: $HOME/.oh-my-zsh"
      # Более надежное удаление символической ссылки с проверкой результата
      /bin/ls -la "$HOME/.oh-my-zsh" # Выводим информацию о ссылке для диагностики
      
      echo "  - Пробуем удалить обычным способом..."
      rm "$HOME/.oh-my-zsh" || {
        echo "  - Не удалось, пробуем удалить через sudo..."
        sudo rm "$HOME/.oh-my-zsh" || {
          echo "  - И это не помогло, пробуем принудительное удаление через unlink..."
          unlink "$HOME/.oh-my-zsh" 2>/dev/null || sudo unlink "$HOME/.oh-my-zsh" 2>/dev/null || {
            echo -e "${RED}❌ Все методы удаления ссылки не удались. Попробуем последний способ...${RESET}"
            sudo find "$HOME" -maxdepth 1 -name ".oh-my-zsh" -delete
          }
        }
      }
    else
      echo "  - Удаляем директорию: $HOME/.oh-my-zsh"
      rm -rf "$HOME/.oh-my-zsh" 2>/dev/null || sudo rm -rf "$HOME/.oh-my-zsh"
    fi
  fi
  
  # Проверяем еще раз, что директория или ссылка удалена
  if [[ -e "$HOME/.oh-my-zsh" ]]; then
    echo -e "${RED}❌ Все попытки удалить .oh-my-zsh не удались! Выходим с ошибкой.${RESET}"
    echo -e "${YELLOW}⚠️ Рекомендация: удалите вручную симлинк или директорию: $HOME/.oh-my-zsh${RESET}"
    return 1
  fi
  
  # Устанавливаем Oh-My-Zsh вручную, клонируя репозиторий
  echo -e "${BLUE}📥 Клонируем репозиторий Oh-My-Zsh...${RESET}"
  git clone --depth=1 "$GIT_OMZ_REPO" "$HOME/.oh-my-zsh" || {
    echo -e "${RED}❌ Ошибка при клонировании репозитория Oh-My-Zsh${RESET}"
    return 1
  }
  
  echo -e "${GREEN}✅ Oh-My-Zsh успешно установлен${RESET}"
  return 0
}

# Функция для деинсталляции Oh-My-Zsh
uninstall_ohmyzsh() {
  echo -e "${YELLOW}♻️ Деинсталляция Oh-My-Zsh...${RESET}"
  export UNATTENDED=true
  
  if [[ -x "$HOME/.oh-my-zsh/tools/uninstall.sh" ]]; then
    "$HOME/.oh-my-zsh/tools/uninstall.sh" || echo "⚠️ Ошибка при деинсталляции, продолжаем..."
  else 
    chmod +x "$HOME/.oh-my-zsh/tools/uninstall.sh" 2>/dev/null || sudo chmod +x "$HOME/.oh-my-zsh/tools/uninstall.sh" 2>/dev/null 
    "$HOME/.oh-my-zsh/tools/uninstall.sh" || echo "⚠️ Ошибка при деинсталляции, продолжаем..."
  fi
}

# Основной блок управления Oh-My-Zsh
if [[ -d "$HOME/.oh-my-zsh" ]]; then
  echo -e "${BLUE}🔄 Проверка Oh-My-Zsh...${RESET}"
  
  # Пробуем обновить Oh-My-Zsh
  if [[ -x "$HOME/.oh-my-zsh/tools/upgrade.sh" ]]; then
    echo "🔄 Обновляем Oh-My-Zsh..."
    export RUNZSH=no
    export KEEP_ZSHRC=yes
    "$HOME/.oh-my-zsh/tools/upgrade.sh" --unattended && {
      echo -e "${GREEN}✅ Oh-My-Zsh успешно обновлен${RESET}"
    } || {
      echo -e "${YELLOW}⚠️ Не удалось обновить Oh-My-Zsh, выполняем переустановку...${RESET}"
      uninstall_ohmyzsh
      install_ohmyzsh || exit 1
    }
  else
    echo -e "${YELLOW}⚠️ Не найден скрипт обновления Oh-My-Zsh, выполняем переустановку...${RESET}"
    # Удаляем директорию напрямую, так как скрипт uninstall.sh может отсутствовать
    echo -e "${YELLOW}⚠️ Удаляем старую установку Oh-My-Zsh...${RESET}"
    rm -rf "$HOME/.oh-my-zsh" 2>/dev/null || sudo rm -rf "$HOME/.oh-my-zsh"
    install_ohmyzsh || exit 1
  fi
else
  # Установка Oh-My-Zsh, если он не установлен
  install_ohmyzsh || exit 1
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
    rm "$target" 2>/dev/null || sudo rm "$target"
  elif [[ -f "$target" ]]; then
    echo -e "📄 Удаляем файл: ${CYAN}$target${RESET}"
    rm "$target" 2>/dev/null || sudo rm "$target"
  elif [[ -d "$target" ]]; then
    echo -e "📁 Удаляем директорию: ${CYAN}$target${RESET}"
    rm -rf "$target" 2>/dev/null || sudo rm -rf "$target"
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

echo -e "${BLUE}📥 Клонируем tmux конфигурацию...${RESET}"
git clone "$GIT_TMUX_REPO" "$BASE_DIR/tmux" || {
  echo -e "${YELLOW}⚠️ Ошибка при клонировании tmux. Проверяем права доступа...${RESET}"
  sudo git clone "$GIT_TMUX_REPO" "$BASE_DIR/tmux"
}

echo -e "${BLUE}📥 Клонируем dotfiles...${RESET}"
git clone "$GIT_DOTFILES_REPO" "$BASE_DIR/dotfiles" || {
  echo -e "${YELLOW}⚠️ Ошибка при клонировании dotfiles. Проверяем права доступа...${RESET}"
  sudo git clone "$GIT_DOTFILES_REPO" "$BASE_DIR/dotfiles"
}

mkdir -p "$VIM_COLORS_DIR" "$VIM_PLUGINS_DIR" || {
  echo -e "${YELLOW}⚠️ Не удалось создать директории для vim. Пробуем с sudo...${RESET}"
  sudo mkdir -p "$VIM_COLORS_DIR" "$VIM_PLUGINS_DIR"
}

if [[ ! -d "$VIM_COLORS_DIR/papercolor-theme" ]]; then
  echo "${BLUE}📥 Клонируем PaperColor тему...${RESET}"
  git clone "https://github.com/NLKNguyen/papercolor-theme.git" "$VIM_COLORS_DIR/papercolor-theme" || {
    echo -e "${YELLOW}⚠️ Ошибка при клонировании темы. Проверяем права доступа...${RESET}"
    sudo git clone "https://github.com/NLKNguyen/papercolor-theme.git" "$VIM_COLORS_DIR/papercolor-theme"
  }
else
  echo "✅ PaperColor уже добавлен"
fi

ln -sf "$VIM_COLORS_DIR/papercolor-theme/colors/PaperColor.vim" "$VIM_COLORS_DIR/PaperColor.vim" || {
  echo -e "${YELLOW}⚠️ Не удалось создать символическую ссылку. Пробуем с sudo...${RESET}"
  sudo ln -sf "$VIM_COLORS_DIR/papercolor-theme/colors/PaperColor.vim" "$VIM_COLORS_DIR/PaperColor.vim"
}

echo "📦 Устанавливаем плагины для Zsh..."
mkdir -p "$BASE_DIR/ohmyzsh/custom/plugins" || {
  echo -e "${YELLOW}⚠️ Не удалось создать директорию для плагинов. Пробуем с sudo...${RESET}"
  sudo mkdir -p "$BASE_DIR/ohmyzsh/custom/plugins"
}

git clone https://github.com/zsh-users/zsh-autosuggestions "$BASE_DIR/ohmyzsh/custom/plugins/zsh-autosuggestions" || {
  echo -e "${YELLOW}⚠️ Ошибка при клонировании плагина. Проверяем права доступа...${RESET}"
  sudo git clone https://github.com/zsh-users/zsh-autosuggestions "$BASE_DIR/ohmyzsh/custom/plugins/zsh-autosuggestions"
}

git clone https://github.com/zsh-users/zsh-syntax-highlighting "$BASE_DIR/ohmyzsh/custom/plugins/zsh-syntax-highlighting" || {
  echo -e "${YELLOW}⚠️ Ошибка при клонировании плагина. Проверяем права доступа...${RESET}"
  sudo git clone https://github.com/zsh-users/zsh-syntax-highlighting "$BASE_DIR/ohmyzsh/custom/plugins/zsh-syntax-highlighting"
}

#----------------------------------------------------
# ⚙️ Настройки окружения
#----------------------------------------------------

echo "⚙️ Настраиваем zsh..."
ln -sf "$BASE_DIR/dotfiles/.zshrc" "$HOME/.zshrc" || {
  echo -e "${YELLOW}⚠️ Не удалось создать символическую ссылку. Пробуем с sudo...${RESET}"
  sudo ln -sf "$BASE_DIR/dotfiles/.zshrc" "$HOME/.zshrc"
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
}

# Удаляем директорию с проверкой прав
rm -rf "$HOME/.oh-my-zsh" 2>/dev/null || sudo rm -rf "$HOME/.oh-my-zsh"

# Создаем символическую ссылку с проверкой прав
ln -sfn "$BASE_DIR/ohmyzsh/" "$HOME/.oh-my-zsh" || {
  echo -e "${YELLOW}⚠️ Не удалось создать символическую ссылку. Пробуем с sudo...${RESET}"
  sudo ln -sfn "$BASE_DIR/ohmyzsh/" "$HOME/.oh-my-zsh"
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
# ✅ Завершение установки
#----------------------------------------------------

# Обновляем владельца всех файлов и директорий
echo -e "${BLUE}🛠️ Установка правильных прав доступа...${RESET}"
sudo chown -R "$USER":"$USER" "$BASE_DIR"
sudo chown -h "$USER":"$USER" "$HOME/.oh-my-zsh" "$HOME/.vim" "$HOME/.zshrc" "$HOME/.vimrc" "$HOME/.tmux.conf" "$HOME/.tmux.conf.local" 2>/dev/null

#----------------------------------------------------
# 🗑️ Очистка временной директории
#----------------------------------------------------
rm -rf "$HOME/init-shell" 2>/dev/null || sudo rm -rf "$HOME/init-shell"

#----------------------------------------------------
# ✅ Завершено
#----------------------------------------------------
echo -e "${GREEN}🎉 Установка завершена успешно!${RESET}"
