#!/usr/bin/env python3
"""
Allonssy! Social Crawler, Dynamic OpenGraph, JSON-LD & Sitemap Engine
Listens on localhost:8088 (behind Caddy reverse-proxy).

Capabilities:
1. Dynamic OpenGraph & Twitter Cards for social bots (WhatsApp, FB, Twitter, Telegram, LinkedIn).
2. Schema.org / JSON-LD Structured Data for Googlebot (Restaurant, Product, Service).
3. Dynamic /sitemap.xml auto-generating all live listings, marketplace items, and posts.
4. /robots.txt referencing the sitemap.
"""

from __future__ import annotations

import html
import json
import os
import re
from datetime import datetime, timezone
from http.server import BaseHTTPRequestHandler, HTTPServer
from urllib.request import Request, urlopen

PORT = int(os.environ.get("PRERENDER_PORT", "8088"))
SUPABASE_URL = os.environ.get("SUPABASE_URL", "http://127.0.0.1:8000")
SUPABASE_ANON_KEY = os.environ.get("SUPABASE_ANON_KEY", "")
BASE_URL = os.environ.get("PUBLIC_APP_URL", "https://app.allonssy.com")
DEFAULT_IMAGE = f"{BASE_URL}/icons/Icon-512.png"


def api_request(path: str) -> list | dict | None:
    url = f"{SUPABASE_URL}/rest/v1/{path}"
    headers = {"apikey": SUPABASE_ANON_KEY, "Authorization": f"Bearer {SUPABASE_ANON_KEY}"} if SUPABASE_ANON_KEY else {}
    req = Request(url, headers=headers)
    try:
        with urlopen(req, timeout=5) as resp:
            return json.loads(resp.read().decode("utf-8"))
    except Exception:
        return None


def fetch_profile(profile_id: str) -> dict | None:
    data = api_request(f"profiles?id=eq.{profile_id}&select=id,full_name,business_name,job_title,bio,city,zipcode,avatar_url,is_restaurant,is_unclaimed")
    return data[0] if data else None


def fetch_post(post_id: str) -> dict | None:
    data = api_request(f"posts?id=eq.{post_id}&select=id,content,market_title,market_price,image_url,location_name,post_type,created_at,profiles(full_name,city)")
    return data[0] if data else None


def build_json_ld(item_type: str, data: dict, target_url: str) -> str:
    ld: dict = {"@context": "https://schema.org"}
    if item_type == "restaurant":
        ld.update({
            "@type": "Restaurant",
            "name": data.get("business_name") or data.get("full_name") or "Restaurant",
            "description": data.get("bio") or "",
            "image": data.get("avatar_url") or DEFAULT_IMAGE,
            "url": target_url,
            "address": {
                "@type": "PostalAddress",
                "addressLocality": data.get("city") or "Ris-Orangis",
                "postalCode": data.get("zipcode") or "91130",
                "addressCountry": "FR"
            }
        })
    elif item_type == "product":
        price = data.get("market_price")
        ld.update({
            "@type": "Product",
            "name": data.get("market_title") or "Article d'occasion",
            "description": data.get("content") or "",
            "image": data.get("image_url") or DEFAULT_IMAGE,
            "url": target_url,
        })
        if price is not None:
            ld["offers"] = {
                "@type": "Offer",
                "price": str(price),
                "priceCurrency": "EUR",
                "availability": "https://schema.org/InStock",
                "url": target_url
            }
    elif item_type == "service":
        ld.update({
            "@type": "Service",
            "name": data.get("market_title") or "Service local",
            "description": data.get("content") or "",
            "url": target_url,
            "areaServed": data.get("location_name") or "Grand Paris Sud"
        })
    else:
        ld.update({
            "@type": "NewsArticle",
            "headline": data.get("market_title") or (data.get("content", "")[:60]),
            "url": target_url,
            "image": [data.get("image_url") or DEFAULT_IMAGE],
            "datePublished": data.get("created_at") or datetime.now(timezone.utc).isoformat()
        })
    return f'<script type="application/ld+json">{json.dumps(ld, ensure_ascii=False)}</script>'


def render_html(title: str, description: str, image: str, target_url: str, json_ld: str = "") -> str:
    safe_title = html.escape(title)
    safe_desc = html.escape(description)
    safe_image = html.escape(image or DEFAULT_IMAGE)
    safe_url = html.escape(target_url)

    return f"""<!DOCTYPE html>
<html lang="fr">
<head>
  <meta charset="UTF-8">
  <title>{safe_title}</title>
  <meta name="description" content="{safe_desc}">

  <!-- OpenGraph -->
  <meta property="og:type" content="article">
  <meta property="og:url" content="{safe_url}">
  <meta property="og:title" content="{safe_title}">
  <meta property="og:description" content="{safe_desc}">
  <meta property="og:image" content="{safe_image}">
  <meta property="og:site_name" content="Allonssy!">

  <!-- Twitter -->
  <meta name="twitter:card" content="summary_large_image">
  <meta name="twitter:title" content="{safe_title}">
  <meta name="twitter:description" content="{safe_desc}">
  <meta name="twitter:image" content="{safe_image}">

  <!-- Schema.org JSON-LD for Google -->
  {json_ld}

  <!-- Instant redirect for real humans -->
  <meta http-equiv="refresh" content="0; url={safe_url}">
</head>
<body>
  <h1>{safe_title}</h1>
  <p>{safe_desc}</p>
  <p><a href="{safe_url}">Ouvrir sur Allonssy!</a></p>
</body>
</html>"""


def generate_sitemap() -> str:
    # Query all businesses & restaurants
    profiles = api_request("profiles?select=id,created_at&limit=1000") or []
    # Query all public posts
    posts = api_request("posts?select=id,created_at&visibility=eq.public&limit=1000") or []

    xml_lines = [
        '<?xml version="1.0" encoding="UTF-8"?>',
        '<urlset xmlns="http://www.sitemaps.org/schemas/sitemap/0.9">',
        f'  <url><loc>{BASE_URL}/</loc><changefreq>hourly</changefreq><priority>1.0</priority></url>',
        f'  <url><loc>{BASE_URL}/marketplace</loc><changefreq>hourly</changefreq><priority>0.9</priority></url>',
        f'  <url><loc>{BASE_URL}/foods</loc><changefreq>hourly</changefreq><priority>0.9</priority></url>',
        f'  <url><loc>{BASE_URL}/gigs</loc><changefreq>hourly</changefreq><priority>0.9</priority></url>',
        f'  <url><loc>{BASE_URL}/businesses</loc><changefreq>daily</changefreq><priority>0.8</priority></url>',
    ]

    for p in profiles:
        pid = p.get("id")
        created = (p.get("created_at") or "")[:10]
        xml_lines.append(f'  <url><loc>{BASE_URL}/p/{pid}</loc><lastmod>{created}</lastmod><changefreq>weekly</changefreq><priority>0.8</priority></url>')

    for post in posts:
        post_id = post.get("id")
        created = (post.get("created_at") or "")[:10]
        xml_lines.append(f'  <url><loc>{BASE_URL}/post/{post_id}</loc><lastmod>{created}</lastmod><changefreq>weekly</changefreq><priority>0.7</priority></url>')

    xml_lines.append('</urlset>')
    return "\n".join(xml_lines)


class PrerenderHandler(BaseHTTPRequestHandler):
    def do_GET(self):
        path = self.path.split("?")[0]
        full_url = f"{BASE_URL}{self.path}"

        # 1. Sitemap
        if path == "/sitemap.xml":
            sitemap_xml = generate_sitemap()
            return self.send_content(sitemap_xml, content_type="application/xml; charset=utf-8")

        # 2. Robots.txt
        if path == "/robots.txt":
            robots_txt = f"""User-agent: *
Allow: /
Sitemap: {BASE_URL}/sitemap.xml
"""
            return self.send_content(robots_txt, content_type="text/plain; charset=utf-8")

        # 3. Match /p/:id (Profile or Business)
        profile_match = re.match(r"^/p/([a-f0-9\-]+)$", path)
        if profile_match:
            pid = profile_match.group(1)
            p = fetch_profile(pid)
            if p:
                name = p.get("business_name") or p.get("full_name") or "Commerce"
                job = p.get("job_title") or ("Restaurant" if p.get("is_restaurant") else "Professionnel")
                city = p.get("city") or "Ris-Orangis"
                title = f"{name} ({job}) à {city} — Allonssy!"
                desc = p.get("bio") or f"Découvrez {name} sur Allonssy, le réseau local de {city}."
                img = p.get("avatar_url") or DEFAULT_IMAGE
                json_ld = build_json_ld("restaurant" if p.get("is_restaurant") else "service", p, full_url)
                return self.send_content(render_html(title, desc, img, full_url, json_ld))

        # 4. Match /post/:id or /foods/:id or /marketplace/product/:id
        post_match = re.match(r"^/(post|foods|marketplace/product|gigs/service)/([a-f0-9\-]+)$", path)
        if post_match:
            post_id = post_match.group(2)
            post = fetch_post(post_id)
            if post:
                ptype = post.get("post_type")
                title = post.get("market_title") or (post.get("content", "")[:60] + "...") or "Annonce Allonssy!"
                desc = post.get("content") or "Consultez cette offre sur Allonssy!"
                price = post.get("market_price")
                if price:
                    title += f" • {price} €"
                img = post.get("image_url") or DEFAULT_IMAGE
                
                item_type = "product" if ptype == "market" else ("service" if ptype in ("service_offer", "service_request") else "article")
                json_ld = build_json_ld(item_type, post, full_url)
                return self.send_content(render_html(title, desc, img, full_url, json_ld))

        # 5. Default fallback
        title = "Allonssy! — Commerces, Restos, Marketplace & Entraide Locale"
        desc = "Découvrez les commerces, restaurants, annonces d'occasion et services entre voisins à Ris-Orangis, Grigny et Évry."
        return self.send_content(render_html(title, desc, DEFAULT_IMAGE, full_url))

    def send_content(self, content: str, content_type: str = "text/html; charset=utf-8"):
        data = content.encode("utf-8")
        self.send_response(200)
        self.send_header("Content-Type", content_type)
        self.send_header("Content-Length", str(len(data)))
        self.end_headers()
        self.wfile.write(data)

    def log_message(self, format, *args):
        pass


def main():
    server = HTTPServer(("127.0.0.1", PORT), PrerenderHandler)
    print(f"[*] Allonssy SEO & Sitemap Engine running on 127.0.0.1:{PORT}")
    try:
        server.serve_forever()
    except KeyboardInterrupt:
        pass


if __name__ == "__main__":
    main()
