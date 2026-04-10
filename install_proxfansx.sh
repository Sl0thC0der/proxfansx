#!/bin/bash

# ==========================================================
# ProxFansX — Fan Control Installer
# ==========================================================
# Author       : Community
# License      : GPL-3.0
# Version      : 2.0
# Last Updated : 2026
# ==========================================================
# Description:
# Universal fan control installer for mini PCs on Proxmox VE
# and Debian. Supports:
#   • Minisforum MS-01 (NCT6798 / nct6775 module)
#   • Any board with Nuvoton NCT67xx chip (nct6775 module)
#   • Any board with ITE IT87xx chip (it87 module)
#   • Generic detection for unknown boards
#   • Informational output for AMD UM/HX series (no hwmon PWM)
#
# One-line install:
#   bash -c "$(wget -qLO - https://raw.githubusercontent.com/Sl0thC0der/proxfansx/main/install_proxfansx.sh)"
# ==========================================================

set -euo pipefail

# Configuration ============================================
INSTALL_DIR="/usr/local/share/proxfansx"
FANCONTROL_CONF="/etc/fancontrol"
SENSORS_CONF_DIR="/etc/sensors.d"
CONFIG_FILE="$INSTALL_DIR/config.json"
LOCAL_VERSION_FILE="$INSTALL_DIR/version.txt"
SERVICE_FILE="/etc/systemd/system/proxfansx-web.service"
WEB_PORT=8010

REPO_URL="https://github.com/Sl0thC0der/proxfansx.git"
TEMP_DIR="/tmp/proxfansx-install-$$"

# Colors ===================================================
NEON_PURPLE_BLUE="\033[38;5;99m"
WHITE="\033[38;5;15m"
RESET="\033[0m"
DARK_GRAY="\033[38;5;244m"
ORANGE="\033[38;5;208m"
YW="\033[33m"
YWB="\033[1;33m"
GN="\033[1;92m"
RD="\033[01;31m"
CL="\033[m"
BL="\033[36m"
BOLD="\033[1m"
BFR="\\r\\033[K"
HOLD="-"
BOR=" | "
CM="${GN}✓ ${CL}"
TAB="    "

# Spinner ==================================================
spinner() {
    local frames=('⠋' '⠙' '⠹' '⠸' '⠼' '⠴' '⠦' '⠧' '⠇' '⠏')
    local spin_i=0
    local interval=0.1
    printf "\e[?25l"
    local color="${YW}"
    while true; do
        printf "\r ${color}%s${CL}" "${frames[spin_i]}"
        spin_i=$(( (spin_i + 1) % ${#frames[@]} ))
        sleep "$interval"
    done
}

# Messages =================================================
msg_info() {
    local msg="$1"
    echo -ne "${TAB}${YW}${HOLD}${msg}"
    spinner &
    SPINNER_PID=$!
}

msg_info2() {
    local msg="$1"
    echo -e "${TAB}${BOLD}${YW}${HOLD}${msg}${CL}"
}

msg_title() {
    local msg="$1"
    echo -e "\n"
    echo -e "${TAB}${BOLD}${HOLD}${BOR}${msg}${BOR}${HOLD}${CL}"
    echo -e "\n"
}

msg_warn() {
    if [ -n "${SPINNER_PID:-}" ] && ps -p $SPINNER_PID > /dev/null 2>&1; then
        kill $SPINNER_PID > /dev/null
    fi
    printf "\e[?25h"
    local msg="$1"
    echo -e "${BFR}${TAB}${CL} ${YWB}${msg}${CL}"
}

msg_ok() {
    if [ -n "${SPINNER_PID:-}" ] && ps -p $SPINNER_PID > /dev/null 2>&1; then
        kill $SPINNER_PID > /dev/null
    fi
    printf "\e[?25h"
    local msg="$1"
    echo -e "${BFR}${TAB}${CM}${GN}${msg}${CL}"
}

msg_error() {
    if [ -n "${SPINNER_PID:-}" ] && ps -p $SPINNER_PID > /dev/null 2>&1; then
        kill $SPINNER_PID > /dev/null
    fi
    printf "\e[?25h"
    local msg="$1"
    echo -e "${BFR}${TAB}${RD}[ERROR] ${msg}${CL}"
}

show_progress() {
    local step="$1"
    local total="$2"
    local message="$3"
    echo -e "\n${BOLD}${BL}${TAB}Installing ProxFansX: Step $step of $total${CL}"
    echo
    msg_info2 "$message"
}

# Logo =====================================================
show_logo() {
    clear

    if [[ -z "${SSH_TTY:-}" && -z "$(who am i 2>/dev/null | awk '{print $NF}' | grep -E '([0-9]{1,3}\.){3}[0-9]{1,3}')" ]]; then

        LOGO=$(cat << "EOF"
\e[0m\e[38;2;61;61;61m▆\e[38;2;60;60;60m▄\e[38;2;54;54;54m▂\e[0m \e[38;2;0;0;0m             \e[0m \e[38;2;54;54;54m▂\e[38;2;60;60;60m▄\e[38;2;61;61;61m▆\e[0m
\e[38;2;59;59;59;48;2;62;62;62m▏  \e[38;2;61;61;61;48;2;37;37;37m▇\e[0m\e[38;2;60;60;60m▅\e[38;2;56;56;56m▃\e[38;2;37;37;37m▁       \e[38;2;36;36;36m▁\e[38;2;56;56;56m▃\e[38;2;60;60;60m▅\e[38;2;61;61;61;48;2;37;37;37m▇\e[48;2;62;62;62m  \e[0m\e[7m\e[38;2;60;60;60m▁\e[0m
\e[38;2;59;59;59;48;2;62;62;62m▏  \e[0m\e[7m\e[38;2;61;61;61m▂\e[0m\e[38;2;62;62;62;48;2;61;61;61m┈\e[48;2;62;62;62m \e[48;2;61;61;61m┈\e[0m\e[38;2;60;60;60m▆\e[38;2;57;57;57m▄\e[38;2;48;48;48m▂\e[0m \e[38;2;47;47;47m▂\e[38;2;57;57;57m▄\e[38;2;60;60;60m▆\e[38;2;62;62;62;48;2;61;61;61m┈\e[48;2;62;62;62m \e[48;2;61;61;61m┈\e[0m\e[7m\e[38;2;60;60;60m▂\e[38;2;57;57;57m▄\e[38;2;47;47;47m▆\e[0m \e[0m
\e[38;2;59;59;59;48;2;62;62;62m▏  \e[0m\e[38;2;32;32;32m▏\e[7m\e[38;2;39;39;39m▇\e[38;2;57;57;57m▅\e[38;2;60;60;60m▃\e[0m\e[38;2;40;40;40;48;2;61;61;61m▁\e[48;2;62;62;62m  \e[38;2;54;54;54;48;2;61;61;61m┊\e[48;2;62;62;62m  \e[38;2;39;39;39;48;2;61;61;61m▁\e[0m\e[7m\e[38;2;60;60;60m▃\e[38;2;57;57;57m▅\e[38;2;38;38;38m▇\e[0m \e[38;2;193;60;2m▃\e[38;2;217;67;2m▅\e[38;2;225;70;2m▇\e[0m
\e[38;2;59;59;59;48;2;62;62;62m▏  \e[0m\e[38;2;32;32;32m▏\e[0m \e[38;2;203;63;2m▄\e[38;2;147;45;1m▂\e[0m \e[7m\e[38;2;55;55;55m▆\e[38;2;60;60;60m▄\e[38;2;61;61;61m▂\e[38;2;60;60;60m▄\e[38;2;55;55;55m▆\e[0m \e[38;2;144;44;1m▂\e[38;2;202;62;2m▄\e[38;2;219;68;2m▆\e[38;2;231;72;3;48;2;226;70;2m┈\e[48;2;231;72;3m  \e[48;2;225;70;2m▉\e[0m
\e[38;2;59;59;59;48;2;62;62;62m▏  \e[0m\e[38;2;32;32;32m▏\e[7m\e[38;2;121;37;1m▉\e[0m\e[38;2;0;0;0;48;2;231;72;3m  \e[0m\e[38;2;221;68;2m▇\e[38;2;208;64;2m▅\e[38;2;212;66;2m▂\e[38;2;123;37;0m▁\e[38;2;211;65;2m▂\e[38;2;207;64;2m▅\e[38;2;220;68;2m▇\e[48;2;231;72;3m  \e[38;2;231;72;3;48;2;225;70;2m┈\e[0m\e[7m\e[38;2;221;68;2m▂\e[0m\e[38;2;44;13;0;48;2;231;72;3m  \e[38;2;231;72;3;48;2;225;70;2m▉\e[0m
\e[38;2;59;59;59;48;2;62;62;62m▏  \e[0m\e[38;2;32;32;32m▏\e[0m \e[7m\e[38;2;190;59;2m▅\e[38;2;216;67;2m▃\e[38;2;225;70;2m▁\e[0m\e[38;2;95;29;0;48;2;231;72;3m  \e[38;2;231;72;3;48;2;230;71;2m┈\e[48;2;231;72;3m  \e[0m\e[7m\e[38;2;225;70;2m▁\e[38;2;216;67;2m▃\e[38;2;191;59;2m▅\e[0m  \e[38;2;0;0;0;48;2;231;72;3m  \e[38;2;231;72;3;48;2;225;70;2m▉\e[0m
\e[38;2;59;59;59;48;2;62;62;62m▏  \e[0m\e[38;2;32;32;32m▏   \e[0m \e[7m\e[38;2;172;53;1m▆\e[38;2;213;66;2m▄\e[38;2;219;68;2m▂\e[38;2;213;66;2m▄\e[38;2;174;54;2m▆\e[0m \e[38;2;0;0;0m   \e[0m \e[38;2;0;0;0;48;2;231;72;3m  \e[38;2;231;72;3;48;2;225;70;2m▉\e[0m
\e[38;2;59;59;59;48;2;62;62;62m▏  \e[0m\e[38;2;32;32;32m▏             \e[0m \e[38;2;0;0;0;48;2;231;72;3m  \e[38;2;231;72;3;48;2;225;70;2m▉\e[0m
\e[7m\e[38;2;52;52;52m▆\e[38;2;59;59;59m▄\e[38;2;61;61;61m▂\e[0m\e[38;2;31;31;31m▏             \e[0m \e[7m\e[38;2;228;71;2m▂\e[38;2;221;69;2m▄\e[38;2;196;60;2m▆\e[0m
EOF
)

        TEXT=(
            ""
            ""
            "${BOLD}ProxFansX${RESET}"
            ""
            "${BOLD}${NEON_PURPLE_BLUE}Universal fan control for${RESET}"
            "${BOLD}${NEON_PURPLE_BLUE}mini PCs on Proxmox VE${RESET}"
            ""
            ""
            ""
            ""
        )

        mapfile -t logo_lines <<< "$LOGO"
        for i in {0..9}; do
            echo -e "${TAB}${logo_lines[i]}  ${WHITE}│${RESET}  ${TEXT[i]}"
        done
        echo -e

    else

        TEXT=(
            ""
            ""
            ""
            ""
            "${BOLD}ProxFansX${RESET}"
            ""
            "${BOLD}${NEON_PURPLE_BLUE}Universal fan control for${RESET}"
            "${BOLD}${NEON_PURPLE_BLUE}mini PCs on Proxmox VE${RESET}"
            ""
            ""
            ""
            ""
            ""
            ""
        )

        LOGO=(
            "${DARK_GRAY}░░░░                     ░░░░${RESET}"
            "${DARK_GRAY}░░░░░░░               ░░░░░░ ${RESET}"
            "${DARK_GRAY}░░░░░░░░░░░       ░░░░░░░    ${RESET}"
            "${DARK_GRAY}░░░░    ░░░░░░ ░░░░░░      ${ORANGE}░░${RESET}"
            "${DARK_GRAY}░░░░       ░░░░░░░      ${ORANGE}░░▒▒▒${RESET}"
            "${DARK_GRAY}░░░░         ░░░     ${ORANGE}░▒▒▒▒▒▒▒${RESET}"
            "${DARK_GRAY}░░░░   ${ORANGE}▒▒▒░       ░▒▒▒▒▒▒▒▒▒▒${RESET}"
            "${DARK_GRAY}░░░░   ${ORANGE}░▒▒▒▒▒   ▒▒▒▒▒░░  ▒▒▒▒${RESET}"
            "${DARK_GRAY}░░░░     ${ORANGE}░░▒▒▒▒▒▒▒░░     ▒▒▒▒${RESET}"
            "${DARK_GRAY}░░░░         ${ORANGE}░░░         ▒▒▒▒${RESET}"
            "${DARK_GRAY}░░░░                     ${ORANGE}▒▒▒▒${RESET}"
            "${DARK_GRAY}░░░░                     ${ORANGE}▒▒▒░${RESET}"
            "${DARK_GRAY}  ░░                     ${ORANGE}░░  ${RESET}"
        )

        for i in {0..12}; do
            echo -e "${TAB}${LOGO[i]}  │${RESET}  ${TEXT[i]}"
        done
        echo -e
    fi
}

# Cleanup ==================================================
cleanup() {
    if [ -d "$TEMP_DIR" ]; then
        rm -rf "$TEMP_DIR"
    fi
}
trap cleanup EXIT

# Helpers ==================================================
get_server_ip() {
    local ip
    ip=$(ip route get 1.1.1.1 2>/dev/null | grep -oP 'src \K\S+')
    [ -z "$ip" ] && ip=$(hostname -I | awk '{print $1}')
    [ -z "$ip" ] && ip="localhost"
    echo "$ip"
}

stop_spinner() {
    if [ -n "${SPINNER_PID:-}" ] && ps -p $SPINNER_PID > /dev/null 2>&1; then
        kill $SPINNER_PID > /dev/null 2>&1 || true
    fi
    printf "\e[?25h"
}

# ==========================================================
# DEVICE DETECTION
# ==========================================================

detect_device() {
    # Returns: "ms01", "nct67xx", "ite87xx", "amd_no_pwm", "generic", "unsupported"
    local board_vendor board_name cpu_vendor chip_found

    board_vendor=$(cat /sys/class/dmi/id/board_vendor 2>/dev/null | tr '[:upper:]' '[:lower:]' || echo "")
    board_name=$(cat /sys/class/dmi/id/board_name 2>/dev/null | tr '[:upper:]' '[:lower:]' || echo "")
    local sys_vendor=$(cat /sys/class/dmi/id/sys_vendor 2>/dev/null | tr '[:upper:]' '[:lower:]' || echo "")
    local product_name=$(cat /sys/class/dmi/id/product_name 2>/dev/null | tr '[:upper:]' '[:lower:]' || echo "")

    # Detect CPU vendor
    cpu_vendor=$(grep -m1 'vendor_id' /proc/cpuinfo 2>/dev/null | awk '{print $3}' | tr '[:upper:]' '[:lower:]')

    # MS-01 specific detection
    if echo "$product_name $board_name $sys_vendor" | grep -qi "ms-01\|ms01"; then
        echo "ms01"
        return
    fi

    # AMD-based Minisforum UM/HX series — no hwmon PWM available
    if echo "$sys_vendor $board_vendor" | grep -qi "minisforum\|minisform\|MINIPC\|mini forum"; then
        if echo "$cpu_vendor" | grep -qi "authenticamd"; then
            echo "amd_no_pwm"
            return
        fi
    fi

    # Try to probe for NCT67xx chip
    if modprobe nct6775 2>/dev/null; then
        sleep 1
        for hwmon_dir in /sys/class/hwmon/hwmon*; do
            chip_name=$(cat "${hwmon_dir}/name" 2>/dev/null || echo "")
            if [[ "$chip_name" =~ ^(nct6775|nct6776|nct6779|nct6791|nct6792|nct6795|nct6796|nct6797|nct6798|nct6799)$ ]]; then
                echo "nct67xx"
                return
            fi
        done
    fi

    # Try to probe for ITE IT87xx chip
    if modprobe it87 2>/dev/null; then
        sleep 1
        for hwmon_dir in /sys/class/hwmon/hwmon*; do
            chip_name=$(cat "${hwmon_dir}/name" 2>/dev/null || echo "")
            if [[ "$chip_name" =~ ^it8 ]]; then
                echo "ite87xx"
                return
            fi
        done
    fi

    # AMD CPU with no detectable PWM chip
    if echo "$cpu_vendor" | grep -qi "authenticamd"; then
        echo "amd_no_pwm"
        return
    fi

    # Something is there but we didn't identify it — try generic
    local pwm_found=false
    for hwmon_dir in /sys/class/hwmon/hwmon*; do
        if ls "${hwmon_dir}"/pwm[0-9] > /dev/null 2>&1; then
            pwm_found=true
            break
        fi
    done

    if $pwm_found; then
        echo "generic"
    else
        echo "unsupported"
    fi
}

# ==========================================================
# FIND hwmon DEVICE BY CHIP FAMILY
# ==========================================================

find_hwmon_device() {
    local chip_family="$1"  # "nct67xx", "ite87xx", or "any"
    local hwmon_dir

    for hwmon_dir in /sys/class/hwmon/hwmon*; do
        [ -f "${hwmon_dir}/name" ] || continue
        local chip_name
        chip_name=$(cat "${hwmon_dir}/name" 2>/dev/null || echo "")

        case "$chip_family" in
            nct67xx)
                if [[ "$chip_name" =~ ^(nct6775|nct6776|nct6779|nct6791|nct6792|nct6795|nct6796|nct6797|nct6798|nct6799)$ ]]; then
                    echo "$hwmon_dir"
                    return 0
                fi
                ;;
            ite87xx)
                if [[ "$chip_name" =~ ^it8 ]]; then
                    echo "$hwmon_dir"
                    return 0
                fi
                ;;
            any)
                if ls "${hwmon_dir}"/pwm[0-9] > /dev/null 2>&1; then
                    echo "$hwmon_dir"
                    return 0
                fi
                ;;
        esac
    done
    return 1
}

# ==========================================================
# INSTALL: COMMON DEPENDENCIES
# ==========================================================

install_dependencies() {
    local total="$1" step="$2"
    show_progress $step $total "Installing basic dependencies"

    msg_info "Updating package lists"
    apt-get update -qq > /dev/null 2>&1
    msg_ok "Package lists updated."

    local DEPS=("lm-sensors" "fancontrol" "curl" "git")
    for pkg in "${DEPS[@]}"; do
        if ! dpkg -l | grep -qw "$pkg" 2>/dev/null; then
            msg_info "Installing ${pkg}"
            apt-get install -y "$pkg" > /dev/null 2>&1
            msg_ok "${pkg} installed."
        else
            msg_warn "${pkg} already installed."
        fi
    done

    # jq separately (may need GitHub fallback)
    if ! command -v jq > /dev/null 2>&1; then
        msg_info "Installing jq"
        if ! apt-get install -y jq > /dev/null 2>&1; then
            wget -q -O /usr/local/bin/jq \
                "https://github.com/jqlang/jq/releases/download/jq-1.7.1/jq-linux-amd64" \
                && chmod +x /usr/local/bin/jq
        fi
        msg_ok "jq installed."
    fi

    msg_ok "Dependencies ready."
}

# ==========================================================
# INSTALL: CLONE REPO
# ==========================================================

clone_repo() {
    local total="$1" step="$2"
    show_progress $step $total "Cloning ProxFansX repository"

    msg_info "Cloning repository"
    if ! git clone --depth 1 "$REPO_URL" "$TEMP_DIR" > /dev/null 2>&1; then
        msg_error "Failed to clone repository from $REPO_URL"
        exit 1
    fi
    msg_ok "Repository cloned."
    cd "$TEMP_DIR"
}

# ==========================================================
# INSTALL: FANCONTROL (NCT67xx / ITE87xx)
# ==========================================================

write_sensors_conf() {
    local chip_family="$1"
    local hwmon_path="$2"
    local chip_name
    chip_name=$(cat "${hwmon_path}/name" 2>/dev/null || echo "unknown")
    local conf_file="${SENSORS_CONF_DIR}/proxfansx.conf"

    mkdir -p "$SENSORS_CONF_DIR"

    case "$chip_family" in
        nct67xx)
            cat > "$conf_file" <<SENSORSCONF
# /etc/sensors.d/proxfansx.conf
# Generated by ProxFansX for ${chip_name}
# Suppresses bogus readings common on NCT67xx chips

chip "${chip_name}-*"

  # Suppress unused voltage rails
  ignore in0
  ignore in1
  ignore in2
  ignore in3
  ignore in4
  ignore in5
  ignore in6
  ignore in7
  ignore in8
  ignore in9
  ignore in10
  ignore in11
  ignore in12
  ignore in13
  ignore in14

  # Suppress unconnected fan headers
  ignore fan3
  ignore fan4
  ignore fan5
  ignore fan6
  ignore fan7

  # Suppress bogus/floating temperature channels
  ignore temp1
  ignore temp3
  ignore temp4
  ignore temp5
  ignore temp6
  ignore temp8
  ignore temp9
  ignore temp10

  # Suppress intrusion detection noise
  ignore intrusion0
  ignore intrusion1

  # Label the useful channels
  label temp2 "CPUTIN"
  label temp7 "CPU"
SENSORSCONF
            ;;
        ite87xx)
            cat > "$conf_file" <<SENSORSCONF
# /etc/sensors.d/proxfansx.conf
# Generated by ProxFansX for ${chip_name}

chip "${chip_name}-*"

  # Suppress unused voltage rails
  ignore in5
  ignore in6
  ignore in7

  # Suppress unconnected fan headers (keep what's active)
  ignore fan3
  ignore fan4
  ignore fan5

  # Suppress bogus temperatures
  ignore temp3
  ignore temp4

  # Label useful channels
  label temp1 "CPU"
  label temp2 "VRM"
SENSORSCONF
            ;;
    esac
}

build_fancontrol_config() {
    local hwmon_path="$1"
    local hwmon_index
    hwmon_index=$(basename "$hwmon_path")
    local chip_name
    chip_name=$(cat "${hwmon_path}/name" 2>/dev/null || echo "unknown")

    # Resolve DEVPATH
    local devpath
    devpath=$(realpath "${hwmon_path}/device" 2>/dev/null | sed 's|^/sys/||') || \
    devpath=$(realpath "${hwmon_path}" | sed 's|^/sys/||')

    local temp_sensor="${hwmon_index}/temp2_input"

    # Detect active fans (RPM > 100) for FCFANS
    local FCFANS_LIST=()
    for n in 1 2 3 4 5; do
        local fan_input="${hwmon_path}/fan${n}_input"
        local pwm_path="${hwmon_path}/pwm${n}"
        if [[ -f "$fan_input" && -f "$pwm_path" ]]; then
            local rpm
            rpm=$(cat "$fan_input" 2>/dev/null || echo "0")
            if [[ "$rpm" -gt 100 ]]; then
                FCFANS_LIST+=("${hwmon_index}/fan${n}_input")
            fi
        fi
    done

    local FCTEMPS_LIST=()
    local FCFANS_FINAL=()
    local PWMS_FINAL=()

    if [[ ${#FCFANS_LIST[@]} -eq 0 ]]; then
        # Fallback: use pwm1 + pwm2
        for n in 1 2; do
            if [[ -f "${hwmon_path}/pwm${n}" ]]; then
                PWMS_FINAL+=("${hwmon_index}/pwm${n}")
                FCTEMPS_LIST+=("${hwmon_index}/pwm${n}=${temp_sensor}")
                FCFANS_FINAL+=("${hwmon_index}/pwm${n}=${hwmon_index}/fan${n}_input")
            fi
        done
    else
        for fan_entry in "${FCFANS_LIST[@]}"; do
            local n
            n=$(echo "$fan_entry" | grep -oP 'fan\K[0-9]+')
            if [[ -f "${hwmon_path}/pwm${n}" ]]; then
                PWMS_FINAL+=("${hwmon_index}/pwm${n}")
                FCTEMPS_LIST+=("${hwmon_index}/pwm${n}=${temp_sensor}")
                FCFANS_FINAL+=("${hwmon_index}/pwm${n}=${hwmon_index}/fan${n}_input")
            fi
        done
    fi

    if [[ ${#PWMS_FINAL[@]} -eq 0 ]]; then
        msg_error "No PWM channels found. Cannot write fancontrol config."
        exit 1
    fi

    local FCTEMPS_STR="${FCTEMPS_LIST[*]}"
    local FCFANS_STR="${FCFANS_FINAL[*]}"
    local PWMS_STR="${PWMS_FINAL[*]}"

    [[ -f "$FANCONTROL_CONF" ]] && cp "$FANCONTROL_CONF" "${FANCONTROL_CONF}.bak" && \
        msg_warn "Existing /etc/fancontrol backed up to /etc/fancontrol.bak"

    cat > "$FANCONTROL_CONF" <<FANCONTROL
# /etc/fancontrol
# Generated by ProxFansX on $(date -Iseconds)
# Chip: ${chip_name} at ${hwmon_path}
# Fan curve: Quiet profile (fans off below 60°C, full speed at 80°C)
#
# NOTE: The CPU blower fan may be driven by an internal microcontroller
#       and may NOT be controllable via this config on some devices.
#       Only fans detected with RPM > 100 are managed here.

INTERVAL=10
DEVPATH=${hwmon_index}=${devpath}
DEVNAME=${hwmon_index}=${chip_name}
FCTEMPS=${FCTEMPS_STR}
FCFANS=${FCFANS_STR}
MINTEMP=${PWMS_STR// /=60 }=60
MAXTEMP=${PWMS_STR// /=80 }=80
MINSTART=${PWMS_STR// /=150 }=150
MINSTOP=${PWMS_STR// /=30 }=30
MINPWM=${PWMS_STR// /=0 }=0
MAXPWM=${PWMS_STR// /=255 }=255
FANCONTROL

    echo "${PWMS_FINAL[*]}"
}

start_fancontrol_service() {
    msg_info "Enabling fancontrol service"
    systemctl enable fancontrol > /dev/null 2>&1
    msg_ok "fancontrol service enabled."

    msg_info "Starting fancontrol service"
    systemctl restart fancontrol
    sleep 2

    if systemctl is-active --quiet fancontrol; then
        msg_ok "fancontrol is running."
    else
        msg_warn "fancontrol failed to start. Check: journalctl -u fancontrol -n 30"
    fi
}

# ==========================================================
# INSTALL: WEB DASHBOARD
# ==========================================================

install_dashboard() {
    local total="$1" step="$2"
    show_progress $step $total "Installing web dashboard"

    msg_info "Creating directories"
    mkdir -p "$INSTALL_DIR"
    [ ! -f "$CONFIG_FILE" ] && echo '{}' > "$CONFIG_FILE"
    msg_ok "Directories created."

    msg_info "Copying web dashboard files"
    if [ -d "$TEMP_DIR/dist" ]; then
        cp -r "$TEMP_DIR/dist/"* "$INSTALL_DIR/"
        msg_ok "Web dashboard files copied."
    else
        msg_warn "Pre-built dashboard not found in repo. Skipping dashboard install."
        return
    fi

    cp "$TEMP_DIR/version.txt" "$LOCAL_VERSION_FILE" 2>/dev/null || true
    cp "$TEMP_DIR/install_proxfansx.sh" "$INSTALL_DIR/install_proxfansx.sh" 2>/dev/null || true
    chmod +x "$INSTALL_DIR/install_proxfansx.sh" 2>/dev/null || true

    # Create systemd service
    if systemctl is-active --quiet proxfansx-web.service 2>/dev/null; then
        systemctl stop proxfansx-web.service 2>/dev/null || true
    fi

    if [ -f "$TEMP_DIR/systemd/proxfansx-web.service" ]; then
        cp "$TEMP_DIR/systemd/proxfansx-web.service" "$SERVICE_FILE"
    else
        cat > "$SERVICE_FILE" <<EOF
[Unit]
Description=ProxFansX - Web Dashboard
After=network.target fancontrol.service

[Service]
Type=simple
User=root
WorkingDirectory=$INSTALL_DIR
ExecStart=/usr/bin/node $INSTALL_DIR/index.cjs
Restart=on-failure
RestartSec=10
Environment="PORT=$WEB_PORT"
Environment="NODE_ENV=production"

[Install]
WantedBy=multi-user.target
EOF
    fi

    systemctl daemon-reload
    systemctl enable proxfansx-web.service > /dev/null 2>&1

    msg_info "Starting web dashboard"
    systemctl start proxfansx-web.service > /dev/null 2>&1
    sleep 3

    if systemctl is-active --quiet proxfansx-web.service; then
        msg_ok "Web dashboard started on port ${WEB_PORT}."
    else
        msg_warn "Dashboard failed to start. Check: journalctl -u proxfansx-web -n 20"
    fi
}

# ==========================================================
# WRITE: DEVICE PROFILE JSON (read by web dashboard)
# ==========================================================

# write_device_profile <family> <chip> <module> <device_name> <pwm_channels> <temp_sensor> <monitoring_only> [notes]
write_device_profile() {
    local family="$1"
    local chip="$2"
    local module="$3"
    local device_name="$4"
    local pwm_channels="$5"   # space-separated, e.g. "pwm1 pwm2"
    local temp_sensor="$6"
    local monitoring_only="$7" # "true" or "false"
    local notes="${8:-}"

    mkdir -p "$INSTALL_DIR"

    # Build JSON array from space-separated PWM list
    local pwm_json="["
    local first=1
    for ch in $pwm_channels; do
        [ $first -eq 0 ] && pwm_json+=","
        pwm_json+="\"$ch\""
        first=0
    done
    pwm_json+="]"

    cat > "$INSTALL_DIR/device.json" <<EOF
{
  "family": "$family",
  "chip": "$chip",
  "module": "$module",
  "device_name": "$device_name",
  "pwm_channels": $pwm_json,
  "temp_sensor": "$temp_sensor",
  "monitoring_only": $monitoring_only,
  "notes": "$notes"
}
EOF
    msg_ok "Device profile written."
}

# ==========================================================
# INSTALL: ITE IT87xx OUT-OF-TREE DRIVER (if needed)
# ==========================================================

maybe_install_it87_oot() {
    # Try standard in-kernel it87 first
    if modprobe it87 2>/dev/null; then
        sleep 1
        for hwmon_dir in /sys/class/hwmon/hwmon*; do
            local chip_name
            chip_name=$(cat "${hwmon_dir}/name" 2>/dev/null || echo "")
            if [[ "$chip_name" =~ ^it8 ]]; then
                msg_ok "ITE chip detected via in-kernel driver: ${chip_name}"
                return 0
            fi
        done
    fi

    # In-kernel driver didn't detect it — try out-of-tree with force_id
    msg_warn "In-kernel it87 driver did not detect chip. Trying force_id workarounds."

    if ! command -v dkms > /dev/null 2>&1; then
        apt-get install -y dkms > /dev/null 2>&1 || true
    fi

    modprobe it87 force_id=0x8628 2>/dev/null || true
    sleep 1

    for hwmon_dir in /sys/class/hwmon/hwmon*; do
        local chip_name
        chip_name=$(cat "${hwmon_dir}/name" 2>/dev/null || echo "")
        if [[ "$chip_name" =~ ^it8 ]]; then
            msg_ok "ITE chip detected with force_id: ${chip_name}"
            # Persist the force_id
            echo "options it87 force_id=0x8628" > /etc/modprobe.d/it87.conf
            return 0
        fi
    done

    return 1
}

# ==========================================================
# BRANCH: AMD — NO PWM AVAILABLE
# ==========================================================

install_amd_no_pwm() {
    local total=3

    show_progress 1 $total "Installing basic dependencies"
    install_dependencies $total 1

    show_progress 2 $total "Cloning repository"
    clone_repo $total 2

    show_progress 3 $total "Installing web dashboard (monitoring only)"
    install_dashboard $total 3

    # Detect AMD device model from DMI
    local AMD_DMI
    AMD_DMI=$(cat /sys/class/dmi/id/product_name 2>/dev/null || echo "AMD Device")
    write_device_profile "amd_no_pwm" "k10temp" "k10temp" "${AMD_DMI}" "" "tctl" "true" "No hwmon PWM on AMD SoC. Use ryzenadj for TDP control."

    local SERVER_IP
    SERVER_IP=$(get_server_ip)

    echo -e "\n"
    echo -e "${TAB}${BOLD}${HOLD}${BOR}ProxFansX installed — Monitoring Mode${BOR}${HOLD}${CL}"
    echo -e "\n"
    echo -e "${TAB} ${YWB}NOTE:${CL} Your device uses an AMD CPU with an embedded fan controller."
    echo -e "${TAB} ${YWB}NOTE:${CL} Fan PWM control is not available via Linux hwmon on this hardware."
    echo -e "${TAB} ${YWB}NOTE:${CL} Temperature monitoring is active via the k10temp module."
    echo -e ""
    echo -e "${TAB}${BOLD}${WHITE}Workaround options:${RESET}"
    echo -e "${TAB}  ${BL}ryzenadj --tctl-temp=85${CL}                    ${DARK_GRAY}# Limit TDP → reduce fan demand${RESET}"
    echo -e "${TAB}  ${BL}systemctl status proxfansx-web${CL}              ${DARK_GRAY}# Dashboard status${RESET}"
    echo -e ""
    echo -e "${TAB} ${YWB}Web dashboard:${CL} ${BOLD}${BL}http://${SERVER_IP}:${WEB_PORT}${CL}"
    echo -e ""
}

# ==========================================================
# BRANCH: UNSUPPORTED
# ==========================================================

install_unsupported() {
    local total=3

    install_dependencies $total 1
    clone_repo $total 2
    install_dashboard $total 3
    write_device_profile "unsupported" "unknown" "none" "Unknown Device" "" "" "true" "No compatible fan controller detected."

    local SERVER_IP
    SERVER_IP=$(get_server_ip)

    echo -e "\n"
    echo -e "${TAB}${BOLD}${HOLD}${BOR}ProxFansX installed — Limited Support${BOR}${HOLD}${CL}"
    echo -e "\n"
    echo -e "${TAB} ${YWB}NOTE:${CL} No PWM-capable hwmon chip was detected on this device."
    echo -e "${TAB} ${YWB}NOTE:${CL} Fan control via fancontrol is not possible."
    echo -e "${TAB} ${YWB}NOTE:${CL} The web dashboard is installed for sensor monitoring."
    echo -e ""
    echo -e "${TAB} ${YWB}Web dashboard:${CL} ${BOLD}${BL}http://${SERVER_IP}:${WEB_PORT}${CL}"
    echo -e ""
}

# ==========================================================
# BRANCH: NCT67xx (MS-01, generic Intel with NCT chip)
# ==========================================================

install_nct67xx() {
    local total=7

    show_progress 1 $total "Installing basic dependencies"
    install_dependencies $total 1

    show_progress 2 $total "Cloning ProxFansX repository"
    clone_repo $total 2

    show_progress 3 $total "Loading nct6775 kernel module"
    msg_info "Loading nct6775 module"
    if ! modprobe nct6775 2>/dev/null; then
        msg_error "Failed to load nct6775 module."
        exit 1
    fi
    sleep 2
    msg_ok "nct6775 module loaded."

    if ! grep -qxF 'nct6775' /etc/modules 2>/dev/null; then
        echo 'nct6775' >> /etc/modules
        msg_ok "nct6775 added to /etc/modules."
    else
        msg_warn "nct6775 already in /etc/modules."
    fi

    show_progress 4 $total "Detecting hardware and writing sensor config"

    local HWMON_PATH
    HWMON_PATH=$(find_hwmon_device "nct67xx") || {
        msg_error "NCT67xx chip not found after loading module."
        exit 1
    }
    local CHIP_NAME
    CHIP_NAME=$(cat "${HWMON_PATH}/name" 2>/dev/null)
    msg_ok "Detected ${CHIP_NAME} at ${HWMON_PATH}."

    # Resolve friendly device label from DMI product name
    local DMI_PRODUCT
    DMI_PRODUCT=$(cat /sys/class/dmi/id/product_name 2>/dev/null | tr '[:upper:]' '[:lower:]' || echo "")
    local DEVICE_LABEL
    if   [[ "$DMI_PRODUCT" == *"ms-01"* ]]; then DEVICE_LABEL="Minisforum MS-01"
    elif [[ "$DMI_PRODUCT" == *"ms01"* ]];  then DEVICE_LABEL="Minisforum MS-01"
    else DEVICE_LABEL="Generic NCT67xx Board"
    fi

    msg_info "Writing sensor configuration"
    write_sensors_conf "nct67xx" "$HWMON_PATH"
    msg_ok "Sensor config written."

    show_progress 5 $total "Writing fancontrol configuration"
    msg_info "Building fancontrol config"
    local pwm_channels
    pwm_channels=$(build_fancontrol_config "$HWMON_PATH")
    msg_ok "fancontrol config written. PWM channels: ${pwm_channels}"

    show_progress 6 $total "Starting fancontrol service"
    start_fancontrol_service

    show_progress 7 $total "Installing web dashboard"
    install_dashboard $total 7
    write_device_profile "nct67xx" "${CHIP_NAME:-nct6798}" "nct6775" "${DEVICE_LABEL:-Generic NCT67xx Board}" "${pwm_channels}" "temp2_input" "false" "CPU blower is not controllable on MS-01."

    local SERVER_IP
    SERVER_IP=$(get_server_ip)

    echo -e "\n"
    echo -e "${TAB}${BOLD}${HOLD}${BOR}ProxFansX installed successfully!${BOR}${HOLD}${CL}"
    echo -e "\n"
    echo -e "${TAB}${BOLD}${WHITE}Useful commands:${RESET}"
    echo -e "${TAB}  ${BL}watch -n2 sensors${CL}                          ${DARK_GRAY}# Live sensor monitor${RESET}"
    echo -e "${TAB}  ${BL}systemctl status fancontrol${CL}                ${DARK_GRAY}# Fan control service${RESET}"
    echo -e "${TAB}  ${BL}systemctl status proxfansx-web${CL}             ${DARK_GRAY}# Dashboard service${RESET}"
    echo -e "${TAB}  ${BL}journalctl -u fancontrol -f${CL}                ${DARK_GRAY}# Live fan control logs${RESET}"
    echo -e "${TAB}  ${BL}cat /etc/fancontrol${CL}                        ${DARK_GRAY}# Active config${RESET}"
    echo -e ""
    echo -e "${TAB} ${YWB}Web dashboard:${CL} ${BOLD}${BL}http://${SERVER_IP}:${WEB_PORT}${CL}"
    echo -e ""
}

# ==========================================================
# BRANCH: ITE IT87xx
# ==========================================================

install_ite87xx() {
    local total=7

    show_progress 1 $total "Installing basic dependencies"
    install_dependencies $total 1

    show_progress 2 $total "Cloning ProxFansX repository"
    clone_repo $total 2

    show_progress 3 $total "Loading ITE it87 kernel module"
    msg_info "Loading it87 module"

    if ! maybe_install_it87_oot; then
        msg_error "Could not load ITE it87 driver. Fan control not available."
        msg_warn "Your board may require acpi_enforce_resources=lax in GRUB kernel options."
        msg_warn "See: https://github.com/frankcrawford/it87"
        install_dashboard $total 7
        write_device_profile "ite87xx" "it87xx" "it87" "ITE IT87xx Board" "" "temp1_input" "true" "it87 driver failed to load. Fan control unavailable."
        return
    fi

    if ! grep -qxF 'it87' /etc/modules 2>/dev/null; then
        echo 'it87' >> /etc/modules
        msg_ok "it87 added to /etc/modules."
    fi

    show_progress 4 $total "Detecting hardware and writing sensor config"

    local HWMON_PATH
    HWMON_PATH=$(find_hwmon_device "ite87xx") || {
        msg_error "ITE chip not found after loading module."
        install_dashboard $total 7
        write_device_profile "ite87xx" "it87xx" "it87" "ITE IT87xx Board" "" "temp1_input" "true" "ITE chip not found in hwmon sysfs."
        return
    }
    local CHIP_NAME
    CHIP_NAME=$(cat "${HWMON_PATH}/name" 2>/dev/null)
    msg_ok "Detected ${CHIP_NAME} at ${HWMON_PATH}."

    # Resolve friendly device label from DMI product name
    local ITE_DMI_PRODUCT
    ITE_DMI_PRODUCT=$(cat /sys/class/dmi/id/product_name 2>/dev/null | tr '[:upper:]' '[:lower:]' || echo "")
    local ITE_DEVICE_LABEL
    if   [[ "$ITE_DMI_PRODUCT" == *"bd790"* ]]; then ITE_DEVICE_LABEL="Minisforum BD790i"
    elif [[ "$ITE_DMI_PRODUCT" == *"bd680"* ]]; then ITE_DEVICE_LABEL="Minisforum BD680i"
    else ITE_DEVICE_LABEL="ITE IT87xx Board"
    fi

    msg_info "Writing sensor configuration"
    write_sensors_conf "ite87xx" "$HWMON_PATH"
    msg_ok "Sensor config written."

    show_progress 5 $total "Writing fancontrol configuration"
    msg_info "Building fancontrol config"
    local pwm_channels
    pwm_channels=$(build_fancontrol_config "$HWMON_PATH")
    msg_ok "fancontrol config written. PWM channels: ${pwm_channels}"

    show_progress 6 $total "Starting fancontrol service"
    start_fancontrol_service

    show_progress 7 $total "Installing web dashboard"
    install_dashboard $total 7
    write_device_profile "ite87xx" "${CHIP_NAME:-it87xx}" "it87" "${ITE_DEVICE_LABEL:-ITE IT87xx Board}" "${pwm_channels}" "temp1_input" "false" "CPU fan header (pwm4) may not be controllable. Connect CPU cooler to SYS_FAN header."

    local SERVER_IP
    SERVER_IP=$(get_server_ip)

    echo -e "\n"
    echo -e "${TAB}${BOLD}${HOLD}${BOR}ProxFansX installed successfully!${BOR}${HOLD}${CL}"
    echo -e "\n"
    echo -e "${TAB} ${YWB}NOTE:${CL} ITE IT87xx chip detected. If CPU fan header is not controllable,"
    echo -e "${TAB} ${YWB}NOTE:${CL} connect it to a SYS_FAN header (known ITE limitation on some boards)."
    echo -e ""
    echo -e "${TAB}${BOLD}${WHITE}Useful commands:${RESET}"
    echo -e "${TAB}  ${BL}watch -n2 sensors${CL}                          ${DARK_GRAY}# Live sensor monitor${RESET}"
    echo -e "${TAB}  ${BL}systemctl status fancontrol${CL}                ${DARK_GRAY}# Fan control service${RESET}"
    echo -e "${TAB}  ${BL}systemctl status proxfansx-web${CL}             ${DARK_GRAY}# Dashboard service${RESET}"
    echo -e ""
    echo -e "${TAB} ${YWB}Web dashboard:${CL} ${BOLD}${BL}http://${SERVER_IP}:${WEB_PORT}${CL}"
    echo -e ""
}

# ==========================================================
# BRANCH: GENERIC (PWM found, unknown chip)
# ==========================================================

install_generic() {
    local total=6

    show_progress 1 $total "Installing basic dependencies"
    install_dependencies $total 1

    show_progress 2 $total "Cloning ProxFansX repository"
    clone_repo $total 2

    show_progress 3 $total "Detecting PWM hardware"
    local HWMON_PATH
    HWMON_PATH=$(find_hwmon_device "any") || {
        msg_error "No PWM-capable hwmon device found."
        install_unsupported
        return
    }
    local CHIP_NAME
    CHIP_NAME=$(cat "${HWMON_PATH}/name" 2>/dev/null || echo "unknown")
    msg_ok "Detected ${CHIP_NAME} at ${HWMON_PATH}."

    show_progress 4 $total "Writing fancontrol configuration"
    msg_info "Building fancontrol config"
    local pwm_channels
    pwm_channels=$(build_fancontrol_config "$HWMON_PATH")
    msg_ok "fancontrol config written. PWM channels: ${pwm_channels}"

    show_progress 5 $total "Starting fancontrol service"
    start_fancontrol_service

    show_progress 6 $total "Installing web dashboard"
    install_dashboard $total 6
    write_device_profile "generic" "${CHIP_NAME:-unknown}" "auto-detected" "Generic Device" "${pwm_channels}" "temp1_input" "false" "Generic PWM chip. Review /etc/fancontrol for your device."

    local SERVER_IP
    SERVER_IP=$(get_server_ip)

    echo -e "\n"
    echo -e "${TAB}${BOLD}${HOLD}${BOR}ProxFansX installed successfully!${BOR}${HOLD}${CL}"
    echo -e "\n"
    echo -e "${TAB} ${YWB}NOTE:${CL} Generic PWM chip detected (${CHIP_NAME})."
    echo -e "${TAB} ${YWB}NOTE:${CL} Review /etc/fancontrol and adjust MINTEMP/MAXTEMP/MINSTART for your device."
    echo -e ""
    echo -e "${TAB} ${YWB}Web dashboard:${CL} ${BOLD}${BL}http://${SERVER_IP}:${WEB_PORT}${CL}"
    echo -e ""
}

# ==========================================================
# MAIN
# ==========================================================

SPINNER_PID=""

# Root check
if [[ $EUID -ne 0 ]]; then
    echo -e "${RD}[ERROR]${CL} This script must be run as root."
    echo    "        Try: sudo bash $0"
    exit 1
fi

show_logo

# Detect device
echo -e "\n${BOLD}${BL}${TAB}Detecting hardware...${CL}\n"
DEVICE_TYPE=$(detect_device)

case "$DEVICE_TYPE" in
    ms01)
        msg_ok "Detected: Minisforum MS-01 (NCT6798 / nct6775 module)"
        install_nct67xx
        ;;
    nct67xx)
        local_chip=""
        for h in /sys/class/hwmon/hwmon*; do
            local_chip=$(cat "$h/name" 2>/dev/null || echo "")
            [[ "$local_chip" =~ ^nct ]] && break
        done
        msg_ok "Detected: Nuvoton ${local_chip:-NCT67xx} chip (nct6775 module)"
        install_nct67xx
        ;;
    ite87xx)
        msg_ok "Detected: ITE IT87xx chip (it87 module)"
        install_ite87xx
        ;;
    amd_no_pwm)
        msg_warn "Detected: AMD-based device — fan PWM not available via Linux hwmon"
        install_amd_no_pwm
        ;;
    generic)
        msg_warn "Detected: Unknown chip with PWM channels — using generic mode"
        install_generic
        ;;
    unsupported)
        msg_warn "Detected: No PWM-capable chip found — monitoring only"
        install_unsupported
        ;;
esac
