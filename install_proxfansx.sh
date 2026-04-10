#!/bin/bash

# ==========================================================
# ProxFansX - Installer
# ==========================================================
# Author       : Community (ServeTheHome + pcfe.net)
# Subproject   : ProxFansX Web Dashboard (port 8010)
# Copyright    : (c) 2025
# License      : GPL-3.0
# Version      : 1.0
# Last Updated : 2025
# ==========================================================
# Description:
# This script installs and configures ProxFansX, a
# fan speed management toolkit for Minisforum MS-01 running
# Proxmox VE or Debian.
#
# - Ensures the script is run with root privileges.
# - Displays an installation confirmation prompt.
# - Installs required dependencies:
#     • lm-sensors (hardware monitoring)
#     • fancontrol (PWM fan speed control)
#     • curl (downloads and connectivity checks)
#     • jq (JSON processing)
#     • git (repository cloning and updates)
#     • nodejs (web dashboard runtime)
# - Loads and persists the nct6775 kernel module.
# - Writes /etc/sensors.d/ms-01.conf (suppress bogus readings).
# - Auto-detects hwmon device index for nct6798 chip.
# - Detects active PWM channels (fan1, fan2).
# - Writes /etc/fancontrol with community-verified quiet values.
# - Enables and starts the fancontrol systemd service.
# - Copies web dashboard files into /usr/local/share/proxfansx.
# - Creates and starts proxfansx-web systemd service.
#
# Notes:
# - The CPU blower fan is driven by an internal microcontroller
#   and is NOT controllable via this configuration.
# - Only pwm1/pwm2 (system/chassis fans) are managed.
# - Web Dashboard runs on port 8010.
# ==========================================================

set -euo pipefail

# Configuration ============================================
INSTALL_DIR="/usr/local/share/proxfansx"
FANCONTROL_CONF="/etc/fancontrol"
SENSORS_CONF="/etc/sensors.d/ms-01.conf"
CONFIG_FILE="$INSTALL_DIR/config.json"
LOCAL_VERSION_FILE="$INSTALL_DIR/version.txt"
SERVICE_FILE="/etc/systemd/system/proxfansx-web.service"
WEB_PORT=8010

# Offline installer envs
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
DGN="\e[32m"
BGN="\e[1;32m"
DEF="\e[1;36m"
CUS="\e[38;5;214m"
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
            "${BOLD}${NEON_PURPLE_BLUE}Fan speed management for${RESET}"
            "${BOLD}${NEON_PURPLE_BLUE}Minisforum MS-01 / Proxmox VE${RESET}"
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
            "${BOLD}${NEON_PURPLE_BLUE}Fan speed management for${RESET}"
            "${BOLD}${NEON_PURPLE_BLUE}Minisforum MS-01 / Proxmox VE${RESET}"
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

# Get server IP ============================================
get_server_ip() {
    local ip
    ip=$(ip route get 1.1.1.1 2>/dev/null | grep -oP 'src \K\S+')
    if [ -z "$ip" ]; then
        ip=$(hostname -I | awk '{print $1}')
    fi
    if [ -z "$ip" ]; then
        ip="localhost"
    fi
    echo "$ip"
}

# ==========================================================
# MAIN
# ==========================================================

SPINNER_PID=""

# 1. Root check
if [[ $EUID -ne 0 ]]; then
    echo -e "${RD}[ERROR]${CL} This script must be run as root."
    echo    "        Try: sudo bash $0"
    exit 1
fi

# 2. Logo
show_logo

# ==========================================================
# Step 1: Install basic dependencies
# ==========================================================
total_steps=7
show_progress 1 $total_steps "Installing basic dependencies"

msg_info "Updating package lists"
apt-get update -qq > /dev/null 2>&1
msg_ok "Package lists updated."

if ! command -v jq > /dev/null 2>&1; then
    msg_info "Installing jq"
    if apt-get install -y jq > /dev/null 2>&1 && command -v jq > /dev/null 2>&1; then
        msg_ok "jq installed."
    else
        local jq_url="https://github.com/jqlang/jq/releases/download/jq-1.7.1/jq-linux-amd64"
        if wget -q -O /usr/local/bin/jq "$jq_url" 2>/dev/null && chmod +x /usr/local/bin/jq; then
            msg_ok "jq installed from GitHub."
        else
            msg_error "Failed to install jq. Please install it manually."
            exit 1
        fi
    fi
else
    msg_warn "jq already installed."
fi

BASIC_DEPS=("lm-sensors" "fancontrol" "curl" "git")
for pkg in "${BASIC_DEPS[@]}"; do
    if ! dpkg -l | grep -qw "$pkg" 2>/dev/null; then
        msg_info "Installing ${pkg}"
        if apt-get install -y "$pkg" > /dev/null 2>&1; then
            msg_ok "${pkg} installed."
        else
            msg_error "Failed to install $pkg. Please install it manually."
            exit 1
        fi
    else
        msg_warn "${pkg} already installed."
    fi
done

msg_ok "lm-sensors, fancontrol, curl, jq and git installed successfully."

# ==========================================================
# Step 2: Clone repository
# ==========================================================
show_progress 2 $total_steps "Cloning ProxFansX repository"

msg_info "Cloning repository"
if ! git clone --depth 1 "$REPO_URL" "$TEMP_DIR" 2>/dev/null; then
    msg_error "Failed to clone repository from $REPO_URL"
    exit 1
fi
msg_ok "Repository cloned successfully."

cd "$TEMP_DIR"

# ==========================================================
# Step 3: Load kernel module
# ==========================================================
show_progress 3 $total_steps "Loading nct6775 kernel module"

msg_info "Loading nct6775 module"
if ! modprobe nct6775 2>/dev/null; then
    msg_error "Failed to load nct6775 module. Is this an MS-01?"
    exit 1
fi
sleep 2
msg_ok "nct6775 module loaded."

if ! grep -qxF 'nct6775' /etc/modules 2>/dev/null; then
    echo 'nct6775' >> /etc/modules
    msg_ok "nct6775 added to /etc/modules (persists across reboots)."
else
    msg_warn "nct6775 already present in /etc/modules."
fi

# ==========================================================
# Step 4: Write sensor configuration + detect hwmon
# ==========================================================
show_progress 4 $total_steps "Writing sensor configuration and detecting hardware"

msg_info "Writing ${SENSORS_CONF}"
mkdir -p /etc/sensors.d
cat > "$SENSORS_CONF" <<'SENSORSCONF'
# /etc/sensors.d/ms-01.conf
# Suppress bogus readings from nct6798 on Minisforum MS-01
# Community-verified: ServeTheHome + pcfe.net

chip "nct6798-*" "nct6776-*" "nct6779-*" "nct6775-*"

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

  # Suppress irrelevant/bogus temperature channels
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

  # Label the channels we actually care about
  label temp2 "CPUTIN"
  label temp7 "PECI_Agent"
SENSORSCONF
msg_ok "Sensor configuration written."

msg_info "Scanning hwmon devices for nct67xx chip"

HWMON_PATH=""
HWMON_INDEX=""
CHIP_NAME=""

for hwmon_dir in /sys/class/hwmon/hwmon*; do
    if [[ ! -f "${hwmon_dir}/name" ]]; then
        continue
    fi
    chip_name=$(cat "${hwmon_dir}/name" 2>/dev/null || echo "")
    if [[ "$chip_name" =~ ^(nct6798|nct6775|nct6776|nct6779)$ ]]; then
        HWMON_PATH="$hwmon_dir"
        HWMON_INDEX=$(basename "$hwmon_dir")
        CHIP_NAME="$chip_name"
        break
    fi
done

if [[ -z "$HWMON_PATH" ]]; then
    msg_error "Could not find nct67xx hwmon device under /sys/class/hwmon/"
    msg_error "Make sure nct6775 module loaded successfully and this is an MS-01."
    exit 1
fi

msg_ok "Found ${CHIP_NAME} at ${HWMON_PATH}."

DEVPATH=$(realpath "${HWMON_PATH}/device" 2>/dev/null | sed 's|^/sys/||')
if [[ -z "$DEVPATH" ]]; then
    DEVPATH=$(realpath "${HWMON_PATH}" | sed 's|^/sys/||')
fi
DEVNAME="$CHIP_NAME"
TEMP_SENSOR="${HWMON_INDEX}/temp2_input"

# Detect active PWM channels
FCFANS_LIST=()
for n in 1 2 3 4 5; do
    fan_input="${HWMON_PATH}/fan${n}_input"
    pwm_path="${HWMON_PATH}/pwm${n}"
    if [[ -f "$fan_input" && -f "$pwm_path" ]]; then
        rpm=$(cat "$fan_input" 2>/dev/null || echo "0")
        if [[ "$rpm" -gt 100 ]]; then
            FCFANS_LIST+=("${HWMON_INDEX}/fan${n}_input")
        fi
    fi
done

FCTEMPS_LIST=()
FCFANS_FINAL=()
PWMS_FINAL=()

if [[ ${#FCFANS_LIST[@]} -eq 0 ]]; then
    msg_warn "No spinning fans detected. Falling back to pwm1 + pwm2 (system default)."
    for n in 1 2; do
        if [[ -f "${HWMON_PATH}/pwm${n}" ]]; then
            PWMS_FINAL+=("${HWMON_INDEX}/pwm${n}")
            FCTEMPS_LIST+=("${HWMON_INDEX}/pwm${n}=${TEMP_SENSOR}")
            FCFANS_FINAL+=("${HWMON_INDEX}/pwm${n}=${HWMON_INDEX}/fan${n}_input")
        fi
    done
else
    for fan_entry in "${FCFANS_LIST[@]}"; do
        n=$(echo "$fan_entry" | grep -oP 'fan\K[0-9]+')
        pwm_candidate="${HWMON_PATH}/pwm${n}"
        if [[ -f "$pwm_candidate" ]]; then
            PWMS_FINAL+=("${HWMON_INDEX}/pwm${n}")
            FCTEMPS_LIST+=("${HWMON_INDEX}/pwm${n}=${TEMP_SENSOR}")
            FCFANS_FINAL+=("${HWMON_INDEX}/pwm${n}=${HWMON_INDEX}/fan${n}_input")
        fi
    done
fi

if [[ ${#PWMS_FINAL[@]} -eq 0 ]]; then
    msg_error "No PWM channels found for ${HWMON_INDEX}. Cannot write fancontrol config."
    exit 1
fi

msg_ok "PWM channels detected: ${PWMS_FINAL[*]}."

FCTEMPS_STR="${FCTEMPS_LIST[*]}"
FCFANS_STR="${FCFANS_FINAL[*]}"
PWMS_STR="${PWMS_FINAL[*]}"

# ==========================================================
# Step 5: Write /etc/fancontrol
# ==========================================================
show_progress 5 $total_steps "Writing fancontrol configuration"

if [[ -f "$FANCONTROL_CONF" ]]; then
    cp "$FANCONTROL_CONF" "${FANCONTROL_CONF}.bak"
    msg_warn "Existing ${FANCONTROL_CONF} backed up to ${FANCONTROL_CONF}.bak"
fi

msg_info "Writing ${FANCONTROL_CONF}"
cat > "$FANCONTROL_CONF" <<FANCONTROL
# /etc/fancontrol
# Generated by proxfansx installer on $(date -Iseconds)
# Hardware: Minisforum MS-01 — nct6798 chip (loaded as ${DEVNAME})
# Fan curve: Quiet profile (ServeTheHome + pcfe.net community-tested)
#
# NOTE: The CPU blower fan is driven by an internal microcontroller
#       and is NOT controllable via this config. Only pwm1/pwm2
#       (system/chassis fans) are managed here.

INTERVAL=10
DEVPATH=${HWMON_INDEX}=${DEVPATH}
DEVNAME=${HWMON_INDEX}=${DEVNAME}
FCTEMPS=${FCTEMPS_STR}
FCFANS=${FCFANS_STR}
MINTEMP=${PWMS_STR// /=60 }=60
MAXTEMP=${PWMS_STR// /=80 }=80
MINSTART=${PWMS_STR// /=150 }=150
MINSTOP=${PWMS_STR// /=30 }=30
MINPWM=${PWMS_STR// /=0 }=0
MAXPWM=${PWMS_STR// /=255 }=255
FANCONTROL
msg_ok "${FANCONTROL_CONF} written."

# Enable and start fancontrol service
msg_info "Enabling fancontrol service"
systemctl enable fancontrol > /dev/null 2>&1
msg_ok "fancontrol service enabled."

msg_info "Starting fancontrol service"
systemctl restart fancontrol
sleep 2

if systemctl is-active --quiet fancontrol; then
    msg_ok "fancontrol service is running."
else
    msg_error "fancontrol service failed to start."
    msg_warn "Check logs with: journalctl -u fancontrol -n 30"
fi

# ==========================================================
# Step 6: Copy web dashboard files
# ==========================================================
show_progress 6 $total_steps "Installing web dashboard"

msg_info "Creating directories and copying files"

mkdir -p "$INSTALL_DIR"
mkdir -p "$INSTALL_DIR/scripts"

# Copy scripts
if [ -d "$TEMP_DIR/scripts" ]; then
    cp -r "$TEMP_DIR/scripts/"* "$INSTALL_DIR/scripts/"
    chmod -R +x "$INSTALL_DIR/scripts/"
fi

# Copy web dashboard (pre-built dist)
if [ -d "$TEMP_DIR/dist" ]; then
    cp -r "$TEMP_DIR/dist/"* "$INSTALL_DIR/"
    msg_ok "Web dashboard files copied."
else
    msg_warn "No pre-built dashboard found. Build from source with: cd web && npm install && npm run build"
fi

# Copy version + config
cp "$TEMP_DIR/version.txt" "$LOCAL_VERSION_FILE" 2>/dev/null || true
cp "$TEMP_DIR/install_ms01_fancontrol.sh" "$INSTALL_DIR/install_ms01_fancontrol.sh" 2>/dev/null || true
chmod +x "$INSTALL_DIR/install_ms01_fancontrol.sh" 2>/dev/null || true

if [ ! -f "$CONFIG_FILE" ]; then
    echo '{}' > "$CONFIG_FILE"
fi

msg_ok "Directories and files created."

# ==========================================================
# Step 7: Create and start web dashboard service
# ==========================================================
show_progress 7 $total_steps "Creating web dashboard service"

if systemctl is-active --quiet proxfansx-web.service 2>/dev/null; then
    msg_info "Stopping existing service"
    systemctl stop proxfansx-web.service
    msg_ok "Existing service stopped."
fi

if [ -f "$TEMP_DIR/systemd/proxfansx-web.service" ]; then
    cp "$TEMP_DIR/systemd/proxfansx-web.service" "$SERVICE_FILE"
    msg_ok "Using service file from repository."
else
    cat > "$SERVICE_FILE" << EOF
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
    msg_ok "Created default service file."
fi

systemctl daemon-reload
systemctl enable proxfansx-web.service > /dev/null 2>&1

msg_info "Starting web dashboard service"
systemctl start proxfansx-web.service > /dev/null 2>&1
sleep 3

if systemctl is-active --quiet proxfansx-web.service; then
    msg_ok "Web dashboard service started successfully."
else
    msg_warn "Web dashboard service failed to start."
    msg_warn "Check logs with: journalctl -u proxfansx-web -n 20"
fi

# ==========================================================
# Summary
# ==========================================================
SERVER_IP=$(get_server_ip)

echo -e "\n"
echo -e "${TAB}${BOLD}${HOLD}${BOR}ProxFansX installed successfully!${BOR}${HOLD}${CL}"
echo -e "\n"

echo -e "${TAB}${BOLD}${WHITE}Useful commands:${RESET}"
echo -e "${TAB}  ${BL}watch -n2 sensors${CL}                               ${DARK_GRAY}# Live sensor monitor${RESET}"
echo -e "${TAB}  ${BL}systemctl status fancontrol${CL}                     ${DARK_GRAY}# Service status${RESET}"
echo -e "${TAB}  ${BL}systemctl status proxfansx-web${CL}            ${DARK_GRAY}# Dashboard status${RESET}"
echo -e "${TAB}  ${BL}journalctl -u fancontrol -f${CL}                     ${DARK_GRAY}# Live service logs${RESET}"
echo -e "${TAB}  ${BL}cat /etc/fancontrol${CL}                             ${DARK_GRAY}# View active config${RESET}"
echo -e ""
echo -e "${TAB} ${YWB}NOTE:${CL} The CPU blower fan is NOT controlled by this script."
echo -e "${TAB} ${YWB}NOTE:${CL} Web dashboard available at: ${BOLD}${BL}http://${SERVER_IP}:${WEB_PORT}${CL}"
echo -e ""
