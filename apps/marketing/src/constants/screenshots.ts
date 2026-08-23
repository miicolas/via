export interface ScreenshotAsset {
  readonly src: string;
  readonly alt: string;
  readonly width: number;
  readonly height: number;
}

export const screenshots = {
  stationsOverview: {
    src: "/screenshots/stations-overview.png",
    alt: "Écran Stations de Via montrant le réseau parisien et les prochains passages à Hôtel de Ville",
    width: 1206,
    height: 2622,
  },
} as const satisfies Record<string, ScreenshotAsset>;
