#!/bin/sh

# Цвета для красоты
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
NC='\033[0m'

echo -e "${YELLOW}Welcome to QuickShell OpenWRT Installer!${NC}"
echo "Select installation mode:"
echo "1) Automatic (install all components)"
echo "2) Manual (choose components)"
read -p "Enter 1 or 2: " mode

run_script() {
    NAME=$1
    URL=$2
    echo -e "${YELLOW}Installing $NAME...${NC}"
    sh <(wget -O - "$URL")
    if [ $? -eq 0 ]; then
        echo -e "${GREEN}$NAME installed successfully!${NC}"
    else
        echo -e "${RED}Error installing $NAME!${NC}"
    fi
}

if [ "$mode" = "1" ]; then
    echo -e "${YELLOW}Running automatic installation...${NC}"
    run_script "BBR" "https://raw.githubusercontent.com/qwertyonek/quickshellrepo/main/Owrt/bbr_qwert.sh"
    run_script "DPI Fix" "https://raw.githubusercontent.com/qwertyonek/quickshellrepo/main/Owrt/dpi_fix_qwert.sh"
    run_script "Podkop" "https://raw.githubusercontent.com/itdoginfo/podkop/refs/heads/main/install.sh"
    run_script "YouTubeUnblock" "https://raw.githubusercontent.com/qwertyonek/quickshellrepo/main/Owrt/ytunblock_qwert.sh"
    run_script "YouTubeUnblock Config Generator" "https://raw.githubusercontent.com/qwertyonek/quickshellrepo/main/Owrt/ytunblock_cfg_generator_qwert.sh"
    echo -e "${GREEN}Automatic installation complete!${NC}"
else
    echo -e "${YELLOW}Running manual installation...${NC}"

    read -p "Install BBR? (y/n): " install_bbr
    [ "$install_bbr" = "y" ] && run_script "BBR" "https://raw.githubusercontent.com/qwertyonek/quickshellrepo/main/Owrt/bbr_qwert.sh"

    read -p "Install DPI Fix? (y/n): " install_dpi
    [ "$install_dpi" = "y" ] && run_script "DPI Fix" "https://raw.githubusercontent.com/qwertyonek/quickshellrepo/main/Owrt/dpi_fix_qwert.sh"

    read -p "Install Podkop? (y/n): " install_podkop
    [ "$install_podkop" = "y" ] && run_script "Podkop" "https://raw.githubusercontent.com/itdoginfo/podkop/refs/heads/main/install.sh"

    read -p "Install YouTubeUnblock? (y/n): " install_yt
    [ "$install_yt" = "y" ] && run_script "YouTubeUnblock" "https://raw.githubusercontent.com/qwertyonek/quickshellrepo/main/Owrt/ytunblock_qwert.sh"

    read -p "Install YouTubeUnblock Config Generator? (y/n): " install_yt_cfg
    [ "$install_yt_cfg" = "y" ] && run_script "YouTubeUnblock Config Generator" "https://raw.githubusercontent.com/qwertyonek/quickshellrepo/main/Owrt/ytunblock_cfg_generator_qwert.sh"

    echo -e "${GREEN}Manual installation complete!${NC}"
fi

echo -e "${YELLOW}Reminder: Configure components manually if needed.${NC}"
echo "- For Podkop: Ensure YouTube uses YouTubeUnblock, disable 'Russia Inside', use your VDS with key."
echo "- For YouTubeUnblock: Verify ad-free YouTube access."
echo "- Reboot router to apply all changes: reboot"
