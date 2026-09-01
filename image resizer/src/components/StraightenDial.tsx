import { useRef } from "react";

interface Props {
  value: number; // degrees
  onChange: (deg: number) => void;
  onStart?: () => void;
  onEnd?: () => void;
  min?: number;
  max?: number;
}

const PX_PER_DEG = 7;

export default function StraightenDial({
  value,
  onChange,
  onStart,
  onEnd,
  min = -45,
  max = 45,
}: Props) {
  const drag = useRef<{ x: number; start: number } | null>(null);

  const ticks: number[] = [];
  for (let d = min; d <= max; d += 1) ticks.push(d);

  const handleDown = (e: React.PointerEvent) => {
    (e.target as Element).setPointerCapture(e.pointerId);
    drag.current = { x: e.clientX, start: value };
    onStart?.();
  };
  const handleMove = (e: React.PointerEvent) => {
    if (!drag.current) return;
    const dx = e.clientX - drag.current.x;
    let next = drag.current.start - dx / PX_PER_DEG;
    if (Math.abs(next) < 0.7) next = 0;
    onChange(Math.min(max, Math.max(min, next)));
  };
  const handleUp = (e: React.PointerEvent) => {
    if (!drag.current) return;
    drag.current = null;
    try {
      (e.target as Element).releasePointerCapture(e.pointerId);
    } catch {
      /* noop */
    }
    onEnd?.();
  };

  return (
    <div className="flex select-none flex-col items-center gap-1">
      <button
        onClick={() => {
          onChange(0);
          onEnd?.();
        }}
        className={`rounded-full px-2.5 py-0.5 text-[11px] font-semibold tabular-nums transition ${
          Math.abs(value) < 0.05
            ? "text-white/50"
            : "bg-amber-400/15 text-amber-300"
        }`}
      >
        {value > 0 ? "+" : ""}
        {value.toFixed(1)}°
      </button>
      <div
        className="relative h-11 w-full max-w-md cursor-ew-resize touch-none overflow-hidden"
        onPointerDown={handleDown}
        onPointerMove={handleMove}
        onPointerUp={handleUp}
        onPointerCancel={handleUp}
        onDoubleClick={() => {
          onChange(0);
          onEnd?.();
        }}
      >
        <div
          className="pointer-events-none absolute inset-0"
          style={{
            maskImage:
              "linear-gradient(90deg, transparent, #000 18%, #000 82%, transparent)",
            WebkitMaskImage:
              "linear-gradient(90deg, transparent, #000 18%, #000 82%, transparent)",
          }}
        >
          <div
            className="absolute top-0 h-full"
            style={{
              left: "50%",
              transform: `translateX(${-value * PX_PER_DEG}px)`,
            }}
          >
            {ticks.map((d) => {
              const major = d % 5 === 0;
              return (
                <span
                  key={d}
                  className={`absolute top-1/2 -translate-y-1/2 rounded-full ${
                    major ? "bg-white/70" : "bg-white/25"
                  }`}
                  style={{
                    left: d * PX_PER_DEG,
                    width: major ? 2 : 1.5,
                    height: major ? 18 : 9,
                    marginLeft: major ? -1 : -0.75,
                  }}
                />
              );
            })}
          </div>
        </div>
        <div className="pointer-events-none absolute left-1/2 top-1/2 h-6 w-[3px] -translate-x-1/2 -translate-y-1/2 rounded-full bg-amber-400 shadow-[0_0_10px_2px_rgba(251,191,36,0.5)]" />
      </div>
    </div>
  );
}
