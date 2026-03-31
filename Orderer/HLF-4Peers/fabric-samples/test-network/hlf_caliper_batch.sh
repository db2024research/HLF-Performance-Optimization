#!/usr/bin/env bash
set -euo pipefail

# ========= User-configurable paths =========
DOWN_DIR="$HOME/Dokumente/Project-Performance-HLF/Extend/extend5/HLF-4Peers/fabric-samples/test-network"
CONFIG_DIR="$HOME/Dokumente/Project-Performance-HLF/Extend/extend5/HLF-4Peers/fabric-samples/test-network/configtx"
CONFIG_FILE="$CONFIG_DIR/configtx.yaml"
UP_DIR="$HOME/Dokumente/Project-Performance-HLF/Extend/extend5/HLF-4Peers/fabric-samples/test-network"
CALIPER_DIR="$HOME/Dokumente/Project-Performance-HLF/Extend/extend5/HLF-4Peers/caliper-benchmarks"
SAVE_DIR="$HOME/Dokumente/Project-Performance-HLF/Extend/extend5/HLF-4Peers/caliper-benchmarks"

# Caliper command (exactly as you provided)
CALIPER_CMD='npx caliper launch manager --caliper-workspace "$(pwd)" --caliper-benchconfig "$(pwd)/benchmarks/samples/fabric/fabcar/config.yaml" --caliper-networkconfig "$(pwd)/networks/fabric/test-network.v2.yaml"'

# Prometheus metrics endpoints (peer -> url)
declare -A PEER_URLS=(
  ["peer0-org1"]="http://amphibian:17051/metrics"
  ["peer1-org1"]="http://amphibian:18051/metrics"
  ["peer0-org2"]="http://amphibian:19051/metrics"
  ["peer1-org2"]="http://amphibian:16051/metrics"
)
# Run these MaxMessageCount values (aka "block sizes")
SIZES=(2 3 4 5 6 7 8 9 10 11 12)
#2, 5, 10, 20, 30, 40
#2 4 6 8 10


# Metrics to extract (histogram sum/count)
METRICS=(
  "gossip_privdata_validation_duration"
  "ledger_blockstorage_commit_time"
  "ledger_statedb_commit_time"
  "gossip_state_commit_duration"
)

# ========= helpers =========
ts() { date +"%Y%m%d-%H%M%S"; }
say() { echo -e "\n=== $* ==="; }
need_cmd() { command -v "$1" >/dev/null 2>&1 || { echo "Error: '$1' is required but not found" >&2; exit 1; }; }

# Compute avg = sum/count across labels from a Prometheus text file
metric_avg() {
  local prefix="$1" file="$2"
  if [[ ! -f "$file" ]]; then printf "NA"; return 0; fi
  local sum count
  sum=$(awk -v m="${prefix}_sum"   '$1 ~ "^"m"({|$)" { s+=$2 } END{ if(s=="") print "NA"; else printf "%.9f", s }' "$file")
  count=$(awk -v m="${prefix}_count" '$1 ~ "^"m"({|$)" { c+=$2 } END{ if(c=="") print "NA"; else printf "%.0f", c }' "$file")
  if [[ "$sum" != "NA" && "$count" != "NA" && "$count" -gt 0 ]]; then
    awk -v s="$sum" -v c="$count" 'BEGIN{ printf "%.9f", s/c }'
  else
    printf "NA"
  fi
}

patch_max_msg() {
  local value="$1"
  say "Patching MaxMessageCount=$value in $CONFIG_FILE"
  cp -f "$CONFIG_FILE" "$CONFIG_FILE.bak.$(ts)"
  # Replace first occurrence of MaxMessageCount: <num>
  sed -i -E "0,/MaxMessageCount:[[:space:]]*[0-9]+/s//MaxMessageCount: ${value}/" "$CONFIG_FILE"
}

bring_down() {
  say "Bringing network down"
  ( cd "$DOWN_DIR" && ./down_fabric.sh ) || true
}

bring_up() {
  say "Bringing network up"
  ( cd "$UP_DIR" && ./setup_IFC_N4.sh )
}

run_caliper() {
  say "Running Caliper"
  ( cd "$CALIPER_DIR" && eval $CALIPER_CMD )
}

fetch_metrics() {
  local run_dir="$1" maxmsg="$2"
  say "Refreshing and fetching metrics -> $run_dir"
  mkdir -p "$run_dir"
  declare -gA METRIC_FILES
  for peer in peer0-org1 peer1-org1 peer0-org2 peer1-org2; do
    local url="${PEER_URLS[$peer]}"
    local out="$run_dir/${peer}_metrics_MaxMsg${maxmsg}_$(ts).prom"
    curl -fsSL "${url}?r=$(date +%s)" -o /dev/null || true  # refresh
    echo "-> GET $url  ->  $out"
    if curl -fsSL "$url" -o "$out"; then
      METRIC_FILES["$peer"]="$out"
    else
      echo "Warning: could not fetch $url; marking NA for $peer" >&2
      METRIC_FILES["$peer"]=""
    fi
  done
}

write_tables() {
  local run_dir="$1" maxmsg="$2"
  local table_md="$run_dir/validation_metrics_AUTOMATION_MaxMsg${maxmsg}.md"
  local table_csv="$run_dir/validation_metrics_AUTOMATION_MaxMsg${maxmsg}.csv"

  echo "Peer,gossip_privdata_validation_duration (s),ledger_blockstorage_commit_time (s),ledger_statedb_commit_time (s),gossip_state_commit_duration (s)" > "$table_csv"
  {
    echo "| Peer | gossip_privdata_validation_duration (s) | ledger_blockstorage_commit_time (s) | ledger_statedb_commit_time (s) | gossip_state_commit_duration (s) |"
    echo "|---|---:|---:|---:|---:|"
  } > "$table_md"

  for peer in peer0-org1 peer1-org1 peer0-org2 peer1-org2; do
    file="${METRIC_FILES[$peer]:-}"
    if [[ -z "${file:-}" || ! -f "$file" ]]; then
      gpv="NA"; lbc="NA"; lsc="NA"; gsc="NA"
    else
      gpv=$(metric_avg "gossip_privdata_validation_duration" "$file")
      lbc=$(metric_avg "ledger_blockstorage_commit_time" "$file")
      lsc=$(metric_avg "ledger_statedb_commit_time" "$file")
      gsc=$(metric_avg "gossip_state_commit_duration" "$file")
    fi
    echo "$peer,$gpv,$lbc,$lsc,$gsc" >> "$table_csv"
    printf "| %s | %s | %s | %s | %s |\n" "$peer" "$gpv" "$lbc" "$lsc" "$gsc" >> "$table_md"
  done

  say "Wrote:"
  echo "  - $table_csv"
  echo "  - $table_md"
}
# Save Caliper's report.html as <mmc>.html and an archived copy
stash_caliper_report() {
  # usage: stash_caliper_report <max_msg>
  local mmc="$1"
  local src="$CALIPER_DIR/report.html"
  local plain_dest="$SAVE_DIR/${mmc}.html"
  local ts_dest="$SAVE_DIR/report_MaxMsg${mmc}_$(date +"%Y%m%d-%H%M%S").html"

  if [[ -f "$src" ]]; then
    cp -f "$src" "$ts_dest"     # keep a timestamped archive
    cp -f "$src" "$plain_dest"  # also keep the simple 2.html / 4.html
    echo "Saved Caliper report:"
    echo "  - $plain_dest"
    echo "  - $ts_dest"
    : > "$src"                  # optional: clear report.html for next run
  else
    echo "Warning: Caliper report not found at: $src"
  fi
}

# ========= Preflight =========
need_cmd bash; need_cmd sed; need_cmd awk; need_cmd curl
mkdir -p "$SAVE_DIR"

# ========= Batch over MaxMessageCount values =========
for MAX_MSG in "${SIZES[@]}"; do
  RUN_STAMP="$(date +"%Y%m%d-%H%M%S")"
  RUN_DIR="$SAVE_DIR/run_MaxMsg${MAX_MSG}_${RUN_STAMP}"

  bring_down
  patch_max_msg "$MAX_MSG"
  bring_up

  run_caliper

  # Save Caliper report as <size>.html and a timestamped copy
  stash_caliper_report "$MAX_MSG"

  fetch_metrics "$RUN_DIR" "$MAX_MSG"
  write_tables  "$RUN_DIR" "$MAX_MSG"

  say "Completed batch for MaxMessageCount=$MAX_MSG"
done

say "All batches done."

