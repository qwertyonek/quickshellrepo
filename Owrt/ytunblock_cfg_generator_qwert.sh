#!/bin/sh

# Обновляет /etc/config/youtubeUnblock на основе списков доменов из URL'ов.
# Улучшения: final_name вычисляется, удаляются пустые/комментированные строки,
# дубликаты, записывается временный файл и производится атомарная замена.

set -u

CFG="/etc/config/youtubeUnblock"
BACKUP="${CFG}.bak.$(date +%Y%m%d%H%M%S)"
TMP_CFG="/tmp/youtubeUnblock.$$"
TMP_LIST="/tmp/temp_list.$$"

# Если есть сервис — остановим
if [ -f /etc/init.d/youtubeUnblock ]; then
    echo "Stopping youtubeUnblock service..."
    /etc/init.d/youtubeUnblock stop || echo "Warning: failed to stop service"
fi

# Сделаем безопасную резервную копию текущего конфига (если существует)
if [ -f "$CFG" ]; then
    cp -p "$CFG" "$BACKUP" && echo "Backup saved to $BACKUP"
else
    echo "No existing config at $CFG — создаём новый"
fi

# Начальная часть конфига (без кавычек в EOF чтобы переменные могли разворачиваться, если нужно)
cat > "$TMP_CFG" << 'INIT_EOF'
config youtubeUnblock 'youtubeUnblock'
    option conf_strat 'ui_flags'
    option packet_mark '32768'
    option queue_num '537'
    option no_ipv6 '1'
INIT_EOF

# Список URL'ов (можешь добавлять/удалять строки)
URLS="
https://raw.githubusercontent.com/itdoginfo/allow-domains/refs/heads/main/Categories/anime.lst
https://raw.githubusercontent.com/itdoginfo/allow-domains/refs/heads/main/Categories/block.lst
https://raw.githubusercontent.com/itdoginfo/allow-domains/refs/heads/main/Categories/news.lst
https://raw.githubusercontent.com/itdoginfo/allow-domains/refs/heads/main/Categories/porn.lst
https://raw.githubusercontent.com/GhostRooter0953/discord-voice-ips/refs/heads/master/main_domains/discord-main-domains-list
https://raw.githubusercontent.com/itdoginfo/allow-domains/refs/heads/main/Services/hdrezka.lst
https://raw.githubusercontent.com/itdoginfo/allow-domains/refs/heads/main/Services/meta.lst
https://raw.githubusercontent.com/itdoginfo/allow-domains/refs/heads/main/Services/twitter.lst
https://raw.githubusercontent.com/itdoginfo/allow-domains/refs/heads/main/Services/youtube.lst
"

# Функция: безопасно скачать URL в файл
download_to_temp() {
    url="$1"
    out="$2"
    # стараемся curl, если нет — wget
    if command -v curl >/dev/null 2>&1; then
        curl -fsSL --max-time 30 "$url" -o "$out"
    elif command -v wget >/dev/null 2>&1; then
        wget -qO "$out" "$url"
    else
        return 2
    fi
}

# Обработка каждого URL
for url in $URLS; do
    # пустые строки в списке пропускаем
    [ -z "$url" ] && continue

    echo "Processing $url ..."

    # Получаем автора (обычно 4-е поле в пути raw.githubusercontent.com/<author>/...)
    author=$(echo "$url" | cut -d'/' -f4 2>/dev/null || true)
    # Получаем имя файла (последнее поле) и очищаем расширение/escape-последовательности
    filename=$(echo "$url" | awk -F/ '{print $NF}' | sed 's/\.lst$//;s/\.txt$//;s/%20/-/g;s/%//g' 2>/dev/null || true)

    # Формируем final_name: <filename>-<author>, но если чего-то не хватает — используем filename или host
    if [ -n "$filename" ] && [ -n "$author" ]; then
        final_name="${filename}-${author}"
    elif [ -n "$filename" ]; then
        final_name="${filename}"
    else
        # fallback: возьмём host
        host=$(echo "$url" | awk -F/ '{print $3}')
        final_name="list-from-${host}"
    fi

    # Очистим временный файл и скачиваем
    rm -f "$TMP_LIST"
    if ! download_to_temp "$url" "$TMP_LIST"; then
        echo "Error downloading $url — пропускаем"
        continue
    fi

    # Нормализация списка: убираем комментарии, пустые строки, trim, и уникализация
    # Также убираем возможные BOM/CRLF
    awk '{
        gsub(/\r/,"");
        if ($0 ~ /^[[:space:]]*#/ || $0 ~ /^[[:space:]]*$/) next;
        # trim
        sub(/^[[:space:]]+/,"");
        sub(/[[:space:]]+$/,"");
        print $0
    }' "$TMP_LIST" | sort -u > "${TMP_LIST}.clean"
    mv "${TMP_LIST}.clean" "$TMP_LIST"

    # Если после очистки нет доменов — пропустить
    if [ ! -s "$TMP_LIST" ]; then
        echo "No domains found in $url after cleaning — пропускаем"
        rm -f "$TMP_LIST"
        continue
    fi

    # Добавляем секцию в временный конфиг. Используем некавычеченный heredoc чтобы $final_name разворачивался
    cat >> "$TMP_CFG" << EOF

config section
    option name '$final_name'
    option tls_enabled '1'
    option fake_sni '1'
    option faking_strategy 'pastseq'
    option fake_sni_seq_len '1'
    option fake_sni_type 'default'
    option frag 'tcp'
    option frag_sni_reverse '1'
    option frag_sni_faked '0'
    option frag_middle_sni '1'
    option frag_sni_pos '1'
    option seg2delay '0'
    option fk_winsize '0'
    option synfake '0'
    option all_domains '0'
EOF

    # Специальные опции для известных final_name
    if [ "$final_name" = "youtube-itdoginfo" ]; then
        echo "    option quic_drop '1'" >> "$TMP_CFG"
    fi

    if [ "$final_name" = "discord-main-domains-list-GhostRooter0953" ] || [ "$final_name" = "discord-main-domains-list-GhostRooter0953" ]; then
        # диапазон UDP портов для дискорд-голоса (если нужно)
        echo "    list udp_dport_filter '50000-50100'" >> "$TMP_CFG"
    fi

    # Остальные опции
    cat >> "$TMP_CFG" << EOF
    option sni_detection 'parse'
    option udp_mode 'fake'
    option udp_faking_strategy 'none'
    option udp_fake_seq_len '6'
    option udp_fake_len '64'
    option udp_filter_quic 'disabled'
    option enabled '1'
EOF

    # Добавляем домены из списка
    while IFS= read -r domain; do
        # Пропустить если пустая строка (на всякий случай)
        [ -n "$domain" ] || continue
        # Если строка начинается с http:// или https:// — возможно файл содержит URL'ы — извлечём хост
        if echo "$domain" | grep -Eq '^[[:alpha:]]+://'; then
            # извлечём hostname
            hostonly=$(echo "$domain" | awk -F/ '{print $3}' | sed 's/:.*$//')
            [ -n "$hostonly" ] && echo "    list sni_domains '$hostonly'" >> "$TMP_CFG"
        else
            echo "    list sni_domains '$domain'" >> "$TMP_CFG"
        fi
    done < "$TMP_LIST"

    # Дополнительные ручные домены для некоторых списков
    case "$final_name" in
        "hdrezka-itdoginfo")
            echo "    list sni_domains 'hdrezka.es'" >> "$TMP_CFG"
            ;;
        "youtube-itdoginfo")
            echo "    list sni_domains 'play.google.com'" >> "$TMP_CFG"
            ;;
    esac

    # Удаляем временный список
    rm -f "$TMP_LIST"
done

# Добавляем статическую секцию для Telegram/WhatsApp звонков
cat >> "$TMP_CFG" << 'EOF'

config section
    option name 'CallsWhatsAppTelegram-routerich'
    option tls_enabled '0'
    option all_domains '0'
    list sni_domains 'cdn-telegram.org'
    list sni_domains 'comments.app'
    list sni_domains 'contest.com'
    list sni_domains 'fragment.com'
    list sni_domains 'graph.org'
    list sni_domains 'quiz.directory'
    list sni_domains 't.me'
    list sni_domains 'tdesktop.com'
    list sni_domains 'telega.one'
    list sni_domains 'telegra.ph'
    list sni_domains 'telegram-cdn.org'
    list sni_domains 'telegram.dog'
    list sni_domains 'telegram.me'
    list sni_domains 'telegram.org'
    list sni_domains 'telegram.space'
    list sni_domains 'telesco.pe'
    list sni_domains 'tg.dev'
    list sni_domains 'tx.me'
    list sni_domains 'usercontent.dev'
    list sni_domains 'graph.facebook.com'
    list sni_domains 'whatsapp.biz'
    list sni_domains 'whatsapp.com'
    list sni_domains 'whatsapp.net'
    option sni_detection 'parse'
    option quic_drop '0'
    option udp_mode 'fake'
    option udp_faking_strategy 'none'
    option udp_fake_seq_len '6'
    option udp_fake_len '64'
    option udp_filter_quic 'disabled'
    option enabled '1'
    option udp_stun_filter '1'
EOF

# Атомарно заменим конфиг (с сохранением прав)
if mv "$TMP_CFG" "$CFG"; then
    echo "Configuration saved to $CFG"
else
    echo "Error: failed to move $TMP_CFG to $CFG — попытаюсь скопировать"
    if cp -p "$TMP_CFG" "$CFG"; then
        echo "Configuration copied to $CFG"
        rm -f "$TMP_CFG"
    else
        echo "Fatal: невозможно записать $CFG"
        rm -f "$TMP_CFG"
        exit 1
    fi
fi

# Перезапустим сервис (если есть)
if [ -f /etc/init.d/youtubeUnblock ]; then
    echo "Restarting youtubeUnblock service..."
    /etc/init.d/youtubeUnblock restart || echo "Warning: failed to restart service"
fi

echo "Done."
