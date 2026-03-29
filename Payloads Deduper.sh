#!/bin/bash
set -euo pipefail
IFS=$'\n\t'

# ----------------------------
# Configuration
# ----------------------------
PAYLOAD_DIR="/root/payloads"
LOG_FILE="/root/payload_cleanup.log"
BACKUP_DIR="/root/payload_backup_$(date +%s)"
MODE="largest"                    # Options: newest | largest | shortest
DRY_RUN=false                      # False for auto deletion
BACKUP=true                         # Backup duplicates
EXCLUDE_PATTERNS=("*.log" "*.tmp") # Files to ignore
PARALLEL_HASH=true                  # Use GNU parallel if available

# Colors
GREEN="\033[0;32m"
RED="\033[0;31m"
NC="\033[0m"

# Normalize payload dir
PAYLOAD_DIR="$(realpath "$PAYLOAD_DIR")"
mkdir -p "$BACKUP_DIR"

declare -A file_hashes
declare -A hash_groups
declare -A duplicates_map
duplicates=()

echo "[*] Starting Final Bulletproof Payload Cleanup (mode: $MODE)..." | tee -a "$LOG_FILE"

# ----------------------------
# Pick best file function
# ----------------------------
pick_best() {
    local f1="$1"
    local f2="$2"
    case "$MODE" in
        newest) [[ "$f1" -nt "$f2" ]] && echo "$f1" || echo "$f2" ;;
        largest) [[ $(stat -c%s "$f1") -gt $(stat -c%s "$f2") ]] && echo "$f1" || echo "$f2" ;;
        shortest) [[ ${#f1} -lt ${#f2} ]] && echo "$f1" || echo "$f2" ;;
        *) echo "$f1" ;;
    esac
}

# ----------------------------
# Step 1: Scan files safely
# ----------------------------
declare -A size_groups

while IFS= read -r -d '' file; do
    [[ -L "$file" ]] && continue
    real_file=$(realpath "$file")
    [[ "$real_file" != "$PAYLOAD_DIR"* ]] && continue

    skip=false
    for pattern in "${EXCLUDE_PATTERNS[@]}"; do
        [[ "$(basename "$file")" == $pattern ]] && skip=true && break
    done
    $skip && continue

    size=$(stat -c%s "$file")
    size_groups[$size]+="$file"$'\n'
done < <(find "$PAYLOAD_DIR" -xdev -type f -print0)

# ----------------------------
# Step 2: Hash groups (bulletproof)
# ----------------------------
for size in "${!size_groups[@]}"; do
    group="${size_groups[$size]}"
    files_to_hash=()

    # Build null-delimited array safely
    while IFS= read -r -d '' file; do
        files_to_hash+=("$file")
    done <<< "$(printf '%s\0' "$group")"

    if $PARALLEL_HASH && command -v parallel >/dev/null 2>&1; then
        # Parallel hashing safely
        printf '%s\0' "${files_to_hash[@]}" | \
        parallel -0 --no-notice sha256sum | while IFS= read -r line; do
            hash="${line%% *}"
            file="${line#* }"

            if [[ -n "${file_hashes[$hash]+_}" ]]; then
                existing="${file_hashes[$hash]}"
                best=$(pick_best "$file" "$existing")
                if [[ "$best" == "$file" ]]; then
                    duplicates+=("$existing")
                    duplicates_map["$existing"]=1
                    file_hashes[$hash]="$file"
                else
                    duplicates+=("$file")
                    duplicates_map["$file"]=1
                fi
            else
                file_hashes[$hash]="$file"
            fi

            hash_groups[$hash]+="$file"$'\n'
        done
    else
        # Single-thread fallback
        for file in "${files_to_hash[@]}"; do
            hash=$(sha256sum "$file" | awk '{print $1}')
            if [[ -n "${file_hashes[$hash]+_}" ]]; then
                existing="${file_hashes[$hash]}"
                best=$(pick_best "$file" "$existing")
                if [[ "$best" == "$file" ]]; then
                    duplicates+=("$existing")
                    duplicates_map["$existing"]=1
                    file_hashes[$hash]="$file"
                else
                    duplicates+=("$file")
                    duplicates_map["$file"]=1
                fi
            else
                file_hashes[$hash]="$file"
            fi
            hash_groups[$hash]+="$file"$'\n'
        done
    fi

    unset files_to_hash
    declare -a files_to_hash
done

# ----------------------------
# Step 3: Process duplicates
# ----------------------------
for file in "${duplicates[@]}"; do
    if [[ "$BACKUP" == true ]]; then
        backup_path="$BACKUP_DIR${file#$PAYLOAD_DIR}"
        mkdir -p "$(dirname "$backup_path")"
        cp "$file" "$backup_path"
        echo "[+] Backup: $file -> $backup_path" | tee -a "$LOG_FILE"
    fi

    if [[ "$DRY_RUN" == true ]]; then
        echo "[DRY RUN] Would delete: $file"
    else
        rm -f "$file"
        echo "[-] Deleted: $file" | tee -a "$LOG_FILE"
    fi
done

# ----------------------------
# Step 4: Summary
# ----------------------------
echo
echo "====================== Summary ======================" | tee -a "$LOG_FILE"

kept_count=0
deleted_count=0

for hash in "${!hash_groups[@]}"; do
    group="${hash_groups[$hash]}"
    total=0
    deleted_in_group=0

    while IFS= read -r f; do
        [[ -z "$f" ]] && continue
        ((total++))
        [[ -n "${duplicates_map[$f]+_}" ]] && ((deleted_in_group++))
    done <<< "$group"

    kept_in_group=$((total - deleted_in_group))
    ((deleted_count+=deleted_in_group))
    ((kept_count+=kept_in_group))

    echo "Group Hash: $hash" | tee -a "$LOG_FILE"
    echo -e "  Total   : $total" | tee -a "$LOG_FILE"
    echo -e "  Kept    : ${GREEN}$kept_in_group${NC}" | tee -a "$LOG_FILE"
    echo -e "  Deleted : ${RED}$deleted_in_group${NC}" | tee -a "$LOG_FILE"
    echo "-----------------------------------------------------" | tee -a "$LOG_FILE"
done

echo -e "Overall Kept   : ${GREEN}$kept_count${NC}" | tee -a "$LOG_FILE"
echo -e "Overall Deleted: ${RED}$deleted_count${NC}" | tee -a "$LOG_FILE"
echo "=====================================================" | tee -a "$LOG_FILE"

echo "[+] Done. Mode: $MODE" | tee -a "$LOG_FILE"
echo "[+] Backup directory: $BACKUP_DIR" | tee -a "$LOG_FILE"
