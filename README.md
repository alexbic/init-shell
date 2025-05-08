# init-shell

Скрипт для автоматической настройки пользовательского окружения на новом сервере. 

## Что делает скрипт

- Устанавливает Zsh, Oh-My-Zsh и tmux
- Создаёт директорию пользовательского окружения `~/.myshell`
- Создаёт бэкап старых конфигов, таких как `.zshrc`, `.tmux.conf` и других в `~/.myshell/backup`
- Клонирует ваши настройки для `zshrc`, `tmux` (`.dotfiles`)
- Настраивает симлинки в домашнюю директорию (`$HOME`)
- Устанавливает полезные плагины для zsh, такие как `zsh-autosuggestions` и `zsh-syntax-highlighting`
- Удаляет временную директорию после завершения.
  
## Структура проекта

После выполнения скрипта будет создана следующая структура:

```text
~/.myshell/
├── backup/     # Старые конфиги (.zshrc, .tmux.conf и другие)
├── dotfiles/   # Ваши dotfiles (.zshrc, .tmux.conf.local и т.д.)
                https://github.com/alexbic/.dotfiles.git
├── tmux/       # Конфигурация tmux от gpakosz
                https://github.com/gpakosz/.tmux.git
└── ohmyzsh/    # Установленная версия Oh My Zsh и плагины
                https://raw.githubusercontent.com/ohmyzsh/ohmyzsh/master/tools/install.sh
                https://github.com/zsh-users/zsh-autosuggestions
                https://github.com/zsh-users/zsh-syntax-highlighting
```

Внимание!
• Скрипт выполняет удаление старых конфигов и временных файлов, поэтому будьте внимательны, если у вас есть важные
настройки в файлах, которые скрипт перемещает или удаляет.

## Как использовать

Просто выполните следующие команды в терминале:

```bash
cd ~
git clone https://github.com/alexbic/init-shell.git
chmod +x init-shell/setup.sh
./init-shell/setup.sh
```

