#!/bin/sh
set -eu

repo=$(CDPATH='' cd -- "$(dirname "$0")/../.." && pwd)
tmp=$(mktemp -d)
trap 'rm -rf "$tmp"' EXIT HUP INT TERM
mkdir "$tmp/bin" "$tmp/jobs"
export LOG="$tmp/log" PATH="$tmp/bin:$PATH"

cat > "$tmp/bin/squeue" <<'EOF'
#!/bin/sh
printf 'squeue' >> "$LOG"
printf ' <%s>' "$@" >> "$LOG"
printf '\n' >> "$LOG"
printf '%s' "${QUEUE_OUTPUT:-}"
exit "${QUEUE_STATUS:-0}"
EOF
cat > "$tmp/bin/scancel" <<'EOF'
#!/bin/sh
printf 'scancel' >> "$LOG"
printf ' <%s>' "$@" >> "$LOG"
printf '\n' >> "$LOG"
[ "${2:-}" != "${FAIL_CANCEL:-never}" ]
EOF
cat > "$tmp/bin/sbatch" <<'EOF'
#!/bin/sh
printf 'sbatch <%s>\n' "$1" >> "$LOG"
[ "$1" != "${FAIL_SUBMIT:-never}" ]
EOF
cat > "$tmp/bin/sleep" <<'EOF'
#!/bin/sh
printf 'sleep <%s>\n' "$1" >> "$LOG"
EOF
chmod +x "$tmp/bin/"*

cancel() { sh "$repo/home/dot_local/bin/executable_slurm-cancel" "$@"; }
submit() { sh "$repo/home/dot_local/bin/executable_sbatchall"; }
check_log() {
    printf '%s\n' "$1" > "$tmp/expected"
    if ! cmp -s "$tmp/expected" "$LOG"; then
        printf 'Unexpected command log:\n' >&2
        diff -u "$tmp/expected" "$LOG" >&2 || :
        exit 1
    fi
}

: > "$LOG"
QUEUE_OUTPUT='12
34
'; export QUEUE_OUTPUT
output=$(cancel)
[ "$output" = "$(printf '12\n34')" ]
check_log "$(printf 'squeue <--me> <-h> <-o> <%%i>\nscancel <--quiet> <12>\nscancel <--quiet> <34>')"

: > "$LOG"
cancel --name 'demo job; echo unexpected' > /dev/null
check_log "$(printf 'squeue <--me> <-h> <-o> <%%i> <-n> <demo job; echo unexpected>\nscancel <--quiet> <12>\nscancel <--quiet> <34>')"

: > "$LOG"
cancel -r 8 10 > /dev/null
check_log "$(printf 'scancel <--quiet> <8>\nscancel <--quiet> <9>\nscancel <--quiet> <10>')"

: > "$LOG"
cancel --range 008 010 > /dev/null
check_log "$(printf 'scancel <--quiet> <8>\nscancel <--quiet> <9>\nscancel <--quiet> <10>')"

: > "$LOG"
FAIL_CANCEL=9; export FAIL_CANCEL
if cancel -r 8 10 > /dev/null; then
    printf 'Failed cancellation unexpectedly succeeded\n' >&2
    exit 1
fi
unset FAIL_CANCEL
check_log "$(printf 'scancel <--quiet> <8>\nscancel <--quiet> <9>\nscancel <--quiet> <10>')"

: > "$LOG"
QUEUE_STATUS=1; export QUEUE_STATUS
if cancel > /dev/null 2>&1; then
    printf 'Failed query unexpectedly succeeded\n' >&2
    exit 1
fi
check_log 'squeue <--me> <-h> <-o> <%i>'
unset QUEUE_STATUS

: > "$LOG"
QUEUE_OUTPUT=; export QUEUE_OUTPUT
cancel > /dev/null
check_log 'squeue <--me> <-h> <-o> <%i>'

: > "$LOG"
if cancel -r 1 '2;echo unexpected' > /dev/null 2>&1; then
    printf 'Invalid range unexpectedly succeeded\n' >&2
    exit 1
fi
[ ! -s "$LOG" ]

: > "$LOG"
if cancel --name '' > /dev/null 2>&1; then
    printf 'Empty job name unexpectedly succeeded\n' >&2
    exit 1
fi
[ ! -s "$LOG" ]

cd "$tmp/jobs"
touch slurm_1.sh slurm_2.sh slurm_4.sh
: > "$LOG"
submit
check_log "$(printf 'sbatch <slurm_1.sh>\nsleep <1>\nsbatch <slurm_2.sh>\nsleep <1>')"

: > "$LOG"
FAIL_SUBMIT=slurm_2.sh; export FAIL_SUBMIT
if submit > /dev/null 2>&1; then
    printf 'Failed submission unexpectedly succeeded\n' >&2
    exit 1
fi
check_log "$(printf 'sbatch <slurm_1.sh>\nsleep <1>\nsbatch <slurm_2.sh>')"

printf 'Slurm helper tests passed\n'
