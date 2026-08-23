import type { ReactNode } from "react";

const cornerPath =
  "M5.50871e-06 0C-0.00788227 37.3001 8.99616 50.0116 50 50H5.50871e-06V0Z";

export function SiteFrame(): ReactNode {
  return (
    <>
      <div className="site-frame site-frame--top" aria-hidden="true" />
      <div className="site-frame site-frame--bottom" aria-hidden="true" />
      <div className="site-frame site-frame--left" aria-hidden="true" />
      <div className="site-frame site-frame--right" aria-hidden="true" />
      {(["top-left", "top-right", "bottom-left", "bottom-right"] as const).map(
        (position) => (
          <svg
            key={position}
            className={`site-corner site-corner--${position}`}
            width="50"
            height="50"
            viewBox="0 0 50 50"
            fill="none"
            aria-hidden="true"
          >
            <path d={cornerPath} fill="currentColor" />
          </svg>
        ),
      )}
    </>
  );
}
