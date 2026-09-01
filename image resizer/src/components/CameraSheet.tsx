import { useCallback, useEffect, useRef, useState } from "react";
import { IconClose, IconSwitchCam } from "./Icons";

interface Props {
  onCapture: (file: File) => void;
  onClose: () => void;
}

export default function CameraSheet({ onCapture, onClose }: Props) {
  const videoRef = useRef<HTMLVideoElement>(null);
  const streamRef = useRef<MediaStream | null>(null);
  const [facing, setFacing] = useState<"environment" | "user">("environment");
  const [error, setError] = useState<string | null>(null);
  const [ready, setReady] = useState(false);

  const stop = useCallback(() => {
    streamRef.current?.getTracks().forEach((t) => t.stop());
    streamRef.current = null;
  }, []);

  useEffect(() => {
    let dead = false;
    setReady(false);
    setError(null);
    (async () => {
      try {
        stop();
        const s = await navigator.mediaDevices.getUserMedia({
          video: {
            facingMode: { ideal: facing },
            width: { ideal: 3840 },
            height: { ideal: 2160 },
          },
          audio: false,
        });
        if (dead) {
          s.getTracks().forEach((t) => t.stop());
          return;
        }
        streamRef.current = s;
        if (videoRef.current) {
          videoRef.current.srcObject = s;
          await videoRef.current.play().catch(() => undefined);
        }
        setReady(true);
      } catch {
        setError(
          "Kamera nicht verfügbar. Bitte Zugriff erlauben oder ein Bild hochladen.",
        );
      }
    })();
    return () => {
      dead = true;
      stop();
    };
  }, [facing, stop]);

  const shoot = () => {
    const v = videoRef.current;
    if (!v || !v.videoWidth) return;
    const c = document.createElement("canvas");
    c.width = v.videoWidth;
    c.height = v.videoHeight;
    const ctx = c.getContext("2d")!;
    if (facing === "user") {
      ctx.translate(c.width, 0);
      ctx.scale(-1, 1);
    }
    ctx.drawImage(v, 0, 0);
    c.toBlob(
      (b) => {
        if (!b) return;
        stop();
        onCapture(
          new File([b], `foto-${Date.now()}.jpg`, { type: "image/jpeg" }),
        );
      },
      "image/jpeg",
      0.95,
    );
  };

  return (
    <div className="fixed inset-0 z-50 flex flex-col bg-black">
      <div className="relative flex-1 overflow-hidden">
        <video
          ref={videoRef}
          playsInline
          muted
          autoPlay
          className="h-full w-full object-cover"
          style={{ transform: facing === "user" ? "scaleX(-1)" : undefined }}
        />
        {!ready && !error && (
          <div className="absolute inset-0 flex items-center justify-center text-sm text-white/60">
            Kamera wird gestartet …
          </div>
        )}
        {error && (
          <div className="absolute inset-0 flex items-center justify-center p-8 text-center text-sm text-white/70">
            {error}
          </div>
        )}
        <button
          onClick={() => {
            stop();
            onClose();
          }}
          className="absolute left-4 top-4 rounded-full bg-black/50 p-2.5 text-white backdrop-blur"
        >
          <IconClose className="h-5 w-5" />
        </button>
        <button
          onClick={() => setFacing((f) => (f === "user" ? "environment" : "user"))}
          className="absolute right-4 top-4 rounded-full bg-black/50 p-2.5 text-white backdrop-blur"
        >
          <IconSwitchCam className="h-5 w-5" />
        </button>
      </div>
      <div className="flex items-center justify-center bg-black py-6 pb-[max(env(safe-area-inset-bottom),24px)]">
        <button
          onClick={shoot}
          disabled={!ready}
          className="h-18 w-18 rounded-full border-4 border-white/90 p-1 transition active:scale-95 disabled:opacity-40"
          style={{ width: 74, height: 74 }}
        >
          <span className="block h-full w-full rounded-full bg-white" />
        </button>
      </div>
    </div>
  );
}
