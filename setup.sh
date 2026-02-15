#!/bin/bash

#----------------------------------------------------
# ⚙️  Переменные
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

# ----------------------------------------------------
# ⚙️  Переменные для автоматизации VPS
# ----------------------------------------------------
# Если переменная окружения ZEROTIER_NETWORK_ID задана (через cloud-config),
# она используется. Иначе - плейсхолдер.
ZEROTIER_NETWORK_ID="${ZEROTIER_NETWORK_ID:-<ВСТАВЬТЕ_ID_СЕТИ_ЗДЕСЬ_ДЛЯ_ОБЫЧНОГО_РЕЖИМА>}"
SILENT_MODE=0

# ----------------------------------------------------
# 🔍 Проверка аргументов
# ----------------------------------------------------
if [[ "$1" == "--auto" ]]; then
    SILENT_MODE=1
    echo -e "${YELLOW}⚙️  Запуск в автоматическом (тихом) режиме...${RESET}"
fi

# 🗄️  Бэкап и архивирование
TIMESTAMP=$(date +"%Y-%m-%d_%H-%M-%S")
BACKUP_DIR="$BASE_DIR/backup"
DATED_BACKUP_DIR="$BACKUP_DIR/backup_$TIMESTAMP"

# 🧹 Шаблоны файлов для очистки
TRASH=".zsh* .tmux* .vim* .oh-my-zsh* .vimrc .tmux.conf"

# 📂 Директории для компонентов
VIM_DIR="$BASE_DIR/vim"
VIM_COLORS_DIR="$VIM_DIR/colors"
VIM_PLUGINS_DIR="$VIM_DIR/plugins"

# 🔗 Git-репозитории
GIT_DOTFILES_REPO="https://github.com/alexbic/dotfiles.git"
GIT_TMUX_REPO="https://github.com/gpakosz/.tmux.git"
GIT_OMZ_REPO="https://github.com/ohmyzsh/ohmyzsh.git"
GIT_OMZ_INSTALL_URL="https://raw.githubusercontent.com/ohmyzsh/ohmyzsh/master/tools/install.sh"
# ... (и другие репозитории) ...


# ----------------------------------------------------
# 🐳 Функция: Установка Docker и Docker Compose V2
# ----------------------------------------------------
install_docker() {
    echo -e "${CYAN}🛠️  Установка Docker и Docker Compose V2...${RESET}"

    if ! command -v docker &>/dev/null; then
        echo -e "${YELLOW}-> Добавление репозитория Docker...${RESET}"

        # Установка зависимостей с тихим подтверждением
        sudo apt-get update -y
        sudo apt-get install -y apt-transport-https ca-certificates curl gnupg lsb-release || true

        sudo install -m 0755 -d /etc/apt/keyrings
        curl -fsSL https://download.docker.com/linux/ubuntu/gpg | sudo gpg --dearmor -o /etc/apt/keyrings/docker.gpg
        sudo chmod a+r /etc/apt/keyrings/docker.gpg

        echo \
          "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/docker.gpg] https://download.docker.com/linux/ubuntu \
          $(. /etc/os-release && echo "$VERSION_CODENAME") stable" | \
          sudo tee /etc/apt/sources.list.d/docker.list > /dev/null

        sudo apt-get update -y
        # Установка Docker Engine, Containerd и Docker Compose Plugin (V2)
        echo -e "${YELLOW}-> Установка Docker...${RESET}"
        sudo apt-get install -y docker-ce docker-ce-cli containerd.io docker-buildx-plugin docker-compose-plugin

        # Добавление пользователя в группу 'docker'
        if ! getent group docker | grep -q "$USER"; then
            echo -e "${YELLOW}-> Добавление пользователя '$USER' в группу 'docker'...${RESET}"
            # $USER - это 'wiz', так как скрипт запускается через sudo -u wiz
            sudo usermod -aG docker "$USER"
        fi

        echo -e "${GREEN}🎉 Docker и Docker Compose установлены.${RESET}"
    else
        echo -e "${GREEN}🎉 Docker уже установлен. Пропускаем.${RESET}"
    fi
}

# ----------------------------------------------------
# 🟢 Функция: Установка ZeroTier и подключение к сети
# ----------------------------------------------------
install_zerotier() {
    echo -e "${CYAN}🛠️  Настройка ZeroTier...${RESET}"

    if ! command -v zerotier-cli &>/dev/null; then
        echo -e "${YELLOW}-> Установка ZeroTier с помощью официального скрипта...${RESET}"
        # Официальный метод установки ZeroTier (неинтерактивный)
        curl -sL 'https://install.zerotier.com/' | sudo bash
        echo -e "${GREEN}🎉 ZeroTier установлен.${RESET}"
    else
        echo -e "${GREEN}🎉 ZeroTier уже установлен. Пропускаем установку.${RESET}"
    fi

    # Автоматическое подключение к сети
    if [[ -n "$ZEROTIER_NETWORK_ID" ]] && [[ "$ZEROTIER_NETWORK_ID" != "<ВСТАВЬТЕ_ID_СЕТИ_ЗДЕСЬ_ДЛЯ_ОБЫЧНОГО_РЕЖИМА>" ]]; then
        echo -e "${YELLOW}-> Подключение к сети ZeroTier ID: $ZEROTIER_NETWORK_ID...${RESET}"
        # Требуется sudo, так как служба ZeroTier запускается от root
        sudo zerotier-cli join "$ZEROTIER_NETWORK_ID"
        echo -e "${GREEN}🎉 ZeroTier: Команда подключения выполнена. (Требуется авторизация в веб-панели).${RESET}"
    else
        echo -e "${YELLOW}-> ZeroTier Network ID не задан. Пропускаем подключение.${RESET}"
    fi
}

# ----------------------------------------------------
# 🛠️  Определяем ОС
# ----------------------------------------------------
OS_TYPE=$(uname -s | tr '[:upper:]' '[:lower:]')
DISTRO=""

if [[ "$OS_TYPE" == "linux" ]]; then
    if command -v lsb_release &>/dev/null; then
        DISTRO=$(lsb_release -is | tr '[:upper:]' '[:lower:]')
    elif [[ -f /etc/os-release ]]; then
        source /etc/os-release
        DISTRO=${ID_LIKE:-$ID}
        DISTRO=$(echo "$DISTRO" | cut -d' ' -f1 | tr '[:upper:]' '[:lower:]')
    fi
fi

# ----------------------------------------------------
# 🗑️  Очистка
# ----------------------------------------------------
echo -e "${YELLOW}🗑️  Архивирование существующих конфигурационных файлов...${RESET}"
mkdir -p "$DATED_BACKUP_DIR"
for file in $TRASH; do
    find "$HOME_DIR" -maxdepth 1 -name "$file" -exec mv {} "$DATED_BACKUP_DIR" \; 2>/dev/null
done
echo -e "${GREEN}🎉 Архивирование завершено.${RESET}"


# ----------------------------------------------------
# 🛠️  Создание базовых директорий
# ----------------------------------------------------
echo -e "${YELLOW}📂 Создание базовых директорий...${RESET}"
mkdir -p "$BASE_DIR"
mkdir -p "$VIM_DIR"
mkdir -p "$VIM_COLORS_DIR"
mkdir -p "$VIM_PLUGINS_DIR"
echo -e "${GREEN}🎉 Директории созданы.${RESET}"


# ----------------------------------------------------
# 🍎 Установка компонентов для macOS
# ----------------------------------------------------
if [[ "$OS_TYPE" == "darwin" ]]; then
    echo -e "${YELLOW}🍎 Инициализация macOS...${RESET}"

    # ------------------------------------------------
    # 📦 Проверка и установка Homebrew
    # ------------------------------------------------
    if ! command -v brew &>/dev/null; then
        echo -e "${CYAN}🛠️  Установка Homebrew...${RESET}"
        /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"
        # Добавление brew в PATH для Apple Silicon
        if [[ -d "/opt/homebrew/bin" ]]; then
            echo 'eval "$(/opt/homebrew/bin/brew shellenv)"' >> "$HOME_DIR/.zprofile"
            eval "$(/opt/homebrew/bin/brew shellenv)"
        fi
        echo -e "${GREEN}🎉 Homebrew установлен.${RESET}"
    else
        echo -e "${GREEN}🎉 Homebrew уже установлен. Пропускаем.${RESET}"
        # Обновление brew
        echo -e "${YELLOW}-> Обновление Homebrew...${RESET}"
        brew update --quiet 2>/dev/null || true
    fi

    # ------------------------------------------------
    # 🛠️  Установка базовых пакетов
    # ------------------------------------------------
    echo -e "${CYAN}🛠️  Установка базовых пакетов (git, zsh, vim, tmux)...${RESET}"
    brew install git zsh vim tmux curl 2>/dev/null || true

    # ------------------------------------------------
    # 🐳 Docker Desktop (опционально, через --auto)
    # ------------------------------------------------
    if [[ "$SILENT_MODE" -eq 1 ]]; then
        if ! command -v docker &>/dev/null; then
            echo -e "${CYAN}🛠️  Установка Docker Desktop...${RESET}"
            brew install --cask docker 2>/dev/null || true
            echo -e "${YELLOW}-> Запустите Docker Desktop из Applications для завершения установки.${RESET}"
        else
            echo -e "${GREEN}🎉 Docker уже установлен.${RESET}"
        fi

        # ZeroTier (опционально)
        if ! command -v zerotier-cli &>/dev/null; then
            echo -e "${CYAN}🛠️  Установка ZeroTier...${RESET}"
            brew install zerotier-one 2>/dev/null || true
            echo -e "${GREEN}🎉 ZeroTier установлен.${RESET}"
        fi

        # Подключение к сети ZeroTier
        if [[ -n "$ZEROTIER_NETWORK_ID" ]] && [[ "$ZEROTIER_NETWORK_ID" != "<ВСТАВЬТЕ_ID_СЕТИ_ЗДЕСЬ_ДЛЯ_ОБЫЧНОГО_РЕЖИМА>" ]]; then
            echo -e "${YELLOW}-> Подключение к сети ZeroTier ID: $ZEROTIER_NETWORK_ID...${RESET}"
            sudo zerotier-cli join "$ZEROTIER_NETWORK_ID" 2>/dev/null || true
            echo -e "${GREEN}🎉 ZeroTier: Команда подключения выполнена.${RESET}"
        fi
    fi

    # ------------------------------------------------
    # 🔗 Установка Oh My Zsh
    # ------------------------------------------------
    if [[ ! -d "$BASE_DIR/ohmyzsh" ]] && [[ ! -d "$HOME_DIR/.oh-my-zsh" ]]; then
        echo -e "${CYAN}🛠️  Установка Oh My Zsh...${RESET}"
        sh -c "$(curl -fsSL $GIT_OMZ_INSTALL_URL)" "" --unattended || true
        # Перемещаем в .myshell
        if [[ -d "$HOME_DIR/.oh-my-zsh" ]] && [[ ! -L "$HOME_DIR/.oh-my-zsh" ]]; then
            mv "$HOME_DIR/.oh-my-zsh" "$BASE_DIR/ohmyzsh"
            ln -sf "$BASE_DIR/ohmyzsh" "$HOME_DIR/.oh-my-zsh"
        fi
        rm -rf "$HOME_DIR/.oh-my-zsh/ohmyzsh" 2>/dev/null || true
        echo -e "${GREEN}🎉 Oh My Zsh установлен.${RESET}"
    elif [[ -d "$BASE_DIR/ohmyzsh" ]]; then
        echo -e "${GREEN}🎉 Oh My Zsh уже установлен в .myshell.${RESET}"
        ln -sf "$BASE_DIR/ohmyzsh" "$HOME_DIR/.oh-my-zsh"
    else
        echo -e "${GREEN}🎉 Oh My Zsh уже установлен. Пропускаем.${RESET}"
    fi

    # ------------------------------------------------
    # 🗄️  Настройка Dotfiles (используем локальные)
    # ------------------------------------------------
    echo -e "${CYAN}🛠️  Настройка Dotfiles...${RESET}"

    # Если dotfiles нет в .myshell, пробуем склонировать
    if [[ ! -d "$BASE_DIR/dotfiles" ]] && [[ -n "$GIT_DOTFILES_REPO" ]]; then
        echo -e "${YELLOW}-> Клонирование Dotfiles из репозитория...${RESET}"
        mkdir -p "$BASE_DIR/dotfiles"
        git clone "$GIT_DOTFILES_REPO" "$BASE_DIR/dotfiles" 2>/dev/null || true
    fi

    # Создание символических ссылок
    echo -e "${YELLOW}-> Создание символических ссылок...${RESET}"
    declare -a dotfiles=(".zshrc" ".vimrc")
    for file in "${dotfiles[@]}"; do
        link="$HOME_DIR/$file"
        source_file="$BASE_DIR/dotfiles/$file"

        if [[ -f "$source_file" ]]; then
            ln -sf "$source_file" "$link"
            echo -e "${BLUE}   Создана ссылка: $file${RESET}"
        fi
    done

    # Настройка TMUX
    echo -e "${YELLOW}-> Настройка tmux...${RESET}"
    if [[ ! -d "$BASE_DIR/tmux" ]]; then
        echo -e "${CYAN}-> Клонирование tmux конфигурации...${RESET}"
        git clone "$GIT_TMUX_REPO" "$BASE_DIR/tmux" 2>/dev/null || true
    fi

    if [[ -f "$BASE_DIR/tmux/.tmux.conf" ]]; then
        ln -sf "$BASE_DIR/tmux/.tmux.conf" "$HOME_DIR/.tmux.conf"
        echo -e "${BLUE}   Создана ссылка: .tmux.conf${RESET}"
    fi

    # .tmux.conf.local - сначала из dotfiles, если нет - копируем шаблон
    if [[ -f "$BASE_DIR/dotfiles/.tmux.conf.local" ]]; then
        ln -sf "$BASE_DIR/dotfiles/.tmux.conf.local" "$HOME_DIR/.tmux.conf.local"
        echo -e "${BLUE}   Создана ссылка: .tmux.conf.local${RESET}"
    elif [[ -f "$BASE_DIR/tmux/.tmux.conf.local" ]] && [[ ! -f "$HOME_DIR/.tmux.conf.local" ]]; then
        cp "$BASE_DIR/tmux/.tmux.conf.local" "$HOME_DIR/"
        echo -e "${BLUE}   Создан файл: .tmux.conf.local${RESET}"
    fi

    # Смена оболочки на zsh (если не уже)
    if [[ "$SHELL" != */zsh ]]; then
        echo -e "${YELLOW}-> Смена оболочки на zsh...${RESET}"
        chsh -s $(which zsh) 2>/dev/null || echo -e "${YELLOW}   (Смена оболочки требует пароль или пройдена ранее)${RESET}"
    fi

# ----------------------------------------------------
# 🐧 Установка компонентов для Linux (Ubuntu/Debian)
# ----------------------------------------------------
elif [[ "$OS_TYPE" == "linux" ]]; then
    echo -e "${YELLOW}🐧 Инициализация Linux ($DISTRO)...${RESET}"

    # Установка базовых пакетов (если их нет)
    if [[ "$DISTRO" == "ubuntu" ]] || [[ "$DISTRO" == "debian" ]]; then
        echo -e "${CYAN}🛠️  Установка базовых пакетов (git, zsh, vim)...${RESET}"
        sudo apt-get update -y
        sudo apt-get install -y git zsh vim curl || true
    fi

    # =========================================================
    # ⚙️  VPS Установка: Docker, Compose, ZeroTier (Только --auto)
    # =========================================================
    if [[ "$SILENT_MODE" -eq 1 ]]; then
        install_docker
        install_zerotier
    fi
    # =========================================================

    # ------------------------------------------------
    # 🔗 Установка Oh My Zsh
    # ------------------------------------------------
    if [[ ! -d "$HOME_DIR/.oh-my-zsh" ]]; then
        echo -e "${CYAN}🛠️  Установка Oh My Zsh...${RESET}"
        # Установка Zsh
        sh -c "$(curl -fsSL $GIT_OMZ_INSTALL_URL)" "" --unattended || true
        # Очистка пустой директории от клона
        rm -rf "$HOME_DIR/.oh-my-zsh/ohmyzsh" 2>/dev/null
        echo -e "${GREEN}🎉 Oh My Zsh установлен.${RESET}"
    else
        echo -e "${GREEN}🎉 Oh My Zsh уже установлен. Пропускаем.${RESET}"
    fi

    # ------------------------------------------------
    # 🗄️  Настройка Dotfiles
    # ------------------------------------------------
    echo -e "${CYAN}🛠️  Клонирование и настройка Dotfiles...${RESET}"
    git clone "$GIT_DOTFILES_REPO" "$BASE_DIR/dotfiles" 2>/dev/null || true

    # Создание символических ссылок
    echo -e "${YELLOW}-> Создание символических ссылок...${RESET}"
    declare -a dotfiles=(".zshrc" ".bashrc" ".tmux.conf" ".vimrc" ".tmux.conf.local")
    for file in "${dotfiles[@]}"; do
        link="$HOME_DIR/$file"
        source_file="$BASE_DIR/dotfiles/$file"

        if [[ -f "$source_file" ]]; then
            ln -sf "$source_file" "$link"
            echo -e "${BLUE}   Создана ссылка: $file${RESET}"
        fi
    done

    # Настройка TMUX
    echo -e "${YELLOW}-> Настройка .tmux.conf.local...${RESET}"
    git clone "$GIT_TMUX_REPO" "$HOME_DIR/.tmux" 2>/dev/null || true
    ln -s -f "$HOME_DIR/.tmux/.tmux.conf" "$HOME_DIR"

    # Установка tpm (tmux plugin manager)
    echo -e "${YELLOW}-> Установка tmux plugin manager (tpm)...${RESET}"
    if [[ ! -d "$HOME_DIR/.tmux/plugins/tpm" ]]; then
        git clone https://github.com/tmux-plugins/tpm "$HOME_DIR/.tmux/plugins/tpm" 2>/dev/null || true
        echo -e "${GREEN}🎉 tpm установлен.${RESET}"
    else
        echo -e "${GREEN}🎉 tpm уже установлен. Пропускаем.${RESET}"
    fi

    # Создание .tmux.conf.local
    if [[ -f "$BASE_DIR/dotfiles/.tmux.conf.local" ]]; then
        ln -sf "$BASE_DIR/dotfiles/.tmux.conf.local" "$HOME_DIR/.tmux.conf.local"
        echo -e "${BLUE}   Создана ссылка: .tmux.conf.local${RESET}"
    else
        cp "$HOME_DIR/.tmux/.tmux.conf.local" "$HOME_DIR" 2>/dev/null || true
    fi

    # Установка владельца для символических ссылок
    echo -e "${YELLOW}-> Установка владельца для ссылок...${RESET}"
    for link in $HOME_DIR/.*; do
      if [[ -L "$link" ]]; then
        sudo chown -h "$USER" "$link" 2>/dev/null
      fi
    done
fi

#----------------------------------------------------
# 🗑️  Очистка временной директории
#----------------------------------------------------
# Этот блок удален, так как репозиторий клонируется в $HOME/init-shell, и мы
# не хотим его удалять, чтобы сохранить его для wiz.


#----------------------------------------------------
# ✅ Завершено
#----------------------------------------------------
echo -e "\n${GREEN}🎉 Установка завершена успешно!${RESET}"

# Информация о системе
if [[ "$OS_TYPE" == "darwin" ]]; then
 echo -e "${BLUE}ℹ️   Информация о macOS:${RESET}"
 echo "  📱 Версия macOS: $(sw_vers -productVersion)"
 echo "  🔄 Архитектура: $(uname -m)"
 echo "  🧩 Компоненты были установлены с помощью Homebrew"
 if command -v wezterm &>/dev/null; then
   echo "  🖥️  WezTerm установлен и настроен"
 else
   echo "  🖥️  WezTerm не установлен"
 fi
elif [[ "$OS_TYPE" == "linux" ]]; then
 echo -e "${BLUE}ℹ️   Информация о Linux:${RESET}"
 echo "  🐧 Дистрибутив: $DISTRO"
 echo "  🔄 Архитектура: $(uname -m)"
 if [[ -f /etc/os-release ]]; then
   source /etc/os-release
   echo "  📱 Версия: $NAME $VERSION_ID"
 fi
fi

echo -e "${YELLOW}ℹ️   ВАЖНО:${RESET}"
echo "   - Для применения изменений перезапустите терминал или выполните: source ~/.zshrc"
echo "   - Если использовался тихий режим (--auto), убедитесь, что вы авторизовали ${CYAN}ZeroTier${RESET} в веб-панели управления."
#if [[ "$OS_TYPE" == "linux" ]]; then
#    echo "   - Для входа в систему используйте порт ${CYAN}2306${RESET}."
#fi

exit 0
