import { sqliteTable, text, integer, real } from "drizzle-orm/sqlite-core";
import { createInsertSchema } from "drizzle-zod";
import { z } from "zod";

// ── Fan Configuration ────────────────────────────────────────────────────────
// Stores the active fancontrol parameters
export const fanConfig = sqliteTable("fan_config", {
  id: integer("id").primaryKey({ autoIncrement: true }),
  mintemp: integer("mintemp").notNull().default(60),
  maxtemp: integer("maxtemp").notNull().default(80),
  minstart: integer("minstart").notNull().default(150),
  minstop: integer("minstop").notNull().default(30),
  minpwm: integer("minpwm").notNull().default(0),
  maxpwm: integer("maxpwm").notNull().default(255),
  interval: integer("interval").notNull().default(10),
  updatedAt: text("updated_at").notNull().default(""),
});

export const insertFanConfigSchema = createInsertSchema(fanConfig).omit({ id: true, updatedAt: true });
export type InsertFanConfig = z.infer<typeof insertFanConfigSchema>;
export type FanConfig = typeof fanConfig.$inferSelect;

// ── Presets ──────────────────────────────────────────────────────────────────
// Named fan curve presets (built-in + user-uploaded)
export const presets = sqliteTable("presets", {
  id: integer("id").primaryKey({ autoIncrement: true }),
  name: text("name").notNull(),
  description: text("description").notNull().default(""),
  isBuiltIn: integer("is_built_in", { mode: "boolean" }).notNull().default(false),
  mintemp: integer("mintemp").notNull(),
  maxtemp: integer("maxtemp").notNull(),
  minstart: integer("minstart").notNull(),
  minstop: integer("minstop").notNull(),
  minpwm: integer("minpwm").notNull(),
  maxpwm: integer("maxpwm").notNull(),
  interval: integer("interval").notNull(),
  createdAt: text("created_at").notNull().default(""),
});

export const insertPresetSchema = createInsertSchema(presets).omit({ id: true, isBuiltIn: true, createdAt: true });
export type InsertPreset = z.infer<typeof insertPresetSchema>;
export type Preset = typeof presets.$inferSelect;

// ── Sensor Readings Log ──────────────────────────────────────────────────────
// Short rolling history for sparkline (last ~60 entries)
export const sensorLog = sqliteTable("sensor_log", {
  id: integer("id").primaryKey({ autoIncrement: true }),
  timestamp: text("timestamp").notNull(),
  cputin: real("cputin"),       // °C
  fan1rpm: integer("fan1rpm"),  // RPM
  fan2rpm: integer("fan2rpm"),  // RPM
  pwm1: integer("pwm1"),        // 0–255
  pwm2: integer("pwm2"),        // 0–255
});

export const insertSensorLogSchema = createInsertSchema(sensorLog).omit({ id: true });
export type InsertSensorLog = z.infer<typeof insertSensorLogSchema>;
export type SensorLog = typeof sensorLog.$inferSelect;
