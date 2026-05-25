# Quickshell Dock для Hyprland (Arch Linux)

Плавающий dock-бар снизу экрана: воркспейсы, запуск приложений, системный трей, часы.

## Установка

### 1. Зависимости

```bash
# Quickshell (из AUR)
yay -S quickshell-git

# Шрифты
sudo pacman -S ttf-roboto
yay -S ttf-material-symbols-variable-git   # иконки Material Symbols
yay -S ttf-inter                            # шрифт Inter (для часов)
```

### 2. Скопируй конфиг

```bash
cp -r /run/media/ubonly/projects/quickshell-dock ~/.config/quickshell
```

### 3. Настрой Hyprland (hyprland.conf)

Добавь в `~/.config/hypr/hyprland.conf`:

```ini
# Blur и прозрачность для quickshell
layerrule = blur, quickshell
layerrule = ignorealpha 0.15, quickshell
layerrule = xray 0, quickshell

# Автозапуск
exec-once = quickshell
```

### 4. Запуск

```bash
# Ручной запуск для проверки
quickshell

# Или если конфиг в другом месте:
quickshell -p ~/.config/quickshell
```

## Структура файлов

```
~/.config/quickshell/
├── shell.qml            # Главный файл (PanelWindow)
├── WorkspaceButton.qml  # Индикаторы воркспейсов
├── AppButton.qml        # Кнопки запуска приложений
├── TrayIcon.qml         # Иконки системного трея
├── ClockWidget.qml      # Часы и дата
└── DockSeparator.qml    # Разделители
```

## Кастомизация

### Изменить приложения в доке

Открой `shell.qml` и отредактируй блок `AppButton`:

```qml
AppButton { appName: "Firefox";  appCmd: "firefox";  iconChar: "\ue051" }
AppButton { appName: "VSCode";   appCmd: "code";     iconChar: "\ue86f" }
// Добавь свои...
```

Коды Material Symbols: https://fonts.google.com/icons

### Количество воркспейсов

В `shell.qml` измени `model: 9` → нужное число.

### Внешний вид

| Параметр | Файл | Что меняет |
|---|---|---|
| `height: 58` | shell.qml | Высота бара |
| `radius: 18` | shell.qml | Скругление углов |
| `bottomMargin: 14` | shell.qml | Отступ от края экрана |
| `color: Qt.rgba(...)` | shell.qml | Цвет фона |
| `spacing: 2` | shell.qml | Расстояние между иконками |

## Горячие клавиши в доке

- **ЛКМ** на воркспейс → переключиться
- **ЛКМ** на приложение → запустить
- **ЛКМ/ПКМ** на иконку трея → activate / secondary activate
