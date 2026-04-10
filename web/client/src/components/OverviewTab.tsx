import { useQuery } from "@tanstack/react-query";
import { apiRequest } from "@/lib/queryClient";
import type { FanConfig, SensorLog } from "@shared/schema";
import { useEffect, useRef } from "react";
import { Thermometer, Wind, Zap, Activity, AlertTriangle, LayoutGrid } from "lucide-react";

interface Props { config?: FanConfig; latest?: SensorLog; }

function tempColor(t: number) {
  if (t < 60) return "#4ade80";
  if (t < 70) return "#fbbf24";
  if (t < 80) return "#fb923c";
  return "#f87171";
}
function pwmPct(p: number) { return Math.round((p / 255) * 100); }

export default function OverviewTab({ config, latest }: Props) {
  const { data: history = [] } = useQuery<SensorLog[]>({
    queryKey: ["/api/sensors"],
    queryFn: () => apiRequest("GET", "/api/sensors").then(r => r.json()),
    refetchInterval: 5000,
  });

  const temp = latest?.cputin ?? 0;
  const fan1 = latest?.fan1rpm ?? 0;
  const fan2 = latest?.fan2rpm ?? 0;
  const pwm1 = latest?.pwm1 ?? 0;
  const pwm2 = latest?.pwm2 ?? 0;

  return (
    <div className="space-y-5 max-w-6xl mx-auto">

      {/* ── 4-column stat cards ── */}
      <div className="grid grid-cols-4 gap-4" data-testid="stat-cards">

        <StatCard
          label="CPUTIN Temperature"
          value={`${temp.toFixed(1)}°C`}
          valueColor={tempColor(temp)}
          sub="temp2_input · nct6798"
          icon={<Thermometer size={16} />}
          bar={{ value: temp, min: 30, max: 90, color: tempColor(temp) }}
          data-testid="card-temp"
        />
        <StatCard
          label="Fan 1 Speed"
          value={`${fan1} RPM`}
          sub={`PWM: ${pwm1}/255 (${pwmPct(pwm1)}%)`}
          icon={<Wind size={16} />}
          bar={{ value: fan1, min: 0, max: 2400, color: "#3b82f6" }}
          data-testid="card-fan1"
        />
        <StatCard
          label="Fan 2 Speed"
          value={`${fan2} RPM`}
          sub={`PWM: ${pwm2}/255 (${pwmPct(pwm2)}%)`}
          icon={<Wind size={16} />}
          bar={{ value: fan2, min: 0, max: 2400, color: "#3b82f6" }}
          data-testid="card-fan2"
        />
        <StatCard
          label="Fan Curve"
          value={`${config?.mintemp ?? 60}–${config?.maxtemp ?? 80}°C`}
          valueColor="#a78bfa"
          sub={`Off below ${config?.mintemp ?? 60}°C · Full at ${config?.maxtemp ?? 80}°C`}
          icon={<Activity size={16} />}
          data-testid="card-curve"
        />
      </div>

      {/* ── Temperature + Fan speed area charts ── */}
      <div className="grid grid-cols-2 gap-4">
        <ChartCard
          title="Temperature"
          icon={<Thermometer size={14} />}
          data={history.map(h => h.cputin ?? 0)}
          min={30} max={90}
          color="#fb923c"
          fillColor="rgba(251,146,60,0.15)"
          unit="°C"
          data-testid="chart-temp"
        />
        <ChartCard
          title="Fan Speed"
          icon={<Wind size={14} />}
          data={history.map(h => h.fan1rpm ?? 0)}
          min={0} max={2400}
          color="#4ade80"
          fillColor="rgba(74,222,128,0.12)"
          unit=" RPM"
          data-testid="chart-fan"
        />
      </div>

      {/* ── Chip details section ── */}
      <div
        className="rounded-xl border p-5"
        style={{ background: "#141414", borderColor: "#242424" }}
        data-testid="chip-details"
      >
        <div className="flex items-center gap-2 mb-4">
          <LayoutGrid size={15} style={{ color: "#3b82f6" }} />
          <h3 className="font-semibold text-sm text-white">Hardware Details</h3>
        </div>
        <div className="grid grid-cols-3 gap-x-8 gap-y-3 text-xs">
          {[
            ["Fan Controller", "Nuvoton nct6798"],
            ["Kernel Module", "nct6775"],
            ["Temp Sensor", "temp2_input (CPUTIN)"],
            ["Controlled Fans", "pwm1, pwm2"],
            ["Poll Interval", `${config?.interval ?? 10} seconds`],
            ["Min Start PWM", `${config?.minstart ?? 150}/255`],
          ].map(([k, v]) => (
            <div key={k} className="flex justify-between border-b pb-2" style={{ borderColor: "#1e1e1e" }}>
              <span style={{ color: "#666" }}>{k}</span>
              <span className="font-mono font-medium" style={{ color: "#e5e5e5" }}>{v}</span>
            </div>
          ))}
        </div>
      </div>

      {/* ── CPU blower warning ── */}
      <div
        className="flex items-start gap-3 rounded-xl border p-4"
        style={{ background: "#1a1200", borderColor: "#3a2800" }}
        data-testid="blower-warning"
      >
        <AlertTriangle size={16} style={{ color: "#fbbf24", flexShrink: 0, marginTop: 1 }} />
        <div className="text-xs leading-relaxed" style={{ color: "#d4a843" }}>
          <strong className="text-white">CPU blower fan is not controlled.</strong>{" "}
          The MS-01's CPU blower is driven by an internal microcontroller and is not exposed via the
          nct6798 hwmon interface. Only the system/chassis fans on <code className="font-mono text-yellow-400">pwm1</code> and{" "}
          <code className="font-mono text-yellow-400">pwm2</code> respond to this configuration.
        </div>
      </div>
    </div>
  );
}

/* ── Stat card ────────────── */
function StatCard({ label, value, valueColor, sub, icon, bar, "data-testid": testId }: {
  label: string; value: string; valueColor?: string; sub?: string;
  icon: React.ReactNode;
  bar?: { value: number; min: number; max: number; color: string };
  "data-testid"?: string;
}) {
  return (
    <div
      className="rounded-xl border p-4 flex flex-col gap-2"
      style={{ background: "#141414", borderColor: "#242424" }}
      data-testid={testId}
    >
      <div className="flex items-center justify-between">
        <span className="text-xs" style={{ color: "#666" }}>{label}</span>
        <span style={{ color: "#444" }}>{icon}</span>
      </div>
      <div
        className="text-2xl font-bold leading-none"
        style={{ color: valueColor || "#f5f5f5" }}
      >
        {value}
      </div>
      {bar && (
        <div className="h-1 rounded-full overflow-hidden" style={{ background: "#222" }}>
          <div
            className="h-full rounded-full transition-all duration-700"
            style={{
              width: `${Math.max(0, Math.min(100, ((bar.value - bar.min) / (bar.max - bar.min)) * 100))}%`,
              background: bar.color,
            }}
          />
        </div>
      )}
      {sub && <div className="text-xs font-mono" style={{ color: "#555" }}>{sub}</div>}
    </div>
  );
}

/* ── Area chart ─────────────────── */
function ChartCard({ title, icon, data, min, max, color, fillColor, unit, "data-testid": testId }: {
  title: string; icon: React.ReactNode; data: number[];
  min: number; max: number; color: string; fillColor: string; unit: string;
  "data-testid"?: string;
}) {
  const canvasRef = useRef<HTMLCanvasElement>(null);

  useEffect(() => {
    const canvas = canvasRef.current;
    if (!canvas) return;
    const ctx = canvas.getContext("2d");
    if (!ctx) return;
    const dpr = window.devicePixelRatio || 1;
    const W = canvas.offsetWidth; const H = canvas.offsetHeight;
    canvas.width = W * dpr; canvas.height = H * dpr;
    ctx.setTransform(dpr, 0, 0, dpr, 0, 0);
    ctx.clearRect(0, 0, W, H);

    const PAD = { top: 8, right: 12, bottom: 24, left: 44 };
    const pW = W - PAD.left - PAD.right;
    const pH = H - PAD.top - PAD.bottom;
    const pts = data.length;
    const range = max - min || 1;

    const tx = (i: number) => PAD.left + (i / Math.max(pts - 1, 1)) * pW;
    const ty = (v: number) => PAD.top + pH - ((Math.max(min, Math.min(max, v)) - min) / range) * pH;

    // Dashed grid lines
    ctx.setLineDash([2, 4]);
    ctx.strokeStyle = "#2a2a2a";
    ctx.lineWidth = 1;
    [0, 0.25, 0.5, 0.75, 1].forEach(frac => {
      const y = PAD.top + frac * pH;
      ctx.beginPath(); ctx.moveTo(PAD.left, y); ctx.lineTo(PAD.left + pW, y); ctx.stroke();
      const v = max - frac * (max - min);
      ctx.fillStyle = "#555"; ctx.font = "10px JetBrains Mono, monospace";
      ctx.textAlign = "right"; ctx.fillText(Math.round(v).toString(), PAD.left - 5, y + 3.5);
    });
    ctx.setLineDash([]);

    if (pts < 2) {
      ctx.fillStyle = color; ctx.font = "11px Inter";
      ctx.textAlign = "center"; ctx.fillText("Collecting data…", W / 2, H / 2);
      return;
    }

    // Fill
    const grad = ctx.createLinearGradient(0, PAD.top, 0, PAD.top + pH);
    grad.addColorStop(0, fillColor); grad.addColorStop(1, "rgba(0,0,0,0)");
    ctx.beginPath();
    ctx.moveTo(tx(0), ty(data[0]));
    for (let i = 1; i < pts; i++) ctx.lineTo(tx(i), ty(data[i]));
    ctx.lineTo(tx(pts - 1), PAD.top + pH); ctx.lineTo(tx(0), PAD.top + pH);
    ctx.closePath(); ctx.fillStyle = grad; ctx.fill();

    // Line
    ctx.beginPath(); ctx.strokeStyle = color; ctx.lineWidth = 1.5; ctx.lineJoin = "round";
    ctx.moveTo(tx(0), ty(data[0]));
    for (let i = 1; i < pts; i++) ctx.lineTo(tx(i), ty(data[i]));
    ctx.stroke();

    // Latest value
    const last = data[pts - 1];
    ctx.fillStyle = color; ctx.font = "bold 11px JetBrains Mono, monospace";
    ctx.textAlign = "right";
    ctx.fillText(`${last.toFixed(last < 10 ? 1 : 0)}${unit}`, W - 8, PAD.top + 14);

    // X labels
    ctx.fillStyle = "#555"; ctx.font = "10px JetBrains Mono"; ctx.textAlign = "center";
    const step = Math.max(1, Math.floor(pts / 6));
    for (let i = 0; i < pts; i += step) {
      ctx.fillText(`${i}`, tx(i), PAD.top + pH + 16);
    }
  }, [data, min, max, color, fillColor, unit]);

  return (
    <div
      className="rounded-xl border overflow-hidden"
      style={{ background: "#141414", borderColor: "#242424" }}
      data-testid={testId}
    >
      <div
        className="flex items-center justify-between px-4 py-3 border-b"
        style={{ borderColor: "#1e1e1e" }}
      >
        <div className="flex items-center gap-2 text-sm font-semibold text-white">
          <span style={{ color }}>{icon}</span>
          {title}
        </div>
        <span className="flex items-center gap-1.5 text-xs" style={{ color }}>
          <span className="w-1.5 h-1.5 rounded-full inline-block" style={{ background: color }} />
          live
        </span>
      </div>
      <div className="px-4 pb-4 pt-2" style={{ height: 160 }}>
        <canvas ref={canvasRef} style={{ width: "100%", height: "100%", display: "block" }} />
      </div>
    </div>
  );
}
