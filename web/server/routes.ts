import type { Express } from "express";
import { createServer, type Server } from "http";
import { storage } from "./storage";
import { insertFanConfigSchema, insertPresetSchema } from "@shared/schema";
import multer from "multer";

// multer for .conf file uploads (memory storage)
const upload = multer({ storage: multer.memoryStorage(), limits: { fileSize: 512 * 1024 } });

// ── Helper: parse an uploaded fancontrol .conf file ──────────────────────────
function parseFancontrolFile(text: string) {
  const get = (key: string): number | null => {
    // e.g. MINTEMP=hwmon2/pwm1=60 hwmon2/pwm2=60  OR  MINTEMP=60
    const re = new RegExp(`^${key}=(.+)$`, 'm');
    const m = text.match(re);
    if (!m) return null;
    // value might be "hwmonN/pwmX=VALUE hwmonN/pwmY=VALUE" — take first number
    const nums = m[1].match(/=(\d+)/);
    if (nums) return parseInt(nums[1]);
    const plain = m[1].trim().match(/^\d+$/);
    if (plain) return parseInt(m[1].trim());
    return null;
  };
  return {
    mintemp:  get('MINTEMP')  ?? 60,
    maxtemp:  get('MAXTEMP')  ?? 80,
    minstart: get('MINSTART') ?? 150,
    minstop:  get('MINSTOP')  ?? 30,
    minpwm:   get('MINPWM')   ?? 0,
    maxpwm:   get('MAXPWM')   ?? 255,
    interval: get('INTERVAL') ?? 10,
  };
}

// ── Mock sensor data simulator (for standalone mode) ─────────────────────────
// On a real Proxmox node, this would read /sys/class/hwmon/hwmonN/temp2_input etc.
// For the web UI preview we simulate realistic values.
let mockTemp = 58;
let mockFan1 = 0;
let mockFan2 = 0;

function simulateSensors(config: ReturnType<typeof storage.getFanConfig>) {
  if (!config) return null;
  // Drift temperature slowly
  mockTemp += (Math.random() - 0.46) * 1.5;
  mockTemp = Math.max(38, Math.min(88, mockTemp));

  // Compute PWM based on curve
  let pwmRaw = 0;
  if (mockTemp <= config.mintemp) {
    pwmRaw = config.minpwm;
  } else if (mockTemp >= config.maxtemp) {
    pwmRaw = config.maxpwm;
  } else {
    const ratio = (mockTemp - config.mintemp) / (config.maxtemp - config.mintemp);
    pwmRaw = Math.round(config.minpwm + ratio * (config.maxpwm - config.minpwm));
    if (pwmRaw > 0 && pwmRaw < config.minstart) pwmRaw = config.minstart;
  }
  // Noise
  const pwm = Math.max(0, Math.min(255, pwmRaw + Math.round((Math.random() - 0.5) * 4)));
  const pct = pwm / 255;
  mockFan1 = pwm === 0 ? 0 : Math.round(600 + pct * 1600 + (Math.random() - 0.5) * 60);
  mockFan2 = pwm === 0 ? 0 : Math.round(580 + pct * 1550 + (Math.random() - 0.5) * 60);

  return {
    timestamp: new Date().toISOString(),
    cputin:   parseFloat(mockTemp.toFixed(1)),
    fan1rpm:  mockFan1,
    fan2rpm:  mockFan2,
    pwm1:     pwm,
    pwm2:     Math.max(0, Math.min(255, pwm + Math.round((Math.random() - 0.5) * 6))),
  };
}

// ── Log simulation timer ──────────────────────────────────────────────────────
let logInterval: ReturnType<typeof setInterval> | null = null;
function startLogTimer() {
  if (logInterval) return;
  logInterval = setInterval(() => {
    const cfg = storage.getFanConfig();
    const reading = simulateSensors(cfg ?? undefined);
    if (reading) {
      storage.addSensorLog(reading);
      storage.pruneOldLogs(120);
    }
  }, 5000);
}

export async function registerRoutes(httpServer: Server, app: Express): Promise<Server> {
  startLogTimer();

  // ── Fan Config ──────────────────────────────────────────────────────────────
  app.get("/api/config", (_req, res) => {
    const cfg = storage.getFanConfig();
    res.json(cfg ?? null);
  });

  app.post("/api/config", (req, res) => {
    const parsed = insertFanConfigSchema.safeParse(req.body);
    if (!parsed.success) {
      return res.status(400).json({ error: "Invalid config", details: parsed.error.flatten() });
    }
    const cfg = storage.updateFanConfig(parsed.data);
    res.json(cfg);
  });

  // ── Presets ─────────────────────────────────────────────────────────────────
  app.get("/api/presets", (_req, res) => {
    res.json(storage.getPresets());
  });

  app.post("/api/presets", (req, res) => {
    const parsed = insertPresetSchema.safeParse(req.body);
    if (!parsed.success) {
      return res.status(400).json({ error: "Invalid preset", details: parsed.error.flatten() });
    }
    const preset = storage.createPreset(parsed.data);
    res.json(preset);
  });

  app.delete("/api/presets/:id", (req, res) => {
    const id = parseInt(req.params.id);
    const preset = storage.getPreset(id);
    if (!preset) return res.status(404).json({ error: "Not found" });
    if (preset.isBuiltIn) return res.status(403).json({ error: "Cannot delete built-in preset" });
    storage.deletePreset(id);
    res.json({ ok: true });
  });

  // Apply a preset as the active config
  app.post("/api/presets/:id/apply", (req, res) => {
    const id = parseInt(req.params.id);
    const preset = storage.getPreset(id);
    if (!preset) return res.status(404).json({ error: "Not found" });
    const cfg = storage.updateFanConfig({
      mintemp:  preset.mintemp,
      maxtemp:  preset.maxtemp,
      minstart: preset.minstart,
      minstop:  preset.minstop,
      minpwm:   preset.minpwm,
      maxpwm:   preset.maxpwm,
      interval: preset.interval,
    });
    res.json(cfg);
  });

  // Upload a /etc/fancontrol file and import its values as a new preset
  app.post("/api/presets/upload", upload.single("file"), (req, res) => {
    if (!req.file) return res.status(400).json({ error: "No file uploaded" });
    const text = req.file.buffer.toString("utf-8");
    let values: ReturnType<typeof parseFancontrolFile>;
    try {
      values = parseFancontrolFile(text);
    } catch {
      return res.status(400).json({ error: "Could not parse fancontrol file" });
    }
    const name = (req.body.name as string) || req.file.originalname.replace(/\.[^.]+$/, "");
    const description = (req.body.description as string) || "Imported from uploaded /etc/fancontrol";
    const preset = storage.createPreset({ name, description, ...values });
    res.json(preset);
  });

  // ── Sensor Log ──────────────────────────────────────────────────────────────
  app.get("/api/sensors", (_req, res) => {
    const log = storage.getSensorLog(60);
    res.json(log);
  });

  // Latest single reading
  app.get("/api/sensors/latest", (_req, res) => {
    const log = storage.getSensorLog(1);
    if (log.length === 0) {
      // Generate a first reading on demand
      const cfg = storage.getFanConfig();
      const reading = simulateSensors(cfg ?? undefined);
      if (reading) {
        const saved = storage.addSensorLog(reading);
        return res.json(saved);
      }
    }
    res.json(log[0] ?? null);
  });

  return httpServer;
}
