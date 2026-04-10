import type { FanConfig } from "@shared/schema";
import { useState } from "react";
import { Copy, Check, Terminal, Download, AlertTriangle } from "lucide-react";
import { useToast } from "@/hooks/use-toast";

interface Props { config?: FanConfig; }

const S = {
  card: {
    background: "#141414",
    border: "1px solid #242424",
    borderRadius: 8,
    overflow: "hidden",
  } as React.CSSProperties,
  cardHeader: {
    display: "flex",
    alignItems: "center",
    justifyContent: "space-between",
    padding: "10px 14px",
    borderBottom: "1px solid #1e1e1e",
    background: "#111",
  } as React.CSSProperties,
  cardHeaderLeft: {
    display: "flex",
    alignItems: "center",
    gap: 8,
  } as React.CSSProperties,
  cardTitle: {
    fontSize: 12,
    fontWeight: 600,
    color: "#e5e5e5",
  } as React.CSSProperties,
  langBadge: {
    fontSize: 10,
    fontWeight: 600,
    color: "#555",
    textTransform: "uppercase" as const,
    letterSpacing: "0.08em",
    fontFamily: "JetBrains Mono, monospace",
  } as React.CSSProperties,
  pre: {
    margin: 0,
    padding: "14px 16px",
    overflowX: "auto" as const,
    fontSize: 12,
    lineHeight: 1.7,
    fontFamily: "JetBrains Mono, monospace",
    background: "#0d0d0d",
    color: "#ccc",
  } as React.CSSProperties,
  copyBtn: {
    display: "flex",
    alignItems: "center",
    gap: 4,
    padding: "3px 10px",
    borderRadius: 5,
    border: "1px solid #2a2a2a",
    background: "transparent",
    color: "#888",
    fontSize: 11,
    cursor: "pointer",
    fontFamily: "Inter, sans-serif",
    transition: "background 0.15s, color 0.15s",
  } as React.CSSProperties,
  dlBtn: {
    display: "flex",
    alignItems: "center",
    gap: 5,
    padding: "3px 10px",
    borderRadius: 5,
    border: "1px solid #1d4ed8",
    background: "#1e3a8a22",
    color: "#60a5fa",
    fontSize: 11,
    cursor: "pointer",
    fontFamily: "Inter, sans-serif",
  } as React.CSSProperties,
  sectionLabel: {
    display: "flex",
    alignItems: "center",
    gap: 8,
    marginBottom: 10,
  } as React.CSSProperties,
  sectionTitle: {
    fontSize: 13,
    fontWeight: 700,
    color: "#e5e5e5",
  } as React.CSSProperties,
  warningCard: {
    display: "flex",
    gap: 12,
    alignItems: "flex-start",
    padding: "12px 16px",
    background: "#1a1200",
    border: "1px solid #7c4f00",
    borderRadius: 8,
  } as React.CSSProperties,
};

export default function CommandsTab({ config }: Props) {
  const fancontrolConfig = config ? `# /etc/fancontrol — current active config
INTERVAL=${config.interval}
DEVPATH=hwmon2=devices/platform/nct6775.2592/hwmon
DEVNAME=hwmon2=nct6798
FCTEMPS=hwmon2/pwm1=hwmon2/temp2_input hwmon2/pwm2=hwmon2/temp2_input
FCFANS=hwmon2/pwm1=hwmon2/fan1_input hwmon2/pwm2=hwmon2/fan2_input
MINTEMP=hwmon2/pwm1=${config.mintemp} hwmon2/pwm2=${config.mintemp}
MAXTEMP=hwmon2/pwm1=${config.maxtemp} hwmon2/pwm2=${config.maxtemp}
MINSTART=hwmon2/pwm1=${config.minstart} hwmon2/pwm2=${config.minstart}
MINSTOP=hwmon2/pwm1=${config.minstop} hwmon2/pwm2=${config.minstop}
MINPWM=hwmon2/pwm1=${config.minpwm} hwmon2/pwm2=${config.minpwm}
MAXPWM=hwmon2/pwm1=${config.maxpwm} hwmon2/pwm2=${config.maxpwm}` : "Loading config…";

  const monitoringCmds = `# Live sensor monitor (refresh every 2s)
watch -n2 sensors

# fancontrol service status
systemctl status fancontrol

# Follow fancontrol logs live
journalctl -u fancontrol -f

# View active fancontrol config
cat /etc/fancontrol

# List all hwmon chips and their names
for d in /sys/class/hwmon/hwmon*; do echo "$d: $(cat $d/name 2>/dev/null)"; done

# Read CPUTIN temperature (millidegrees → divide by 1000)
cat /sys/class/hwmon/hwmon2/temp2_input

# Read current PWM value (0–255)
cat /sys/class/hwmon/hwmon2/pwm1

# Read fan1 RPM
cat /sys/class/hwmon/hwmon2/fan1_input

# Re-run setup after kernel update (re-detects hwmon index)
bash ms01-fancontrol-setup.sh`;

  const troubleshootCmds = `# Check if nct6775 module is loaded
lsmod | grep nct6775

# Load module manually
modprobe nct6775

# Reload fancontrol service
systemctl restart fancontrol

# Show fancontrol full log (last 50 lines)
journalctl -u fancontrol -n 50 --no-pager

# Check if PWM control is enabled for pwm1
cat /sys/class/hwmon/hwmon2/pwm1_enable

# Enable PWM control on pwm1 (1=manual, 2=auto)
echo 2 > /sys/class/hwmon/hwmon2/pwm1_enable

# Check chip name at hwmon2
cat /sys/class/hwmon/hwmon2/name`;

  return (
    <div style={{ display: "flex", flexDirection: "column", gap: 20 }}>
      {/* Header */}
      <div style={{ display: "flex", alignItems: "baseline", gap: 10 }}>
        <span style={{ fontSize: 15, fontWeight: 700, color: "#e5e5e5" }}>Commands &amp; Reference</span>
        <span style={{ fontSize: 12, color: "#555" }}>Monitoring, troubleshooting and config reference</span>
      </div>

      {/* Setup script */}
      <div>
        <div style={S.sectionLabel}>
          <Terminal size={14} color="#3b82f6" />
          <span style={S.sectionTitle}>Setup Script</span>
        </div>
        <CodeBlock
          title="Install / Re-run"
          lang="bash"
          code="bash ms01-fancontrol-setup.sh"
          actions={
            <button
              style={S.dlBtn}
              onClick={() => {
                const a = document.createElement("a");
                a.href = "/ms01-fancontrol-setup.sh";
                a.download = "ms01-fancontrol-setup.sh";
                a.click();
              }}
              data-testid="btn-download-script"
            >
              <Download size={10} /> Download Script
            </button>
          }
        />
      </div>

      {/* Active config */}
      <div>
        <div style={S.sectionLabel}>
          <Terminal size={14} color="#4ade80" />
          <span style={S.sectionTitle}>Active /etc/fancontrol</span>
          <span style={{ fontSize: 11, color: "#555" }}>current values</span>
        </div>
        <CodeBlock
          title="fancontrol config"
          lang="conf"
          code={fancontrolConfig}
          testId="active-config-block"
        />
      </div>

      {/* Monitoring */}
      <div>
        <div style={S.sectionLabel}>
          <Terminal size={14} color="#fbbf24" />
          <span style={S.sectionTitle}>Monitoring</span>
        </div>
        <CodeBlock
          title="Live monitoring commands"
          lang="bash"
          code={monitoringCmds}
          testId="monitoring-commands"
        />
      </div>

      {/* Troubleshooting */}
      <div>
        <div style={S.sectionLabel}>
          <Terminal size={14} color="#fb923c" />
          <span style={S.sectionTitle}>Troubleshooting</span>
        </div>
        <CodeBlock
          title="Diagnostic commands"
          lang="bash"
          code={troubleshootCmds}
          testId="troubleshoot-commands"
        />
      </div>

      {/* hwmon warning */}
      <div style={S.warningCard}>
        <AlertTriangle size={15} color="#fbbf24" style={{ flexShrink: 0, marginTop: 1 }} />
        <div style={{ fontSize: 12, color: "#d4a300", lineHeight: 1.6 }}>
          <strong style={{ color: "#fbbf24" }}>hwmon index may differ per node.</strong>{" "}
          Replace{" "}
          <code style={{ fontFamily: "JetBrains Mono, monospace", background: "#2a1a00", padding: "1px 5px", borderRadius: 3, color: "#fb923c" }}>
            hwmon2
          </code>{" "}
          in the commands above with the index printed during setup (e.g.{" "}
          <code style={{ fontFamily: "JetBrains Mono, monospace", background: "#2a1a00", padding: "1px 5px", borderRadius: 3, color: "#fb923c" }}>
            hwmon0
          </code>
          ,{" "}
          <code style={{ fontFamily: "JetBrains Mono, monospace", background: "#2a1a00", padding: "1px 5px", borderRadius: 3, color: "#fb923c" }}>
            hwmon3
          </code>
          …). The setup script auto-detects and prints the correct index.
        </div>
      </div>
    </div>
  );
}

// ── Reusable code block ──────────────────────────────────────────────────────
function CodeBlock({
  title, lang, code, actions, testId,
}: {
  title: string;
  lang: string;
  code: string;
  actions?: React.ReactNode;
  testId?: string;
}) {
  const [copied, setCopied] = useState(false);

  const copy = () => {
    navigator.clipboard.writeText(code).then(() => {
      setCopied(true);
      setTimeout(() => setCopied(false), 1800);
    });
  };

  return (
    <div style={{ ...S.card, marginTop: 0 }} data-testid={testId}>
      {/* Card header bar */}
      <div style={S.cardHeader}>
        <div style={S.cardHeaderLeft}>
          <Terminal size={11} color="#555" />
          <span style={S.cardTitle}>{title}</span>
          <span style={S.langBadge}>{lang}</span>
        </div>
        <div style={{ display: "flex", gap: 6, alignItems: "center" }}>
          {actions}
          <button
            style={{
              ...S.copyBtn,
              color: copied ? "#4ade80" : "#888",
              borderColor: copied ? "#166534" : "#2a2a2a",
            }}
            onClick={copy}
            data-testid={`btn-copy-${title.replace(/\s+/g, "-").toLowerCase()}`}
          >
            {copied ? <Check size={10} /> : <Copy size={10} />}
            {copied ? "Copied" : "Copy"}
          </button>
        </div>
      </div>

      {/* Code area */}
      <pre style={S.pre}>
        {code.split("\n").map((line, i) => (
          <div
            key={i}
            style={{
              color: line.startsWith("#")
                ? "#4ade8066"
                : line.startsWith("INTERVAL=") || line.startsWith("DEVPATH=") || line.startsWith("DEVNAME=") || line.startsWith("FC") || line.startsWith("MIN") || line.startsWith("MAX")
                ? "#ccc"
                : "#bbb",
            }}
          >
            {line || "\u00A0"}
          </div>
        ))}
      </pre>
    </div>
  );
}
