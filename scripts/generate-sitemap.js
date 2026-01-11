const fs = require("fs");
const fetch = require("node-fetch");

async function main() {
  const API_BASE = process.env.NEXT_PUBLIC_API_BASE;
  const baseUrl = process.env.NEXT_PUBLIC_SITE_URL || "https://yourdomain.com";

  // 1) Fetch all products
  const res = await fetch(`${API_BASE}/catalog/products`);
  const { items } = await res.json();

  // 2) Build URL list
  const urls = [
    `${baseUrl}/`,
    `${baseUrl}/products`,
    ...items.map((p) => `${baseUrl}/products/${p.slug}`),
  ];

  // 3) Wrap in XML
  const xml = [
    '<?xml version="1.0" encoding="UTF-8"?>',
    "<urlset xmlns='http://www.sitemaps.org/schemas/sitemap/0.9'>",
    ...urls.map((url) => `
      <url>
        <loc>${url}</loc>
      </url>
    `),
    "</urlset>",
  ].join("");

  // 4) Write to public/sitemap.xml
  fs.writeFileSync("public/sitemap.xml", xml.trim());
  console.log("sitemap.xml generated with", urls.length, "urls");
}

main().catch((e) => {
  console.error(e);
  process.exit(1);
});
