<#
.SYNOPSIS
    Windows-часть провижининга: установка Nerd Font и настройка Windows Terminal.

.DESCRIPTION
    setup.sh (bash) настраивает Linux/macOS. В сценарии WSL иконки в `ls` (eza)
    рисует Windows Terminal шрифтом со стороны Windows, поэтому Nerd Font нужно
    поставить именно в Windows. Этот скрипт делает это без прав администратора:
      1. Скачивает CaskaydiaCove Nerd Font (Nerd-версия Cascadia Code).
      2. Ставит .ttf в пользовательские шрифты (%LOCALAPPDATA%\Microsoft\Windows\Fonts)
         и регистрирует их в реестре HKCU (per-user, без админа).
      3. Прописывает шрифт в Windows Terminal (profiles.defaults или конкретный профиль).
      4. Рассылает WM_FONTCHANGE — шрифт подхватывается без перезапуска.

.PARAMETER FontFace
    Имя шрифта для Windows Terminal. По умолчанию Mono-вариант (иконки в одну ячейку).

.PARAMETER ProfileName
    Если задан — шрифт прописывается только в профиль WT с этим именем (например "Linux").
    По умолчанию — в profiles.defaults (действует на все профили).

.PARAMETER SkipTerminalConfig
    Только поставить шрифт, не трогать настройки Windows Terminal.

.PARAMETER Force
    Переустановить шрифт, даже если он уже зарегистрирован.

.EXAMPLE
    pwsh -File .\setup.ps1
    pwsh -File .\setup.ps1 -ProfileName "Linux"

.NOTES
    Рекомендуется PowerShell 7 (pwsh). Права администратора не требуются.
#>

[CmdletBinding()]
param(
    [string]$FontFace           = 'CaskaydiaCove Nerd Font Mono',
    [string]$FontZipUrl         = 'https://github.com/ryanoasis/nerd-fonts/releases/latest/download/CascadiaCode.zip',
    [string]$FontMatch          = 'CaskaydiaCove',
    [string]$ProfileName        = '',
    [switch]$SkipTerminalConfig,
    [switch]$Force
)

$ErrorActionPreference = 'Stop'

# ----------------------------------------------------
# 🎨 Хелперы вывода
# ----------------------------------------------------
function Write-Step { param($m) Write-Host "🛠️  $m" -ForegroundColor Cyan }
function Write-Ok   { param($m) Write-Host "✅ $m" -ForegroundColor Green }
function Write-Warn { param($m) Write-Host "⚠️  $m" -ForegroundColor Yellow }
function Write-Err  { param($m) Write-Host "❌ $m" -ForegroundColor Red }

# ----------------------------------------------------
# 🧩 WinAPI: загрузка шрифта в сессию + широковещание WM_FONTCHANGE
# ----------------------------------------------------
if (-not ('NativeFont' -as [type])) {
    Add-Type @"
using System;
using System.Runtime.InteropServices;
public class NativeFont {
    [DllImport("gdi32.dll", CharSet = CharSet.Unicode)] public static extern int AddFontResource(string lpFileName);
    [DllImport("user32.dll")] public static extern int SendMessage(IntPtr hWnd, int Msg, IntPtr wParam, IntPtr lParam);
}
"@
}
$HWND_BROADCAST = [IntPtr]0xffff
$WM_FONTCHANGE  = 0x001D

# ----------------------------------------------------
# 🔤 Установка Nerd Font (per-user)
# ----------------------------------------------------
function Install-NerdFont {
    $fontsDir = Join-Path $env:LOCALAPPDATA 'Microsoft\Windows\Fonts'
    $regKey   = 'HKCU:\Software\Microsoft\Windows NT\CurrentVersion\Fonts'
    New-Item -ItemType Directory -Force -Path $fontsDir | Out-Null

    # Идемпотентность: если шрифт уже стоит и нет -Force — пропускаем установку
    $already = Get-ChildItem -Path $fontsDir -Filter "*$FontMatch*.ttf" -ErrorAction SilentlyContinue
    if ($already -and -not $Force) {
        Write-Ok "Nerd Font уже установлен ($($already.Count) файлов). Пропускаю. (-Force для переустановки)"
        return
    }

    # Скачивание
    $tmp = Join-Path ([IO.Path]::GetTempPath()) ("nerdfont_" + [Guid]::NewGuid().ToString('N'))
    New-Item -ItemType Directory -Force -Path $tmp | Out-Null
    $zip = Join-Path $tmp 'font.zip'
    Write-Step "Загрузка Nerd Font: $FontZipUrl"
    try { [Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12 } catch {}
    Invoke-WebRequest -Uri $FontZipUrl -OutFile $zip -UseBasicParsing

    Write-Step 'Распаковка...'
    $ext = Join-Path $tmp 'extracted'
    Expand-Archive -Path $zip -DestinationPath $ext -Force
    $ttfs = Get-ChildItem -Path $ext -Recurse -Filter '*.ttf' | Where-Object { $_.Name -like "*$FontMatch*" }
    if (-not $ttfs) { $ttfs = Get-ChildItem -Path $ext -Recurse -Filter '*.ttf' }
    Write-Step "Найдено начертаний: $($ttfs.Count)"

    Add-Type -AssemblyName System.Drawing
    $installed = 0
    foreach ($ttf in $ttfs) {
        $dest = Join-Path $fontsDir $ttf.Name
        Copy-Item -Path $ttf.FullName -Destination $dest -Force

        # Имя для реестра: семейство + стиль из имени файла (уникально и читаемо)
        $title = $ttf.BaseName
        try {
            $pfc = New-Object System.Drawing.Text.PrivateFontCollection
            $pfc.AddFontFile($dest)
            $family = $pfc.Families[0].Name
            $pfc.Dispose()
            $style  = ($ttf.BaseName -split '-')[-1]
            if ($style -and $style -ne $ttf.BaseName) {
                $styleSpaced = ($style -creplace '(?<=.)([A-Z])', ' $1').Trim()
                $title = "$family $styleSpaced"
            } else { $title = $family }
        } catch {}

        Set-ItemProperty -Path $regKey -Name "$title (TrueType)" -Value $dest -Force
        [void][NativeFont]::AddFontResource($dest)   # доступен сразу в текущей сессии
        $installed++
    }

    # Уведомляем работающие приложения о новых шрифтах
    [void][NativeFont]::SendMessage($HWND_BROADCAST, $WM_FONTCHANGE, [IntPtr]::Zero, [IntPtr]::Zero)
    Remove-Item -Recurse -Force $tmp -ErrorAction SilentlyContinue
    Write-Ok "Установлено и зарегистрировано начертаний: $installed"
    Write-Ok "Папка: $fontsDir"
}

# ----------------------------------------------------
# ⚙️  Настройка шрифта в Windows Terminal
# ----------------------------------------------------
function Set-TerminalFont {
    $candidates = @(
        (Join-Path $env:LOCALAPPDATA 'Packages\Microsoft.WindowsTerminal_8wekyb3d8bbwe\LocalState\settings.json'),
        (Join-Path $env:LOCALAPPDATA 'Packages\Microsoft.WindowsTerminalPreview_8wekyb3d8bbwe\LocalState\settings.json'),
        (Join-Path $env:LOCALAPPDATA 'Microsoft\Windows Terminal\settings.json')
    ) | Where-Object { Test-Path $_ }

    if (-not $candidates) {
        Write-Warn 'settings.json Windows Terminal не найден. Пропускаю настройку терминала.'
        Write-Warn "Задайте шрифт вручную: Параметры → профиль → Внешний вид → Шрифт → $FontFace"
        return
    }

    foreach ($path in $candidates) {
        Write-Step "Настройка Windows Terminal: $path"
        Copy-Item $path "$path.bak-nerdfont" -Force
        try {
            $json = Get-Content -Raw -Path $path | ConvertFrom-Json
        } catch {
            Write-Warn "Не удалось разобрать JSON (возможно, есть комментарии). Пропускаю: $path"
            continue
        }

        # Утилита: гарантированно выставить .font.face на объекте-профиле
        $setFace = {
            param($obj)
            if ($null -eq $obj.font) {
                $obj | Add-Member -NotePropertyName font -NotePropertyValue ([PSCustomObject]@{ face = $FontFace }) -Force
            } elseif ($obj.font.PSObject.Properties.Name -contains 'face') {
                $obj.font.face = $FontFace
            } else {
                $obj.font | Add-Member -NotePropertyName face -NotePropertyValue $FontFace -Force
            }
        }

        if ($ProfileName) {
            $prof = $json.profiles.list | Where-Object { $_.name -eq $ProfileName }
            if (-not $prof) {
                Write-Warn "Профиль '$ProfileName' не найден — прописываю в profiles.defaults."
            } else {
                & $setFace $prof
                Write-Ok "Шрифт '$FontFace' задан профилю '$ProfileName'."
            }
        }

        if (-not $ProfileName -or -not ($json.profiles.list | Where-Object { $_.name -eq $ProfileName })) {
            if ($null -eq $json.profiles.defaults) {
                $json.profiles | Add-Member -NotePropertyName defaults -NotePropertyValue ([PSCustomObject]@{}) -Force
            }
            & $setFace $json.profiles.defaults
            Write-Ok "Шрифт '$FontFace' задан в profiles.defaults (для всех профилей)."
        }

        $json | ConvertTo-Json -Depth 32 | Set-Content -Path $path -Encoding UTF8
        Write-Ok "Сохранено (бэкап: $path.bak-nerdfont)"
    }
}

# ----------------------------------------------------
# 🚀 Основной ход
# ----------------------------------------------------
Write-Host ''
Write-Step 'Windows-часть провижининга (Nerd Font + Windows Terminal)'
Write-Host ''

Install-NerdFont

if (-not $SkipTerminalConfig) {
    Set-TerminalFont
} else {
    Write-Warn 'Настройка Windows Terminal пропущена (-SkipTerminalConfig).'
}

Write-Host ''
Write-Ok 'Готово!'
Write-Host "   Шрифт: $FontFace" -ForegroundColor Blue
Write-Host '   Если иконки не появились сразу — полностью закройте и откройте Windows Terminal.' -ForegroundColor Blue
Write-Host '   Проверка (в профиле WSL): ls' -ForegroundColor Blue
