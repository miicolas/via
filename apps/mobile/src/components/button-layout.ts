export function resolveButtonMatchContents(expands: boolean) {
  return {
    content: true as const,
    outer: expands ? ({ vertical: true } as const) : true,
  };
}

export function resolveButtonHostStyle(expands: boolean, contentHeight: number | undefined) {
  return expands && contentHeight !== undefined ? { height: contentHeight } : undefined;
}

export function resolveButtonLabelLayout(expands: boolean, hasCustomContent: boolean) {
  return expands && !hasCustomContent
    ? { fontSize: 15, maxLines: 1 as const, weight: 'semibold' as const }
    : undefined;
}
