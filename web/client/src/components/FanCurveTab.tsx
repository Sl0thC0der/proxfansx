import { useEffect, useRef, useState } from "react";
import { useForm } from "react-hook-form";
import { zodResolver } from "@hookform/resolvers/zod";
import { useMutation, useQueryClient } from "@tanstack/react-query";
import { apiRequest } from "@/lib/queryClient";
import { insertFanConfigSchema, type FanConfig, type InsertFanConfig } from "@shared/schema";
import { Form, FormField, FormItem, FormLabel, FormControl, FormMessage } from "@/components/ui/form";
import { Input } from "@/components/ui/input";
import { Button } from "@/components/ui/button";
import { useToast } from "@/hooks/use-toast";
import { Save, RotateCcw, Sliders } from "lucide-react";

const DEFAULTS: InsertFanConfig = {
  mintemp: 60, maxtemp: 80, minstart: 150, minstop: 30,
  minpwm: 0, maxpwm: 255, interval: 10,
};

interface Props { config?: FanConfig; }

export default function FanCurveTab({ config }: Props) {
  const qc = useQueryClient();
  const { toast } = useToast();
  const canvasRef = useRef<HTMLCanvasElement>(null);

  const form = useForm<InsertFanConfig>({
    resolver: zodResolver(insertFanConfigSchema),
    defaultValues: config ? {
      mintemp: config.mintemp, maxtemp: config.maxtemp, minstart: config.minstart,
      minstop: config.minstop, minpwm: config.minpwm, maxpwm: config.maxpwm, interval: config.interval,
    } : DEFAULTS,
  });

  useEffect(() => {
    if (config) form.reset({
      mintemp: config.mintemp, maxtemp: config.maxtemp, minstart: config.minstart,
      minstop: config.minstop, minpwm: config.minpwm, maxpwm: config.maxpwm, interval: config.interval,
    });
  }, [config]);

  const values = form.watch();
  useEffect(() => { drawCurve(canvasRef.current, values); }, [values]);

  const save = useMutation({
    mutationFn: (data: InsertFanConfig) =>
      apiRequest("POST", "/api/config", data).then(r => r.json()),
    onSuccess: () => {
      qc.invalidateQueries({ queryKey: ["/api/config"] });
      toast({ title: "Config saved", description: "Fan curve updated." });
    },
    onError: () => toast({ title: "Error", description: "Failed to save.", variant: "destructive" }),
  });

  return (
    <div className="max-w-6xl mx-auto space-y-5">

      {/* Section header */}
      <div className="flex items-center gap-2">
        <Sliders size={16} style={{ color: "#3b82f6" }} />
        <h2 className="text-base font-semibold text-white">Fan Curve Configuration</h2>
        <span className="text-xs" style={{ color: "#555" }}>PWM vs. temperature for pwm1 + pwm2</span>
      </div>

      <div className="grid grid-cols-5 gap-5">

        {/* Chart */}
        <div
          className="col-span-3 rounded-xl border overflow-hidden"
          style={{ background: "#141414", borderColor: "#242424" }}
        >
          <div
            className="flex items-center justify-between px-4 py-3 border-b text-xs"
            style={{ borderColor: "#1e1e1e", color: "#555" }}
          >
            <span className="text-white font-medium">PWM (%) vs Temperature (°C)</span>
            <span style={{ color: "#3b82f6" }}>pwm1 + pwm2</span>
          </div>
          <div className="p-4" style={{ height: 300 }}>
            <canvas
              ref={canvasRef}
              style={{ width: "100%", height: "100%", display: "block" }}
              data-testid="fan-curve-canvas"
            />
          </div>
        </div>

        {/* Parameter form */}
        <div
          className="col-span-2 rounded-xl border flex flex-col"
          style={{ background: "#141414", borderColor: "#242424" }}
        >
          <div
            className="px-4 py-3 border-b text-xs font-semibold text-white"
            style={{ borderColor: "#1e1e1e" }}
          >
            Parameters
          </div>
          <div className="flex-1 overflow-y-auto p-4">
            <Form {...form}>
              <form onSubmit={form.handleSubmit(d => save.mutate(d))} className="space-y-3" data-testid="config-form">

                <FieldGroup label="Temperature thresholds (°C)">
                  <FieldRow form={form} name="mintemp" label="MINTEMP" desc="Fans off below" />
                  <FieldRow form={form} name="maxtemp" label="MAXTEMP" desc="Full speed at" />
                </FieldGroup>

                <FieldGroup label="PWM limits (0–255)">
                  <FieldRow form={form} name="minpwm"   label="MINPWM"   desc="Allow full stop" />
                  <FieldRow form={form} name="maxpwm"   label="MAXPWM"   desc="Max duty" />
                  <FieldRow form={form} name="minstart" label="MINSTART"  desc="Spin-up PWM" />
                  <FieldRow form={form} name="minstop"  label="MINSTOP"   desc="Keep running" />
                </FieldGroup>

                <FieldGroup label="Polling">
                  <FieldRow form={form} name="interval" label="INTERVAL" desc="Poll seconds" />
                </FieldGroup>

                <div className="flex gap-2 pt-2">
                  <Button
                    type="submit"
                    size="sm"
                    className="flex-1 h-8 text-xs gap-1.5"
                    style={{ background: "#3b82f6", color: "#fff" }}
                    disabled={save.isPending}
                    data-testid="btn-save-config"
                  >
                    <Save size={12} />
                    {save.isPending ? "Saving…" : "Apply Config"}
                  </Button>
                  <Button
                    type="button"
                    variant="outline"
                    size="sm"
                    className="h-8 w-8 p-0"
                    style={{ borderColor: "#333", background: "#1a1a1a" }}
                    onClick={() => form.reset(DEFAULTS)}
                    data-testid="btn-reset-config"
                  >
                    <RotateCcw size={12} style={{ color: "#888" }} />
                  </Button>
                </div>
              </form>
            </Form>
          </div>
        </div>
      </div>

      {/* Parameter reference table */}
      <div
        className="rounded-xl border overflow-hidden"
        style={{ borderColor: "#242424" }}
        data-testid="param-table"
      >
        <div
          className="px-4 py-3 border-b text-xs font-semibold text-white"
          style={{ background: "#141414", borderColor: "#1e1e1e" }}
        >
          Parameter Reference — /etc/fancontrol
        </div>
        <table className="w-full text-xs" style={{ background: "#0f0f0f" }}>
          <thead>
            <tr style={{ borderBottom: "1px solid #1e1e1e", background: "#141414" }}>
              {["Parameter", "Current Value", "Description"].map(h => (
                <th key={h} className="px-4 py-2 text-left font-semibold" style={{ color: "#555", fontSize: 10, textTransform: "uppercase", letterSpacing: "0.08em" }}>{h}</th>
              ))}
            </tr>
          </thead>
          <tbody>
            {[
              ["MINTEMP",  values.mintemp,  "Below this °C fans can stop"],
              ["MAXTEMP",  values.maxtemp,  "At this °C fans run at MAXPWM"],
              ["MINSTART", values.minstart, "Min PWM to spin fans up from stopped"],
              ["MINSTOP",  values.minstop,  "Min PWM to keep fans running"],
              ["MINPWM",   values.minpwm,   "Min PWM output (0 = allow full stop)"],
              ["MAXPWM",   values.maxpwm,   "Max PWM output (255 = full speed)"],
              ["INTERVAL", values.interval, "Poll interval in seconds"],
            ].map(([k, v, d], i) => (
              <tr key={k as string} style={{ borderBottom: "1px solid #1a1a1a", background: i % 2 === 0 ? "#0f0f0f" : "#111" }}>
                <td className="px-4 py-2 font-mono font-medium" style={{ color: "#3b82f6" }}>{k}</td>
                <td className="px-4 py-2 font-mono font-bold text-white">{v}</td>
                <td className="px-4 py-2" style={{ color: "#666" }}>{d}</td>
              </tr>
            ))}
          </tbody>
        </table>
      </div>
    </div>
  );
}

function FieldGroup({ label, children }: { label: string; children: React.ReactNode }) {
  return (
    <div>
      <div className="text-xs font-semibold mb-2 pb-1 border-b" style={{ color: "#555", borderColor: "#1e1e1e" }}>{label}</div>
      <div className="space-y-2">{children}</div>
    </div>
  );
}

function FieldRow({ form, name, label, desc }: {
  form: ReturnType<typeof useForm<InsertFanConfig>>;
  name: keyof InsertFanConfig; label: string; desc: string;
}) {
  return (
    <FormField control={form.control} name={name} render={({ field }) => (
      <FormItem className="flex items-center gap-2">
        <div className="w-20 shrink-0">
          <FormLabel className="text-xs font-mono" style={{ color: "#3b82f6" }}>{label}</FormLabel>
        </div>
        <FormControl>
          <Input
            {...field}
            type="number"
            onChange={e => field.onChange(parseInt(e.target.value) || 0)}
            className="h-7 text-xs font-mono px-2"
            style={{ background: "#1a1a1a", borderColor: "#333", color: "#e5e5e5" }}
            data-testid={`input-${name}`}
          />
        </FormControl>
        <span className="text-xs shrink-0" style={{ color: "#555" }}>{desc}</span>
        <FormMessage />
      </FormItem>
    )} />
  );
}

// ── Canvas draw function ───────────────────────────────────────────────────
function drawCurve(canvas: HTMLCanvasElement | null, v: InsertFanConfig) {
  if (!canvas) return;
  const ctx = canvas.getContext("2d");
  if (!ctx) return;
  const dpr = window.devicePixelRatio || 1;
  const W = canvas.offsetWidth; const H = canvas.offsetHeight;
  canvas.width = W * dpr; canvas.height = H * dpr;
  ctx.setTransform(dpr, 0, 0, dpr, 0, 0);
  ctx.clearRect(0, 0, W, H);

  const PAD = { top: 12, right: 16, bottom: 32, left: 44 };
  const pW = W - PAD.left - PAD.right;
  const pH = H - PAD.top - PAD.bottom;
  const TMIN = 20, TMAX = 100;

  const tx = (t: number) => PAD.left + ((t - TMIN) / (TMAX - TMIN)) * pW;
  const ty = (p: number) => PAD.top + pH - (p / 100) * pH;
  const tempToPct = (t: number) => {
    if (t <= v.mintemp) return (v.minpwm / 255) * 100;
    if (t >= v.maxtemp) return (v.maxpwm / 255) * 100;
    return ((v.minpwm + (t - v.mintemp) / (v.maxtemp - v.mintemp) * (v.maxpwm - v.minpwm)) / 255) * 100;
  };

  // Dashed grid
  ctx.strokeStyle = "#2a2a2a"; ctx.lineWidth = 1; ctx.setLineDash([2, 4]);
  ctx.font = "10px JetBrains Mono, monospace";
  [0, 25, 50, 75, 100].forEach(p => {
    const y = ty(p);
    ctx.beginPath(); ctx.moveTo(PAD.left, y); ctx.lineTo(PAD.left + pW, y); ctx.stroke();
    ctx.setLineDash([]);
    ctx.fillStyle = "#444"; ctx.textAlign = "right"; ctx.fillText(p + "%", PAD.left - 5, y + 3.5);
    ctx.setLineDash([2, 4]);
  });
  for (let t = TMIN; t <= TMAX; t += 10) {
    const x = tx(t);
    ctx.beginPath(); ctx.moveTo(x, PAD.top); ctx.lineTo(x, PAD.top + pH); ctx.stroke();
    ctx.setLineDash([]);
    ctx.fillStyle = "#444"; ctx.textAlign = "center"; ctx.fillText(t + "°", x, PAD.top + pH + 14);
    ctx.setLineDash([2, 4]);
  }
  ctx.setLineDash([]);

  // Gradient fill
  const pts = 300;
  const grad = ctx.createLinearGradient(0, PAD.top, 0, PAD.top + pH);
  grad.addColorStop(0, "rgba(59,130,246,0.3)"); grad.addColorStop(1, "rgba(59,130,246,0.02)");
  ctx.beginPath();
  ctx.moveTo(tx(TMIN), ty(tempToPct(TMIN)));
  for (let i = 1; i <= pts; i++) ctx.lineTo(tx(TMIN + (TMAX - TMIN) * i / pts), ty(tempToPct(TMIN + (TMAX - TMIN) * i / pts)));
  ctx.lineTo(tx(TMAX), ty(0)); ctx.lineTo(tx(TMIN), ty(0));
  ctx.closePath(); ctx.fillStyle = grad; ctx.fill();

  // Curve line
  ctx.beginPath(); ctx.strokeStyle = "#3b82f6"; ctx.lineWidth = 2; ctx.lineJoin = "round";
  ctx.moveTo(tx(TMIN), ty(tempToPct(TMIN)));
  for (let i = 1; i <= pts; i++) ctx.lineTo(tx(TMIN + (TMAX - TMIN) * i / pts), ty(tempToPct(TMIN + (TMAX - TMIN) * i / pts)));
  ctx.stroke();

  // Axes
  ctx.strokeStyle = "#2a2a2a"; ctx.lineWidth = 1;
  ctx.beginPath(); ctx.moveTo(PAD.left, PAD.top); ctx.lineTo(PAD.left, PAD.top + pH); ctx.lineTo(PAD.left + pW, PAD.top + pH); ctx.stroke();

  // Keypoints
  [{ t: v.mintemp }, { t: v.maxtemp }].forEach(({ t }) => {
    const x = tx(t); const y = ty(tempToPct(t));
    ctx.strokeStyle = "rgba(251,146,60,0.5)"; ctx.lineWidth = 1; ctx.setLineDash([3,3]);
    ctx.beginPath(); ctx.moveTo(x, y); ctx.lineTo(x, PAD.top + pH); ctx.stroke(); ctx.setLineDash([]);
    ctx.beginPath(); ctx.arc(x, y, 5, 0, Math.PI * 2);
    ctx.fillStyle = "#fb923c"; ctx.fill();
    ctx.strokeStyle = "#0d0d0d"; ctx.lineWidth = 2; ctx.stroke();
    ctx.fillStyle = "#888"; ctx.font = "10px JetBrains Mono"; ctx.textAlign = "center";
    ctx.fillText(`${t}°C`, x, PAD.top + pH + 26);
  });
}
