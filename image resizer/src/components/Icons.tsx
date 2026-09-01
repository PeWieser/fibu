import type { SVGProps } from "react";

const base = (p: SVGProps<SVGSVGElement>) => ({
  viewBox: "0 0 24 24",
  fill: "none",
  stroke: "currentColor",
  strokeWidth: 1.8,
  strokeLinecap: "round" as const,
  strokeLinejoin: "round" as const,
  ...p,
});

export const IconUpload = (p: SVGProps<SVGSVGElement>) => (
  <svg {...base(p)}>
    <path d="M12 16V4" />
    <path d="m7 9 5-5 5 5" />
    <path d="M4 15v3a2 2 0 0 0 2 2h12a2 2 0 0 0 2-2v-3" />
  </svg>
);

export const IconCamera = (p: SVGProps<SVGSVGElement>) => (
  <svg {...base(p)}>
    <path d="M3 8.5A2.5 2.5 0 0 1 5.5 6h1.9c.5 0 .96-.26 1.24-.68l.72-1.1A1.5 1.5 0 0 1 10.6 3.5h2.8c.5 0 .97.25 1.25.67l.72 1.1c.28.42.74.73 1.24.73h1.9A2.5 2.5 0 0 1 21 8.5v9a2.5 2.5 0 0 1-2.5 2.5h-13A2.5 2.5 0 0 1 3 17.5z" />
    <circle cx="12" cy="13" r="3.6" />
  </svg>
);

export const IconCrop = (p: SVGProps<SVGSVGElement>) => (
  <svg {...base(p)}>
    <path d="M6.5 2v15.5H22" />
    <path d="M2 6.5h15.5V22" />
  </svg>
);

export const IconRotate = (p: SVGProps<SVGSVGElement>) => (
  <svg {...base(p)}>
    <rect x="3" y="10" width="11" height="11" rx="2" />
    <path d="M14 4h2a5 5 0 0 1 5 5v2" />
    <path d="m18.5 8.5 2.5 2.8 2.2-2.8" transform="translate(-2.3 0)" />
  </svg>
);

export const IconFlip = (p: SVGProps<SVGSVGElement>) => (
  <svg {...base(p)}>
    <path d="M12 3v18" />
    <path d="M9 7 4 12l5 5z" />
    <path d="M15 7l5 5-5 5z" />
  </svg>
);

export const IconUndo = (p: SVGProps<SVGSVGElement>) => (
  <svg {...base(p)}>
    <path d="M3 7v6h6" />
    <path d="M3.5 13a9 9 0 1 1 2.2 6" />
  </svg>
);

export const IconCheck = (p: SVGProps<SVGSVGElement>) => (
  <svg {...base(p)}>
    <path d="m4 12.5 5.2 5.2L20 7" />
  </svg>
);

export const IconClose = (p: SVGProps<SVGSVGElement>) => (
  <svg {...base(p)}>
    <path d="M6 6l12 12M18 6 6 18" />
  </svg>
);

export const IconDownload = (p: SVGProps<SVGSVGElement>) => (
  <svg {...base(p)}>
    <path d="M12 4v12" />
    <path d="m7 11 5 5 5-5" />
    <path d="M4 20h16" />
  </svg>
);

export const IconSwitchCam = (p: SVGProps<SVGSVGElement>) => (
  <svg {...base(p)}>
    <path d="M4 8a8 8 0 0 1 13.3-6" />
    <path d="M20 16A8 8 0 0 1 6.7 22" />
    <path d="M17 2v4h-4" />
    <path d="M7 22v-4h4" />
  </svg>
);

export const IconLink = (p: SVGProps<SVGSVGElement>) => (
  <svg {...base(p)}>
    <path d="M10 13a5 5 0 0 0 7.5.5l2-2A5 5 0 0 0 12.5 4.4l-1.1 1.1" />
    <path d="M14 11a5 5 0 0 0-7.5-.5l-2 2A5 5 0 0 0 11.5 19.6l1.1-1.1" />
  </svg>
);

export const IconUnlink = (p: SVGProps<SVGSVGElement>) => (
  <svg {...base(p)}>
    <path d="M9.5 14.5 6 18" />
    <path d="M14.5 9.5 18 6" />
    <path d="M10 13a5 5 0 0 0 3 1.4" />
    <path d="M14 11a5 5 0 0 0-3-1.4" />
    <path d="M4 4l16 16" />
  </svg>
);
