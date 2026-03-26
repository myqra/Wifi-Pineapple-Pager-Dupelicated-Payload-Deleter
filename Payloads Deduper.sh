#!/bin/bash
# Title: Ultimate Payload Deduper
# Description: Detects AND safely removes duplicate payloads from your WiFi Pineapple Pager
# Author: ChatGPT

PAYLOAD_DIR="/root/payloads"
BACKUP_DIR="/root/payload_backup_$(date +%s)"

mkdir -p "$BACKUP_DIR"

echo "=== Ultimate Payload Deduper ==="
echo

declare -A signatures

# Function to generate a "signature" of a payload
get_signature() {
    local dir="$1"
    # Extract important commands only (add more as needed)
    grep -rhoE "aireplay-ng|airodump-ng|hcxdumptool|mdk4|tcpdump" "$dir" 2>/dev/null | sort | uniq | tr '\n' ' '
}

# Scan payloads
for payload in "$PAYLOAD_DIR"/*; do
    [ -d "$payload" ] || continue
    sig=$(get_signature "$payload")
    if [ -z "$sig" ]; then
        sig="unique_$(basename "$payload")"
    fi
    signatures["$sig"]+="$payload "
done

echo "=== Potential Duplicate Groups ==="
echo

group_id=1
declare -A groups

for sig in "${!signatures[@]}"; do
    payloads=${signatures[$sig]}
    count=$(echo "$payloads" | wc -w)
    if [ "$count" -gt 1 ]; then
        echo "Group $group_id:"
        echo "Signature: $sig"
        echo "$payloads"
        echo
        groups[$group_id]="$payloads"
        ((group_id++))
    fi
done

if [ ${#groups[@]} -eq 0 ]; then
    echo "No duplicates found."
    exit 0
fi

echo "=== Deletion Phase ==="
echo "A backup will be created at: $BACKUP_DIR"
echo

for id in "${!groups[@]}"; do
    echo "Group $id:"
    payloads=(${groups[$id]})
    i=1
    for p in "${payloads[@]}"; do
        echo "[$i] $p"
        ((i++))
    done
    echo
    read -p "Select payload number to KEEP (or press Enter to skip): " keep
    if [[ "$keep" =~ ^[0-9]+$ ]] && [ "$keep" -ge 1 ] && [ "$keep" -le "${#payloads[@]}" ]; then
        keep_index=$((keep-1))
        for i in "${!payloads[@]}"; do
            if [ "$i" -ne "$keep_index" ]; then
                p="${payloads[$i]}"
                echo "Backing up and removing: $p"
                mv "$p" "$BACKUP_DIR/"
            fi
        done
    else
        echo "Skipping group $id"
    fi
    echo
done

echo "=== Done ==="
echo "Backups stored in: $BACKUP_DIR"




121 barrels
118 flower pots 108 dead horn coral fan
110 spruce signs
107 bamboo
57 white carpet
142 lanterns
118 bookshelfs
95 oak leaves
83 oak trapdoor
41 light gray carpet
46 smooth quartyz stairs
38 decorated pots
36 gray wool
35 poppys
35 red carpet
27 dead buysh
25 oak sign
27 spruce fence gate17 
smooth quartz blocvk
 17 warped stairs 
16 mangrove wood
15 flowering azalea leaves
14 anvils
13 brewiong stands 
13 brown carpet
11 sea pickl;e 
11 dark prismarine slabs
10 dark oak signs