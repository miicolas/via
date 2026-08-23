import type { FooterGroup } from "@/constants/types";
import type { ReactNode } from "react";

export function FooterLinkGroup({
  group,
}: {
  readonly group: FooterGroup;
}): ReactNode {
  return (
    <div>
      <h3 className="mb-4 text-xs font-medium tracking-wider text-white/75 uppercase">
        {group.label}
      </h3>
      <ul className="space-y-2">
        {group.items.map((link) => (
          <li key={link.label}>
            <a
              href={link.href}
              className="text-sm text-white transition-colors hover:text-white/75"
            >
              {link.label}
            </a>
          </li>
        ))}
      </ul>
    </div>
  );
}
