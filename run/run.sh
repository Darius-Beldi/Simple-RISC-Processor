#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)
PROJECT_ROOT=$(cd -- "$SCRIPT_DIR/.." && pwd)
BUILD_DIR="$SCRIPT_DIR/sim"
LOG_DIR="$SCRIPT_DIR/logs"
RTL_FILELIST="$PROJECT_ROOT/src/rtl/files.f"
TB_FILELIST="$PROJECT_ROOT/src/tb/files.f"
SNAPSHOT="sim_snapshot"
WDB="$BUILD_DIR/simulation.wdb"

MODE="batch"
TOP="top_tb"
SIM_TIME="all"
VIEW_ONLY=0
CLEAN_ONLY=0
PLUSARGS=()

usage() {
    cat <<'EOF'
Usage: run.sh [options] [-- +PLUSARG ...]

Options:
  --mode batch|gui  Run in batch mode (default) or launch a live GUI session
  --top MODULE      Testbench top module (default: top_tb)
  --time TIME       Batch duration, for example 10us; use "all" to run to $finish
  --view            Open the saved waveform database without recompiling
  --clean           Remove generated simulation artifacts
  -h, --help        Show this help
EOF
}

die() {
    printf 'ERROR: %s\n' "$*" >&2
    exit 1
}

need_value() {
    [[ $# -ge 2 ]] || die "option $1 requires a value"
}

while [[ $# -gt 0 ]]; do
    case "$1" in
        --mode)
            need_value "$@"
            MODE="$2"
            shift 2
            ;;
        --top)
            need_value "$@"
            TOP="$2"
            shift 2
            ;;
        --time)
            need_value "$@"
            SIM_TIME="$2"
            shift 2
            ;;
        --view)
            VIEW_ONLY=1
            shift
            ;;
        --clean)
            CLEAN_ONLY=1
            shift
            ;;
        -h|--help)
            usage
            exit 0
            ;;
        --)
            shift
            PLUSARGS+=("$@")
            break
            ;;
        +*)
            PLUSARGS+=("$1")
            shift
            ;;
        *)
            die "unknown argument: $1"
            ;;
    esac
done

[[ "$MODE" == "batch" || "$MODE" == "gui" ]] || \
    die "--mode must be either 'batch' or 'gui'"

if [[ $CLEAN_ONLY -eq 1 ]]; then
    # These paths are fixed children of run/; no user-provided path is removed.
    rm -rf -- "$BUILD_DIR" "$LOG_DIR" "$SCRIPT_DIR/.Xil"
    printf 'Removed generated simulation artifacts from %s\n' "$SCRIPT_DIR"
    exit 0
fi

command -v xsim >/dev/null 2>&1 || \
    die "xsim was not found; source the Vivado settings64.sh script first"

if [[ $VIEW_ONLY -eq 1 ]]; then
    [[ -f "$WDB" ]] || \
        die "saved waveform database not found: $WDB (run 'make sim' first)"
    cd -- "$BUILD_DIR"
    # XSim 2024.2 expects the WDB as the positional snapshot argument before
    # -gui. Putting -gui first can start an empty diskless project instead.
    exec xsim "$WDB" -gui
fi

command -v xvlog >/dev/null 2>&1 || \
    die "xvlog was not found; source the Vivado settings64.sh script first"
command -v xelab >/dev/null 2>&1 || \
    die "xelab was not found; source the Vivado settings64.sh script first"

[[ -f "$RTL_FILELIST" ]] || die "RTL file list not found: $RTL_FILELIST"
[[ -f "$TB_FILELIST" ]] || die "testbench file list not found: $TB_FILELIST"

# Always rebuild from only the files selected by the current branch's lists.
rm -rf -- "$BUILD_DIR"
mkdir -p -- "$BUILD_DIR" "$LOG_DIR"

SOURCES=()
XVLOG_FILE_OPTIONS=()

trim() {
    local value="$1"
    value="${value#"${value%%[![:space:]]*}"}"
    value="${value%"${value##*[![:space:]]}"}"
    printf '%s' "$value"
}

resolve_source() {
    local entry="$1"
    local list_dir="$2"
    local candidate

    if [[ "$entry" == /* ]]; then
        candidate="$entry"
    elif [[ -e "$PROJECT_ROOT/$entry" ]]; then
        candidate="$PROJECT_ROOT/$entry"
    elif [[ -e "$list_dir/$entry" ]]; then
        # Also accept paths relative to the file list for small local lists.
        candidate="$list_dir/$entry"
    else
        die "source '$entry' from a file list does not exist (paths are normally relative to $PROJECT_ROOT)"
    fi

    printf '%s' "$candidate"
}

read_filelist() {
    local filelist="$1"
    local list_dir
    local line
    local payload
    local item
    local resolved
    local -a items

    list_dir=$(dirname -- "$filelist")
    while IFS= read -r line || [[ -n "$line" ]]; do
        line="${line%$'\r'}"
        line=$(trim "$line")
        [[ -z "$line" || "$line" == \#* || "$line" == //* ]] && continue

        case "$line" in
            +incdir+*)
                payload="${line#+incdir+}"
                IFS='+' read -r -a items <<< "$payload"
                for item in "${items[@]}"; do
                    [[ -n "$item" ]] || continue
                    resolved=$(resolve_source "$item" "$list_dir")
                    [[ -d "$resolved" ]] || die "include path is not a directory: $item"
                    XVLOG_FILE_OPTIONS+=(-i "$resolved")
                done
                ;;
            +define+*)
                payload="${line#+define+}"
                IFS='+' read -r -a items <<< "$payload"
                for item in "${items[@]}"; do
                    [[ -n "$item" ]] && XVLOG_FILE_OPTIONS+=(-d "$item")
                done
                ;;
            -*)
                # Keep standard xvlog options usable in simple file lists.
                read -r -a items <<< "$line"
                XVLOG_FILE_OPTIONS+=("${items[@]}")
                ;;
            *)
                SOURCES+=("$(resolve_source "$line" "$list_dir")")
                ;;
        esac
    done < "$filelist"
}

# Compilation order is intentional: design sources before testbench sources.
read_filelist "$RTL_FILELIST"
read_filelist "$TB_FILELIST"
[[ ${#SOURCES[@]} -gt 0 ]] || \
    die "no sources were listed in src/rtl/files.f or src/tb/files.f"

run_logged() {
    local log_file="$1"
    shift
    printf 'Running:'
    printf ' %q' "$@"
    printf '\n'
    "$@" 2>&1 | tee "$log_file"
}

cd -- "$BUILD_DIR"

run_logged "$LOG_DIR/xvlog.log" \
    xvlog -sv "${XVLOG_FILE_OPTIONS[@]}" "${SOURCES[@]}"

run_logged "$LOG_DIR/xelab.log" \
    xelab "work.$TOP" -snapshot "$SNAPSHOT" -debug typical \
    -timescale 1ns/1ps

XSIM_ARGS=(xsim "$SNAPSHOT" -wdb "$WDB")
for item in "${PLUSARGS[@]}"; do
    [[ "$item" == +* ]] || die "simulation argument must start with '+': $item"
    XSIM_ARGS+=(-testplusarg "$item")
done

if [[ "$MODE" == "gui" ]]; then
    XSIM_ARGS+=(-gui)
else
    export SIM_TIME
    XSIM_ARGS+=(-tclbatch "$SCRIPT_DIR/xsim_batch.tcl")
fi

run_logged "$LOG_DIR/xsim.log" "${XSIM_ARGS[@]}"

printf 'Waveform database: %s\n' "$WDB"
