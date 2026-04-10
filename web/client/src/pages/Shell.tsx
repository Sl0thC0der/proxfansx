import { useState } from "react";
import { useQuery } from "@tanstack/react-query";
import { apiRequest } from "@/lib/queryClient";
import type { FanConfig, SensorLog, DeviceInfo } from "@shared/schema";
import OverviewTab from "@/components/OverviewTab";
import FanCurveTab from "@/components/FanCurveTab";
import PresetsTab from "@/components/PresetsTab";
import CommandsTab from "@/components/CommandsTab";
import CompatibilityTab from "@/components/CompatibilityTab";
import LogStrip from "@/components/LogStrip";
import { Wind, RefreshCw, Moon, Sun, AlertTriangle, CheckCircle, Info } from "lucide-react";
import { useTheme } from "@/App";

const TABS = [
  { id: "overview",       label: "Overview" },
  { id: "fancurve",       label: "Fan Curve" },
  { id: "presets",        label: "Presets" },
  { id: "commands",       label: "Commands" },
  { id: "compatibility",  label: "Compatibility" },
];

export default function Shell() {
  const [activeTab, setActiveTab] = useState("overview");
  const [refreshKey, setRefreshKey] = useState(0);
  const { dark, setDark } = useTheme();

  const { data: config, refetch: refetchConfig } = useQuery<FanConfig>({
    queryKey: ["/api/config"],
    queryFn: () => apiRequest("GET", "/api/config").then(r => r.json()),
    refetchInterval: 15000,
  });

  const { data: latest, refetch: refetchLatest } = useQuery<SensorLog>({
    queryKey: ["/api/sensors/latest"],
    queryFn: () => apiRequest("GET", "/api/sensors/latest").then(r => r.json()),
    refetchInterval: 5000,
  });

  const { data: device } = useQuery<DeviceInfo>({
    queryKey: ["/api/device"],
    queryFn: () => apiRequest("GET", "/api/device").then(r => r.json()),
    staleTime: Infinity, // device profile doesn't change at runtime
  });

  const refresh = () => {
    setRefreshKey(k => k + 1);
    refetchConfig();
    refetchLatest();
  };

  const temp = latest?.cputin ?? 0;
  const isWarning  = temp >= 75;
  const isCritical = temp >= 85;

  // Derive a short subtitle for the header
  const headerSubtitle = device
    ? device.monitoring_only
      ? `${device.device_name} · Monitor only`
      : `${device.device_name}`
    : "Fan Monitor";

  return (
    <div className="flex flex-col min-h-screen" style={{ background: "#0d0d0d" }} data-testid="shell">

      {/* ═══════════════════════════════════════════════════════════════
          TOP HEADER
          ═══════════════════════════════════════════════════════════════ */}
      <header
        className="flex items-center justify-between px-5 h-14 shrink-0"
        style={{ background: "#111111", borderBottom: "1px solid #222" }}
        data-testid="header"
      >
        {/* Logo block */}
        <div className="flex items-center gap-3">
          <div
            className="w-9 h-9 rounded-lg flex items-center justify-center font-black text-white text-lg"
            style={{ background: "linear-gradient(135deg, #e55c2f 0%, #f08030 100%)" }}
          >
            M
          </div>
          <div>
            <div className="font-semibold text-sm text-white leading-tight">ProxFansX</div>
            <div className="text-xs" style={{ color: "#666" }}>{headerSubtitle}</div>
          </div>
        </div>

        {/* Right: node info + status + controls */}
        <div className="flex items-center gap-4">
          {/* Device chip pill */}
          {device && (
            <div className="flex items-center gap-1.5 text-xs font-mono" style={{ color: "#666" }}>
              <span style={{ color: "#444" }}>chip:</span>
              <span className="text-white">{device.chip}</span>
            </div>
          )}

          {/* Node */}
          <div className="flex items-center gap-2 text-xs" style={{ color: "#888" }}>
            <Wind size={13} style={{ color: "#666" }} />
            <span className="text-white font-medium">
              {device?.device_name?.toLowerCase().replace(/\s+/g, "-") ?? "proxfansx"}
            </span>
          </div>

          {/* Status badge */}
          {latest && (
            <div
              className="flex items-center gap-1.5 px-2.5 py-1 rounded-md text-xs font-semibold"
              style={{
                background: isCritical ? "#3f1111" : isWarning ? "#3a2800" : "#0d2a1a",
                color: isCritical ? "#f87171" : isWarning ? "#fbbf24" : "#4ade80",
                border: `1px solid ${isCritical ? "#7f1d1d" : isWarning ? "#78350f" : "#14532d"}`,
              }}
              data-testid="status-badge"
            >
              {isCritical || isWarning ? <AlertTriangle size={11} /> : <CheckCircle size={11} />}
              {isCritical ? "Critical" : isWarning ? "Warning" : "OK"}
            </div>
          )}

          {/* Sensor pill */}
          {latest && (
            <div className="flex items-center gap-3 text-xs font-mono" style={{ color: "#666" }}>
              <span>{device?.temp_sensor ?? "CPUTIN"}: <span style={{ color: tempColor(temp) }}>{temp.toFixed(1)}°C</span></span>
              {!device?.monitoring_only && (
                <>
                  <span>fan1: <span style={{ color: "#60a5fa" }}>{latest.fan1rpm ?? 0} RPM</span></span>
                  <span>fan2: <span style={{ color: "#60a5fa" }}>{latest.fan2rpm ?? 0} RPM</span></span>
                </>
              )}
            </div>
          )}

          {/* Refresh */}
          <button
            onClick={refresh}
            className="flex items-center gap-1.5 text-xs px-2.5 py-1.5 rounded-md transition-colors"
            style={{ color: "#aaa", background: "#1a1a1a", border: "1px solid #2a2a2a" }}
            data-testid="btn-refresh"
          >
            <RefreshCw size={12} />
            Refresh
          </button>

          {/* Theme toggle */}
          <button
            onClick={() => setDark(!dark)}
            className="flex items-center justify-center w-8 h-8 rounded-md transition-colors"
            style={{ color: "#aaa", background: "#1a1a1a", border: "1px solid #2a2a2a" }}
            data-testid="theme-toggle"
            aria-label="Toggle theme"
          >
            {dark ? <Sun size={13} /> : <Moon size={13} />}
          </button>
        </div>
      </header>

      {/* ═══════════════════════════════════════════════════════════════
          TAB BAR
          ═══════════════════════════════════════════════════════════════ */}
      <div
        className="flex items-center px-5 gap-1"
        style={{ background: "#111111", borderBottom: "1px solid #222", height: 48 }}
        data-testid="tab-bar"
      >
        {TABS.map(tab => {
          // Hide Fan Curve / Presets / Commands tabs in monitoring-only mode
          if (device?.monitoring_only && ["fancurve", "presets", "commands"].includes(tab.id)) {
            return null;
          }
          const active = activeTab === tab.id;
          return (
            <button
              key={tab.id}
              onClick={() => setActiveTab(tab.id)}
              className="px-5 py-1.5 rounded-md text-sm font-medium transition-all"
              style={{
                background: active ? "#3b82f6" : "transparent",
                color: active ? "#fff" : "#666",
              }}
              data-testid={`tab-${tab.id}`}
            >
              {tab.label}
            </button>
          );
        })}
      </div>

      {/* ═══════════════════════════════════════════════════════════════
          MONITORING-ONLY BANNER
          ═══════════════════════════════════════════════════════════════ */}
      {device?.monitoring_only && (
        <div
          className="flex items-center gap-2 px-5 py-2.5 text-xs"
          style={{ background: "#1a1f3a", borderBottom: "1px solid #1e3a5f", color: "#93b4e8" }}
          data-testid="monitoring-only-banner"
        >
          <Info size={13} style={{ color: "#3b82f6", flexShrink: 0 }} />
          <span>
            <strong className="text-white">Monitoring mode</strong> — {device.chip} does not expose
            PWM fan control. Temperature monitoring is active.
            {device.notes && ` ${device.notes}`}
          </span>
        </div>
      )}

      {/* ═══════════════════════════════════════════════════════════════
          MAIN CONTENT
          ═══════════════════════════════════════════════════════════════ */}
      <main className="flex-1 overflow-y-auto px-5 py-5" data-testid="main-content">
        <div key={refreshKey}>
          {activeTab === "overview"      && <OverviewTab config={config} latest={latest} device={device} />}
          {activeTab === "fancurve"      && !device?.monitoring_only && <FanCurveTab config={config} />}
          {activeTab === "presets"       && !device?.monitoring_only && <PresetsTab config={config} />}
          {activeTab === "commands"      && !device?.monitoring_only && <CommandsTab config={config} />}
          {activeTab === "compatibility" && <CompatibilityTab />}
        </div>
      </main>

      {/* ═══════════════════════════════════════════════════════════════
          BOTTOM LOG STRIP
          ═══════════════════════════════════════════════════════════════ */}
      <LogStrip />
    </div>
  );
}

function tempColor(t: number): string {
  if (t < 60) return "#4ade80";
  if (t < 70) return "#fbbf24";
  if (t < 80) return "#fb923c";
  return "#f87171";
}
