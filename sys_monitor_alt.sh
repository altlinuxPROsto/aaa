#!/bin/bash

# ============================================
# Скрипт мониторинга системы ALT Linux
# Отслеживает: загрузку CPU, диски, обновления
# ============================================

# --- Конфигурация ---
LOG_DIR="/var/log/monitoring"
LOG_FILE="${LOG_DIR}/sys_health_$(date +%Y%m%d).log"
CPU_CORES=$(nproc)                     # Количество ядер процессора
THRESHOLD_DISK=80                      # Порог заполнения диска в %
TIMESTAMP=$(date "+%Y-%m-%d %H:%M:%S")

# Создаём директорию для логов, если её нет
if [ ! -d "$LOG_DIR" ]; then
    sudo mkdir -p "$LOG_DIR"
fi

# Функция для записи в лог (дублирует вывод в консоль и файл)
log() {
    echo "$1" | tee -a "$LOG_FILE"
}

# --- Начало отчёта ---
log "============================================="
log "Отчёт о состоянии системы ALT Linux от ${TIMESTAMP}"
log "============================================="

# --- 1. МОНИТОРИНГ ЗАГРУЗКИ CPU ---
log ""
log "=== 1. ЗАГРУЗКА ПРОЦЕССОРА (LOAD AVERAGE) ==="

LOAD_INFO=$(uptime | awk -F 'load average:' '{print $2}')
LOAD_1=$(echo "$LOAD_INFO" | awk -F ',' '{print $1}' | sed 's/ //g')
LOAD_5=$(echo "$LOAD_INFO" | awk -F ',' '{print $2}' | sed 's/ //g')
LOAD_15=$(echo "$LOAD_INFO" | awk -F ',' '{print $3}' | sed 's/ //g')

log "Количество ядер CPU: $CPU_CORES"
log "Средняя нагрузка: $LOAD_INFO"

# Проверка: превышает ли нагрузка количество ядер?
if (( $(echo "$LOAD_1 > $CPU_CORES" | bc -l) )); then
    log "⚠️  ВНИМАНИЕ: 1-минутная нагрузка ($LOAD_1) превышает кол-во ядер ($CPU_CORES)!"
elif (( $(echo "$LOAD_5 > $CPU_CORES" | bc -l) )); then
    log "⚠️  Предупреждение: 5-минутная нагрузка ($LOAD_5) превышает кол-во ядер ($CPU_CORES)."
else
    log "✅ Нагрузка в норме."
fi

# --- 2. МОНИТОРИНГ ДИСКОВ ---
log ""
log "=== 2. ДИСКОВОЕ ПРОСТРАНСТВО ==="

# Выводим df -h, отфильтровывая tmpfs и squashfs (псевдо-файловые системы)
df -h | grep -E '^/dev/' | while read line; do
    USAGE=$(echo $line | awk '{print $5}' | sed 's/%//')
    MOUNT=$(echo $line | awk '{print $6}')
    if [ $USAGE -ge $THRESHOLD_DISK ]; then
        log "⚠️  КРИТИЧНО: $MOUNT заполнен на $USAGE% (превышен порог $THRESHOLD_DISK%)"
    else
        log "✅ Раздел $MOUNT: $USAGE% использовано"
    fi
done

# Дополнительно: топ-5 самых больших каталогов в /var (источник проблем)
log "Топ-5 каталогов в /var по размеру:"
sudo du -sh /var/* 2>/dev/null | sort -rh | head -5 | while read line; do
    log "  $line"
done

# --- 3. МОНИТОРИНГ ОБНОВЛЕНИЙ ALT LINUX ---
log ""
log "=== 3. СТАТУС ОБНОВЛЕНИЙ СИСТЕМЫ ALT LINUX ==="

# Проверяем версию ядра
log "Текущая версия ядра: $(uname -r)"

# Проверяем, есть ли доступные обновления (без применения)
log "Проверка наличия ожидающих обновлений..."
sudo apt-get update > /dev/null 2>&1

# В ALT Linux для подсчёта обновлений используем apt-get -s dist-upgrade
UPDATES=$(sudo apt-get -s dist-upgrade 2>/dev/null | grep -c '^Inst')

if [ "$UPDATES" -gt 0 ]; then
    log "⚠️  Доступно $UPDATES обновлений(е). Рекомендуется выполнить apt-get dist-upgrade."
    log "Список основных обновлений:"
    sudo apt-get -s dist-upgrade 2>/dev/null | grep '^Inst' | head -5 | while read line; do
        log "  - $line"
    done
else
    log "✅ Система обновлена. Критических обновлений не найдено."
fi

# Проверка необходимости обновления ядра (информационная)
log "Для обновления ядра используется команда: sudo update-kernel"

# --- 4. ИТОГИ ---
log ""
log "============================================="
log "Отчёт сохранён: $LOG_FILE"
log "============================================="

exit 0
