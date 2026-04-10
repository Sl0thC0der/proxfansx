import { CheckCircle, XCircle, AlertTriangle, Info, ExternalLink } from "lucide-react";

type SupportLevel = "full" | "partial" | "monitoring" | "none" | "unknown";

interface DeviceEntry {
  device: string;
  chipFamily: string;
  module: string;
  pwmSupport: SupportLevel;
  tempSupport: SupportLevel;
  fans: string;
  notes: string;
}

const DEVICES: DeviceEntry[] = [
  {
    device: "Minisforum MS-01",
    chipFamily: "Nuvoton NCT6798",
    module: "nct6775",
    pwmSupport: "full",
    tempSupport: "full",
    fans: "pwm1, pwm2 (system fans)",
    notes: "CPU blower is not controllable — it is driven by an internal MCU.",
  },
  {
    device: "Generic NCT67xx boards",
    chipFamily: "Nuvoton NCT67xx",
    module: "nct6775",
    pwmSupport: "full",
    tempSupport: "full",
    fans: "All exposed PWM channels",
    notes: "Auto-detected. Fan channel count varies by board.",
  },
  {
    device: "Minisforum BD series (BD790i, BD680i…)",
    chipFamily: "ITE IT87xx",
    module: "it87",
    pwmSupport: "partial",
    tempSupport: "full",
    fans: "SYS_FAN headers only",
    notes: "CPU fan (pwm4) has no sysfs data — plug CPU cooler into SYS_FAN to regain control.",
  },
  {
    device: "Generic ITE IT87xx boards",
    chipFamily: "ITE IT87xx",
    module: "it87",
    pwmSupport: "partial",
    tempSupport: "full",
    fans: "Most PWM headers",
    notes: "Out-of-tree it87 driver may be required on some kernels.",
  },
  {
    device: "Minisforum UM/HX series (UM580, UM790 Pro, HX200G…)",
    chipFamily: "AMD (no Super I/O)",
    module: "k10temp",
    pwmSupport: "none",
    tempSupport: "full",
    fans: "None",
    notes: "No hwmon PWM on AMD SoC platforms. Dashboard runs in monitoring-only mode. Use ryzenadj for TDP control.",
  },
  {
    device: "Minisforum N5 Pro",
    chipFamily: "ITE IT5571 (Embedded Controller)",
    module: "none",
    pwmSupport: "none",
    tempSupport: "none",
    fans: "None",
    notes: "ITE IT5571 is an EC, not a Super I/O. No kernel driver or sysfs interface available.",
  },
  {
    device: "Other / Unknown",
    chipFamily: "Generic",
    module: "auto-detected",
    pwmSupport: "unknown",
    tempSupport: "unknown",
    fans: "Auto-detected",
    notes: "Installer scans available hwmon PWM channels and creates a best-effort configuration.",
  },
];

function SupportBadge({ level }: { level: SupportLevel }) {
  const cfg: Record<SupportLevel, { icon: React.ReactNode; label: string; bg: string; fg: string; border: string }> = {
    full: {
      icon: <CheckCircle size={11} />,
      label: "Full",
      bg: "#0d2a1a", fg: "#4ade80", border: "#14532d",
    },
    partial: {
      icon: <AlertTriangle size={11} />,
      label: "Partial",
      bg: "#3a2800", fg: "#fbbf24", border: "#78350f",
    },
    monitoring: {
      icon: <Info size={11} />,
      label: "Monitor only",
      bg: "#1a1f3a", fg: "#3b82f6", border: "#1e3a5f",
    },
    none: {
      icon: <XCircle size={11} />,
      label: "None",
      bg: "#3f1111", fg: "#f87171", border: "#7f1d1d",
    },
    unknown: {
      icon: <Info size={11} />,
      label: "Unknown",
      bg: "#1a1a1a", fg: "#888", border: "#333",
    },
  };
  const c = cfg[level];
  return (
    <span
      className="inline-flex items-center gap-1 px-2 py-0.5 rounded text-xs font-semibold"
      style={{ background: c.bg, color: c.fg, border: `1px solid ${c.border}` }}
    >
      {c.icon}
      {c.label}
    </span>
  );
}

export default function CompatibilityTab() {
  return (
    <div className="space-y-5 max-w-6xl mx-auto">

      {/* Page intro */}
      <div
        className="rounded-xl border p-5"
        style={{ background: "#141414", borderColor: "#242424" }}
      >
        <h2 className="text-sm font-semibold text-white mb-1">Device Compatibility</h2>
        <p className="text-xs leading-relaxed" style={{ color: "#888" }}>
          ProxFansX auto-detects your hardware chip family at install time and configures fan control
          accordingly. The table below shows what to expect for each supported device class.
        </p>
      </div>

      {/* Compatibility table */}
      <div
        className="rounded-xl border overflow-hidden"
        style={{ background: "#141414", borderColor: "#242424" }}
      >
        <div
          className="px-5 py-3 border-b"
          style={{ borderColor: "#1e1e1e" }}
        >
          <h3 className="text-sm font-semibold text-white">Supported Devices</h3>
        </div>
        <div className="overflow-x-auto">
          <table className="w-full text-xs">
            <thead>
              <tr style={{ borderBottom: "1px solid #1e1e1e" }}>
                {["Device", "Chip Family", "Kernel Module", "PWM Control", "Temp Sensing", "Controllable Fans", "Notes"].map(h => (
                  <th
                    key={h}
                    className="px-4 py-3 text-left font-semibold"
                    style={{ color: "#666" }}
                  >
                    {h}
                  </th>
                ))}
              </tr>
            </thead>
            <tbody>
              {DEVICES.map((d, i) => (
                <tr
                  key={d.device}
                  style={{
                    borderBottom: i < DEVICES.length - 1 ? "1px solid #1a1a1a" : undefined,
                  }}
                  className="transition-colors hover:bg-[#1a1a1a]"
                >
                  <td className="px-4 py-3 font-medium text-white whitespace-nowrap">{d.device}</td>
                  <td className="px-4 py-3 font-mono" style={{ color: "#a78bfa" }}>{d.chipFamily}</td>
                  <td className="px-4 py-3 font-mono" style={{ color: "#60a5fa" }}>
                    {d.module === "none" ? <span style={{ color: "#555" }}>none</span> : d.module}
                  </td>
                  <td className="px-4 py-3"><SupportBadge level={d.pwmSupport} /></td>
                  <td className="px-4 py-3"><SupportBadge level={d.tempSupport} /></td>
                  <td className="px-4 py-3" style={{ color: "#ccc" }}>{d.fans}</td>
                  <td className="px-4 py-3" style={{ color: "#666", maxWidth: 300 }}>{d.notes}</td>
                </tr>
              ))}
            </tbody>
          </table>
        </div>
      </div>

      {/* AMD info box */}
      <div
        className="flex items-start gap-3 rounded-xl border p-4"
        style={{ background: "#1a1f3a", borderColor: "#1e3a5f" }}
      >
        <Info size={16} style={{ color: "#3b82f6", flexShrink: 0, marginTop: 1 }} />
        <div className="text-xs leading-relaxed" style={{ color: "#93b4e8" }}>
          <strong className="text-white">AMD UM/HX devices — monitoring only.</strong>{" "}
          AMD SoC platforms do not expose PWM fan control via hwmon. ProxFansX installs in
          temperature-monitoring mode. For TDP limiting on AMD devices, use{" "}
          <code className="font-mono text-blue-300">ryzenadj</code> separately.
        </div>
      </div>

      {/* ITE BD info box */}
      <div
        className="flex items-start gap-3 rounded-xl border p-4"
        style={{ background: "#3a2800", borderColor: "#78350f" }}
      >
        <AlertTriangle size={16} style={{ color: "#fbbf24", flexShrink: 0, marginTop: 1 }} />
        <div className="text-xs leading-relaxed" style={{ color: "#d4a843" }}>
          <strong className="text-white">ITE IT87xx — CPU fan limitation.</strong>{" "}
          On Minisforum BD series boards (BD790i, BD680i), the CPU fan header (pwm4) has no sysfs
          interface. To retain fan speed control, connect your CPU cooler to a{" "}
          <strong className="text-yellow-300">SYS_FAN header</strong> instead of the CPU_FAN header.
          The out-of-tree{" "}
          <code className="font-mono text-yellow-400">it87</code> driver may be required on kernels
          without upstream support.
        </div>
      </div>

    </div>
  );
}
