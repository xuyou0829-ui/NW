#!/usr/bin/env bash
set -Eeuo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
CONFIG_FILE="${SCRIPT_DIR}/config.env"
if [[ -f "${1:-}" ]]; then
  CONFIG_FILE="$1"
fi
source "$CONFIG_FILE"

: "${TIME_UNIT_SECONDS:=3600}"
if [[ -z "${MEMORY_TARGET_PERCENT:-}" ]]; then
  MEMORY_TARGET_PERCENT="${MEMORY_PERCENT:-80}"
fi
if [[ -z "${MEMORY_MIN_PERCENT:-}" ]]; then
  MEMORY_MIN_PERCENT=75
fi
if [[ -z "${MEMORY_MAX_PERCENT:-}" ]]; then
  MEMORY_MAX_PERCENT=85
fi
if [[ -z "${CONTROL_WINDOW_SECONDS:-}" ]]; then
  CONTROL_WINDOW_SECONDS=60
fi
if [[ -z "${MEMORY_RANGE_GRACE_SECONDS:-}" ]]; then
  MEMORY_RANGE_GRACE_SECONDS=30
fi

BURN_SECONDS=$((BURN_HOURS * TIME_UNIT_SECONDS))
REST_SECONDS=$((REST_HOURS * TIME_UNIT_SECONDS))
CHUNK_SECONDS=$((CHUNK_HOURS * TIME_UNIT_SECONDS))
TOTAL_SECONDS=$((BURN_PHASES * BURN_SECONDS + (BURN_PHASES - 1) * REST_SECONDS))
CHUNKS_PER_BURN=$((BURN_SECONDS / CHUNK_SECONDS))

if (( CHUNK_SECONDS <= 0 )); then
  echo "CHUNK_HOURS must be > 0" >&2
  exit 1
fi

if (( BURN_SECONDS % CHUNK_SECONDS != 0 )); then
  echo "BURN_HOURS must be divisible by CHUNK_HOURS" >&2
  exit 1
fi

if (( MEMORY_TARGET_PERCENT <= 0 || MEMORY_TARGET_PERCENT > 80 )); then
  echo "MEMORY_TARGET_PERCENT must be between 1 and 80" >&2
  exit 1
fi

if (( MEMORY_MIN_PERCENT <= 0 || MEMORY_MIN_PERCENT > MEMORY_TARGET_PERCENT )); then
  echo "MEMORY_MIN_PERCENT must be > 0 and <= MEMORY_TARGET_PERCENT" >&2
  exit 1
fi

if (( MEMORY_MAX_PERCENT < MEMORY_TARGET_PERCENT || MEMORY_MAX_PERCENT > 85 )); then
  echo "MEMORY_MAX_PERCENT must be >= MEMORY_TARGET_PERCENT and <= 85" >&2
  exit 1
fi

if (( CONTROL_WINDOW_SECONDS <= 0 )); then
  echo "CONTROL_WINDOW_SECONDS must be > 0" >&2
  exit 1
fi

for cmd in stress-ng awk grep sed date tail; do
  if ! command -v "$cmd" >/dev/null 2>&1; then
    echo "Missing required command: $cmd" >&2
    exit 1
  fi
done

LOG_DIR="${SCRIPT_DIR}/${LOG_DIR}"
STATE_DIR="${SCRIPT_DIR}/${STATE_DIR}"
REPORT_DIR="${SCRIPT_DIR}/${REPORT_DIR}"
mkdir -p "$LOG_DIR" "$STATE_DIR" "$REPORT_DIR"

EVENT_LOG="${LOG_DIR}/events.log"
METRICS_LOG="${LOG_DIR}/metrics.csv"
STRESS_LOG="${LOG_DIR}/stress-ng.log"
STATE_FILE="${STATE_DIR}/current_state.env"
SUMMARY_FILE="${REPORT_DIR}/summary.txt"
RUN_ID=$(date -u +"%Y%m%dT%H%M%SZ")

START_TS=$(date +%s)
STATUS="running"
FAIL_REASON=""
CURRENT_PHASE="init"
CURRENT_PHASE_INDEX=0
CURRENT_CHUNK=0
LAST_CPU="0.0"
LAST_MEM_PCT="0.0"
LAST_MEM_USED_GB="0.0"
LAST_MEM_TOTAL_GB="0.0"
LAST_TEMP_C="N/A"
LAST_CE_COUNT="N/A"
LAST_UE_COUNT="N/A"
MAX_CPU="0.0"
MAX_MEM_PCT="0.0"
MAX_TEMP_C_SEEN="N/A"
STRESS_PID=""
CPU_PREV_TOTAL=""
CPU_PREV_IDLE=""
SENSOR_WARNING=0
EDAC_AVAILABLE=0
OVERALL_ELAPSED_AT_PHASE_START=0
PHASE_START_TS=$START_TS
LAST_ALERTS="None detected"
LAST_ALERT_COUNT=0
MEMORY_HEALTH="Checking"
MEMORY_RANGE_STATUS="Checking"
STRESS_STATUS="idle"
SEGMENT_START_TS=$START_TS

if compgen -G "/sys/devices/system/edac/mc/mc*/ce_count" >/dev/null 2>&1; then
  EDAC_AVAILABLE=1
fi

log_event() {
  local ts
  ts=$(date -u +"%F %T UTC")
  echo "[$ts] $*" >> "$EVENT_LOG"
}

save_state() {
  cat > "$STATE_FILE" <<EOF
STATUS=${STATUS}
FAIL_REASON=${FAIL_REASON}
CURRENT_PHASE=${CURRENT_PHASE}
CURRENT_PHASE_INDEX=${CURRENT_PHASE_INDEX}
CURRENT_CHUNK=${CURRENT_CHUNK}
START_TS=${START_TS}
LAST_CPU=${LAST_CPU}
LAST_MEM_PCT=${LAST_MEM_PCT}
LAST_TEMP_C=${LAST_TEMP_C}
LAST_CE_COUNT=${LAST_CE_COUNT}
LAST_UE_COUNT=${LAST_UE_COUNT}
MAX_CPU=${MAX_CPU}
MAX_MEM_PCT=${MAX_MEM_PCT}
MAX_TEMP_C_SEEN=${MAX_TEMP_C_SEEN}
LAST_ALERT_COUNT=${LAST_ALERT_COUNT}
MEMORY_HEALTH=${MEMORY_HEALTH}
MEMORY_RANGE_STATUS=${MEMORY_RANGE_STATUS}
STRESS_STATUS=${STRESS_STATUS}
EOF
}

rotate_file_if_exists() {
  local file archive
  file=$1
  if [[ -f "$file" && -s "$file" ]]; then
    archive="${file}.${RUN_ID}.bak"
    mv "$file" "$archive"
  fi
}

prepare_run_files() {
  rotate_file_if_exists "$EVENT_LOG"
  rotate_file_if_exists "$STRESS_LOG"
  rotate_file_if_exists "$METRICS_LOG"
  rotate_file_if_exists "$SUMMARY_FILE"
  : > "$EVENT_LOG"
  : > "$STRESS_LOG"
}

init_metrics_log() {
  if [[ ! -f "$METRICS_LOG" ]]; then
    echo "timestamp,overall_elapsed_s,phase,phase_index,chunk_index,chunk_elapsed_s,cpu_pct,mem_pct,mem_used_gb,mem_total_gb,temp_c,ce_count,ue_count" > "$METRICS_LOG"
  fi
}

append_metrics() {
  local ts overall_elapsed chunk_elapsed
  ts=$(date -u +"%F %T")
  overall_elapsed=$(( $(date +%s) - START_TS ))
  chunk_elapsed=$(( $(date +%s) - CHUNK_START_TS ))
  echo "$ts,$overall_elapsed,$CURRENT_PHASE,$CURRENT_PHASE_INDEX,$CURRENT_CHUNK,$chunk_elapsed,$LAST_CPU,$LAST_MEM_PCT,$LAST_MEM_USED_GB,$LAST_MEM_TOTAL_GB,$LAST_TEMP_C,$LAST_CE_COUNT,$LAST_UE_COUNT" >> "$METRICS_LOG"
}

human_time() {
  local total h m s
  total=$1
  (( total < 0 )) && total=0
  h=$((total / 3600))
  m=$(((total % 3600) / 60))
  s=$((total % 60))
  printf "%02dh:%02dm:%02ds" "$h" "$m" "$s"
}

progress_pct() {
  awk -v part="$1" -v whole="$2" 'BEGIN { if (whole <= 0) { printf "0.0" } else { printf "%.1f", (part / whole) * 100 } }'
}

max_float() {
  awk -v a="$1" -v b="$2" 'BEGIN { if (a == "N/A") print b; else if (b == "N/A") print a; else if (a + 0 >= b + 0) print a; else print b }'
}

read_cpu_usage() {
  local cpu user nice system idle iowait irq softirq steal guest guest_nice total idle_all diff_total diff_idle
  read -r cpu user nice system idle iowait irq softirq steal guest guest_nice < /proc/stat
  total=$((user + nice + system + idle + iowait + irq + softirq + steal))
  idle_all=$((idle + iowait))

  if [[ -n "$CPU_PREV_TOTAL" ]]; then
    diff_total=$((total - CPU_PREV_TOTAL))
    diff_idle=$((idle_all - CPU_PREV_IDLE))
    LAST_CPU=$(awk -v dt="$diff_total" -v di="$diff_idle" 'BEGIN { if (dt <= 0) printf "0.0"; else printf "%.1f", ((dt - di) / dt) * 100 }')
  else
    LAST_CPU="0.0"
  fi

  CPU_PREV_TOTAL=$total
  CPU_PREV_IDLE=$idle_all
}

read_memory_usage() {
  local mem_total_kb mem_available_kb mem_used_kb
  mem_total_kb=$(awk '/MemTotal:/ {print $2}' /proc/meminfo)
  mem_available_kb=$(awk '/MemAvailable:/ {print $2}' /proc/meminfo)
  mem_used_kb=$((mem_total_kb - mem_available_kb))
  LAST_MEM_PCT=$(awk -v used="$mem_used_kb" -v total="$mem_total_kb" 'BEGIN { if (total <= 0) printf "0.0"; else printf "%.1f", (used / total) * 100 }')
  LAST_MEM_USED_GB=$(awk -v used="$mem_used_kb" 'BEGIN { printf "%.1f", used / 1024 / 1024 }')
  LAST_MEM_TOTAL_GB=$(awk -v total="$mem_total_kb" 'BEGIN { printf "%.1f", total / 1024 / 1024 }')
}

normalize_temp_stream() {
  awk '
    BEGIN { max = "" }
    {
      gsub(/[^0-9.+-]/, "", $0)
      if ($0 == "" || $0 == "+" || $0 == "-") next
      raw = $0 + 0
      temp = ""
      if (raw > 1000 && raw < 200000) {
        temp = raw / 1000
      } else if (raw > 0 && raw < 150) {
        temp = raw
      }
      if (temp != "" && temp > 0 && temp < 150) {
        if (max == "" || temp > max) max = temp
      }
    }
    END {
      if (max != "") printf "%.1f", max
    }
  '
}

read_temperature() {
  local max_temp=""
  if command -v sensors >/dev/null 2>&1; then
    max_temp=$(sensors 2>/dev/null | grep -Eo '[-+]?[0-9]+(\.[0-9]+)?°C' | normalize_temp_stream) || true
  fi

  if [[ -z "$max_temp" ]]; then
    local thermal
    thermal=$(find /sys/class/thermal -maxdepth 2 -name temp -type f 2>/dev/null | xargs -r cat 2>/dev/null | normalize_temp_stream) || true
    max_temp="$thermal"
  fi

  if [[ -n "$max_temp" ]]; then
    LAST_TEMP_C="$max_temp"
  else
    LAST_TEMP_C="N/A"
    SENSOR_WARNING=1
  fi
}

sum_edac_counts() {
  local pattern sum=0 found=0 file value
  pattern=$1
  shopt -s nullglob
  for file in /sys/devices/system/edac/mc/mc*/"$pattern"; do
    value=$(cat "$file" 2>/dev/null || echo 0)
    if [[ "$value" =~ ^[0-9]+$ ]]; then
      sum=$((sum + value))
      found=1
    fi
  done
  shopt -u nullglob

  if (( found )); then
    echo "$sum"
  else
    echo "N/A"
  fi
}

read_edac_counts() {
  LAST_CE_COUNT=$(sum_edac_counts ce_count)
  LAST_UE_COUNT=$(sum_edac_counts ue_count)
}

baseline_ce=$(sum_edac_counts ce_count)
baseline_ue=$(sum_edac_counts ue_count)

refresh_memory_health() {
  local ce_delta="N/A" ue_delta="N/A"
  if [[ "$baseline_ce" =~ ^[0-9]+$ ]] && [[ "$LAST_CE_COUNT" =~ ^[0-9]+$ ]]; then
    ce_delta=$((LAST_CE_COUNT - baseline_ce))
  fi
  if [[ "$baseline_ue" =~ ^[0-9]+$ ]] && [[ "$LAST_UE_COUNT" =~ ^[0-9]+$ ]]; then
    ue_delta=$((LAST_UE_COUNT - baseline_ue))
  fi

  if [[ "$ue_delta" != "N/A" && "$ue_delta" -gt 0 ]]; then
    MEMORY_HEALTH="FAIL (UE +${ue_delta})"
  elif [[ "$ce_delta" != "N/A" && "$ce_delta" -gt 0 ]]; then
    MEMORY_HEALTH="WARN (CE +${ce_delta})"
  elif (( EDAC_AVAILABLE == 1 )); then
    MEMORY_HEALTH="OK"
  else
    MEMORY_HEALTH="EDAC unavailable"
  fi

  if awk -v current="$LAST_MEM_PCT" -v min="$MEMORY_MIN_PERCENT" 'BEGIN { exit !(current < min) }'; then
    MEMORY_RANGE_STATUS="LOW"
  elif awk -v current="$LAST_MEM_PCT" -v max="$MEMORY_MAX_PERCENT" 'BEGIN { exit !(current > max) }'; then
    MEMORY_RANGE_STATUS="HIGH"
  else
    MEMORY_RANGE_STATUS="OK"
  fi
}

calculate_vm_bytes_percent() {
  awk -v used="$LAST_MEM_PCT" -v target="$MEMORY_TARGET_PERCENT" 'BEGIN {
    desired = target - used
    if (desired < 1) desired = 1
    if (desired > 80) desired = 80
    printf "%d", desired
  }'
}

refresh_alerts() {
  local event_alerts stress_alerts combined
  event_alerts=$(tail -n 50 "$EVENT_LOG" 2>/dev/null | grep -Ei 'fail|error|warn|abort|exceed|interrupt|EDAC|temperature .*exceeded' | tail -n 3 || true)
  stress_alerts=$(tail -n 200 "$STRESS_LOG" 2>/dev/null | grep -Ei 'error|fail|warn|oom|killed|segfault|assert|corrupt|mce|edac|ecc|miscompare' | tail -n 3 || true)
  combined=$(printf "%s\n%s\n" "$event_alerts" "$stress_alerts" | awk 'NF && !seen[$0]++')

  if [[ -n "$combined" ]]; then
    LAST_ALERTS="$combined"
    LAST_ALERT_COUNT=$(printf "%s\n" "$combined" | awk 'NF { count++ } END { print count + 0 }')
  else
    LAST_ALERTS="None detected"
    LAST_ALERT_COUNT=0
  fi
}

refresh_stress_status() {
  if [[ -n "$STRESS_PID" ]] && kill -0 "$STRESS_PID" 2>/dev/null; then
    STRESS_STATUS="running (pid ${STRESS_PID})"
  elif [[ "$STATUS" == "failed" ]]; then
    STRESS_STATUS="failed"
  elif [[ "$CURRENT_PHASE" == rest* ]]; then
    STRESS_STATUS="resting"
  else
    STRESS_STATUS="idle"
  fi
}

update_live_metrics() {
  read_cpu_usage
  read_memory_usage
  read_temperature
  read_edac_counts
  refresh_memory_health
  refresh_alerts
  refresh_stress_status
  MAX_CPU=$(max_float "$MAX_CPU" "$LAST_CPU")
  MAX_MEM_PCT=$(max_float "$MAX_MEM_PCT" "$LAST_MEM_PCT")
  MAX_TEMP_C_SEEN=$(max_float "$MAX_TEMP_C_SEEN" "$LAST_TEMP_C")
}

render_dashboard() {
  local now overall_elapsed phase_elapsed phase_total remaining overall_pct phase_pct chunk_elapsed chunk_remaining display_overall_elapsed display_phase_elapsed
  now=$(date +%s)
  overall_elapsed=$((now - START_TS))
  phase_elapsed=$((now - PHASE_START_TS))

  display_overall_elapsed=$overall_elapsed
  if (( display_overall_elapsed > TOTAL_SECONDS )); then
    display_overall_elapsed=$TOTAL_SECONDS
  fi

  if [[ "$CURRENT_PHASE" == burn* ]]; then
    phase_total=$BURN_SECONDS
  elif [[ "$CURRENT_PHASE" == rest* ]]; then
    phase_total=$REST_SECONDS
  else
    phase_total=0
  fi

  display_phase_elapsed=$phase_elapsed
  if (( phase_total > 0 && display_phase_elapsed > phase_total )); then
    display_phase_elapsed=$phase_total
  fi

  overall_pct=$(progress_pct "$display_overall_elapsed" "$TOTAL_SECONDS")
  phase_pct=$(progress_pct "$display_phase_elapsed" "$phase_total")
  chunk_elapsed=$((now - CHUNK_START_TS))
  chunk_remaining=$((CHUNK_DURATION - chunk_elapsed))
  remaining=$((TOTAL_SECONDS - overall_elapsed))

  if [[ -t 1 ]]; then
    printf '\033[H\033[2J'
  fi

  cat <<EOF
Server Memory Stress Test
=========================
Status            : ${STATUS}
Current phase     : ${CURRENT_PHASE} (${CURRENT_PHASE_INDEX})
Current chunk     : ${CURRENT_CHUNK}
Overall progress  : ${overall_pct}% ($(human_time "$display_overall_elapsed") / $(human_time "$TOTAL_SECONDS"))
Phase progress    : ${phase_pct}% ($(human_time "$display_phase_elapsed") / $(human_time "$phase_total"))
Time remaining    : $(human_time "$remaining")
Chunk remaining   : $(human_time "$chunk_remaining")

Live metrics
------------
CPU utilization   : ${LAST_CPU}%
Memory utilization: ${LAST_MEM_PCT}% (${LAST_MEM_USED_GB} GiB / ${LAST_MEM_TOTAL_GB} GiB)
Memory band       : ${MEMORY_MIN_PERCENT}% - ${MEMORY_MAX_PERCENT}% (target ${MEMORY_TARGET_PERCENT}%)
Range status      : ${MEMORY_RANGE_STATUS}
Temperature       : ${LAST_TEMP_C} C (reasonable max)
EDAC CE / UE      : ${LAST_CE_COUNT} / ${LAST_UE_COUNT}

Health checks
-------------
Stress process    : ${STRESS_STATUS}
Memory health     : ${MEMORY_HEALTH}
Detected alerts   : ${LAST_ALERT_COUNT}

Latest alerts
-------------
${LAST_ALERTS}

Peak metrics
------------
Max CPU           : ${MAX_CPU}%
Max memory        : ${MAX_MEM_PCT}%
Max temperature   : ${MAX_TEMP_C_SEEN} C

Paths
-----
Config            : ${CONFIG_FILE}
Events log        : ${EVENT_LOG}
Metrics log       : ${METRICS_LOG}
Summary           : ${SUMMARY_FILE}

Recent events
-------------
$(tail -n 6 "$EVENT_LOG" 2>/dev/null)
EOF
}

check_temperature_limit() {
  if [[ "$LAST_TEMP_C" != "N/A" ]] && awk -v temp="$LAST_TEMP_C" -v max="$MAX_TEMP_C" 'BEGIN { exit !(temp > max) }'; then
    FAIL_REASON="Temperature ${LAST_TEMP_C}C exceeded limit ${MAX_TEMP_C}C"
    STATUS="failed"
    log_event "$FAIL_REASON"
    if [[ -n "$STRESS_PID" ]] && kill -0 "$STRESS_PID" 2>/dev/null; then
      kill "$STRESS_PID" 2>/dev/null || true
      wait "$STRESS_PID" 2>/dev/null || true
    fi
    save_state
    finalize_report
    exit 1
  fi
}

check_memory_band_limit() {
  local segment_elapsed
  if [[ "$CURRENT_PHASE" != burn* ]]; then
    return 0
  fi

  segment_elapsed=$(( $(date +%s) - SEGMENT_START_TS ))
  if (( segment_elapsed < MEMORY_RANGE_GRACE_SECONDS )); then
    return 0
  fi

  if [[ "$MEMORY_RANGE_STATUS" != "OK" ]]; then
    FAIL_REASON="Memory utilization ${LAST_MEM_PCT}% is outside the allowed range ${MEMORY_MIN_PERCENT}% - ${MEMORY_MAX_PERCENT}%"
    STATUS="failed"
    log_event "$FAIL_REASON"
    if [[ -n "$STRESS_PID" ]] && kill -0 "$STRESS_PID" 2>/dev/null; then
      kill "$STRESS_PID" 2>/dev/null || true
      wait "$STRESS_PID" 2>/dev/null || true
    fi
    save_state
    finalize_report
    exit 1
  fi
}

cleanup_on_signal() {
  STATUS="aborted"
  FAIL_REASON="Interrupted by signal"
  log_event "$FAIL_REASON"
  if [[ -n "$STRESS_PID" ]] && kill -0 "$STRESS_PID" 2>/dev/null; then
    kill "$STRESS_PID" 2>/dev/null || true
    wait "$STRESS_PID" 2>/dev/null || true
  fi
  save_state
  finalize_report
  exit 130
}
trap cleanup_on_signal INT TERM

monitor_for_duration() {
  local duration end_ts
  duration=$1
  CHUNK_DURATION=$duration
  CHUNK_START_TS=$(date +%s)
  end_ts=$((CHUNK_START_TS + duration))

  while (( $(date +%s) < end_ts )); do
    update_live_metrics
    append_metrics
    render_dashboard
    check_temperature_limit
    check_memory_band_limit
    save_state
    sleep "$SAMPLE_SECONDS"
  done

  update_live_metrics
  append_metrics
  render_dashboard
  save_state
}

run_burn_chunk() {
  local phase_num chunk_num exit_code remaining_seconds segment_seconds vm_bytes_percent
  phase_num=$1
  chunk_num=$2
  CURRENT_PHASE="burn${phase_num}"
  CURRENT_PHASE_INDEX=$phase_num
  CURRENT_CHUNK=$chunk_num
  CHUNK_DURATION=$CHUNK_SECONDS
  CHUNK_START_TS=$(date +%s)
  remaining_seconds=$CHUNK_SECONDS

  log_event "Starting ${CURRENT_PHASE} chunk ${chunk_num}/${CHUNKS_PER_BURN}"
  save_state

  while (( remaining_seconds > 0 )); do
    update_live_metrics
    vm_bytes_percent=$(calculate_vm_bytes_percent)
    segment_seconds=$CONTROL_WINDOW_SECONDS
    if (( segment_seconds > remaining_seconds )); then
      segment_seconds=$remaining_seconds
    fi
    SEGMENT_START_TS=$(date +%s)

    log_event "Running ${CURRENT_PHASE} chunk ${chunk_num}/${CHUNKS_PER_BURN} segment for ${segment_seconds}s with vm-bytes ${vm_bytes_percent}%"

    local stress_cmd=(stress-ng --vm "$VM_WORKERS" --vm-bytes "${vm_bytes_percent}%" --vm-keep --vm-method "$VM_METHOD" --verify --timeout "${segment_seconds}s" --metrics-brief)
    if (( CPU_WORKERS > 0 )); then
      stress_cmd+=(--cpu "$CPU_WORKERS")
    fi

    "${stress_cmd[@]}" >> "$STRESS_LOG" 2>&1 &
    STRESS_PID=$!

    while kill -0 "$STRESS_PID" 2>/dev/null; do
      update_live_metrics
      append_metrics
      render_dashboard
      check_temperature_limit
      check_memory_band_limit
      save_state
      sleep "$SAMPLE_SECONDS"
    done

    wait "$STRESS_PID"
    exit_code=$?
    STRESS_PID=""

    update_live_metrics
    append_metrics
    render_dashboard
    save_state

    if (( exit_code != 0 )); then
      STATUS="failed"
      FAIL_REASON="stress-ng failed in ${CURRENT_PHASE} chunk ${chunk_num} with exit code ${exit_code}"
      log_event "$FAIL_REASON"
      return 1
    fi

    remaining_seconds=$((remaining_seconds - segment_seconds))
  done

  log_event "Completed ${CURRENT_PHASE} chunk ${chunk_num}/${CHUNKS_PER_BURN}"
  return 0
}

run_rest_phase() {
  local phase_num
  phase_num=$1
  CURRENT_PHASE="rest${phase_num}"
  CURRENT_PHASE_INDEX=$phase_num
  CURRENT_CHUNK=0
  CHUNK_DURATION=$REST_SECONDS
  log_event "Starting ${CURRENT_PHASE} for $(human_time "$REST_SECONDS")"
  save_state
  monitor_for_duration "$REST_SECONDS"
  log_event "Completed ${CURRENT_PHASE}"
}

finalize_report() {
  local end_ts total_runtime final_status note ce_delta ue_delta
  end_ts=$(date +%s)
  total_runtime=$((end_ts - START_TS))
  ce_delta="N/A"
  ue_delta="N/A"

  if [[ "$baseline_ce" =~ ^[0-9]+$ ]] && [[ "$LAST_CE_COUNT" =~ ^[0-9]+$ ]]; then
    ce_delta=$((LAST_CE_COUNT - baseline_ce))
  fi
  if [[ "$baseline_ue" =~ ^[0-9]+$ ]] && [[ "$LAST_UE_COUNT" =~ ^[0-9]+$ ]]; then
    ue_delta=$((LAST_UE_COUNT - baseline_ue))
  fi

  final_status="PASS"
  note="Completed all configured phases"

  if [[ "$STATUS" == "failed" || "$STATUS" == "aborted" ]]; then
    final_status="FAIL"
    note="$FAIL_REASON"
  elif [[ "$ue_delta" != "N/A" && "$ue_delta" -gt 0 ]]; then
    final_status="FAIL"
    note="Detected ${ue_delta} new EDAC UE errors"
  elif [[ "$ce_delta" != "N/A" && "$ce_delta" -gt 0 ]]; then
    final_status="PASS WITH WARNING"
    note="Detected ${ce_delta} new EDAC CE errors"
  elif (( SENSOR_WARNING == 1 )) || [[ "$LAST_TEMP_C" == "N/A" ]]; then
    final_status="PASS WITH WARNING"
    note="Completed, but temperature sensors were unavailable"
  fi

  cat > "$SUMMARY_FILE" <<EOF
Server Memory Stress Test Summary
=================================
Result              : ${final_status}
Note                : ${note}
Started at          : $(date -d "@${START_TS}" -u +"%F %T UTC")
Finished at         : $(date -d "@${end_ts}" -u +"%F %T UTC")
Total runtime       : $(human_time "$total_runtime")
Configured burn     : ${BURN_PHASES} x ${BURN_HOURS}h
Configured rest     : ${REST_HOURS}h between burn phases
Chunk size          : ${CHUNK_HOURS}h
Memory band         : ${MEMORY_MIN_PERCENT}% - ${MEMORY_MAX_PERCENT}%
Memory target       : ${MEMORY_TARGET_PERCENT}%
Control window      : ${CONTROL_WINDOW_SECONDS}s
Peak CPU usage      : ${MAX_CPU}%
Peak memory usage   : ${MAX_MEM_PCT}%
Peak temperature    : ${MAX_TEMP_C_SEEN} C
Final CE count      : ${LAST_CE_COUNT}
Final UE count      : ${LAST_UE_COUNT}
CE delta            : ${ce_delta}
UE delta            : ${ue_delta}
Events log          : ${EVENT_LOG}
Metrics log         : ${METRICS_LOG}
Stress log          : ${STRESS_LOG}
EOF
}

main() {
  prepare_run_files
  init_metrics_log
  log_event "Starting memory stress test with ${BURN_PHASES} burn phases, ${CHUNKS_PER_BURN} chunks per burn phase, memory band ${MEMORY_MIN_PERCENT}% - ${MEMORY_MAX_PERCENT}% and target ${MEMORY_TARGET_PERCENT}%"
  update_live_metrics
  save_state

  local burn_index chunk_index
  for (( burn_index=1; burn_index<=BURN_PHASES; burn_index++ )); do
    PHASE_START_TS=$(date +%s)
    for (( chunk_index=1; chunk_index<=CHUNKS_PER_BURN; chunk_index++ )); do
      run_burn_chunk "$burn_index" "$chunk_index" || {
        finalize_report
        render_dashboard
        exit 1
      }
    done

    OVERALL_ELAPSED_AT_PHASE_START=$(( $(date +%s) - START_TS ))

    if (( burn_index < BURN_PHASES )); then
      PHASE_START_TS=$(date +%s)
      run_rest_phase "$burn_index"
    fi
  done

  STATUS="completed"
  CURRENT_PHASE="done"
  CURRENT_PHASE_INDEX=$BURN_PHASES
  CURRENT_CHUNK=$CHUNKS_PER_BURN
  log_event "All phases completed successfully"
  save_state
  finalize_report
  render_dashboard
}

main "$@"
