import { useEffect, useRef, useState } from "react";
import { IconCamera, IconCrop, IconUpload } from "./Icons";
import CameraSheet from "./CameraSheet";

interface Props {
  onFile: (file: File) => void;
  error?: string | null;
}

export default function UploadScreen({ onFile, error }: Props) {
  const inputRef = useRef<HTMLInputElement>(null);
  const captureRef = useRef<HTMLInputElement>(null);
  const [drag, setDrag] = useState(false);
  const [camera, setCamera] = useState(false);

  const hasGUM =
    typeof navigator !== "undefined" &&
    !!navigator.mediaDevices?.getUserMedia &&
    (window.isSecureContext ?? true);

  useEffect(() => {
    const onPaste = (e: ClipboardEvent) => {
      const item = [...(e.clipboardData?.items ?? [])].find((i) =>
        i.type.startsWith("image/"),
      );
      const f = item?.getAsFile();
      if (f) onFile(f);
    };
    window.addEventListener("paste", onPaste);
    return () => window.removeEventListener("paste", onPaste);
  }, [onFile]);

  const pick = (files: FileList | null) => {
    const f = files?.[0];
    if (f) onFile(f);
  };

  return (
    <div className="relative flex min-h-[100dvh] flex-col items-center justify-center overflow-hidden bg-neutral-950 px-5 py-10 text-white">
      <div className="pointer-events-none absolute -top-40 left-1/2 h-[520px] w-[520px] -translate-x-1/2 rounded-full bg-amber-500/15 blur-[120px]" />
      <div className="pointer-events-none absolute -bottom-52 right-0 h-[420px] w-[420px] rounded-full bg-indigo-500/10 blur-[120px]" />

      <div className="relative w-full max-w-xl">
        <div className="mb-8 text-center">
          <div className="mx-auto mb-5 inline-flex h-14 w-14 items-center justify-center rounded-2xl bg-gradient-to-br from-amber-300 to-amber-500 text-neutral-900 shadow-lg shadow-amber-500/25">
            <IconCrop className="h-7 w-7" strokeWidth={2} />
          </div>
          <h1 className="text-[27px] font-semibold tracking-tight sm:text-4xl">
            Bild zuschneiden &amp; skalieren
          </h1>
          <p className="mx-auto mt-2.5 max-w-md text-[14.5px] leading-relaxed text-white/55">
            Bild wählen, Ausschnitt ziehen, begradigen – fertig. Alles passiert
            direkt auf deinem Gerät, nichts wird hochgeladen.
          </p>
        </div>

        <div
          onDragOver={(e) => {
            e.preventDefault();
            setDrag(true);
          }}
          onDragLeave={() => setDrag(false)}
          onDrop={(e) => {
            e.preventDefault();
            setDrag(false);
            pick(e.dataTransfer.files);
          }}
          onClick={() => inputRef.current?.click()}
          className={`group cursor-pointer rounded-3xl border-2 border-dashed p-8 text-center transition sm:p-12 ${
            drag
              ? "border-amber-400 bg-amber-400/10"
              : "border-white/15 bg-white/[0.03] hover:border-white/30 hover:bg-white/[0.06]"
          }`}
        >
          <div className="mx-auto mb-4 flex h-12 w-12 items-center justify-center rounded-full bg-white/10 text-white/80 transition group-hover:bg-white/15">
            <IconUpload className="h-6 w-6" />
          </div>
          <p className="text-[15px] font-medium">
            Bild hierher ziehen oder tippen
          </p>
          <p className="mt-1 text-[12.5px] text-white/45">
            JPG · PNG · WebP · HEIC · GIF — auch Einfügen mit ⌘/Strg + V
          </p>
        </div>

        <div className="mt-3 grid grid-cols-2 gap-3">
          <button
            onClick={() => inputRef.current?.click()}
            className="flex items-center justify-center gap-2 rounded-2xl bg-white py-3.5 text-[14px] font-semibold text-neutral-900 transition active:scale-[0.98]"
          >
            <IconUpload className="h-4.5 w-4.5" strokeWidth={2} />
            Bild wählen
          </button>
          <button
            onClick={() => {
              if (hasGUM) setCamera(true);
              else captureRef.current?.click();
            }}
            className="flex items-center justify-center gap-2 rounded-2xl bg-white/10 py-3.5 text-[14px] font-semibold text-white transition hover:bg-white/15 active:scale-[0.98]"
          >
            <IconCamera className="h-4.5 w-4.5" strokeWidth={2} />
            Foto aufnehmen
          </button>
        </div>

        {error && (
          <p className="mt-4 rounded-xl bg-red-500/15 px-4 py-3 text-center text-[13px] text-red-300">
            {error}
          </p>
        )}

        <div className="mt-8 grid grid-cols-3 gap-2 text-center text-[11.5px] text-white/40">
          {[
            ["Touch & Maus", "Ziehen, pinchen, zoomen"],
            ["Auto-Zoom", "Ausschnitt füllt den Screen"],
            ["Begradigen", "±45° mit Feindrehung"],
          ].map(([t, s]) => (
            <div key={t} className="rounded-xl bg-white/[0.04] px-2 py-3">
              <div className="font-semibold text-white/70">{t}</div>
              <div className="mt-0.5">{s}</div>
            </div>
          ))}
        </div>
      </div>

      <input
        ref={inputRef}
        type="file"
        accept="image/*"
        className="hidden"
        onChange={(e) => {
          pick(e.target.files);
          e.target.value = "";
        }}
      />
      <input
        ref={captureRef}
        type="file"
        accept="image/*"
        capture="environment"
        className="hidden"
        onChange={(e) => {
          pick(e.target.files);
          e.target.value = "";
        }}
      />

      {camera && (
        <CameraSheet
          onClose={() => setCamera(false)}
          onCapture={(f) => {
            setCamera(false);
            onFile(f);
          }}
        />
      )}
    </div>
  );
}
