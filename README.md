# init-shell

Автоматический скрипт настройки пользовательского окружения на новом сервере (macOS и Linux). Для Windows/WSL есть отдельный `setup.ps1` — установка Nerd Font и настройка Windows Terminal.

> Начиная с этой версии скрипт устанавливает [Herdr](https://herdr.dev) вместо tmux. Если предпочитаете tmux — последняя версия зафиксирована в ветке [`tmux`](https://github.com/alexbic/init-shell/tree/tmux).

## Что делает скрипт

### Базовая настройка
- Устанавливает **Zsh** и **Oh-My-Zsh** с полезными плагинами
- На Linux генерирует и устанавливает русскую locale `ru_RU.UTF-8` по умолчанию
- Устанавливает **Herdr** — agent-aware терминальный мультиплексор (замена tmux)
- На Linux запускает **Herdr Headless Server** и включает его автозапуск
- Автоматически показывает текущий каталог удалённого workspace в `herdr-mirror`
- Устанавливает **zoxide** для умной навигации по директориям
- Устанавливает **eza** (современная замена `ls` с иконками)
- Устанавливает **gh** (GitHub CLI)
- Устанавливает **Nerd Font** (CaskaydiaCove) для иконок в `eza`/`ls` и prompt
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

Если `herdr.dev` недоступен из региона сервера, перед запуском задайте стандартную
переменную прокси, например `export HTTPS_PROXY=http://proxy-host:port` или
`export ALL_PROXY=socks5h://proxy-host:port`. Установщик делает три попытки и завершает
`setup.sh` с ошибкой, если бинарник `~/.local/bin/herdr` фактически не появился.

На Linux скрипт также устанавливает пользовательские службы `herdr-server.service` и
`herdr-workspace-cwd.service`. Для работы после выхода пользователя включается systemd linger.
Установка завершается с ошибкой, если бинарник не доступен по стабильному пути
`~/.local/bin/herdr` или обе службы не перешли в состояние `active`. Это исключает ложное
сообщение об успешной настройке при сбое загрузки или пользовательского systemd.
Если сервер стартует без workspace, служба автоматически создаёт первый workspace в домашнем каталоге.
Чтобы новый сервер появился на управляющем Mac, отдельно добавьте его SSH-алиас и секцию
`[hosts.<name>]` в конфигурацию `herdr-mirror`.

### Подключение нового сервера к herdr-mirror

Эту часть выполняет администратор на управляющем компьютере после запуска `setup.sh` на сервере.

1. Добавьте сервер в `~/.ssh/config`:

   ```sshconfig
   Host my-server
       HostName 192.168.88.150
       User wiz
       IdentityFile ~/.ssh/id_ed25519_my_server
   ```

2. Убедитесь, что вход по ключу работает без запроса пароля:

   ```bash
   ssh -o BatchMode=yes my-server true
   ```

3. Узнайте точный каталог конфигурации mirror и откройте `hosts.toml`:

   ```bash
   herdr plugin config-dir mirror
   ```

   Обычно это `~/.config/herdr/plugins/config/mirror/hosts.toml`. Добавьте сервер:

   ```toml
   [hosts.my_server]
   target = "my-server"
   prefix = "my-server"
   remote_bin = "~/.local/bin/herdr"
   always_control = true
   ```

   Имя секции `my_server` должно быть уникальным, `target` должен совпадать с SSH-алиасом,
   а `prefix` определяет имя сервера в левой панели Herdr.

4. Запустите mirror и проверьте состояние:

   ```bash
   herdr-mirror start
   herdr-mirror status
   ```

После подключения workspace появится как `my-server: ~/текущий/каталог`. Если daemon mirror
уже работал во время изменения `hosts.toml`, перезапустите Herdr или daemon mirror, чтобы он
перечитал конфигурацию.

Состояние удалённых служб можно проверить командой:

```bash
systemctl --user status herdr-server.service herdr-workspace-cwd.service
```

Логи синхронизации каталога доступны через:

```bash
journalctl --user -u herdr-workspace-cwd.service --since today
```

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

Linux locale можно переопределить перед запуском, например:

```bash
export LINUX_LOCALE=en_US.UTF-8
export LINUX_LANGUAGE=en_US:en
./init-shell/setup.sh
```

### Windows (WSL + Windows Terminal) — `setup.ps1`

В сценарии **WSL** иконки в `ls` (eza) рисует Windows Terminal шрифтом со стороны Windows. Nerd Font, установленный внутри Linux через `setup.sh`, на рендеринг Windows Terminal **не влияет** — шрифт нужно поставить в саму Windows. Для этого есть `setup.ps1` (запускать в **PowerShell 7**, права администратора **не нужны**):

```powershell
# из папки репозитория, напр. \\wsl.localhost\Ubuntu\home\<user>\init-shell
pwsh -File .\setup.ps1
```

Скрипт:
- скачивает **CaskaydiaCove Nerd Font** и ставит per-user (`%LOCALAPPDATA%\Microsoft\Windows\Fonts` + реестр `HKCU`);
- прописывает шрифт в **Windows Terminal** (`settings.json`, с бэкапом `.bak-nerdfont`);
- рассылает `WM_FONTCHANGE` — иконки подхватываются без перезапуска терминала.

Полезные параметры:

| Параметр | Назначение |
|----------|------------|
| `-ProfileName "Linux"` | прописать шрифт только в указанный профиль WT (иначе — в `profiles.defaults`) |
| `-SkipTerminalConfig` | только установить шрифт, не трогать настройки терминала |
| `-Force` | переустановить шрифт, даже если он уже стоит |
| `-FontFace "..."` | другое имя шрифта (по умолчанию `CaskaydiaCove Nerd Font Mono`) |

> Скрипт идемпотентен: при повторном запуске без `-Force` пропускает установку, если шрифт уже зарегистрирован.

## Что устанавливается

| Компонент | macOS | Linux (VPS) |
|-----------|-------|---------------|
| Homebrew | ✅ | ✅ |
| Zsh + Oh-My-Zsh | ✅ | ✅ |
| Herdr | ✅ | ✅ |
| zoxide | ✅ | ✅ |
| eza | ✅ | ✅ |
| gh (GitHub CLI) | ✅ | ✅ |
| Nerd Font (CaskaydiaCove) | ✅ | ✅ |
| jq | ✅ | ✅ |
| Vim | ✅ | ✅ |
| zsh-autosuggestions | ✅ | ✅ |
| zsh-syntax-highlighting | ✅ | ✅ |
| Docker + Compose V2 | --auto | ✅ (--auto) |
| ZeroTier | --auto | ✅ (--auto) |

> **Windows-часть** (Nerd Font в саму Windows + настройка Windows Terminal) ставится отдельным скриптом `setup.ps1` — см. раздел «Windows (WSL + Windows Terminal)» выше.

## Предупреждение

⚠️ Скрипт выполняет удаление и перемещение старых конфигурационных файлов. Сохраните важные настройки перед запуском.
