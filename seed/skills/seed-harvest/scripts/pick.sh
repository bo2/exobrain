#!/usr/bin/env bash
# pick.sh — checkbox menu over harvest candidates.
#
#   pick.sh <candidates-file>
#
# Each input line is TAB-separated: <id> <precheck 0|1> <label>. Blank lines and
# lines starting with '#' are section headers, shown but not selectable. Prints
# the selected ids to stdout, one per line.
#
# Reads keystrokes from /dev/tty so it works when stdout is captured; set
# SEED_HARVEST_INPUT=<file> to drive it from a script (the tests do this).
set -euo pipefail

CANDIDATES="${1:-}"
[[ -n "$CANDIDATES" && -f "$CANDIDATES" ]] || { echo "pick.sh: need a candidates file" >&2; exit 2; }

ids=() marks=() labels=() headers=()
while IFS=$'\t' read -r id pre label || [[ -n "${id:-}" ]]; do
    [[ -z "${id// }" ]] && continue
    case "$id" in
        \#*) headers+=("${#ids[@]}:${id#\#}"); continue ;;
    esac
    ids+=("$id")
    marks+=("$([[ "${pre:-0}" == 1 ]] && echo 1 || echo 0)")
    labels+=("${label:-$id}")
done < "$CANDIDATES"

[[ ${#ids[@]} -gt 0 ]] || { echo "pick.sh: no candidates" >&2; exit 3; }

if [[ -n "${SEED_HARVEST_INPUT:-}" ]]; then
    exec 3< "$SEED_HARVEST_INPUT"; out=/dev/stderr
else
    exec 3< /dev/tty; out=/dev/tty
fi

render() {
    local n=1 i h
    echo "" >"$out"
    echo "Harvest candidates (type a number to toggle, 'a' all, 'n' none, Enter to accept):" >"$out"
    for i in "${!ids[@]}"; do
        for h in ${headers[@]+"${headers[@]}"}; do
            [[ "${h%%:*}" == "$i" ]] && printf '\n  %s\n' "${h#*:}" >"$out"
        done
        printf '  %2d. [%s] %s\n' "$n" "$([[ "${marks[$i]}" == 1 ]] && echo x || echo ' ')" "${labels[$i]}" >"$out"
        n=$((n + 1))
    done
    printf 'Toggle # (Enter to accept): ' >"$out"
}

while true; do
    render
    read -r input <&3 || break
    case "$input" in
        "") break ;;
        a|A) for i in "${!marks[@]}"; do marks[$i]=1; done ;;
        n|N) for i in "${!marks[@]}"; do marks[$i]=0; done ;;
        q|Q) echo "  aborted" >"$out"; exit 4 ;;
        *)
            if [[ "$input" =~ ^[0-9]+$ ]] && (( input >= 1 && input <= ${#ids[@]} )); then
                i=$((input - 1)); marks[$i]=$(( 1 - marks[$i] ))
            else
                echo "  ? enter a listed number, 'a', 'n', 'q', or Enter to accept" >"$out"
            fi
            ;;
    esac
done

for i in "${!ids[@]}"; do
    [[ "${marks[$i]}" == 1 ]] && printf '%s\n' "${ids[$i]}"
done
exit 0
