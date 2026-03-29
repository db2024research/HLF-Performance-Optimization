
#!/usr/bin/env bash
set -euo pipefail

# ========= User-configurable paths (from your message) =========
DOWN_DIR="$HOME/Dokumente/Project-Performance-HLF/Extend/extend5/HLF-4Peers/fabric-samples/test-network"
CONFIG_DIR="$HOME/Dokumente/Project-Performance-HLF/Extend/extend5/HLF-4Peers/fabric-samples/test-network/configtx"
CONFIG_FILE="$CONFIG_DIR/configtx.yaml"
UP_DIR="$HOME/Dokumente/Project-Performance-HLF/Extend/extend5/HLF-4Peers/fabric-samples/test-network"
CALIPER_DIR="$HOME/Dokumente/Project-Performance-HLF/Extend/extend5/HLF-4Peers/caliper-benchmarks"
SAVE_DIR="$HOME/Dokumente/Project-Performance-HLF/Extend/extend5/HLF-4Peers/caliper-benchmarks"

# Caliper command (as you provided)
CALIPER_CMD='npx caliper launch manager --caliper-workspace "$(pwd)" --caliper-benchconfig "$(pwd)/benchmarks/samples/fabric/fabcar/config.yaml" --caliper-networkconfig "$(pwd)/networks/fabric/test-network.v2.yaml"'

# Prometheus metrics endpoints (peer -> url)
declare -A PEER_URLS=(
  ["peer0-org1"]="http://amphibian:17051/metrics"
  ["peer1-org1"]="http://amphibian:18051/metrics"
  ["peer0-org2"]="http://amphibian:19051/metrics"
  ["peer1-org2"]="http://amphibian:16051/metrics"
)

# Metrics to extract (Prometheus metric base names)
# For histograms, we’ll prefer *_sum and *_count to compute averages.
METRICS=(
  "gossip_privdata_validation_duration"
  "ledger_blockstorage_commit_time"
  "ledger_statedb_commit_time"
  "gossip_state_commit_duration"
)

# ========= helpers =========
ts() { date +"%Y%m%d-%H%M%S"; }

say() { echo -e "\n=== $* ==="; }

need_cmd() {
  command -v "$1" >/dev/null 2>&1 || {
    echo "Error: '$1' is required but not found in PATH" >&2
    exit 1
  }
}

# Extract average value from a Prometheus metrics file.
# Prefers histogram avg = sum/count if available; falls back to first gauge/counter sample.
# Usage: metric_avg_from_file <metric_base_name> <file>
metric_avg_from_file() {
  local base="$1"
  local file="$2"

  # Try histogram: *_sum and *_count (might have labels; sum over all)
  local sum count
  sum=$(awk -v m="${base}_sum" '$1 ~ "^"m"(" || $1 == m { s+=$2 } END{ if(s=="") print "NA"; else printf "%.9f", s }' "$file")
  count=$(awk -v m="${base}_count" '$1 ~ "^"m"(" || $1 == m { c+=$2 } END{ if(c=="") print "NA"; else printf "%.0f", c }' "$file")

  if [[ "$sum" != "NA" && "$count" != "NA" && "$count" -gt 0 ]]; then
    # average seconds
    awk -v s="$sum" -v c="$count" 'BEGIN{ printf "%.9f", s/c }'
    return 0
  fi

  # Fallback: look for a single-sample metric without suffix (take the first numeric)
  local first
  first=$(awk -v m="^${base}($|{)" '$1 ~ m { print $2; exit }' "$file")
  if [[ -n "${first:-}" ]]; then
    awk -v v="$first" 'BEGIN{ printf "%.9f", v }'
    return 0
  fi

  # Fallback: maybe buckets exist but no sum/count — return NA
  printf "NA"
}

# ========= 1) Bring network down =========
say "Bringing network down"
need_cmd bash
need_cmd sed
need_cmd awk
need_cmd curl

cd "$DOWN_DIR"
./down_fabric.sh

# ========= 2) Prompt for MaxMessageCount and patch configtx.yaml =========
say "Configuring MaxMessageCount in $CONFIG_FILE"
read -rp "Enter MaxMessageCount (integer): " MAX_MSG
if ! [[ "$MAX_MSG" =~ ^[0-9]+$ ]]; then
  echo "Error: MaxMessageCount must be an integer." >&2
  exit 1
fi

# Backup config first
cp -f "$CONFIG_FILE" "$CONFIG_FILE.bak.$(ts)"

# Replace the first occurrence like: MaxMessageCount: <number>
# This is a simple/robust replacement. If you have multiple profiles/channels
# and want to target a specific stanza, you can refine the sed range.
sed -i -E "0,/MaxMessageCount:[[:space:]]*[0-9]+/s//MaxMessageCount: ${MAX_MSG}/" "$CONFIG_FILE"

say "MaxMessageCount set to $MAX_MSG (backup: $CONFIG_FILE.bak.$(ts))"

# ========= 3) Bring network up =========
say "Bringing network up"
cd "$UP_DIR"
./setup_IFC_N4.sh

say "Network up. Proceeding to Caliper."

# ========= 4) Run Caliper =========
cd "$CALIPER_DIR"
# shellcheck disable=SC2086
eval $CALIPER_CMD

say "Caliper benchmark completed."

# ========= 5) Fetch peer metrics and save =========
mkdir -p "$SAVE_DIR"
RUN_ID="$(ts)"
say "Fetching Prometheus metrics and saving into $SAVE_DIR (run: $RUN_ID)"

declare -A METRIC_FILES
for peer in "${!PEER_URLS[@]}"; do
  url="${PEER_URLS[$peer]}"
  out="$SAVE_DIR/${peer}_metrics_MaxMsg${MAX_MSG}_${RUN_ID}.prom"
  METRIC_FILES["$peer"]="$out"
  echo "-> $peer  ($url)"
  curl -fsSL "$url" -o "$out"
done

say "Metrics downloaded."

# ========= 5) Fetch peer metrics and save (with refresh) =========
mkdir -p "$SAVE_DIR"
RUN_ID="$(ts)"
say "Refreshing and fetching Prometheus metrics into $SAVE_DIR (run: $RUN_ID)"

# If you changed any ports, make sure PEER_URLS above is up to date.
# Current mapping (as you requested):
#   peer0-org1 -> http://amphibian:17051/metrics
#   peer1-org1 -> http://amphibian:18051/metrics
#   peer0-org2 -> http://amphibian:19051/metrics
#   peer1-org2 -> http://amphibian:16051/metrics

declare -A METRIC_FILES
for peer in peer0-org1 peer1-org1 peer0-org2 peer1-org2; do
  url="${PEER_URLS[$peer]}"

  # "Refresh" the endpoint once (throw away) then fetch & save
  curl -fsSL "${url}?r=$(date +%s)" -o /dev/null || true
  out="$SAVE_DIR/${peer}_metrics_MaxMsg${MAX_MSG}_${RUN_ID}.prom"
  echo "-> GET $url  ->  $out"
  if curl -fsSL "$url" -o "$out"; then
    METRIC_FILES["$peer"]="$out"
  else
    echo "Warning: could not fetch $url; will mark NA for $peer" >&2
    METRIC_FILES["$peer"]=""
  fi
done

say "Metrics downloaded."

# ========= 6) Parse metrics, build tables, and (optionally) compare to manual =========
TABLE_MD_SYS="$SAVE_DIR/validation_metrics_AUTOMATION_MaxMsg${MAX_MSG}_${RUN_ID}.md"
TABLE_CSV_SYS="$SAVE_DIR/validation_metrics_AUTOMATION_MaxMsg${MAX_MSG}_${RUN_ID}.csv"

# OPTIONAL: set manual files here if you want an automatic comparison.
# Map peers to the manual files you saved (edit paths if needed).
declare -A MANUAL_FILES=(
  ["peer0-org1"]="$SAVE_DIR/1.txt"
  ["peer1-org1"]="$SAVE_DIR/2.txt"
  ["peer0-org2"]="$SAVE_DIR/3.txt"
  ["peer1-org2"]="$SAVE_DIR/4.txt"
)

TABLE_MD_MAN="$SAVE_DIR/validation_metrics_MANUAL_MaxMsg${MAX_MSG}_${RUN_ID}.md"
TABLE_CSV_MAN="$SAVE_DIR/validation_metrics_MANUAL_MaxMsg${MAX_MSG}_${RUN_ID}.csv"

# Helper: compute avg = sum/count for a histogram family, summing across labels.
metric_avg() {
  # usage: metric_avg <prefix> <file>
  local prefix="$1" file="$2"
  if [[ ! -f "$file" ]]; then
    printf "NA"; return 0
  fi
  # Match lines like: <prefix>_sum{...} <value>   OR   <prefix>_sum <value>
  local sum count
  sum=$(awk -v m="${prefix}_sum"   '$1 ~ "^"m"({|$)" { s+=$2 } END{ if(s=="") print "NA"; else printf "%.9f", s }' "$file")
  count=$(awk -v m="${prefix}_count" '$1 ~ "^"m"({|$)" { c+=$2 } END{ if(c=="") print "NA"; else printf "%.0f", c }' "$file")
  if [[ "$sum" != "NA" && "$count" != "NA" && "$count" -gt 0 ]]; then
    awk -v s="$sum" -v c="$count" 'BEGIN{ printf "%.9f", s/c }'
  else
    printf "NA"
  fi
}

write_tables_for_set() {
  # usage: write_tables_for_set <name> <md_out> <csv_out> <files_assoc_name>
  local setname="$1" mdout="$2" csvout="$3" files_assoc_name="$4"
  local peers=("peer0-org1" "peer1-org1" "peer0-org2" "peer1-org2")

  echo "Peer,gossip_privdata_validation_duration (s),ledger_blockstorage_commit_time (s),ledger_statedb_commit_time (s),gossip_state_commit_duration (s)" > "$csvout"
  {
    echo "| Peer | gossip_privdata_validation_duration (s) | ledger_blockstorage_commit_time (s) | ledger_statedb_commit_time (s) | gossip_state_commit_duration (s) |"
    echo "|---|---:|---:|---:|---:|"
  } > "$mdout"

  for peer in "${peers[@]}"; do
    # indirect lookup in assoc array whose name is in $files_assoc_name
    # shellcheck disable=SC1083,SC2296
    eval "file=\${${files_assoc_name}[\"$peer\"]:-}"
    if [[ -z "${file:-}" || ! -f "$file" ]]; then
      gpv="NA"; lbc="NA"; lsc="NA"; gsc="NA"
    else
      gpv=$(metric_avg "gossip_privdata_validation_duration" "$file")
      lbc=$(metric_avg "ledger_blockstorage_commit_time" "$file")
      lsc=$(metric_avg "ledger_statedb_commit_time" "$file")
      gsc=$(metric_avg "gossip_state_commit_duration" "$file")
    fi
    echo "$peer,$gpv,$lbc,$lsc,$gsc" >> "$csvout"
    printf "| %s | %s | %s | %s | %s |\n" "$peer" "$gpv" "$lbc" "$lsc" "$gsc" >> "$mdout"
  done
}

# Build the AUTOMATION table
write_tables_for_set "automation" "$TABLE_MD_SYS" "$TABLE_CSV_SYS" METRIC_FILES
echo "Automation tables written:"
echo " - $TABLE_CSV_SYS"
echo " - $TABLE_MD_SYS"

# Build the MANUAL table if those files exist
manual_any=false
for peer in "${!MANUAL_FILES[@]}"; do
  [[ -f "${MANUAL_FILES[$peer]}" ]] && manual_any=true && break
done
if $manual_any; then
  write_tables_for_set "manual" "$TABLE_MD_MAN" "$TABLE_CSV_MAN" MANUAL_FILES
  echo "Manual tables written:"
  echo " - $TABLE_CSV_MAN"
  echo " - $TABLE_MD_MAN"
else
  echo "Manual files not found in $SAVE_DIR (1.txt..4.txt). Skipping manual table."
fi

# OPTIONAL: compare manual vs automation and report mismatches
if $manual_any; then
  DIFF_MD="$SAVE_DIR/validation_metrics_DIFF_MaxMsg${MAX_MSG}_${RUN_ID}.md"
  {
    echo "| Peer | Metric | Manual (s) | Auto (s) | Δ (Auto-Manual) | Match? |"
    echo "|---|---|---:|---:|---:|:--:|"
  } > "$DIFF_MD"

  tol="1e-9" # tolerance for float matching
  for peer in peer0-org1 peer1-org1 peer0-org2 peer1-org2; do
    man="${MANUAL_FILES[$peer]:-}"; aut="${METRIC_FILES[$peer]:-}"
    for m in gossip_privdata_validation_duration ledger_blockstorage_commit_time ledger_statedb_commit_time gossip_state_commit_duration; do
      manv=$(metric_avg "$m" "$man")
      autv=$(metric_avg "$m" "$aut")
      if [[ "$manv" == "NA" || "$autv" == "NA" ]]; then
        match="NO"
        delta="NA"
      else
        # compute delta with awk for portability
        delta=$(awk -v a="$autv" -v b="$manv" 'BEGIN{ printf "%.12f", a-b }')
        absd=$(awk -v d="$delta" 'BEGIN{ if(d<0)d=-d; printf "%.12f", d }')
        within=$(awk -v d="$absd" -v t="$tol" 'BEGIN{ print (d<=t) ? "YES" : "NO" }')
        match="$within"
      fi
      printf "| %s | %s | %s | %s | %s | %s |\n" "$peer" "$m" "${manv}" "${autv}" "${delta}" "${match}" >> "$DIFF_MD"
    done
  done
  echo "Diff table: $DIFF_MD"
fi

