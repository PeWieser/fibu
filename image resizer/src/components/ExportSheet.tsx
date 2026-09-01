import { useEffect, useMemo, useRef, useState } from "react";
import type { Rect, View } from "../lib/geometry";
import { canvasToBlob, formatBytes, renderCrop } from "../lib/exportImage";
import { IconClose, IconDownload, IconLink, IconUnlink } from "./Icons";

interface Props {
  img: HTMLImageElement;
  iw: number;
  ih: number;
  rot90: number;
  flip: boolean;
  view: View;
  crop: Rect;
  cw: number;
  ch: number;
  fileName: string;
  onClose: () => void;
}

const FORMATS = [
  { label: "JPEG", type: "image/jpeg", ext: "jpg" },
  { label: "PNG", type: "image/png", ext: "png" },
  { label: "WebP", type: "image/webp", ext: "webp" },
];

export default function ExportSheet(p: Props) {
  const natW = Math.max(1, Math.round(p.crop.w / p.view.scale));
  const natH = Math.max(1, Math.round(p.crop.h / p.view.scale));
  const ratio = natW / natH;

  const [w, setW] = useState(natW);
  const [h, setH] = useState(natH);
  const [lock, setLock] = useState(true);
  const [fmt, setFmt] = useState(FORMATS[0]);
  const [quality, setQuality] = useState(0.9);
  const [blob, setBlob] = useState<Blob | null>(null);
  const [url, setUrl] = useState<string>("");
  const [busy, setBusy] = useState(true);
  const [copied, setCopied] = useState(false);
  const urlRef = useRef("");

  const setWidth = (v: number) => {
    const nv = Math.max(1, Math.min(20000, Math.round(v || 1)));
    setW(nv);
    if (lock) setH(Math.max(1, Math.round(nv / ratio)));
  };
  const setHeight = (v: number) => {
    const nv = Math.max(1, Math.min(20000, Math.round(v || 1)));
    setH(nv);
    if (lock) setW(Math.max(1, Math.round(nv * ratio)));
  };

  const baseName = useMemo(
    () => p.fileName.replace(/\.[^./\\]+$/, "") || "bild",
    [p.fileName],
  );

  useEffect(() => {
    let cancelled = false;
    setBusy(true);
    const t = window.setTimeout(async () => {
      try {
        const canvas = renderCrop({
          img: p.img,
          iw: p.iw,
          ih: p.ih,
          rot90: p.rot90,
          flip: p.flip,
          view: p.view,
          crop: p.crop,
          cw: p.cw,
          ch: p.ch,
          outW: w,
          outH: h,
          background: fmt.type === "image/jpeg" ? "#ffffff" : undefined,
        });
        const b = await canvasToBlob(canvas, fmt.type, quality);
        if (cancelled) return;
        if (urlRef.current) URL.revokeObjectURL(urlRef.current);
        const u = URL.createObjectURL(b);
        urlRef.current = u;
        setBlob(b);
        setUrl(u);
      } catch {
        /* noop */
      } finally {
        if (!cancelled) setBusy(false);
      }
    }, 260);
    return () => {
      cancelled = true;
      clearTimeout(t);
    };
    // eslint-disable-next-line react-hooks/exhaustive-deps
  }, [w, h, fmt, quality]);

  useEffect(
    () => () => {
      if (urlRef.current) URL.revokeObjectURL(urlRef.current);
    },
    [],
  );

  const download = () => {
    if (!blob) return;
    const a = document.createElement("a");
    a.href = URL.createObjectURL(blob);
    a.download = `${baseName}-${w}x${h}.${fmt.ext}`;
    document.body.appendChild(a);
    a.click();
    setTimeout(() => {
      URL.revokeObjectURL(a.href);
      a.remove();
    }, 1000);
  };

  const copy = async () => {
    if (!blob) return;
    try {
      await navigator.clipboard.write([
        new ClipboardItem({ [blob.type]: blob }),
      ]);
      setCopied(true);
      setTimeout(() => setCopied(false), 1600);
    } catch {
      /* not supported */
    }
  };

  const percents = [100, 75, 50, 25];
  const widths = [3840, 2048, 1920, 1280, 800, 400];

  return (
    <div className="fixed inset-0 z-50 flex items-end justify-center bg-black/70 backdrop-blur-sm sm:items-center">
      <div
        className="absolute inset-0"
        onClick={onCloseSafe(p.onClose)}
        aria-hidden
      />
      <div className="relative flex max-h-[92dvh] w-full max-w-lg flex-col overflow-hidden rounded-t-3xl border border-white/10 bg-neutral-900 text-white shadow-2xl sm:rounded-3xl">
        <div className="flex items-center justify-between px-5 pt-4">
          <h2 className="text-base font-semibold">Exportieren</h2>
          <button
            onClick={p.onClose}
            className="rounded-full p-2 text-white/60 transition hover:bg-white/10 hover:text-white"
          >
            <IconClose className="h-5 w-5" />
          </button>
        </div>

        <div className="min-h-0 flex-1 space-y-4 overflow-y-auto px-5 pb-4 pt-3">
          <div className="flex h-44 items-center justify-center overflow-hidden rounded-2xl bg-[repeating-conic-gradient(#2a2a2a_0_25%,#232323_0_50%)] bg-[length:20px_20px]">
            {url ? (
              <img
                src={url}
                alt="Vorschau"
                className="max-h-44 max-w-full object-contain"
              />
            ) : (
              <span className="text-xs text-white/40">Rendern …</span>
            )}
          </div>

          <div className="flex items-end gap-2">
            <Field label="Breite (px)">
              <input
                type="number"
                inputMode="numeric"
                value={w}
                onChange={(e) => setWidth(Number(e.target.value))}
                className="w-full rounded-xl bg-white/[0.07] px-3 py-2.5 text-sm tabular-nums outline-none ring-amber-400/60 focus:ring-2"
              />
            </Field>
            <button
              onClick={() => setLock((l) => !l)}
              title="Seitenverhältnis sperren"
              className={`mb-1 rounded-xl p-2.5 transition ${
                lock
                  ? "bg-amber-400/20 text-amber-300"
                  : "bg-white/[0.07] text-white/50"
              }`}
            >
              {lock ? (
                <IconLink className="h-4.5 w-4.5" />
              ) : (
                <IconUnlink className="h-4.5 w-4.5" />
              )}
            </button>
            <Field label="Höhe (px)">
              <input
                type="number"
                inputMode="numeric"
                value={h}
                onChange={(e) => setHeight(Number(e.target.value))}
                className="w-full rounded-xl bg-white/[0.07] px-3 py-2.5 text-sm tabular-nums outline-none ring-amber-400/60 focus:ring-2"
              />
            </Field>
          </div>

          <div className="flex flex-wrap gap-1.5">
            {percents.map((pc) => (
              <Chip
                key={pc}
                active={w === Math.round((natW * pc) / 100)}
                onClick={() => {
                  setW(Math.max(1, Math.round((natW * pc) / 100)));
                  setH(Math.max(1, Math.round((natH * pc) / 100)));
                }}
              >
                {pc}%
              </Chip>
            ))}
            {widths
              .filter((x) => x <= natW * 2)
              .map((x) => (
                <Chip key={x} active={w === x} onClick={() => setWidth(x)}>
                  {x}px
                </Chip>
              ))}
          </div>

          <div className="flex gap-1.5">
            {FORMATS.map((f) => (
              <button
                key={f.type}
                onClick={() => setFmt(f)}
                className={`flex-1 rounded-xl py-2 text-[13px] font-medium transition ${
                  fmt.type === f.type
                    ? "bg-white text-neutral-900"
                    : "bg-white/[0.07] text-white/75 hover:bg-white/15"
                }`}
              >
                {f.label}
              </button>
            ))}
          </div>

          {fmt.type !== "image/png" && (
            <div>
              <div className="mb-1 flex justify-between text-[12px] text-white/55">
                <span>Qualität</span>
                <span className="tabular-nums">
                  {Math.round(quality * 100)}%
                </span>
              </div>
              <input
                type="range"
                min={0.3}
                max={1}
                step={0.01}
                value={quality}
                onChange={(e) => setQuality(Number(e.target.value))}
                className="w-full accent-amber-400"
              />
            </div>
          )}

          <div className="flex items-center justify-between rounded-xl bg-white/[0.05] px-3.5 py-2.5 text-[12.5px]">
            <span className="text-white/55">
              Original-Ausschnitt: {natW} × {natH} px
            </span>
            <span className="font-semibold tabular-nums text-white/85">
              {busy || !blob ? "…" : formatBytes(blob.size)}
            </span>
          </div>
        </div>

        <div className="flex gap-2 border-t border-white/10 bg-neutral-900 px-5 py-3 pb-[max(env(safe-area-inset-bottom),12px)]">
          <button
            onClick={copy}
            className="rounded-xl bg-white/[0.08] px-4 py-3 text-sm font-medium text-white/80 transition hover:bg-white/15"
          >
            {copied ? "Kopiert!" : "Kopieren"}
          </button>
          <button
            onClick={download}
            disabled={!blob}
            className="flex flex-1 items-center justify-center gap-2 rounded-xl bg-amber-400 py-3 text-sm font-semibold text-neutral-900 transition active:scale-[0.98] disabled:opacity-50"
          >
            <IconDownload className="h-4.5 w-4.5" />
            Herunterladen
          </button>
        </div>
      </div>
    </div>
  );
}

const onCloseSafe = (fn: () => void) => () => fn();

function Field({
  label,
  children,
}: {
  label: string;
  children: React.ReactNode;
}) {
  return (
    <label className="flex-1">
      <span className="mb-1 block text-[11.5px] font-medium text-white/50">
        {label}
      </span>
      {children}
    </label>
  );
}

function Chip({
  children,
  active,
  onClick,
}: {
  children: React.ReactNode;
  active?: boolean;
  onClick: () => void;
}) {
  return (
    <button
      onClick={onClick}
      className={`rounded-full px-3 py-1.5 text-[12px] font-medium transition ${
        active
          ? "bg-amber-400 text-neutral-900"
          : "bg-white/[0.07] text-white/70 hover:bg-white/15"
      }`}
    >
      {children}
    </button>
  );
}
