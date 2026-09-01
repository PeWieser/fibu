import { useCallback, useEffect, useMemo, useRef, useState } from "react";
import {
  clampView,
  computeFitTarget,
  easeInOutCubic,
  fitRect,
  largestValidCrop,
  lerpRect,
  lerpView,
  orientedSize,
  rectCenter,
  resolveCrop,
  rot,
  type Rect,
  type View,
} from "../lib/geometry";
import StraightenDial from "./StraightenDial";
import ExportSheet from "./ExportSheet";
import {
  IconCheck,
  IconClose,
  IconFlip,
  IconRotate,
  IconUndo,
} from "./Icons";

interface EditorState {
  view: View;
  crop: Rect;
}

interface Props {
  img: HTMLImageElement;
  fileName: string;
  onReset: () => void;
}

const MIN_CROP = 52;
const FIT_DELAY = 380;
const FIT_DURATION = 520;

const ASPECTS: Array<{ label: string; value: number | null | "original" }> = [
  { label: "Frei", value: null },
  { label: "Original", value: "original" },
  { label: "1:1", value: 1 },
  { label: "4:5", value: 4 / 5 },
  { label: "3:4", value: 3 / 4 },
  { label: "2:3", value: 2 / 3 },
  { label: "9:16", value: 9 / 16 },
  { label: "5:4", value: 5 / 4 },
  { label: "4:3", value: 4 / 3 },
  { label: "3:2", value: 3 / 2 },
  { label: "16:9", value: 16 / 9 },
];

export default function CropEditor({ img, fileName, onReset }: Props) {
  const stageRef = useRef<HTMLDivElement>(null);
  const [size, setSize] = useState({ cw: 0, ch: 0 });
  const [st, setStState] = useState<EditorState | null>(null);
  const [rot90, setRot90] = useState(0);
  const [flip, setFlip] = useState(false);
  const [aspectKey, setAspectKey] = useState<string>("Frei");
  const [straight, setStraight] = useState(0); // degrees
  const [active, setActive] = useState(false);
  const [showExport, setShowExport] = useState(false);
  const [hint, setHint] = useState(true);

  useEffect(() => {
    const t = window.setTimeout(() => setHint(false), 4200);
    return () => clearTimeout(t);
  }, []);

  const stRef = useRef<EditorState | null>(null);
  const setSt = useCallback((v: EditorState) => {
    stRef.current = v;
    setStState(v);
  }, []);

  const iw = img.naturalWidth;
  const ih = img.naturalHeight;
  const { ew, eh } = useMemo(() => orientedSize(iw, ih, rot90), [iw, ih, rot90]);
  const dims = useRef({ ew, eh });
  dims.current = { ew, eh };

  const sizeRef = useRef(size);
  sizeRef.current = size;

  const safe = useMemo<Rect>(() => {
    const pad = Math.min(30, Math.max(10, Math.min(size.cw, size.ch) * 0.05));
    return {
      x: pad,
      y: pad,
      w: Math.max(40, size.cw - pad * 2),
      h: Math.max(40, size.ch - pad * 2),
    };
  }, [size]);
  const safeRef = useRef(safe);
  safeRef.current = safe;

  /* ---------------- measure ---------------- */
  useEffect(() => {
    const el = stageRef.current;
    if (!el) return;
    const ro = new ResizeObserver(() => {
      const r = el.getBoundingClientRect();
      setSize({ cw: r.width, ch: r.height });
    });
    ro.observe(el);
    const r = el.getBoundingClientRect();
    setSize({ cw: r.width, ch: r.height });
    return () => ro.disconnect();
  }, []);

  /* ---------------- animation ---------------- */
  const anim = useRef<{
    from: EditorState;
    to: EditorState;
    t0: number;
    dur: number;
    raf: number;
  } | null>(null);
  const fitTimer = useRef<number | null>(null);

  const stopAnim = useCallback(() => {
    if (anim.current) {
      cancelAnimationFrame(anim.current.raf);
      anim.current = null;
    }
  }, []);

  const animateTo = useCallback(
    (to: EditorState, dur = FIT_DURATION) => {
      const from = stRef.current;
      if (!from) return;
      stopAnim();
      const step = () => {
        const a = anim.current;
        if (!a) return;
        const t = Math.min(1, (performance.now() - a.t0) / a.dur);
        const e = easeInOutCubic(t);
        setSt({
          view: lerpView(a.from.view, a.to.view, e),
          crop: lerpRect(a.from.crop, a.to.crop, e),
        });
        if (t < 1) a.raf = requestAnimationFrame(step);
        else anim.current = null;
      };
      anim.current = { from, to, t0: performance.now(), dur, raf: 0 };
      anim.current.raf = requestAnimationFrame(step);
    },
    [setSt, stopAnim],
  );

  const cancelPending = useCallback(() => {
    if (fitTimer.current) {
      clearTimeout(fitTimer.current);
      fitTimer.current = null;
    }
    stopAnim();
  }, [stopAnim]);

  const doFit = useCallback(
    (dur = FIT_DURATION) => {
      const s = stRef.current;
      const { cw, ch } = sizeRef.current;
      if (!s || !cw || !ch) return;
      const t = computeFitTarget(s.crop, s.view, safeRef.current, cw, ch);
      const cA = rectCenter(s.crop);
      const cB = rectCenter(t.crop);
      if (
        Math.abs(t.k - 1) < 0.003 &&
        Math.hypot(cA.x - cB.x, cA.y - cB.y) < 0.6
      )
        return;
      animateTo({ view: t.view, crop: t.crop }, dur);
    },
    [animateTo],
  );

  const scheduleFit = useCallback(
    (delay = FIT_DELAY) => {
      if (fitTimer.current) clearTimeout(fitTimer.current);
      fitTimer.current = window.setTimeout(() => {
        fitTimer.current = null;
        doFit();
      }, delay);
    },
    [doFit],
  );

  useEffect(() => () => cancelPending(), [cancelPending]);

  /* ---------------- init / reset ---------------- */
  const initialise = useCallback(() => {
    const { cw, ch } = sizeRef.current;
    if (!cw || !ch) return;
    const d = dims.current;
    const crop = fitRect(safeRef.current, d.ew / d.eh);
    setSt({
      crop,
      view: { scale: crop.w / d.ew, tx: 0, ty: 0, angle: 0 },
    });
  }, [setSt]);

  useEffect(() => {
    if (!st && size.cw > 0 && size.ch > 0) initialise();
    // eslint-disable-next-line react-hooks/exhaustive-deps
  }, [size, st]);

  // re-fit on viewport changes (rotate device / resize window)
  const lastSize = useRef({ cw: 0, ch: 0 });
  useEffect(() => {
    if (!stRef.current || !size.cw) return;
    if (lastSize.current.cw === 0) {
      lastSize.current = size;
      return;
    }
    if (
      Math.abs(lastSize.current.cw - size.cw) < 2 &&
      Math.abs(lastSize.current.ch - size.ch) < 2
    )
      return;
    lastSize.current = size;
    cancelPending();
    doFit(280);
  }, [size, doFit, cancelPending]);

  const fullReset = () => {
    cancelPending();
    setRot90(0);
    setFlip(false);
    setStraight(0);
    setAspectKey("Frei");
    dims.current = orientedSize(iw, ih, 0);
    requestAnimationFrame(initialise);
  };

  /* ---------------- gestures ---------------- */
  const pointers = useRef(new Map<number, { x: number; y: number }>());
  const gesture = useRef<
    | null
    | { type: "pan"; p0: { x: number; y: number }; view: View }
    | {
        type: "pinch";
        d0: number;
        m0: { x: number; y: number };
        view: View;
      }
    | {
        type: "handle";
        h: string;
        p0: { x: number; y: number };
        crop: Rect;
      }
  >(null);
  const stageRect = useRef<DOMRect | null>(null);

  const toLocal = (e: { clientX: number; clientY: number }) => {
    const r = stageRect.current!;
    return { x: e.clientX - r.left, y: e.clientY - r.top };
  };

  const currentAspect = useMemo(() => {
    const a = ASPECTS.find((x) => x.label === aspectKey);
    if (!a || a.value === null) return null;
    if (a.value === "original") return ew / eh;
    return a.value;
  }, [aspectKey, ew, eh]);
  const aspectRef = useRef<number | null>(currentAspect);
  aspectRef.current = currentAspect;

  const beginPanOrPinch = () => {
    const s = stRef.current;
    if (!s) return;
    const pts = [...pointers.current.values()];
    if (pts.length >= 2) {
      const [a, b] = pts;
      gesture.current = {
        type: "pinch",
        d0: Math.max(1, Math.hypot(a.x - b.x, a.y - b.y)),
        m0: { x: (a.x + b.x) / 2, y: (a.y + b.y) / 2 },
        view: s.view,
      };
    } else if (pts.length === 1) {
      gesture.current = { type: "pan", p0: pts[0], view: s.view };
    } else {
      gesture.current = null;
    }
  };

  const onPointerDown = (e: React.PointerEvent) => {
    if (!stRef.current) return;
    const el = stageRef.current!;
    stageRect.current = el.getBoundingClientRect();
    el.setPointerCapture(e.pointerId);
    pointers.current.set(e.pointerId, toLocal(e));
    cancelPending();
    setActive(true);
    setHint(false);
    const handle = (e.target as HTMLElement).dataset?.handle;
    if (handle && pointers.current.size === 1) {
      gesture.current = {
        type: "handle",
        h: handle,
        p0: toLocal(e),
        crop: stRef.current.crop,
      };
    } else {
      beginPanOrPinch();
    }
  };

  const onPointerMove = (e: React.PointerEvent) => {
    if (!pointers.current.has(e.pointerId) || !stRef.current) return;
    pointers.current.set(e.pointerId, toLocal(e));
    const g = gesture.current;
    const s = stRef.current;
    const { cw, ch } = sizeRef.current;
    const { ew: EW, eh: EH } = dims.current;
    if (!g) return;

    if (g.type === "pan") {
      const p = pointers.current.get(e.pointerId)!;
      const v: View = {
        ...g.view,
        tx: g.view.tx + (p.x - g.p0.x),
        ty: g.view.ty + (p.y - g.p0.y),
      };
      setSt({ crop: s.crop, view: clampView(v, s.crop, cw, ch, EW, EH) });
      return;
    }

    if (g.type === "pinch") {
      const pts = [...pointers.current.values()];
      if (pts.length < 2) return;
      const [a, b] = pts;
      const d = Math.max(1, Math.hypot(a.x - b.x, a.y - b.y));
      const m = { x: (a.x + b.x) / 2, y: (a.y + b.y) / 2 };
      const ratio = Math.min(8, Math.max(0.05, d / g.d0));
      const nextScale = Math.min(12, g.view.scale * ratio);
      const C = { x: cw / 2, y: ch / 2 };
      const f = nextScale / g.view.scale;
      const v: View = {
        ...g.view,
        scale: nextScale,
        tx: m.x - C.x - f * (g.m0.x - C.x - g.view.tx),
        ty: m.y - C.y - f * (g.m0.y - C.y - g.view.ty),
      };
      setSt({ crop: s.crop, view: clampView(v, s.crop, cw, ch, EW, EH) });
      return;
    }

    if (g.type === "handle") {
      const p = pointers.current.get(e.pointerId)!;
      const dx = p.x - g.p0.x;
      const dy = p.y - g.p0.y;
      const c = g.crop;
      let left = c.x;
      let top = c.y;
      let right = c.x + c.w;
      let bottom = c.y + c.h;
      const h = g.h;
      if (h.includes("w")) left = c.x + dx;
      if (h.includes("e")) right = c.x + c.w + dx;
      if (h.includes("n")) top = c.y + dy;
      if (h.includes("s")) bottom = c.y + c.h + dy;

      // keep inside the safe area (per edge -> feels natural with free ratio)
      const sf = safeRef.current;
      left = Math.min(Math.max(left, sf.x), right - 8);
      top = Math.min(Math.max(top, sf.y), bottom - 8);
      right = Math.max(Math.min(right, sf.x + sf.w), left + 8);
      bottom = Math.max(Math.min(bottom, sf.y + sf.h), top + 8);

      const a = aspectRef.current;
      const applyAspect = () => {
        if (!a) return;
        let nw = right - left;
        let nh = bottom - top;
        const corner = h.length === 2;
        if (corner) {
          if (nw / a > nh) nh = nw / a;
          else nw = nh * a;
        } else if (h === "n" || h === "s") nw = nh * a;
        else nh = nw / a;
        if (h.includes("w")) left = right - nw;
        else if (h.includes("e")) right = left + nw;
        else {
          const m = (left + right) / 2;
          left = m - nw / 2;
          right = m + nw / 2;
        }
        if (h.includes("n")) top = bottom - nh;
        else if (h.includes("s")) bottom = top + nh;
        else {
          const m = (top + bottom) / 2;
          top = m - nh / 2;
          bottom = m + nh / 2;
        }
      };
      applyAspect();

      // minimum size
      const minW = a ? Math.max(MIN_CROP, MIN_CROP * a) : MIN_CROP;
      const minH = a ? minW / a : MIN_CROP;
      if (right - left < minW) {
        if (h.includes("w")) left = right - minW;
        else if (h.includes("e")) right = left + minW;
        else {
          const m = (left + right) / 2;
          left = m - minW / 2;
          right = m + minW / 2;
        }
      }
      if (bottom - top < minH) {
        if (h.includes("n")) top = bottom - minH;
        else if (h.includes("s")) bottom = top + minH;
        else {
          const m = (top + bottom) / 2;
          top = m - minH / 2;
          bottom = m + minH / 2;
        }
      }

      const desired: Rect = {
        x: left,
        y: top,
        w: right - left,
        h: bottom - top,
      };
      const next = resolveCrop(
        g.crop,
        desired,
        s.view,
        safeRef.current,
        cw,
        ch,
        EW,
        EH,
      );
      setSt({ view: s.view, crop: next });
    }
  };

  const endPointer = (e: React.PointerEvent) => {
    if (!pointers.current.has(e.pointerId)) return;
    pointers.current.delete(e.pointerId);
    try {
      stageRef.current?.releasePointerCapture(e.pointerId);
    } catch {
      /* noop */
    }
    if (pointers.current.size === 0) {
      gesture.current = null;
      setActive(false);
      scheduleFit();
    } else {
      beginPanOrPinch();
    }
  };

  const onWheel = (e: WheelEvent) => {
    e.preventDefault();
    const s = stRef.current;
    if (!s) return;
    const el = stageRef.current!;
    stageRect.current = el.getBoundingClientRect();
    const p = toLocal(e);
    const { cw, ch } = sizeRef.current;
    const { ew: EW, eh: EH } = dims.current;
    cancelPending();
    const factor = Math.exp(-e.deltaY * 0.0018);
    const nextScale = Math.min(12, s.view.scale * factor);
    const C = { x: cw / 2, y: ch / 2 };
    const f = nextScale / s.view.scale;
    const v: View = {
      ...s.view,
      scale: nextScale,
      tx: p.x - C.x - f * (p.x - C.x - s.view.tx),
      ty: p.y - C.y - f * (p.y - C.y - s.view.ty),
    };
    setSt({ crop: s.crop, view: clampView(v, s.crop, cw, ch, EW, EH) });
    scheduleFit(260);
  };

  const wheelRef = useRef(onWheel);
  wheelRef.current = onWheel;
  useEffect(() => {
    const el = stageRef.current;
    if (!el) return;
    const h = (e: WheelEvent) => wheelRef.current(e);
    el.addEventListener("wheel", h, { passive: false });
    return () => el.removeEventListener("wheel", h);
  }, []);

  /* ---------------- tools ---------------- */
  const onStraighten = (deg: number) => {
    const s = stRef.current;
    if (!s) return;
    cancelPending();
    setStraight(deg);
    const v = clampView(
      { ...s.view, angle: (deg * Math.PI) / 180 },
      s.crop,
      size.cw,
      size.ch,
      ew,
      eh,
    );
    setSt({ crop: s.crop, view: v });
  };

  const rotate90 = () => {
    const s = stRef.current;
    if (!s) return;
    cancelPending();
    const dir = flip ? -1 : 1;
    const theta = Math.PI / 2;
    const C = { x: size.cw / 2, y: size.ch / 2 };
    const cc = rectCenter(s.crop);
    const nc = rot(theta, cc.x - C.x, cc.y - C.y);
    const t = rot(theta, s.view.tx, s.view.ty);
    const crop: Rect = {
      w: s.crop.h,
      h: s.crop.w,
      x: C.x + nc.x - s.crop.h / 2,
      y: C.y + nc.y - s.crop.w / 2,
    };
    const nextRot = (((rot90 + dir) % 4) + 4) % 4;
    const d = orientedSize(iw, ih, nextRot);
    dims.current = d;
    setRot90(nextRot);
    if (aspectKey !== "Frei" && aspectKey !== "Original") {
      // keep chosen ratio: the rotated crop no longer matches -> switch to free
      setAspectKey("Frei");
    }
    const view = clampView(
      { ...s.view, tx: t.x, ty: t.y },
      crop,
      size.cw,
      size.ch,
      d.ew,
      d.eh,
    );
    // fit immediately: the rotated crop can stick out of the safe area
    const fitted = computeFitTarget(crop, view, safeRef.current, size.cw, size.ch);
    setSt({ crop: fitted.crop, view: fitted.view });
  };

  const doFlip = () => {
    const s = stRef.current;
    if (!s) return;
    cancelPending();
    const C = { x: size.cw / 2, y: size.ch / 2 };
    const cc = rectCenter(s.crop);
    const crop: Rect = {
      ...s.crop,
      x: C.x - (cc.x - C.x) - s.crop.w / 2,
    };
    const view: View = {
      ...s.view,
      tx: -s.view.tx,
      angle: -s.view.angle,
    };
    setStraight((v) => -v);
    setFlip((f) => !f);
    setSt({
      crop,
      view: clampView(view, crop, size.cw, size.ch, ew, eh),
    });
  };

  const chooseAspect = (label: string) => {
    const s = stRef.current;
    if (!s) return;
    cancelPending();
    setAspectKey(label);
    const entry = ASPECTS.find((x) => x.label === label)!;
    if (entry.value === null) {
      scheduleFit(60);
      return;
    }
    const a = entry.value === "original" ? ew / eh : entry.value;
    const cc = rectCenter(s.crop);
    const crop = largestValidCrop(
      a,
      cc,
      safeRef.current,
      s.view,
      size.cw,
      size.ch,
      ew,
      eh,
    );
    setSt({ view: s.view, crop });
    requestAnimationFrame(() => doFit(420));
  };

  /* ---------------- derived ---------------- */
  const cropPixels = st
    ? {
        w: Math.max(1, Math.round(st.crop.w / st.view.scale)),
        h: Math.max(1, Math.round(st.crop.h / st.view.scale)),
      }
    : { w: 0, h: 0 };

  const showGrid = active;

  return (
    <div className="flex h-[100dvh] w-full flex-col overflow-hidden bg-neutral-950 text-white">
      {/* header */}
      <header className="flex shrink-0 items-center justify-between gap-3 px-3 py-2.5 sm:px-5">
        <button
          onClick={onReset}
          className="flex h-10 items-center gap-2 rounded-full px-3 text-sm font-medium text-white/70 transition hover:bg-white/10 hover:text-white"
        >
          <IconClose className="h-5 w-5" />
          <span className="hidden sm:inline">Neues Bild</span>
        </button>
        <div className="pointer-events-none flex flex-col items-center leading-tight">
          <span className="text-[13px] font-semibold">Zuschneiden</span>
          <span className="text-[11px] tabular-nums text-white/45">
            {cropPixels.w} × {cropPixels.h} px
          </span>
        </div>
        <button
          onClick={() => {
            cancelPending();
            setShowExport(true);
          }}
          className="flex h-10 items-center gap-2 rounded-full bg-amber-400 px-4 text-sm font-semibold text-neutral-900 shadow-lg shadow-amber-500/20 transition active:scale-95"
        >
          <IconCheck className="h-4.5 w-4.5" />
          Fertig
        </button>
      </header>

      {/* stage */}
      <div
        ref={stageRef}
        onPointerDown={onPointerDown}
        onPointerMove={onPointerMove}
        onPointerUp={endPointer}
        onPointerCancel={endPointer}
        className="relative min-h-0 flex-1 cursor-grab touch-none select-none overflow-hidden overscroll-none active:cursor-grabbing"
        style={{ touchAction: "none" }}
      >
        {st && (
          <>
            <div
              className="absolute left-1/2 top-1/2 h-0 w-0"
              style={{
                transform: `translate3d(${st.view.tx}px, ${st.view.ty}px, 0) rotate(${st.view.angle}rad) scale(${st.view.scale})`,
                willChange: "transform",
              }}
            >
              <img
                src={img.src}
                alt=""
                draggable={false}
                className="absolute select-none"
                style={{
                  left: -iw / 2,
                  top: -ih / 2,
                  width: iw,
                  height: ih,
                  maxWidth: "none",
                  transform: `scaleX(${flip ? -1 : 1}) rotate(${rot90 * 90}deg)`,
                }}
              />
            </div>

            {/* dim + frame */}
            <div className="pointer-events-none absolute inset-0">
              <div
                className="absolute"
                style={{
                  left: st.crop.x,
                  top: st.crop.y,
                  width: st.crop.w,
                  height: st.crop.h,
                  boxShadow: `0 0 0 100vmax rgba(0,0,0,${active ? 0.72 : 0.55})`,
                  transition: "box-shadow .25s ease",
                }}
              />
              <div
                className="absolute border border-white/85"
                style={{
                  left: st.crop.x,
                  top: st.crop.y,
                  width: st.crop.w,
                  height: st.crop.h,
                }}
              >
                {/* rule of thirds */}
                <div
                  className="absolute inset-0 transition-opacity duration-200"
                  style={{ opacity: showGrid ? 1 : 0 }}
                >
                  {[1, 2].map((i) => (
                    <span
                      key={`v${i}`}
                      className="absolute top-0 h-full w-px bg-white/35"
                      style={{ left: `${(i * 100) / 3}%` }}
                    />
                  ))}
                  {[1, 2].map((i) => (
                    <span
                      key={`h${i}`}
                      className="absolute left-0 h-px w-full bg-white/35"
                      style={{ top: `${(i * 100) / 3}%` }}
                    />
                  ))}
                </div>
                {/* corner brackets */}
                {(
                  [
                    ["nw", "top-[-3px] left-[-3px]", "border-t-[3px] border-l-[3px] rounded-tl-[3px]"],
                    ["ne", "top-[-3px] right-[-3px]", "border-t-[3px] border-r-[3px] rounded-tr-[3px]"],
                    ["sw", "bottom-[-3px] left-[-3px]", "border-b-[3px] border-l-[3px] rounded-bl-[3px]"],
                    ["se", "bottom-[-3px] right-[-3px]", "border-b-[3px] border-r-[3px] rounded-br-[3px]"],
                  ] as const
                ).map(([k, pos, bord]) => (
                  <span
                    key={k}
                    className={`absolute h-6 w-6 border-white ${pos} ${bord}`}
                  />
                ))}
                {/* edge ticks */}
                <span className="absolute left-1/2 top-[-2px] h-[3px] w-7 -translate-x-1/2 rounded bg-white" />
                <span className="absolute left-1/2 bottom-[-2px] h-[3px] w-7 -translate-x-1/2 rounded bg-white" />
                <span className="absolute top-1/2 left-[-2px] w-[3px] h-7 -translate-y-1/2 rounded bg-white" />
                <span className="absolute top-1/2 right-[-2px] w-[3px] h-7 -translate-y-1/2 rounded bg-white" />
              </div>

              {/* hit areas */}
              {(
                [
                  ["nw", 0, 0],
                  ["n", 0.5, 0],
                  ["ne", 1, 0],
                  ["e", 1, 0.5],
                  ["se", 1, 1],
                  ["s", 0.5, 1],
                  ["sw", 0, 1],
                  ["w", 0, 0.5],
                ] as const
              ).map(([h, fx, fy]) => (
                <div
                  key={h}
                  data-handle={h}
                  className="pointer-events-auto absolute"
                  style={{
                    left: st.crop.x + st.crop.w * fx - 26,
                    top: st.crop.y + st.crop.h * fy - 26,
                    width: 52,
                    height: 52,
                    cursor:
                      h.length === 2
                        ? `${h}-resize`
                        : h === "n" || h === "s"
                          ? "ns-resize"
                          : "ew-resize",
                  }}
                />
              ))}
            </div>

            <div
              className="pointer-events-none absolute bottom-3 left-1/2 -translate-x-1/2 rounded-full bg-black/60 px-3.5 py-1.5 text-center text-[11.5px] text-white/80 backdrop-blur transition-opacity duration-500"
              style={{ opacity: hint ? 1 : 0 }}
            >
              Ecken ziehen zum Zuschneiden · Wischen &amp; Pinch zum Bewegen
            </div>
          </>
        )}
      </div>

      {/* controls */}
      <div className="shrink-0 border-t border-white/10 bg-neutral-950/95 pb-[max(env(safe-area-inset-bottom),8px)]">
      <div className="mx-auto w-full max-w-2xl space-y-2 px-2 pt-2 sm:px-4">
        <StraightenDial
          value={straight}
          onChange={onStraighten}
          onStart={cancelPending}
          onEnd={() => scheduleFit(220)}
        />

        <div className="-mx-2 flex gap-1.5 overflow-x-auto px-2 pb-1 [scrollbar-width:none] [&::-webkit-scrollbar]:hidden">
          {ASPECTS.map((a) => (
            <button
              key={a.label}
              onClick={() => chooseAspect(a.label)}
              className={`shrink-0 rounded-full px-3.5 py-1.5 text-[12.5px] font-medium transition ${
                aspectKey === a.label
                  ? "bg-white text-neutral-900"
                  : "bg-white/10 text-white/75 hover:bg-white/15"
              }`}
            >
              {a.label}
            </button>
          ))}
        </div>

        <div className="flex items-center justify-center gap-2 pb-1">
          <ToolButton onClick={rotate90} label="Drehen">
            <IconRotate className="h-5 w-5" />
          </ToolButton>
          <ToolButton onClick={doFlip} label="Spiegeln" activeState={flip}>
            <IconFlip className="h-5 w-5" />
          </ToolButton>
          <ToolButton onClick={fullReset} label="Zurücksetzen">
            <IconUndo className="h-5 w-5" />
          </ToolButton>
        </div>
      </div>
      </div>

      {showExport && st && (
        <ExportSheet
          img={img}
          iw={iw}
          ih={ih}
          rot90={rot90}
          flip={flip}
          view={st.view}
          crop={st.crop}
          cw={size.cw}
          ch={size.ch}
          fileName={fileName}
          onClose={() => setShowExport(false)}
        />
      )}
    </div>
  );
}

function ToolButton({
  children,
  label,
  onClick,
  activeState,
}: {
  children: React.ReactNode;
  label: string;
  onClick: () => void;
  activeState?: boolean;
}) {
  return (
    <button
      onClick={onClick}
      className={`flex h-11 items-center gap-2 rounded-xl px-3.5 text-[12.5px] font-medium transition active:scale-95 ${
        activeState
          ? "bg-amber-400/20 text-amber-300"
          : "bg-white/[0.07] text-white/80 hover:bg-white/15"
      }`}
    >
      {children}
      <span>{label}</span>
    </button>
  );
}
