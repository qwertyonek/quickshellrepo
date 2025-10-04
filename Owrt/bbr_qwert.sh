#!/bin/sh

# Проверка наличия пакета kmod-tcp-bbr
if opkg list-installed | grep -q kmod-tcp-bbr; then
    echo "BBR module is already installed."
else
    echo "Installing BBR module..."
    opkg update && opkg install kmod-tcp-bbr
    if [ $? -ne 0 ]; then
        echo "Error installing kmod-tcp-bbr."
        exit 1
    fi
fi

# Проверка и загрузка модуля BBR
if lsmod | grep -q tcp_bbr; then
    echo "BBR module is already loaded."
else
    echo "Loading BBR module..."
    modprobe tcp_bbr
    if [ $? -ne 0 ]; then
        echo "Error loading tcp_bbr module."
        exit 1
    fi
fi

# Установка BBR как алгоритма по умолчанию
echo "Setting BBR as default congestion control algorithm..."
sed -i '/tcp_congestion_control/d' /etc/sysctl.conf
echo 'net.ipv4.tcp_congestion_control=bbr' >> /etc/sysctl.conf
sysctl -w net.ipv4.tcp_congestion_control=bbr
if [ $? -ne 0 ]; then
    echo "Error setting BBR as default."
    exit 1
fi

# Проверка текущего алгоритма
echo "Current TCP congestion control algorithm:"
sysctl net.ipv4.tcp_congestion_control

# Проверка загрузки модуля BBR
echo "Checking if BBR module is loaded:"
lsmod | grep tcp_bbr

echo "Setup complete! It is recommended to reboot your router for changes to take effect."
