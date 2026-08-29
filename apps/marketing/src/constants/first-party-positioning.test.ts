import { readFileSync } from "node:fs";
import { describe, expect, test } from "bun:test";
import { communityContent } from "./community-page";
import { marketingPageSlugs, marketingPages, getMarketingPage } from "./marketing-pages";
import { footerNavigation, navigation } from "./navigation";

describe("first-party API positioning", () => {
  test("does not publish API or integrations product pages", () => {
    expect(marketingPageSlugs).not.toContain("api");
    expect(marketingPageSlugs).not.toContain("integrations");
    expect(getMarketingPage("api")).toBeUndefined();
    expect(getMarketingPage("integrations")).toBeUndefined();
  });

  test("keeps API routes out of every navigation group", () => {
    const serialized = JSON.stringify({ navigation, footerNavigation });
    expect(serialized).not.toContain('href":"/api"');
    expect(serialized).not.toContain('href":"/integrations"');
  });

  test("frames community participation as data quality", () => {
    const serialized = JSON.stringify(communityContent);
    expect(serialized).not.toContain(["Explorer l", "’API"].join(""));
    expect(serialized).not.toContain(["Détournez l", "’API"].join(""));
    expect(serialized).not.toContain("GET /v1/");
    expect(serialized).toContain("dataQuality");
  });

  test("does not make a public API offer in retained page content", () => {
    const serialized = JSON.stringify(marketingPages);
    expect(serialized).not.toContain('href":"/api"');
    expect(serialized).not.toContain("API lorsqu’elle est mise à disposition");
    expect(serialized).not.toContain("Obtenir un accès");
  });

  test("documents first-party transports and hand-written public projections", () => {
    const readme = readFileSync(new URL("../../../../README.md", import.meta.url), "utf8");
    expect(readme).not.toContain(["iOS app and ", "third parties"].join(""));
    expect(readme).toContain("first-party");
    expect(readme).toContain("/public");
    expect(readme).toContain("ADR 0003");
  });
});
