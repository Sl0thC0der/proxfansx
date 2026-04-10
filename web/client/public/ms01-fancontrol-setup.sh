#!/bin/bash

# ==========================================================
# MS-01 Fan Control Setup
# ==========================================================
# Author       : Community (ServeTheHome + pcfe.net)
# Subproject   : MS-01 FanControl (System Fan Management)
# License      : GPL-3.0
# Version      : 1.0
# Last Updated : 2025
# ==========================================================
# Description:
# This script installs and configures fancontrol for the
# Minisforum MS-01 running Proxmox VE or Debian.
#
# - Ensures the script is run with root privileges.
# - Installs required dependencies:
#     • lm-sensors (hardware monitoring)
#     • fancontrol (PWM fan speed control)
# - Loads and persists the nct6775 kernel module.
# - Writes /etc/sensors.d/ms-01.conf (suppress bogus readings).
# - Auto-detects hwmon device index for nct6798 chip.
# - Detects active PWM channels (fan1, fan2).
# - Writes /etc/fancontrol with community-verified quiet values.
# - Enables and starts the fancontrol systemd service.
#
# Notes:
# - The CPU blower fan is driven by an internal microcontroller
#   and is NOT controllable via this configuration.
# - Only pwm1/pwm2 (system/chassis fans) are managed.
# - Community-verified values: MINTEMP=60, MAXTEMP=80,
#   MINSTART=150, MINSTOP=30, MINPWM=0, MAXPWM=255
# ==========================================================

set -euo pipefail

# Configuration ============================================
FANCONTROL_CONF="/etc/fancontrol"
SENSORS_CONF="/etc/sensors.d/ms-01.conf"

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
    echo -e "\n${BOLD}${BL}${TAB}Installing MS-01 FanControl: Step $step of $total${CL}"
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
            "${BOLD}MS-01 FanControl${RESET}"
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
            "${BOLD}MS-01 FanControl${RESET}"
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

# ==========================================================

SPINNER_PID=""

# 1. Root check ============================================
if [[ $EUID -ne 0 ]]; then
    echo -e "${RD}[ERROR]${CL} This script must be run as root."
    echo    "        Try: sudo bash $0"
    exit 1
fi

# 2. Logo ==================================================
show_logo

# 3. Install dependencies ==================================
show_progress 1 6 "Installing lm-sensors and fancontrol"

msg_info "Updating package lists"
apt-get update -qq > /dev/null 2>&1
msg_ok "Package lists updated."

msg_info "Installing lm-sensors and fancontrol"
apt-get install -y lm-sensors fancontrol > /dev/null 2>&1
msg_ok "lm-sensors and fancontrol installed."

# 4. Load kernel module ====================================
show_progress 2 6 "Loading nct6775 kernel module"

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

# 5. Write sensors config ==================================
show_progress 3 6 "Writing sensor configuration"

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

# 6. Auto-detect hwmon device ==============================
show_progress 4 6 "Detecting hwmon device and PWM channels"

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

# 7. Write /etc/fancontrol =================================
show_progress 5 6 "Writing fancontrol configuration"

if [[ -f "$FANCONTROL_CONF" ]]; then
    cp "$FANCONTROL_CONF" "${FANCONTROL_CONF}.bak"
    msg_warn "Existing ${FANCONTROL_CONF} backed up to ${FANCONTROL_CONF}.bak"
fi

msg_info "Writing ${FANCONTROL_CONF}"
cat > "$FANCONTROL_CONF" <<FANCONTROL
# /etc/fancontrol
# Generated by proxfansx-setup.sh on $(date -Iseconds)
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

# 8. Enable and start service ==============================
show_progress 6 6 "Enabling and starting fancontrol service"

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
    journalctl -u fancontrol -n 20 --no-pager || true
    exit 1
fi

# 9. Summary ===============================================
echo -e "\n"
echo -e "${TAB}${BOLD}${HOLD}${BOR}MS-01 FanControl installed successfully!${BOR}${HOLD}${CL}"
echo -e "\n"

echo -e "${TAB}${BOLD}${WHITE}Useful commands:${RESET}"
echo -e "${TAB}  ${BL}watch -n2 sensors${CL}                               ${DARK_GRAY}# Live sensor monitor${RESET}"
echo -e "${TAB}  ${BL}systemctl status fancontrol${CL}                     ${DARK_GRAY}# Service status${RESET}"
echo -e "${TAB}  ${BL}journalctl -u fancontrol -f${CL}                     ${DARK_GRAY}# Live service logs${RESET}"
echo -e "${TAB}  ${BL}cat /etc/fancontrol${CL}                             ${DARK_GRAY}# View active config${RESET}"
echo -e "${TAB}  ${BL}cat /sys/class/hwmon/${HWMON_INDEX}/pwm1${CL}              ${DARK_GRAY}# Current PWM value (0–255)${RESET}"
echo -e "${TAB}  ${BL}cat /sys/class/hwmon/${HWMON_INDEX}/fan1_input${CL}        ${DARK_GRAY}# Current fan1 RPM${RESET}"
echo -e "${TAB}  ${BL}cat /sys/class/hwmon/${HWMON_INDEX}/temp2_input${CL}       ${DARK_GRAY}# CPUTIN in millidegrees${RESET}"
echo -e ""
echo -e "${TAB} ${YWB}NOTE:${CL} The CPU blower fan is NOT controlled by this script."
echo -e "${TAB} ${YWB}NOTE:${CL} Web dashboard available at: http://$(hostname -I | awk '{print $1}'):8010"
echo -e ""
