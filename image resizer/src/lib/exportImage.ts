import type { Rect, View } from "./geometry";

export interface RenderOptions {
  img: CanvasImageSource;
  iw: number;
  ih: number;
  rot90: number;
  flip: boolean;
  view: View;
  crop: Rect;
  cw: number;
  ch: number;
  outW: number;
  outH: number;
  background?: string;
}

export function renderCrop(o: RenderOptions): HTMLCanvasElement {
  const canvas = document.createElement("canvas");
  canvas.width = Math.max(1, Math.round(o.outW));
  canvas.height = Math.max(1, Math.round(o.outH));
  const ctx = canvas.getContext("2d")!;
  ctx.imageSmoothingEnabled = true;
  ctx.imageSmoothingQuality = "high";

  if (o.background) {
    ctx.fillStyle = o.background;
    ctx.fillRect(0, 0, canvas.width, canvas.height);
  }

  const k = canvas.width / o.crop.w; // screen px -> output px
  const C = { x: o.cw / 2, y: o.ch / 2 };

  ctx.save();
  ctx.translate((C.x + o.view.tx - o.crop.x) * k, (C.y + o.view.ty - o.crop.y) * k);
  ctx.rotate(o.view.angle);
  ctx.scale(o.view.scale * k, o.view.scale * k);
  // oriented image space: q = M0 * R90 * p
  ctx.scale(o.flip ? -1 : 1, 1);
  ctx.rotate((((o.rot90 % 4) + 4) % 4) * (Math.PI / 2));
  ctx.drawImage(o.img, -o.iw / 2, -o.ih / 2, o.iw, o.ih);
  ctx.restore();
  return canvas;
}

export function canvasToBlob(
  canvas: HTMLCanvasElement,
  type: string,
  quality: number,
): Promise<Blob> {
  return new Promise((resolve, reject) => {
    canvas.toBlob(
      (b) => (b ? resolve(b) : reject(new Error("Export fehlgeschlagen"))),
      type,
      quality,
    );
  });
}

export function formatBytes(bytes: number) {
  if (bytes < 1024) return `${bytes} B`;
  if (bytes < 1024 * 1024) return `${(bytes / 1024).toFixed(0)} KB`;
  return `${(bytes / (1024 * 1024)).toFixed(2)} MB`;
}
