#!/usr/bin/env bash
# ==============================================================================
# Production Linux System Health Monitoring Script
# ==============================================================================
set -euo pipefail

# Default configuration values
DEFAULT_DISK_THRESHOLD=80
DEFAULT_CPU_THRESHOLD=90
DEFAULT_MEM_THRESHOLD=85
DEFAULT_LOG_FILE="health_log.txt"
DEFAULT_MAX_LOG_SIZE_KB=1024 # 1 MB maximum before rotation

DISK_THRESHOLD="$DEFAULT_DISK_THRESHOLD"
CPU_THRESHOLD="$DEFAULT_CPU_THRESHOLD"
MEM_THRESHOLD="$DEFAULT_MEM_THRESHOLD"
LOG_FILE="$DEFAULT_LOG_FILE"
MAX_LOG_SIZE_KB="$DEFAULT_MAX_LOG_SIZE_KB"
OUTPUT_JSON=false

# Exit codes
EXIT_OK=0
EXIT_WARNING=1
EXIT_CRITICAL=2

show_help() {
    cat <<EOF
Usage: $(basename "$0") [OPTIONS]

Production server health audit script. Gathers CPU, memory, disk, load average,
and top memory processes. Evaluates thresholds, rotates logs, and returns status codes.

Options:
  --disk NUM         Disk usage warning threshold percent (default: ${DEFAULT_DISK_THRESHOLD}%)
  --cpu NUM          CPU usage warning threshold percent (default: ${DEFAULT_CPU_THRESHOLD}%)
  --mem NUM          Memory usage warning threshold percent (default: ${DEFAULT_MEM_THRESHOLD}%)
  --log FILE         Path to destination health log file (default: ${DEFAULT_LOG_FILE})
  --max-size-kb NUM  Maximum log size in KB before rotating (default: ${DEFAULT_MAX_LOG_SIZE_KB} KB)
  --json             Format log output and stdout as structured JSON
  -h, --help         Display this help message and exit

Exit Codes:
  0 - Healthy: All system metrics are within normal parameters
  1 - Warning: One or more metrics exceeded configured warning thresholds
  2 - Critical: Severe threshold breach (Disk/Memory >= 95% or CPU >= 98%)

Environment Variables:
  ALERT_WEBHOOK_URL  Optional Slack/Discord incoming webhook URL for alert notifications
EOF
}

# Parse command line arguments
while [[ $# -gt 0 ]]; do
    case "$1" in
        --disk)
            DISK_THRESHOLD="$2"
            shift 2
            ;;
        --cpu)
            CPU_THRESHOLD="$2"
            shift 2
            ;;
        --mem)
            MEM_THRESHOLD="$2"
            shift 2
            ;;
        --log)
            LOG_FILE="$2"
            shift 2
            ;;
        --max-size-kb)
            MAX_LOG_SIZE_KB="$2"
            shift 2
            ;;
        --json)
            OUTPUT_JSON=true
            shift
            ;;
        -h|--help)
            show_help
            exit "$EXIT_OK"
            ;;
        *)
            echo "Unknown argument: $1" >&2
            echo "Run '$(basename "$0") --help' for usage." >&2
            exit "$EXIT_CRITICAL"
            ;;
    esac
done

# Perform basic log rotation
rotate_logs() {
    local target_file="$1"
    local max_kb="$2"

    if [[ -f "$target_file" ]]; then
        local size_kb
        size_kb=$(du -k "$target_file" | cut -f1)
        if [[ "$size_kb" -ge "$max_kb" ]]; then
            local timestamp
            timestamp=$(date +"%Y%m%d_%H%M%S")
            mv "$target_file" "${target_file}.${timestamp}.bak"
            # Keep only the 3 most recent backups
            find "$(dirname "$target_file")" -name "$(basename "$target_file").*.bak" | sort -r | tail -n +4 | xargs -r rm -f
        fi
    fi
}

# Collect System Metrics
TIMESTAMP=$(date -u +"%Y-%m-%dT%H:%M:%SZ")

# 1. CPU Usage Calculation (across 1-second sample)
CPU_IDLE=$(top -bn2 -d 0.5 | grep -i "^%Cpu" | tail -n 1 | awk '{print $8}' | tr -d 'id,')
CPU_USAGE=$(awk -v idle="$CPU_IDLE" 'BEGIN { printf "%.1f", 100 - idle }')
# Fallback in case top output parsing produces empty string
if [[ -z "$CPU_USAGE" ]]; then
    CPU_USAGE="0.0"
fi

# 2. Memory Usage Calculation
MEM_TOTAL=$(free -m | awk '/^Mem:/{print $2}')
MEM_AVAILABLE=$(free -m | awk '/^Mem:/{print $7}')
MEM_USED=$(( MEM_TOTAL - MEM_AVAILABLE ))
MEM_USAGE=$(awk -v used="$MEM_USED" -v total="$MEM_TOTAL" 'BEGIN { printf "%.1f", (used / total) * 100 }')

# 3. Disk Usage (Highest mounted filesystem usage)
MAX_DISK_LINE=$(df -hP -x tmpfs -x devtmpfs -x squashfs | tail -n +2 | sort -k5 -rn | head -n 1)
DISK_USAGE=$(echo "$MAX_DISK_LINE" | awk '{print $5}' | tr -d '%')
DISK_MOUNT=$(echo "$MAX_DISK_LINE" | awk '{print $6}')

# 4. Load Average (1m, 5m, 15m)
read -r LOAD_1 LOAD_5 LOAD_15 _ < /proc/loadavg

# 5. Top 5 Processes by Memory Usage
TOP_PROCESSES=$(ps -eo pid,user,%cpu,%mem,comm --sort=-%mem | head -n 6)

# Status determination & Threshold evaluation
STATUS="OK"
EXIT_CODE=$EXIT_OK
declare -a WARNINGS=()

# Evaluate CPU
if (( $(awk "BEGIN {print ($CPU_USAGE >= 98 ? 1 : 0)}") )); then
    STATUS="CRITICAL"
    EXIT_CODE=$EXIT_CRITICAL
    WARNINGS+=("CRITICAL: CPU usage is ${CPU_USAGE}% (exceeds critical 98%)")
elif (( $(awk "BEGIN {print ($CPU_USAGE >= $CPU_THRESHOLD ? 1 : 0)}") )); then
    [[ "$STATUS" != "CRITICAL" ]] && STATUS="WARNING"
    [[ "$EXIT_CODE" -eq $EXIT_OK ]] && EXIT_CODE=$EXIT_WARNING
    WARNINGS+=("WARNING: CPU usage is ${CPU_USAGE}% (exceeds threshold ${CPU_THRESHOLD}%)")
fi

# Evaluate Memory
if (( $(awk "BEGIN {print ($MEM_USAGE >= 95 ? 1 : 0)}") )); then
    STATUS="CRITICAL"
    EXIT_CODE=$EXIT_CRITICAL
    WARNINGS+=("CRITICAL: Memory usage is ${MEM_USAGE}% (exceeds critical 95%)")
elif (( $(awk "BEGIN {print ($MEM_USAGE >= $MEM_THRESHOLD ? 1 : 0)}") )); then
    [[ "$STATUS" != "CRITICAL" ]] && STATUS="WARNING"
    [[ "$EXIT_CODE" -eq $EXIT_OK ]] && EXIT_CODE=$EXIT_WARNING
    WARNINGS+=("WARNING: Memory usage is ${MEM_USAGE}% (exceeds threshold ${MEM_THRESHOLD}%)")
fi

# Evaluate Disk
if [[ "$DISK_USAGE" -ge 95 ]]; then
    STATUS="CRITICAL"
    EXIT_CODE=$EXIT_CRITICAL
    WARNINGS+=("CRITICAL: Disk '${DISK_MOUNT}' usage is ${DISK_USAGE}% (exceeds critical 95%)")
elif [[ "$DISK_USAGE" -ge "$DISK_THRESHOLD" ]]; then
    [[ "$STATUS" != "CRITICAL" ]] && STATUS="WARNING"
    [[ "$EXIT_CODE" -eq $EXIT_OK ]] && EXIT_CODE=$EXIT_WARNING
    WARNINGS+=("WARNING: Disk '${DISK_MOUNT}' usage is ${DISK_USAGE}% (exceeds threshold ${DISK_THRESHOLD}%)")
fi

# Rotate log file if needed
rotate_logs "$LOG_FILE" "$MAX_LOG_SIZE_KB"

# Emit output (Text or JSON)
if [[ "$OUTPUT_JSON" == true ]]; then
    TOP_PROCS_JSON=$(ps -eo pid,user,%cpu,%mem,comm --sort=-%mem | tail -n +2 | head -n 5 | awk '{printf "{\"pid\":%s,\"user\":\"%s\",\"cpu\":\"%s\",\"mem\":\"%s\",\"command\":\"%s\"},", $1, $2, $3, $4, $5}' | sed 's/,$//')
    
    WARNINGS_JSON="[]"
    if [[ ${#WARNINGS[@]} -gt 0 ]]; then
        WARNINGS_FORMATTED=$(printf '"%s",' "${WARNINGS[@]}" | sed 's/,$//')
        WARNINGS_JSON="[${WARNINGS_FORMATTED}]"
    fi

    LOG_ENTRY=$(cat <<EOF
{"timestamp":"${TIMESTAMP}","status":"${STATUS}","exit_code":${EXIT_CODE},"metrics":{"cpu_percent":${CPU_USAGE},"memory_percent":${MEM_USAGE},"disk_percent":${DISK_USAGE},"disk_mount":"${DISK_MOUNT}","load_average":{"1m":${LOAD_1},"5m":${LOAD_5},"15m":${LOAD_15}}},"warnings":${WARNINGS_JSON},"top_memory_processes":[${TOP_PROCS_JSON}]}
EOF
)
    echo "$LOG_ENTRY" >> "$LOG_FILE"
    echo "$LOG_ENTRY"
else
    # Standard human-readable text output
    {
        echo "=== System Health Check: ${TIMESTAMP} [STATUS: ${STATUS}] ==="
        echo "CPU Utilization:   ${CPU_USAGE}% (Threshold: ${CPU_THRESHOLD}%)"
        echo "Memory Usage:      ${MEM_USAGE}% (Used: ${MEM_USED}MB / Total: ${MEM_TOTAL}MB, Threshold: ${MEM_MEM_THRESHOLD:-$MEM_THRESHOLD}%)"
        echo "Disk Usage:        ${DISK_USAGE}% on ${DISK_MOUNT} (Threshold: ${DISK_THRESHOLD}%)"
        echo "Load Average:      ${LOAD_1}, ${LOAD_5}, ${LOAD_15}"
        echo "Top 5 Processes by Memory:"
        echo "$TOP_PROCESSES"
        if [[ ${#WARNINGS[@]} -gt 0 ]]; then
            echo "Alert Warnings:"
            for warn in "${WARNINGS[@]}"; do
                echo "  [WARNING] $warn"
            done
        fi
        echo "------------------------------------------------------------------"
    } | tee -a "$LOG_FILE"
fi

# Optional Webhook Notification on Warning / Critical
if [[ "$EXIT_CODE" -gt 0 && -n "${ALERT_WEBHOOK_URL:-}" ]]; then
    MSG="[System Health Alert] Host $(hostname) is in state ${STATUS} (Exit: ${EXIT_CODE}): ${WARNINGS[*]}"
    curl -fsSL -X POST -H 'Content-type: application/json' \
        --data "{\"text\":\"${MSG}\"}" \
        "${ALERT_WEBHOOK_URL}" >/dev/null 2>&1 || true
fi

exit "$EXIT_CODE"
