import { drizzle } from "drizzle-orm/better-sqlite3";
import Database from "better-sqlite3";
import { eq, desc } from "drizzle-orm";
import {
  fanConfig, presets, sensorLog,
  type FanConfig, type InsertFanConfig,
  type Preset, type InsertPreset,
  type SensorLog, type InsertSensorLog,
} from "@shared/schema";

const sqlite = new Database("ms01.db");
export const db = drizzle(sqlite);

// ── Migrate / seed ───────────────────────────────────────────────────────────
sqlite.exec(`
  CREATE TABLE IF NOT EXISTS fan_config (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    mintemp INTEGER NOT NULL DEFAULT 60,
    maxtemp INTEGER NOT NULL DEFAULT 80,
    minstart INTEGER NOT NULL DEFAULT 150,
    minstop INTEGER NOT NULL DEFAULT 30,
    minpwm INTEGER NOT NULL DEFAULT 0,
    maxpwm INTEGER NOT NULL DEFAULT 255,
    interval INTEGER NOT NULL DEFAULT 10,
    updated_at TEXT NOT NULL DEFAULT ''
  );

  CREATE TABLE IF NOT EXISTS presets (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    name TEXT NOT NULL,
    description TEXT NOT NULL DEFAULT '',
    is_built_in INTEGER NOT NULL DEFAULT 0,
    mintemp INTEGER NOT NULL,
    maxtemp INTEGER NOT NULL,
    minstart INTEGER NOT NULL,
    minstop INTEGER NOT NULL,
    minpwm INTEGER NOT NULL,
    maxpwm INTEGER NOT NULL,
    interval INTEGER NOT NULL,
    created_at TEXT NOT NULL DEFAULT ''
  );

  CREATE TABLE IF NOT EXISTS sensor_log (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    timestamp TEXT NOT NULL,
    cputin REAL,
    fan1rpm INTEGER,
    fan2rpm INTEGER,
    pwm1 INTEGER,
    pwm2 INTEGER
  );
`);

// Seed default config if empty
const existingConfig = db.select().from(fanConfig).get();
if (!existingConfig) {
  db.insert(fanConfig).values({
    mintemp: 60, maxtemp: 80, minstart: 150, minstop: 30,
    minpwm: 0, maxpwm: 255, interval: 10,
    updatedAt: new Date().toISOString(),
  }).run();
}

// Seed built-in presets if empty
const existingPresets = db.select().from(presets).all();
if (existingPresets.length === 0) {
  const builtins = [
    {
      name: "Quiet (Community Default)",
      description: "Fans off below 60°C, ramp to 100% at 80°C. Community-verified from ServeTheHome + pcfe.net. Ideal for light workloads.",
      isBuiltIn: true,
      mintemp: 60, maxtemp: 80, minstart: 150, minstop: 30, minpwm: 0, maxpwm: 255, interval: 10,
      createdAt: new Date().toISOString(),
    },
    {
      name: "Silent",
      description: "Fans stay off until 65°C, full blast at 85°C. Great for idle/media server use. Only kicks in under heavy sustained load.",
      isBuiltIn: true,
      mintemp: 65, maxtemp: 85, minstart: 150, minstop: 30, minpwm: 0, maxpwm: 200, interval: 10,
      createdAt: new Date().toISOString(),
    },
    {
      name: "Balanced",
      description: "Fans spin up at 55°C, run at 30% minimum. Good all-rounder for Proxmox nodes under variable load.",
      isBuiltIn: true,
      mintemp: 55, maxtemp: 75, minstart: 140, minstop: 40, minpwm: 30, maxpwm: 255, interval: 10,
      createdAt: new Date().toISOString(),
    },
    {
      name: "Performance",
      description: "Fans always on at 40% minimum. Aggressive ramp starts at 50°C. For compute-heavy Proxmox clusters where thermals matter.",
      isBuiltIn: true,
      mintemp: 50, maxtemp: 70, minstart: 130, minstop: 50, minpwm: 100, maxpwm: 255, interval: 5,
      createdAt: new Date().toISOString(),
    },
  ];
  for (const p of builtins) {
    db.insert(presets).values(p).run();
  }
}

// ── Storage interface ────────────────────────────────────────────────────────
export interface IStorage {
  // Fan config
  getFanConfig(): FanConfig | undefined;
  updateFanConfig(data: InsertFanConfig): FanConfig;

  // Presets
  getPresets(): Preset[];
  getPreset(id: number): Preset | undefined;
  createPreset(data: InsertPreset): Preset;
  deletePreset(id: number): void;

  // Sensor log
  getSensorLog(limit?: number): SensorLog[];
  addSensorLog(entry: InsertSensorLog): SensorLog;
  pruneOldLogs(keepCount: number): void;
}

export const storage: IStorage = {
  getFanConfig() {
    return db.select().from(fanConfig).get();
  },

  updateFanConfig(data) {
    const existing = db.select().from(fanConfig).get();
    if (existing) {
      return db.update(fanConfig)
        .set({ ...data, updatedAt: new Date().toISOString() })
        .where(eq(fanConfig.id, existing.id))
        .returning()
        .get();
    } else {
      return db.insert(fanConfig)
        .values({ ...data, updatedAt: new Date().toISOString() })
        .returning()
        .get();
    }
  },

  getPresets() {
    return db.select().from(presets).all();
  },

  getPreset(id) {
    return db.select().from(presets).where(eq(presets.id, id)).get();
  },

  createPreset(data) {
    return db.insert(presets)
      .values({ ...data, createdAt: new Date().toISOString() })
      .returning()
      .get();
  },

  deletePreset(id) {
    db.delete(presets).where(eq(presets.id, id)).run();
  },

  getSensorLog(limit = 60) {
    return db.select().from(sensorLog).orderBy(desc(sensorLog.id)).limit(limit).all().reverse();
  },

  addSensorLog(entry) {
    return db.insert(sensorLog).values(entry).returning().get();
  },

  pruneOldLogs(keepCount) {
    const rows = db.select().from(sensorLog).orderBy(desc(sensorLog.id)).all();
    if (rows.length > keepCount) {
      const toDelete = rows.slice(keepCount);
      for (const row of toDelete) {
        db.delete(sensorLog).where(eq(sensorLog.id, row.id)).run();
      }
    }
  },
};
