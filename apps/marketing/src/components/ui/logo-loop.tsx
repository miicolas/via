"use client";

import {
  useCallback,
  useEffect,
  useMemo,
  useRef,
  useState,
  type CSSProperties,
  type ReactNode,
} from "react";

export interface LogoLoopItem {
  readonly node: ReactNode;
  readonly href?: string;
  readonly title?: string;
}

interface LogoLoopProps {
  readonly logos: readonly LogoLoopItem[];
  readonly speed?: number;
  readonly direction?: "left" | "right";
  readonly logoHeight?: number;
  readonly gap?: number;
  readonly pauseOnHover?: boolean;
  readonly className?: string;
}

const SMOOTH_TAU = 0.25;
const MIN_COPIES = 2;
const COPY_HEADROOM = 2;

export function LogoLoop({
  logos,
  speed = 120,
  direction = "left",
  logoHeight = 48,
  gap = 32,
  pauseOnHover = true,
  className = "",
}: LogoLoopProps): ReactNode {
  const containerRef = useRef<HTMLDivElement>(null);
  const trackRef = useRef<HTMLDivElement>(null);
  const sequenceRef = useRef<HTMLUListElement>(null);
  const isHoveredRef = useRef(false);
  const animationFrameRef = useRef<number | null>(null);
  const lastTimestampRef = useRef<number | null>(null);
  const offsetRef = useRef(0);
  const velocityRef = useRef(0);
  const sequenceWidthRef = useRef(0);
  const [copyCount, setCopyCount] = useState(MIN_COPIES);

  const targetVelocity = useMemo(() => {
    const directionMultiplier = direction === "left" ? 1 : -1;
    return Math.abs(speed) * directionMultiplier;
  }, [direction, speed]);

  const updateDimensions = useCallback(() => {
    const containerWidth = containerRef.current?.clientWidth ?? 0;
    const sequenceWidth =
      sequenceRef.current?.getBoundingClientRect().width ?? 0;

    if (sequenceWidth > 0) {
      sequenceWidthRef.current = Math.ceil(sequenceWidth);
      const next = Math.max(
        MIN_COPIES,
        Math.ceil(containerWidth / sequenceWidth) + COPY_HEADROOM,
      );
      setCopyCount((current) => (current === next ? current : next));
    }
  }, []);

  useEffect(() => {
    const container = containerRef.current;
    const sequence = sequenceRef.current;
    if (!container || !sequence) return;

    const observer = new ResizeObserver(updateDimensions);
    observer.observe(container);
    observer.observe(sequence);
    return () => observer.disconnect();
  }, [logos, updateDimensions]);

  useEffect(() => {
    const track = trackRef.current;
    if (!track) return;

    if (window.matchMedia("(prefers-reduced-motion: reduce)").matches) {
      track.style.transform = "translate3d(0, 0, 0)";
      return;
    }

    const animate = (timestamp: number): void => {
      if (lastTimestampRef.current === null)
        lastTimestampRef.current = timestamp;

      const deltaTime =
        Math.max(0, timestamp - lastTimestampRef.current) / 1000;
      lastTimestampRef.current = timestamp;
      const target = isHoveredRef.current && pauseOnHover ? 0 : targetVelocity;
      velocityRef.current +=
        (target - velocityRef.current) *
        (1 - Math.exp(-deltaTime / SMOOTH_TAU));

      const sequenceWidth = sequenceWidthRef.current;
      if (sequenceWidth > 0) {
        const offset = offsetRef.current + velocityRef.current * deltaTime;
        offsetRef.current =
          ((offset % sequenceWidth) + sequenceWidth) % sequenceWidth;
        track.style.transform = `translate3d(${-offsetRef.current}px, 0, 0)`;
      }

      animationFrameRef.current = requestAnimationFrame(animate);
    };

    animationFrameRef.current = requestAnimationFrame(animate);
    return () => {
      if (animationFrameRef.current !== null) {
        cancelAnimationFrame(animationFrameRef.current);
        animationFrameRef.current = null;
      }
      lastTimestampRef.current = null;
    };
  }, [pauseOnHover, targetVelocity]);

  const customProperties = {
    "--logo-gap": `${gap}px`,
    "--logo-height": `${logoHeight}px`,
  } as CSSProperties;

  return (
    <div className="flex justify-center px-6">
      <div
        ref={containerRef}
        className={`relative w-full max-w-480 overflow-x-hidden mask-[linear-gradient(to_right,transparent,black_10%,black_90%,transparent)] [-webkit-mask-image:linear-gradient(to_right,transparent,black_10%,black_90%,transparent)] ${className}`}
        style={customProperties}
      >
        <div
          ref={trackRef}
          className="flex w-max will-change-transform select-none"
          onMouseEnter={() => {
            isHoveredRef.current = true;
          }}
          onMouseLeave={() => {
            isHoveredRef.current = false;
          }}
        >
          {Array.from({ length: copyCount }, (_, copyIndex) => (
            <ul
              key={copyIndex}
              ref={copyIndex === 0 ? sequenceRef : undefined}
              className="flex items-center"
              aria-hidden={copyIndex > 0}
            >
              {logos.map((item, itemIndex) => (
                <li
                  key={`${copyIndex}-${itemIndex}`}
                  className="mr-(--logo-gap) flex-none text-(length:--logo-height) leading-none"
                >
                  {item.href ? (
                    <a
                      href={item.href}
                      target="_blank"
                      rel="noreferrer noopener"
                      className="inline-flex items-center invert"
                      title={item.title}
                    >
                      {item.node}
                    </a>
                  ) : (
                    <span className="inline-flex items-center invert">
                      {item.node}
                    </span>
                  )}
                </li>
              ))}
            </ul>
          ))}
        </div>
      </div>
    </div>
  );
}
