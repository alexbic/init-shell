# init-shell

Автоматический скрипт настройки пользовательского окружения на новом сервере (macOS и Linux).

> Начиная с этой версии скрипт устанавливает [Herdr](https://herdr.dev) вместо tmux. Если предпочитаете tmux — последняя версия зафиксирована в ветке [`tmux`](https://github.com/alexbic/init-shell/tree/tmux).

## Что делает скрипт

### Базовая настройка
- Устанавливает **Zsh** и **Oh-My-Zsh** с полезными плагинами
- Устанавливает **Herdr** — agent-aware терминальный мультиплексор (замена tmux)
- Устанавливает **zoxide** для умной навигации по директориям
- Устанавливает **jq** (нужен обёртке `claude()` из dotfiles для работы с Herdr API)
- Устанавливает **Homebrew** (пакетный менеджер) на macOS и Linux
- Создаёт директорию пользовательского окружения `~/.myshell`
- Создаёт бэкап старых конфигов в `~/.myshell/backup`
- Клонирует и настраивает dotfiles (`.zshrc`, `.vimrc`)
- **Меняет shell по умолчанию на zsh**

### VPS режим (`--auto`)
При запуске с флагом `--auto` дополнительно устанавливает:
- **Docker** и **Docker Compose V2**
- **ZeroTier** с автоматическим подключением к сети (если задана переменная `ZEROTIER_NETWORK_ID`)

## Структура проекта

После выполнения скрипта будет создана следующая структура:

```text
~/.myshell/
├── backup/          # Резервные копии существующих конфигов
├── dotfiles/        # Ваши dotfiles (.zshrc и т.д.)
├── ohmyzsh/         # Установленная версия Oh-My-Zsh
└── vim/             # Vim цвета и плагины
```

Herdr устанавливается официальным инсталлятором (`herdr.dev/install.sh`) как отдельный бинарник, вне `~/.myshell` — конфиг (опциональный) живёт в `~/.config/herdr/config.toml`.

## Использование

### Обычный режим (интерактивный)
```bash
cd ~
git clone https://github.com/alexbic/init-shell.git
chmod +x init-shell/setup.sh
./init-shell/setup.sh
```

### VPS режим (автоматический)
```bash
export ZEROTIER_NETWORK_ID="your-network-id"
./init-shell/setup.sh --auto
```

Переменная окружения `ZEROTIER_NETWORK_ID` может быть задана через cloud-config для автоматического подключения к сети ZeroTier.

## Что устанавливается

| Компонент | macOS | Linux (VPS) |
|-----------|-------|---------------|
| Homebrew | ✅ | ✅ |
| Zsh + Oh-My-Zsh | ✅ | ✅ |
| Herdr | ✅ | ✅ |
| zoxide | ✅ | ✅ |
| jq | ✅ | ✅ |
| Vim | ✅ | ✅ |
| zsh-autosuggestions | ✅ | ✅ |
| zsh-syntax-highlighting | ✅ | ✅ |
| Docker + Compose V2 | --auto | ✅ (--auto) |
| ZeroTier | --auto | ✅ (--auto) |

## Предупреждение

⚠️ Скрипт выполняет удаление и перемещение старых конфигурационных файлов. Сохраните важные настройки перед запуском.
