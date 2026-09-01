export interface Rect {
  x: number;
  y: number;
  w: number;
  h: number;
}

/** View transform: screen = C + T + scale * R(angle) * q  (q = oriented image space, origin = image center) */
export interface View {
  scale: number;
  tx: number;
  ty: number;
  angle: number; // radians (straighten only)
}

export const TAU = Math.PI * 2;

export function rot(a: number, x: number, y: number) {
  const c = Math.cos(a);
  const s = Math.sin(a);
  return { x: x * c - y * s, y: x * s + y * c };
}

export function orientedSize(iw: number, ih: number, r90: number) {
  const k = ((r90 % 4) + 4) % 4;
  return k % 2 === 0 ? { ew: iw, eh: ih } : { ew: ih, eh: iw };
}

export function rectCenter(r: Rect) {
  return { x: r.x + r.w / 2, y: r.y + r.h / 2 };
}

export function lerp(a: number, b: number, t: number) {
  return a + (b - a) * t;
}

export function lerpRect(a: Rect, b: Rect, t: number): Rect {
  return {
    x: lerp(a.x, b.x, t),
    y: lerp(a.y, b.y, t),
    w: lerp(a.w, b.w, t),
    h: lerp(a.h, b.h, t),
  };
}

export function lerpView(a: View, b: View, t: number): View {
  return {
    scale: lerp(a.scale, b.scale, t),
    tx: lerp(a.tx, b.tx, t),
    ty: lerp(a.ty, b.ty, t),
    angle: lerp(a.angle, b.angle, t),
  };
}

export const easeInOutCubic = (t: number) =>
  t < 0.5 ? 4 * t * t * t : 1 - Math.pow(-2 * t + 2, 3) / 2;

/** Corners of the crop rect expressed in oriented image space (image pixels, origin center). */
export function cropCornersInImage(
  crop: Rect,
  view: View,
  cw: number,
  ch: number,
) {
  const cx = cw / 2;
  const cy = ch / 2;
  const pts: Array<[number, number]> = [
    [crop.x, crop.y],
    [crop.x + crop.w, crop.y],
    [crop.x + crop.w, crop.y + crop.h],
    [crop.x, crop.y + crop.h],
  ];
  return pts.map(([px, py]) => {
    const d = rot(-view.angle, px - cx - view.tx, py - cy - view.ty);
    return { x: d.x / view.scale, y: d.y / view.scale };
  });
}

/** Smallest scale so that a crop of this size (at `angle`) can still be fully covered by the image. */
export function minScaleFor(crop: Rect, angle: number, ew: number, eh: number) {
  const c = Math.abs(Math.cos(angle));
  const s = Math.abs(Math.sin(angle));
  return Math.max((crop.w * c + crop.h * s) / ew, (crop.w * s + crop.h * c) / eh);
}

/** Force the crop rect to stay covered by the image by growing scale / shifting translation. */
export function clampView(
  view: View,
  crop: Rect,
  cw: number,
  ch: number,
  ew: number,
  eh: number,
): View {
  const v: View = { ...view };
  const min = minScaleFor(crop, v.angle, ew, eh);
  if (v.scale < min) v.scale = min;

  const pts = cropCornersInImage(crop, v, cw, ch);
  const xs = pts.map((p) => p.x);
  const ys = pts.map((p) => p.y);
  const minX = Math.min(...xs);
  const maxX = Math.max(...xs);
  const minY = Math.min(...ys);
  const maxY = Math.max(...ys);

  let dx = 0;
  let dy = 0;
  if (maxX - minX >= ew) dx = -(minX + maxX) / 2;
  else if (minX < -ew / 2) dx = -ew / 2 - minX;
  else if (maxX > ew / 2) dx = ew / 2 - maxX;

  if (maxY - minY >= eh) dy = -(minY + maxY) / 2;
  else if (minY < -eh / 2) dy = -eh / 2 - minY;
  else if (maxY > eh / 2) dy = eh / 2 - maxY;

  if (dx !== 0 || dy !== 0) {
    const d = rot(v.angle, dx * v.scale, dy * v.scale);
    v.tx -= d.x;
    v.ty -= d.y;
  }
  return v;
}

export function cropIsInsideImage(
  crop: Rect,
  view: View,
  cw: number,
  ch: number,
  ew: number,
  eh: number,
  eps = 0.5,
) {
  const pts = cropCornersInImage(crop, view, cw, ch);
  return pts.every(
    (p) =>
      p.x >= -ew / 2 - eps &&
      p.x <= ew / 2 + eps &&
      p.y >= -eh / 2 - eps &&
      p.y <= eh / 2 + eps,
  );
}

/** Largest rect with `aspect` (w/h) that fits centered inside `safe`. */
export function fitRect(safe: Rect, aspect: number): Rect {
  let w = safe.w;
  let h = w / aspect;
  if (h > safe.h) {
    h = safe.h;
    w = h * aspect;
  }
  return {
    x: safe.x + (safe.w - w) / 2,
    y: safe.y + (safe.h - h) / 2,
    w,
    h,
  };
}

/**
 * Apple-Photos style auto zoom: the crop rect grows to fill the safe area and the
 * image transform follows so that exactly the same pixels stay visible.
 */
export function computeFitTarget(
  crop: Rect,
  view: View,
  safe: Rect,
  cw: number,
  ch: number,
) {
  const target = fitRect(safe, crop.w / crop.h);
  const k = target.w / crop.w;
  const cc = rectCenter(crop);
  const tc = rectCenter(target);
  const C = { x: cw / 2, y: ch / 2 };
  const nextView: View = {
    angle: view.angle,
    scale: view.scale * k,
    tx: tc.x + k * (C.x + view.tx - cc.x) - C.x,
    ty: tc.y + k * (C.y + view.ty - cc.y) - C.y,
  };
  return { crop: target, view: nextView, k };
}

export function clampRectToBounds(r: Rect, b: Rect): Rect {
  const w = Math.min(r.w, b.w);
  const h = Math.min(r.h, b.h);
  return {
    w,
    h,
    x: Math.min(Math.max(r.x, b.x), b.x + b.w - w),
    y: Math.min(Math.max(r.y, b.y), b.y + b.h - h),
  };
}

/** Largest rect with given aspect, centered on `center`, fitting inside safe area AND the image. */
export function largestValidCrop(
  aspect: number,
  center: { x: number; y: number },
  safe: Rect,
  view: View,
  cw: number,
  ch: number,
  ew: number,
  eh: number,
): Rect {
  const build = (w: number): Rect => {
    const h = w / aspect;
    return { x: center.x - w / 2, y: center.y - h / 2, w, h };
  };
  const maxW = Math.min(safe.w, safe.h * aspect);
  let lo = 8;
  let hi = maxW;
  const ok = (w: number) => {
    const r = build(w);
    if (
      r.x < safe.x - 0.5 ||
      r.y < safe.y - 0.5 ||
      r.x + r.w > safe.x + safe.w + 0.5 ||
      r.y + r.h > safe.y + safe.h + 0.5
    )
      return false;
    return cropIsInsideImage(r, view, cw, ch, ew, eh);
  };
  if (ok(hi)) return build(hi);
  for (let i = 0; i < 24; i++) {
    const mid = (lo + hi) / 2;
    if (ok(mid)) lo = mid;
    else hi = mid;
  }
  return build(lo);
}

export function rectInside(r: Rect, b: Rect, eps = 0.5) {
  return (
    r.x >= b.x - eps &&
    r.y >= b.y - eps &&
    r.x + r.w <= b.x + b.w + eps &&
    r.y + r.h <= b.y + b.h + eps
  );
}

/**
 * Interpolate between a known-valid rect and a desired rect until it is valid again.
 * Interpolation keeps the aspect ratio intact (unlike hard clamping).
 */
export function resolveCrop(
  from: Rect,
  to: Rect,
  view: View,
  safe: Rect,
  cw: number,
  ch: number,
  ew: number,
  eh: number,
): Rect {
  const valid = (r: Rect) =>
    rectInside(r, safe) && cropIsInsideImage(r, view, cw, ch, ew, eh);
  if (valid(to)) return to;
  let lo = 0;
  let hi = 1;
  for (let i = 0; i < 22; i++) {
    const mid = (lo + hi) / 2;
    if (valid(lerpRect(from, to, mid))) lo = mid;
    else hi = mid;
  }
  return lerpRect(from, to, lo);
}
