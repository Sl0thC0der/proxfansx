# ProxFansX

<p align="center">
  <strong>Fan speed management for Minisforum MS-01 / Proxmox VE</strong>
</p>

<p align="center">
  <a href="#one-line-install">Install</a> •
  <a href="#web-dashboard">Dashboard</a> •
  <a href="#presets">Presets</a> •
  <a href="#how-it-works">How It Works</a> •
  <a href="#commands">Commands</a>
</p>

---

## One-Line Install

Run this command on your Proxmox VE / Debian server:

```bash
bash -c "$(wget -qLO - https://raw.githubusercontent.com/Sl0thC0der/proxfansx/main/install_ms01_fancontrol.sh)"
```

The installer will:

| Step | Action |
|------|--------|
| 1 | Install dependencies (`lm-sensors`, `fancontrol`, `curl`, `jq`, `git`) |
| 2 | Clone this repository |
| 3 | Load `nct6775` kernel module and persist across reboots |
| 4 | Write `/etc/sensors.d/ms-01.conf` (suppress bogus readings) |
| 5 | Auto-detect hwmon device and active PWM channels |
| 6 | Write `/etc/fancontrol` with community-verified quiet curve |
| 7 | Install and start the web dashboard on port **8010** |

## Web Dashboard

After installation, open your browser:

```
http://<YOUR-SERVER-IP>:8010
```

Modern dark dashboard with:

- **Overview** — Live CPUTIN temperature, fan RPM, PWM duty, area charts
- **Fan Curve** — Visual PWM vs temperature curve, edit parameters live
- **Presets** — Quiet / Silent / Balanced / Performance, import custom `/etc/fancontrol` files
- **Commands** — Copy-paste reference for monitoring and troubleshooting

The dashboard runs as a systemd service (`proxfansx-web.service`) that starts automatically on boot.

## Presets

| Preset | MINTEMP | MAXTEMP | MINPWM | MAXPWM | MINSTART | MINSTOP | INTERVAL |
|--------|---------|---------|--------|--------|----------|---------|----------|
| **Quiet (Default)** | 60°C | 80°C | 0 | 255 | 150 | 30 | 10s |
| Silent | 65°C | 85°C | 0 | 200 | 150 | 30 | 10s |
| Balanced | 55°C | 75°C | 30 | 255 | 140 | 40 | 10s |
| Performance | 50°C | 70°C | 100 | 255 | 130 | 50 | 5s |

Community-verified values from [ServeTheHome](https://www.servethehome.com/) and [pcfe.net](https://pcfe.net/).

## How It Works

- **Chip**: Nuvoton `nct6798` (loaded via `nct6775` kernel module)
- **Controlled fans**: `pwm1` + `pwm2` (system/chassis fans)
- **Temperature sensor**: `temp2_input` (CPUTIN)
- **Fan curve**: Linear ramp from MINTEMP to MAXTEMP

> ⚠️ **The CPU blower fan is NOT controllable.** It is driven by an internal microcontroller and is not exposed via the nct6798 hwmon interface. Only the system/chassis fans on `pwm1` and `pwm2` respond to this configuration.

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

# Re-run installer (after kernel update)
bash -c "$(wget -qLO - https://raw.githubusercontent.com/Sl0thC0der/proxfansx/main/install_ms01_fancontrol.sh)"
```

## Uninstall

```bash
systemctl stop proxfansx-web
systemctl disable proxfansx-web
rm /etc/systemd/system/proxfansx-web.service
systemctl daemon-reload

systemctl stop fancontrol
rm /etc/fancontrol
rm /etc/sensors.d/ms-01.conf
rm -rf /usr/local/share/proxfansx
```

## License

GPL-3.0 — See [LICENSE](LICENSE) for details.
