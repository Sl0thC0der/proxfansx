import { useState } from "react";
import { useQuery } from "@tanstack/react-query";
import { apiRequest } from "@/lib/queryClient";
import type { SensorLog } from "@shared/schema";
import { ChevronUp, ChevronDown, Activity } from "lucide-react";

function tempColor(t: number): string {
  if (t < 60) return "#4ade80";
  if (t < 70) return "#fbbf24";
  if (t < 80) return "#fb923c";
  return "#f87171";
}

export default function LogStrip() {
  const [expanded, setExpanded] = useState(false);

  const { data: log = [] } = useQuery<SensorLog[]>({
    queryKey: ["/api/sensors"],
    queryFn: () => apiRequest("GET", "/api/sensors").then(r => r.json()),
    refetchInterval: 5000,
  });

  const reversed = [...log].reverse().slice(0, 30);
  const latest = log[log.length - 1];

  return (
    <div
      style={{
        flexShrink: 0,
        borderTop: "1px solid #1e1e1e",
        background: "#0d0d0d",
        height: expanded ? 200 : 34,
        transition: "height 0.2s ease",
        display: "flex",
        flexDirection: "column",
        overflow: "hidden",
      }}
      data-testid="log-strip"
    >
      {/* Toggle bar */}
      <button
        style={{
          display: "flex",
          alignItems: "center",
          gap: 10,
          padding: "0 14px",
          height: 34,
          flexShrink: 0,
          width: "100%",
          background: "transparent",
          border: "none",
          cursor: "pointer",
          textAlign: "left",
          borderBottom: expanded ? "1px solid #1e1e1e" : "none",
        }}
        onClick={() => setExpanded(!expanded)}
        data-testid="log-strip-toggle"
      >
        {/* Label */}
        <div style={{ display: "flex", alignItems: "center", gap: 6 }}>
          <Activity size={11} color="#3b82f6" />
          <span
            style={{
              fontSize: 11,
              fontWeight: 600,
              color: "#3b82f6",
              textTransform: "uppercase",
              letterSpacing: "0.06em",
            }}
          >
            Sensor Log
          </span>
          <span
            style={{
              fontSize: 10,
              color: "#444",
              marginLeft: 2,
            }}
          >
            History
          </span>
        </div>

        {/* Live inline values when collapsed */}
        {!expanded && latest && (
          <div
            style={{
              display: "flex",
              alignItems: "center",
              gap: 14,
              marginLeft: 8,
              fontFamily: "JetBrains Mono, monospace",
            }}
          >
            <span style={{ fontSize: 11, color: tempColor(latest.cputin ?? 0) }}>
              {(latest.cputin ?? 0).toFixed(1)}°C
            </span>
            <span style={{ fontSize: 11, color: "#4ade80" }}>
              {latest.fan1rpm ?? 0} RPM
            </span>
            <span style={{ fontSize: 11, color: "#555" }}>
              PWM {latest.pwm1 ?? 0}
            </span>
          </div>
        )}

        {/* Chevron */}
        <div style={{ marginLeft: "auto" }}>
          {expanded
            ? <ChevronDown size={12} color="#555" />
            : <ChevronUp size={12} color="#555" />
          }
        </div>
      </button>

      {/* Log table */}
      {expanded && (
        <div style={{ flex: 1, overflowY: "auto" }}>
          <table
            style={{
              width: "100%",
              borderCollapse: "collapse",
              fontSize: 11,
              fontFamily: "JetBrains Mono, monospace",
            }}
          >
            <thead>
              <tr>
                {["Timestamp", "CPUTIN", "Fan1 RPM", "Fan2 RPM", "PWM1", "PWM2"].map(h => (
                  <th
                    key={h}
                    style={{
                      padding: "4px 14px",
                      textAlign: "left",
                      fontWeight: 500,
                      color: "#444",
                      borderBottom: "1px solid #1a1a1a",
                      letterSpacing: "0.04em",
                    }}
                  >
                    {h}
                  </th>
                ))}
              </tr>
            </thead>
            <tbody>
              {reversed.map(row => (
                <tr
                  key={row.id}
                  style={{ borderBottom: "1px solid #111" }}
                  data-testid={`log-row-${row.id}`}
                >
                  <td style={{ padding: "3px 14px", color: "#444" }}>
                    {new Date(row.timestamp).toLocaleTimeString()}
                  </td>
                  <td style={{ padding: "3px 14px", color: tempColor(row.cputin ?? 0) }}>
                    {(row.cputin ?? 0).toFixed(1)}°C
                  </td>
                  <td style={{ padding: "3px 14px", color: "#4ade80" }}>
                    {row.fan1rpm ?? 0}
                  </td>
                  <td style={{ padding: "3px 14px", color: "#4ade80" }}>
                    {row.fan2rpm ?? 0}
                  </td>
                  <td style={{ padding: "3px 14px", color: "#888" }}>
                    {row.pwm1 ?? 0}
                  </td>
                  <td style={{ padding: "3px 14px", color: "#888" }}>
                    {row.pwm2 ?? 0}
                  </td>
                </tr>
              ))}
              {reversed.length === 0 && (
                <tr>
                  <td
                    colSpan={6}
                    style={{
                      padding: "10px 14px",
                      textAlign: "center",
                      color: "#333",
                      fontFamily: "Inter, sans-serif",
                    }}
                  >
                    No sensor data yet — collecting…
                  </td>
                </tr>
              )}
            </tbody>
          </table>
        </div>
      )}
    </div>
  );
}
