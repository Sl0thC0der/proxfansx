# ProxFansX

<p align="center">
  <strong>Fan speed management for Proxmox VE and Minisforum devices</strong>
</p>

<p align="center">
  <a href="#one-line-install">Install</a> •
  <a href="#device-compatibility">Compatibility</a> •
  <a href="#web-dashboard">Dashboard</a> •
  <a href="#presets">Presets</a> •
  <a href="#how-it-works">How It Works</a> •
  <a href="#commands">Commands</a>
</p>

---

## One-Line Install

Run this command on your Proxmox VE / Debian server:

```bash
bash -c "$(wget -qLO - https://raw.githubusercontent.com/Sl0thC0der/proxfansx/main/install_proxfansx.sh)"
```

The installer auto-detects your hardware and branches accordingly — no manual configuration needed.

---

## Device Compatibility

| Device | Chip | Module | PWM Control | Notes |
|--------|------|--------|-------------|-------|
| Minisforum MS-01 | NCT6798 | nct6775 | ✅ Full | CPU blower not controllable (MCU-driven) |
| Generic NCT67xx boards | NCT67xx | nct6775 | ✅ Full | All exposed PWM channels |
| Minisforum BD790i / BD680i | ITE IT87xx | it87 | ⚠️ Partial | CPU fan (pwm4) has no sysfs — use SYS_FAN header |
| Generic ITE IT87xx boards | ITE IT87xx | it87 | ⚠️ Partial | Out-of-tree driver may be required |
| Minisforum UM/HX series | AMD (k10temp) | k10temp | ❌ Monitoring only | No hwmon PWM on AMD SoC — use ryzenadj for TDP |
| Minisforum N5 Pro | ITE IT5571 (EC) | none | ❌ None | EC not a Super I/O — no kernel driver |
| Other / Unknown | Generic | auto | ⚠️ Best-effort | Installer scans available PWM channels |

---

## Installer Behavior

| Detected Chip | Branch | Outcome |
|---------------|--------|---------|
| NCT6798 on MS-01 | `nct67xx` | Full fancontrol + dashboard |
| Any NCT67xx | `nct67xx` | Full fancontrol + dashboard |
| ITE IT87xx | `ite87xx` | fancontrol (partial) + dashboard |
| AMD k10temp only | `amd_no_pwm` | Dashboard (monitoring only) |
| Unknown PWM found | `generic` | fancontrol (best-effort) + dashboard |
| No PWM at all | `unsupported` | Dashboard (monitoring only) |

---

## Web Dashboard

After installation, open your browser:

```
http://<YOUR-SERVER-IP>:8010
```

Dark dashboard with ProxMenux-style design:

- **Overview** — Live temperature, fan RPM, PWM duty, area charts, hardware details, device-specific warnings
- **Fan Curve** — Visual PWM vs temperature curve, edit parameters live
- **Presets** — Quiet / Silent / Balanced / Performance, import custom `/etc/fancontrol` files
- **Commands** — Copy-paste reference for monitoring and troubleshooting
- **Compatibility** — Full device support matrix

> On AMD and unsupported devices the dashboard runs in **monitoring-only mode** — Fan Curve, Presets, and Commands tabs are hidden automatically.

The dashboard runs as a systemd service (`proxfansx-web.service`) that starts automatically on boot.

---

## Presets

| Preset | MINTEMP | MAXTEMP | MINPWM | MAXPWM | MINSTART | MINSTOP | INTERVAL |
|--------|---------|---------|--------|--------|----------|---------|----------|
| **Quiet (Default)** | 60°C | 80°C | 0 | 255 | 150 | 30 | 10s |
| Silent | 65°C | 85°C | 0 | 200 | 150 | 30 | 10s |
| Balanced | 55°C | 75°C | 30 | 255 | 140 | 40 | 10s |
| Performance | 50°C | 70°C | 100 | 255 | 130 | 50 | 5s |

---

## How It Works

- **Auto-detection**: The installer scans hwmon devices and selects the matching install branch
- **Chip** (MS-01): Nuvoton `nct6798` loaded via `nct6775` kernel module
- **Controlled fans** (MS-01): `pwm1` + `pwm2` (system/chassis fans)
- **Temperature sensor** (MS-01): `temp2_input` (CPUTIN)
- **Fan curve**: Linear ramp from MINTEMP to MAXTEMP
- **device.json**: Written at install time — tells the dashboard which chip/family/mode was detected

> ⚠️ **MS-01 only**: The CPU blower fan is NOT controllable. It is driven by an internal microcontroller not exposed via nct6798 hwmon. Only the system/chassis fans on `pwm1` and `pwm2` respond to this configuration.

> ⚠️ **ITE IT87xx (BD series)**: The CPU fan header (pwm4) has no sysfs interface. Connect your CPU cooler to a SYS_FAN header to regain control. The out-of-tree `it87` driver may be required on some kernels.

> ℹ️ **AMD UM/HX devices**: No hwmon PWM. Dashboard installs in monitoring-only mode. Use `ryzenadj` for TDP limiting.

---

## Commands

```bash
# Live sensor monitor
watch -n2 sensors

# Service status
systemctl status fancontrol
systemctl status proxfansx-web

# Live logs
journalctl -u fancontrol -f

# View active config
cat /etc/fancontrol

# View detected device profile
cat /usr/local/share/proxfansx/device.json

# Re-run installer
bash -c "$(wget -qLO - https://raw.githubusercontent.com/Sl0thC0der/proxfansx/main/install_proxfansx.sh)"
```

---

## Uninstall

```bash
systemctl stop proxfansx-web
systemctl disable proxfansx-web
rm /etc/systemd/system/proxfansx-web.service
systemctl daemon-reload

systemctl stop fancontrol
rm /etc/fancontrol
rm /etc/sensors.d/proxfansx.conf
rm -rf /usr/local/share/proxfansx
```

---

## License

GPL-3.0 — See [LICENSE](LICENSE) for details.
