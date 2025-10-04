#!/bin/sh

# Проверка наличия необходимых утилит
for cmd in sed uci fw4; do
    if ! command -v $cmd &>/dev/null; then
        echo "Ошибка: Утилита $cmd не установлена."
        exit 1
    fi
done

# Резервное копирование исходного файла
cp /usr/share/firewall4/templates/ruleset.uc /usr/share/firewall4/templates/ruleset.uc.bak

# Модификация правил фаервола
sed -i 's/meta l4proto { tcp, udp } flow offload @ft;/meta l4proto { tcp, udp } ct original packets ge 30 flow offload @ft;/g' /usr/share/firewall4/templates/ruleset.uc
if [ $? -ne 0 ]; then
    echo "Ошибка: Не удалось изменить правила фаервола."
    exit 1
fi

# Перезапуск фаервола
fw4 restart
if [ $? -ne 0 ]; then
    echo "Ошибка: Не удалось перезапустить фаервол."
    exit 1
fi

# Добавление правил для блокировки UDP-портов 80 и 443
for port in 80 443; do
    uci add firewall rule
    uci set firewall.@rule[-1].name="Block_UDP_$port"
    uci set firewall.@rule[-1].src="*"
    uci set firewall.@rule[-1].dest_port="$port"
    uci set firewall.@rule[-1].proto="udp"
    uci set firewall.@rule[-1].target="REJECT"
    if [ $? -ne 0 ]; then
        echo "Ошибка: Не удалось добавить правило для порта $port."
        exit 1
    fi
done

# Применение изменений
uci commit firewall
if [ $? -ne 0 ]; then
    echo "Ошибка: Не удалось применить изменения фаервола."
    exit 1
fi

# Перезапуск фаервола
/etc/init.d/firewall restart
if [ $? -ne 0 ]; then
    echo "Ошибка: Не удалось перезапустить фаервол."
    exit 1
fi

echo "Настройки DPI успешно обновлены."
