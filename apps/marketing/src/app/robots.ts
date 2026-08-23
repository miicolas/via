import { project } from "@/constants/project";
import type { MetadataRoute } from "next";

export default function robots(): MetadataRoute.Robots {
  return {
    rules: [{ userAgent: "*", allow: "/", disallow: ["/api/", "/private/"] }],
    sitemap: `${project.metadata.url}/sitemap.xml`,
    host: project.metadata.url,
  };
}
