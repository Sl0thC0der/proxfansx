import { useState, useRef } from "react";
import { useQuery, useMutation, useQueryClient } from "@tanstack/react-query";
import { apiRequest } from "@/lib/queryClient";
import type { Preset, FanConfig } from "@shared/schema";
import { Button } from "@/components/ui/button";
import { Input } from "@/components/ui/input";
import { useToast } from "@/hooks/use-toast";
import { Dialog, DialogContent, DialogHeader, DialogTitle, DialogTrigger } from "@/components/ui/dialog";
import { Check, Trash2, Upload, Lock, FileUp, Database } from "lucide-react";

interface Props { config?: FanConfig; }

export default function PresetsTab({ config }: Props) {
  const qc = useQueryClient();
  const { toast } = useToast();
  const [uploadOpen, setUploadOpen] = useState(false);

  const { data: presets = [], isLoading } = useQuery<Preset[]>({
    queryKey: ["/api/presets"],
    queryFn: () => apiRequest("GET", "/api/presets").then(r => r.json()),
  });

  const applyMut = useMutation({
    mutationFn: (id: number) => apiRequest("POST", `/api/presets/${id}/apply`).then(r => r.json()),
    onSuccess: () => { qc.invalidateQueries({ queryKey: ["/api/config"] }); toast({ title: "Preset applied" }); },
    onError: () => toast({ title: "Error", variant: "destructive" }),
  });

  const deleteMut = useMutation({
    mutationFn: (id: number) => apiRequest("DELETE", `/api/presets/${id}`).then(r => r.json()),
    onSuccess: () => { qc.invalidateQueries({ queryKey: ["/api/presets"] }); toast({ title: "Deleted" }); },
    onError: () => toast({ title: "Error", variant: "destructive" }),
  });

  const builtIn = presets.filter(p => p.isBuiltIn);
  const custom   = presets.filter(p => !p.isBuiltIn);

  return (
    <div className="max-w-6xl mx-auto space-y-5">

      {/* Header */}
      <div className="flex items-center justify-between">
        <div className="flex items-center gap-2">
          <Database size={16} style={{ color: "#3b82f6" }} />
          <h2 className="text-base font-semibold text-white">Fan Curve Presets</h2>
          <span className="text-xs" style={{ color: "#555" }}>Apply a preset or import your own /etc/fancontrol</span>
        </div>
        <Dialog open={uploadOpen} onOpenChange={setUploadOpen}>
          <DialogTrigger asChild>
            <Button
              size="sm"
              className="text-xs h-8 gap-1.5"
              style={{ background: "#1a1a1a", border: "1px solid #333", color: "#aaa" }}
              data-testid="btn-upload-open"
            >
              <Upload size={12} /> Import Config File
            </Button>
          </DialogTrigger>
          <DialogContent style={{ background: "#141414", borderColor: "#2a2a2a" }}>
            <DialogHeader>
              <DialogTitle className="text-white">Import /etc/fancontrol</DialogTitle>
            </DialogHeader>
            <UploadForm onSuccess={() => { setUploadOpen(false); qc.invalidateQueries({ queryKey: ["/api/presets"] }); }} />
          </DialogContent>
        </Dialog>
      </div>

      {/* Built-in section */}
      <Section title="Built-in Presets" icon={<Lock size={12} />}>
        {isLoading ? <LoadingRows /> : builtIn.map(p => (
          <PresetRow key={p.id} preset={p} config={config}
            onApply={() => applyMut.mutate(p.id)} isApplying={applyMut.isPending} />
        ))}
      </Section>

      {/* Custom section */}
      <Section title="Custom / Imported" icon={<FileUp size={12} />}>
        {custom.length === 0 ? <EmptyState /> : custom.map(p => (
          <PresetRow key={p.id} preset={p} config={config}
            onApply={() => applyMut.mutate(p.id)}
            onDelete={() => deleteMut.mutate(p.id)}
            isApplying={applyMut.isPending} />
        ))}
      </Section>
    </div>
  );
}

function Section({ title, icon, children }: { title: string; icon: React.ReactNode; children: React.ReactNode }) {
  return (
    <div className="rounded-xl border overflow-hidden" style={{ borderColor: "#242424" }}>
      <div
        className="flex items-center gap-2 px-4 py-2.5 border-b text-xs font-semibold text-white uppercase tracking-wider"
        style={{ background: "#1a1a1a", borderColor: "#242424", color: "#888" }}
      >
        <span style={{ color: "#3b82f6" }}>{icon}</span>
        <span>{title}</span>
      </div>
      <div style={{ background: "#111" }}>{children}</div>
    </div>
  );
}

function PresetRow({ preset, config, onApply, onDelete, isApplying }: {
  preset: Preset; config?: FanConfig;
  onApply: () => void; onDelete?: () => void; isApplying: boolean;
}) {
  const isActive = config &&
    config.mintemp === preset.mintemp && config.maxtemp === preset.maxtemp &&
    config.minstart === preset.minstart && config.minstop === preset.minstop &&
    config.minpwm === preset.minpwm && config.maxpwm === preset.maxpwm;

  return (
    <div
      className="flex items-center gap-3 px-4 py-3 border-b text-xs transition-colors"
      style={{ borderColor: "#1a1a1a", background: isActive ? "rgba(59,130,246,0.06)" : "transparent" }}
      data-testid={`preset-row-${preset.id}`}
    >
      {/* Active check */}
      <div className="w-4 shrink-0 flex justify-center">
        {isActive && <Check size={13} style={{ color: "#3b82f6" }} />}
      </div>

      {/* Name + desc */}
      <div className="flex-1 min-w-0">
        <div className="flex items-center gap-2 mb-0.5">
          <span className="font-semibold text-white">{preset.name}</span>
          {preset.isBuiltIn && (
            <span className="text-xs px-1.5 py-0.5 rounded font-mono" style={{ background: "#1e1e1e", color: "#666" }}>
              built-in
            </span>
          )}
          {isActive && (
            <span className="text-xs px-1.5 py-0.5 rounded" style={{ background: "rgba(59,130,246,0.2)", color: "#60a5fa" }}>
              active
            </span>
          )}
        </div>
        {preset.description && (
          <div className="truncate" style={{ color: "#555" }}>{preset.description}</div>
        )}
      </div>

      {/* Param pills */}
      <div className="flex gap-1.5 shrink-0">
        {[
          [`OFF@${preset.mintemp}°`],
          [`MAX@${preset.maxtemp}°`],
          [`MIN_PWM=${preset.minpwm}`],
          [`INT=${preset.interval}s`],
        ].map(([v]) => (
          <span key={v} className="font-mono text-xs px-2 py-0.5 rounded"
            style={{ background: "#1a1a1a", color: "#555", border: "1px solid #2a2a2a" }}>
            {v}
          </span>
        ))}
      </div>

      {/* Actions */}
      <div className="flex gap-1.5 shrink-0">
        <Button
          size="sm"
          className="text-xs h-7 px-3"
          style={isActive
            ? { background: "#1a1a1a", border: "1px solid #333", color: "#60a5fa" }
            : { background: "#3b82f6", color: "#fff" }
          }
          onClick={onApply}
          disabled={isApplying || isActive as boolean}
          data-testid={`btn-apply-${preset.id}`}
        >
          {isActive ? "Active" : "Apply"}
        </Button>
        {onDelete && !preset.isBuiltIn && (
          <Button
            size="sm"
            variant="ghost"
            className="h-7 w-7 p-0"
            onClick={onDelete}
            data-testid={`btn-delete-${preset.id}`}
          >
            <Trash2 size={12} style={{ color: "#f87171" }} />
          </Button>
        )}
      </div>
    </div>
  );
}

function UploadForm({ onSuccess }: { onSuccess: () => void }) {
  const { toast } = useToast();
  const [name, setName] = useState("");
  const [desc, setDesc] = useState("");
  const [file, setFile] = useState<File | null>(null);
  const fileRef = useRef<HTMLInputElement>(null);
  const [loading, setLoading] = useState(false);

  const submit = async (e: React.FormEvent) => {
    e.preventDefault();
    if (!file) return;
    setLoading(true);
    try {
      const fd = new FormData();
      fd.append("file", file);
      fd.append("name", name || file.name.replace(/\.[^.]+$/, ""));
      fd.append("description", desc);
      const res = await fetch("/api/presets/upload", { method: "POST", body: fd });
      if (!res.ok) throw new Error((await res.json()).error);
      toast({ title: "Imported successfully" });
      onSuccess();
    } catch (err: any) {
      toast({ title: "Import failed", description: err.message, variant: "destructive" });
    } finally { setLoading(false); }
  };

  return (
    <form onSubmit={submit} className="space-y-4 pt-2" data-testid="upload-form">
      <div className="space-y-1.5">
        <label className="text-xs font-medium text-white">Config file</label>
        <div
          className="border-2 border-dashed rounded-lg p-6 text-center cursor-pointer"
          style={{ borderColor: file ? "#3b82f6" : "#2a2a2a", background: "#0f0f0f" }}
          onClick={() => fileRef.current?.click()}
          data-testid="upload-dropzone"
        >
          <FileUp size={22} className="mx-auto mb-2" style={{ color: "#444" }} />
          {file
            ? <p className="text-xs font-medium" style={{ color: "#3b82f6" }}>{file.name}</p>
            : <p className="text-xs" style={{ color: "#555" }}>Click to select your <code>/etc/fancontrol</code> file</p>
          }
        </div>
        <input ref={fileRef} type="file" className="hidden" accept="*" onChange={e => setFile(e.target.files?.[0] ?? null)} data-testid="file-input" />
      </div>
      <div className="space-y-1.5">
        <label className="text-xs font-medium text-white">Preset name</label>
        <Input value={name} onChange={e => setName(e.target.value)} placeholder="My custom preset"
          className="h-8 text-xs" style={{ background: "#1a1a1a", borderColor: "#333", color: "#e5e5e5" }} data-testid="input-preset-name" />
      </div>
      <div className="space-y-1.5">
        <label className="text-xs font-medium text-white">Description (optional)</label>
        <Input value={desc} onChange={e => setDesc(e.target.value)} placeholder="Short description"
          className="h-8 text-xs" style={{ background: "#1a1a1a", borderColor: "#333", color: "#e5e5e5" }} data-testid="input-preset-description" />
      </div>
      <Button type="submit" disabled={!file || loading} className="w-full text-xs"
        style={{ background: "#3b82f6", color: "#fff" }} data-testid="btn-import-submit">
        <Upload size={12} className="mr-1.5" />
        {loading ? "Importing…" : "Import Preset"}
      </Button>
    </form>
  );
}

function LoadingRows() {
  return <>{[1,2,3].map(i => (
    <div key={i} className="px-4 py-3 border-b animate-pulse" style={{ borderColor: "#1a1a1a" }}>
      <div className="h-3 rounded w-1/3 mb-1.5" style={{ background: "#1e1e1e" }} />
      <div className="h-2.5 rounded w-2/3" style={{ background: "#1a1a1a" }} />
    </div>
  ))}</>;
}

function EmptyState() {
  return (
    <div className="flex flex-col items-center py-10 gap-2" style={{ color: "#444" }}>
      <FileUp size={28} />
      <p className="text-xs">No custom presets yet. Import a /etc/fancontrol file.</p>
    </div>
  );
}
