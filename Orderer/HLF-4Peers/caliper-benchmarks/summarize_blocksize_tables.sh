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

# Metrics (column headers & order)
COLS=(
  "gossip_privdata_validation_duration"
  "ledger_statedb_commit_time"
  "ledger_blockstorage_commit_time"
  "gossip_state_commit_duration"
)

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

# newest .prom for peer at a specific MaxMessageCount (block size)
latest_prom_for_peer_mmc() {
  local mmc="$1" peer="$2"
  local run_dir
  run_dir=$(ls -d "$SAVE_DIR"/run_MaxMsg${mmc}_* 2>/dev/null | sort | tail -1 || true)
  [[ -n "${run_dir:-}" ]] || { echo ""; return 0; }
  ls -t "$run_dir/${peer}_metrics_MaxMsg${mmc}_"*.prom 2>/dev/null | head -1 || true
}

# ------------------------------------------------------------
# Part A) Summarize Prometheus .prom files (your original script)
# ------------------------------------------------------------
mapfile -t ALL_RUNS < <(ls -d "$SAVE_DIR"/run_MaxMsg*_*/ 2>/dev/null | sed 's:/*$::' || true)
if [[ ${#ALL_RUNS[@]} -eq 0 ]]; then
  echo "No run directories found under: $SAVE_DIR"
  echo "Expected: run_MaxMsg<mmc>_<timestamp>/"
  exit 1
fi

declare -a SIZES=()
for d in "${ALL_RUNS[@]}"; do
  base="$(basename "$d")"
  mmc="${base#run_MaxMsg}"
  mmc="${mmc%%_*}"
  SIZES+=("$mmc")
done
mapfile -t SIZES < <(printf "%s\n" "${SIZES[@]}" | awk 'NF' | sort -n | uniq)

say "Detected block sizes:"
echo "  ${SIZES[*]}"

OUT_STAMP="$(ts)"
OUT_MD="$SAVE_DIR/summary_blocksize_${OUT_STAMP}.md"
OUT_CSV="$SAVE_DIR/summary_blocksize_${OUT_STAMP}.csv"
: > "$OUT_MD"
: > "$OUT_CSV"

echo "peer,blocksize,gossip_privdata_validation_duration,ledger_statedb_commit_time,ledger_blockstorage_commit_time,gossip_state_commit_duration" >> "$OUT_CSV"

for peer in peer0-org1 peer1-org1 peer0-org2 peer1-org2; do
  label="${PEER_LABELS[$peer]}"

  {
    echo
    echo "${label}"
    echo
    echo "| blocksize | gossip_privdata_validation_duration* | ledger_statedb_commit_time* | ledger_blockstorage_commit_time* | gossip_state_commit_duration* |"
    echo "|---:|---:|---:|---:|---:|"
  } >> "$OUT_MD"

  for mmc in "${SIZES[@]}"; do
    file="$(latest_prom_for_peer_mmc "$mmc" "$peer")"
    declare -A R
    for m in "${COLS[@]}"; do
      R["$m"]="$(metric_avg "$m" "${file:-/nonexistent}")"
    done

    printf "| %s | %s | %s | %s | %s |\n" "$mmc" \
      "${R[gossip_privdata_validation_duration]}" \
      "${R[ledger_statedb_commit_time]}" \
      "${R[ledger_blockstorage_commit_time]}" \
      "${R[gossip_state_commit_duration]}" >> "$OUT_MD"

    printf "%s,%s,%s,%s,%s,%s\n" "$label" "$mmc" \
      "${R[gossip_privdata_validation_duration]}" \
      "${R[ledger_statedb_commit_time]}" \
      "${R[ledger_blockstorage_commit_time]}" \
      "${R[gossip_state_commit_duration]}" >> "$OUT_CSV"
  done

  echo >> "$OUT_MD"
done

say "Wrote Prometheus summary outputs:"
echo "  Markdown: $OUT_MD"
echo "  CSV:      $OUT_CSV"

# ------------------------------------------------------------
# Part B) Summarize Caliper HTML files (2.html, 4.html, ...) -> CSV
# ------------------------------------------------------------
CALIPER_OUT_CSV="$SAVE_DIR/caliper_summary_${OUT_STAMP}.csv"

say "Parsing Caliper HTML reports (*.html like 2.html, 4.html, ...)"
python3 - "$SAVE_DIR" "$CALIPER_OUT_CSV" <<'PY'
import re, sys, csv
from pathlib import Path
from html import unescape

in_dir = Path(sys.argv[1]).expanduser().resolve()
out_csv = Path(sys.argv[2]).expanduser().resolve()

html_files = sorted([p for p in in_dir.glob("*.html") if re.fullmatch(r"\d+\.html", p.name)])
if not html_files:
    print(f"No numeric html files found in {in_dir} (expected 2.html, 4.html, ...)", file=sys.stderr)
    sys.exit(1)

def strip_tags(s: str) -> str:
    s = re.sub(r"<script.*?</script>", "", s, flags=re.S|re.I)
    s = re.sub(r"<style.*?</style>", "", s, flags=re.S|re.I)
    s = re.sub(r"<[^>]+>", " ", s)
    s = unescape(s)
    s = re.sub(r"\s+", " ", s).strip()
    return s

def to_float(x: str):
    x = x.replace(",", "").strip()
    x = re.sub(r"[^\d.\-eE+]", "", x)
    return float(x) if x else None

def parse_latency_throughput(html: str):
    header_tr = re.search(
        r"<tr[^>]*>.*?<th[^>]*>.*?Avg\s*Latency\s*\(s\).*?</th>.*?<th[^>]*>.*?Throughput\s*\(TPS\).*?</th>.*?</tr>",
        html, flags=re.S|re.I
    )
    if not header_tr:
        raise ValueError("Could not find header row with 'Avg Latency (s)' and 'Throughput (TPS)'.")

    hdr_html = header_tr.group(0)
    ths = re.findall(r"<th[^>]*>(.*?)</th>", hdr_html, flags=re.S|re.I)
    headers = [strip_tags(t).lower() for t in ths]

    def idx_exact(name):
        name = name.lower()
        for i, h in enumerate(headers):
            if h == name:
                return i
        return None

    i_lat = idx_exact("avg latency (s)")
    i_tps = idx_exact("throughput (tps)")

    if i_lat is None or i_tps is None:
        raise ValueError(f"Found header row but could not map columns. Headers={headers}")

    tail = html[header_tr.end():]
    data_tr = re.search(r"<tr[^>]*>\s*(?:<td[^>]*>.*?</td>\s*)+</tr>", tail, flags=re.S|re.I)
    if not data_tr:
        raise ValueError("Found header row but no data row (<td>...) after it.")

    tds = re.findall(r"<td[^>]*>(.*?)</td>", data_tr.group(0), flags=re.S|re.I)
    cells = [strip_tags(td) for td in tds]

    if i_lat >= len(cells) or i_tps >= len(cells):
        raise ValueError(f"Data row too short. cells={cells}")

    latency = to_float(cells[i_lat])
    tps = to_float(cells[i_tps])
    if latency is None or tps is None:
        raise ValueError(f"Parsed cells but got None: latency={cells[i_lat]!r}, tps={cells[i_tps]!r}")

    return latency, tps

rows = []
for f in html_files:
    bs = int(f.stem)
    html = f.read_text(errors="ignore")
    try:
        lat, tps = parse_latency_throughput(html)
        rows.append((bs, lat, tps))
        print(f"✔ {f.name}: latency={lat}, throughput={tps}")
    except Exception as e:
        print(f"WARNING: {f.name}: {e}", file=sys.stderr)

rows.sort(key=lambda x: x[0])

with out_csv.open("w", newline="") as fp:
    w = csv.writer(fp)
    w.writerow(["block_size", "latency", "throughput"])
    w.writerows(rows)

print(f"Wrote: {out_csv}")
PY

say "Wrote Caliper summary output:"
echo "  CSV: $CALIPER_OUT_CSV"
echo
echo "All done ✔"

