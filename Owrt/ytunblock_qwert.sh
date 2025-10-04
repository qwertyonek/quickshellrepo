#!/bin/sh

# Проверка наличия необходимых утилит
for cmd in wget opkg uname; do
    if ! command -v $cmd &>/dev/null; then
        echo "Ошибка: Утилита $cmd не установлена."
        exit 1
    fi
done

# Определение архитектуры
ARCH=$(uname -m)
echo "Обнаружена архитектура: $ARCH"

# Выбор соответствующего пакета в зависимости от архитектуры
case "$ARCH" in
    aarch64)
        PKG="youtubeUnblock-1.0.0-10-f37c3dd-aarch64_generic-openwrt-23.05.ipk"
        ;;
    armv7)
        PKG="youtubeUnblock-1.0.0-10-f37c3dd-armv7-static.tar.gz"
        ;;
    armv7sf)
        PKG="youtubeUnblock-1.0.0-10-f37c3dd-armv7sf-static.tar.gz"
        ;;
    armv6l)
        PKG="youtubeUnblock-1.0.0-10-f37c3dd-arm_arm1176jzf-s_vfp-openwrt-23.05.ipk"
        ;;
    armv5te)
        PKG="youtubeUnblock-1.0.0-10-f37c3dd-arm_arm926ej-s-openwrt-23.05.ipk"
        ;;
    x86_64)
        PKG="youtubeUnblock-1.0.0-10-f37c3dd-x86_64-openwrt-23.05.ipk"
        ;;
    mips)
        PKG="youtubeUnblock-1.0.0-10-f37c3dd-mips-static.tar.gz"
        ;;
    mipsel)
        PKG="youtubeUnblock-1.0.0-10-f37c3dd-mipsel-static.tar.gz"
        ;;
    *)
        echo "Ошибка: архитектура '$ARCH' не поддерживается этим скриптом"
        exit 1
        ;;
esac

# Шаг 1. Обновление списка пакетов
echo "Обновляем список пакетов..."
opkg update
if [ $? -eq 0 ]; then
    echo "Список пакетов обновлен"
else
    echo "Ошибка обновления списка пакетов"
    exit 1
fi

# Шаг 2. Установка модулей для nftables
echo "Устанавливаем модули kmod-nft-queue и kmod-nfnetlink-queue..."
opkg install kmod-nft-queue kmod-nfnetlink-queue
if [ $? -eq 0 ]; then
    echo "Модули установлены"
else
    echo "Ошибка установки модулей"
    exit 1
fi

# Шаг 3. Проверка установленных пакетов
echo "Проверяем установку kmod-nft..."
opkg list-installed | grep kmod-nft
if [ $? -eq 0 ]; then
    echo "Пакеты kmod-nft обнаружены"
else
    echo "Пакеты kmod-nft не найдены"
    exit 1
fi

# Шаг 4. Скачивание и установка youtubeUnblock
echo "Скачиваем пакет youtubeUnblock..."
wget -O "/tmp/$PKG" "https://github.com/Waujito/youtubeUnblock/releases/download/v1.0.0/$PKG"
if [ $? -eq 0 ]; then
    echo "Пакет youtubeUnblock скачан"
else
    echo "Ошибка скачивания youtubeUnblock"
    exit 1
fi

# Проверка существования файла
if [ ! -f "/tmp/$PKG" ]; then
    echo "Ошибка: файл $PKG не был найден в /tmp"
    exit 1
fi

echo "Устанавливаем youtubeUnblock..."
opkg install "/tmp/$PKG"
if [ $? -eq 0 ]; then
    echo "youtubeUnblock установлен успешно"
else
    echo "Ошибка установки youtubeUnblock"
    exit 1
fi

# Шаг 5. Установка luci-app-youtubeUnblock
echo "Скачиваем пакет luci-app-youtubeUnblock..."
wget -O "/tmp/luci-app-youtubeUnblock-1.0.0-10-f37c3dd.ipk" "https://github.com/Waujito/youtubeUnblock/releases/download/v1.0.0/luci-app-youtubeUnblock-1.0.0-10-f37c3dd.ipk"
if [ $? -eq 0 ]; then
    echo "Пакет luci-app-youtubeUnblock скачан"
else
    echo "Ошибка скачивания luci-app-youtubeUnblock"
    exit 1
fi

echo "Устанавливаем luci-app-youtubeUnblock..."
opkg install "/tmp/luci-app-youtubeUnblock-1.0.0-10-f37c3dd.ipk"
if [ $? -eq 0 ]; then
    echo "luci-app-youtubeUnblock установлен успешно"
else
    echo "Ошибка установки luci-app-youtubeUnblock"
    exit 1
fi

# Шаг 6. Включение автозапуска youtubeUnblock
echo "Включаем автозапуск youtubeUnblock..."
/etc/init.d/youtubeUnblock enable
if [ $? -eq 0 ]; then
    echo "youtubeUnblock настроен на автозапуск"
else
    echo "Ошибка включения автозапуска youtubeUnblock"
    exit 1
fi

echo "=== Установка завершена успешно ==="
