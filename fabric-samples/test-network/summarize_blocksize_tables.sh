#!/usr/bin/env bash
set -euo pipefail

# === Adjust only if you changed this path in your batch script ===
SAVE_DIR="$HOME/Dokumente/Project-Performance-HLF/Extend/extend5/HLF-4Peers/caliper-benchmarks"

# Peer ids (filenames) and pretty labels
declare -A PEER_LABELS=(
  ["peer0-org1"]="peer0-Org1"
  ["peer1-org1"]="peer1-Org1"
  ["peer0-org2"]="peer0-Org2"
  ["peer1-org2"]="peer1-Org2"
)

# Metrics in the exact order you want
COLS=(
  "gossip_privdata_validation_duration"
  "ledger_statedb_commit_time"
  "ledger_blockstorage_commit_time"
  "gossip_state_commit_duration"
)

# --- helpers ---
ts() { date +"%Y%m%d-%H%M%S"; }
say() { echo -e "\n=== $* ==="; }

# avg = sum/count across labels from a Prometheus text file
metric_avg() {
  local prefix="$1" file="$2"
  [[ -f "$file" ]] || { printf "NA"; return 0; }
  local sum count
  sum=$(awk -v m="${prefix}_sum"   '$1 ~ "^"m"({|$)" { s+=$2 } END{ if(s=="") print "NA"; else printf "%.9f", s }' "$file")
  count=$(awk -v m="${prefix}_count" '$1 ~ "^"m"({|$)" { c+=$2 } END{ if(c=="") print "NA"; else printf "%.0f", c }' "$file")
  if [[ "$sum" != "NA" && "$count" != "NA" && "$count" -gt 0 ]]; then
    awk -v s="$sum" -v c="$count" 'BEGIN{ printf "%.9f", s/c }'
  else
    printf "NA"
  fi
}

# --- find newest run folders without using extra functions ---
RUN2=$(ls -d "$SAVE_DIR"/run_MaxMsg2_* 2>/dev/null | sort | tail -1 || true)
RUN4=$(ls -d "$SAVE_DIR"/run_MaxMsg4_* 2>/dev/null | sort | tail -1 || true)

if [[ -z "${RUN2:-}" || -z "${RUN4:-}" ]]; then
  echo "Could not find both run directories under: $SAVE_DIR"
  echo "Expected: run_MaxMsg2_<timestamp>/ and run_MaxMsg4_<timestamp>/"
  exit 1
fi

say "Using run dirs:"
echo " - MMC=2 : $RUN2"
echo " - MMC=4 : $RUN4"

# output file
OUT_MD="$SAVE_DIR/summary_blocksize_$(ts).md"
: > "$OUT_MD"

# helper: newest .prom for peer in a given run dir
latest_prom_for_peer() {
  local run_dir="$1" peer="$2" mmc="$3"
  ls -t "$run_dir/${peer}_metrics_MaxMsg${mmc}_"*.prom 2>/dev/null | head -1 || true
}

# --- build the markdown ---
for peer in peer0-org1 peer1-org1 peer0-org2 peer1-org2; do
  label="${PEER_LABELS[$peer]}"

  file2="$(latest_prom_for_peer "$RUN2" "$peer" 2)"
  file4="$(latest_prom_for_peer "$RUN4" "$peer" 4)"

  # compute values for both rows (blocksize 2, 4)
  declare -A R2 R4
  for m in "${COLS[@]}"; do
    R2["$m"]="$(metric_avg "$m" "${file2:-/nonexistent}")"
    R4["$m"]="$(metric_avg "$m" "${file4:-/nonexistent}")"
  done

  {
    echo
    echo "${label}"
    echo
    echo "| blocksize | gossip_privdata_validation_duration* | ledger_statedb_commit_time* | ledger_blockstorage_commit_time* | gossip_state_commit_duration* |"
    echo "|---:|---:|---:|---:|---:|"
    printf "| %d | %s | %s | %s | %s |\n" 2 "${R2[gossip_privdata_validation_duration]}" "${R2[ledger_statedb_commit_time]}" "${R2[ledger_blockstorage_commit_time]}" "${R2[gossip_state_commit_duration]}"
    printf "| %d | %s | %s | %s | %s |\n" 4 "${R4[gossip_privdata_validation_duration]}" "${R4[ledger_statedb_commit_time]}" "${R4[ledger_blockstorage_commit_time]}" "${R4[gossip_state_commit_duration]}"
    echo
  } >> "$OUT_MD"
done

say "Wrote summary:"
echo "  $OUT_MD"

