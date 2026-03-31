#!/usr/bin/env bash
set -euo pipefail

# Folder containing the 4 input files (can be passed as first arg)
IN_DIR="${1:-.}"

# Output CSV path (optional 2nd arg)
TS="$(date +"%Y%m%d-%H%M%S")"
OUT_CSV="${2:-$IN_DIR/manual_metrics_${TS}.csv}"

# Peer files (exact filenames as you described)
declare -A FILES=(
  ["peer0-Org1"]="$IN_DIR/peer0-Org1.txt"
  ["peer0-Org2"]="$IN_DIR/peer0-Org2.txt"
  ["peer1-Org1"]="$IN_DIR/peer1-Org1.txt"
  ["peer1-Org2"]="$IN_DIR/peer1-Org2.txt"
)

# ---- helpers ----

# Return average = <metric>_sum / <metric>_count for channel="mychannel"
# Usage: metric_avg_from_file <metric_base> <file>
# Example: metric_avg_from_file gossip_privdata_validation_duration peer0-Org1.txt
metric_avg_from_file() {
  local base="$1"
  local file="$2"

  if [[ ! -f "$file" ]]; then
    printf "NA"
    return 0
  fi

  # Sum all values for *_sum{...channel="mychannel"...}
  local sum count
  sum=$(awk -v m="${base}_sum" '
    $1 ~ "^"m"\\{" && $0 ~ /channel="mychannel"/ { s += $2 }
    END { if (s == 0 && NR == 0) print ""; else printf("%.9f", s) }
  ' "$file")

  # Sum all values for *_count{...channel="mychannel"...}
  count=$(awk -v m="${base}_count" '
    $1 ~ "^"m"\\{" && $0 ~ /channel="mychannel"/ { c += $2 }
    END { if (c == 0 && NR == 0) print ""; else printf("%.0f", c) }
  ' "$file")

  if [[ -n "${sum}" && -n "${count}" && "${count}" != "0" ]]; then
    awk -v s="$sum" -v c="$count" 'BEGIN { printf "%.9f", s/c }'
  else
    printf "NA"
  fi
}

# ---- write CSV ----

# Header
echo "Peer,gossip_privdata_validation_duration_*,ledger_statedb_commit_time_*" > "$OUT_CSV"

# Fixed output order as requested
for peer in "peer0-Org1" "peer0-Org2" "peer1-Org1" "peer1-Org2"; do
  file="${FILES[$peer]}"

  gpv=$(metric_avg_from_file "gossip_privdata_validation_duration" "$file")
  lsc=$(metric_avg_from_file "ledger_statedb_commit_time" "$file")

  echo "$peer,$gpv,$lsc" >> "$OUT_CSV"
done

echo "CSV written to: $OUT_CSV"

