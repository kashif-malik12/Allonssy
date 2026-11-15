#!/usr/bin/env python3
"""
Allonssy! Social Crawler & Dynamic OpenGraph Pre-renderer
Listens on localhost:8088 (behind Caddy reverse-proxy).

When social bots (WhatsApp, Facebook, Twitter, LinkedIn, Telegram, Googlebot)
request shareable URLs (/p/:id, /post/:id, /restaurants, /marketplace), this service
queries PostgREST on the VPS and responds with pre-rendered HTML containing
rich OpenGraph and Twitter card meta tags.
"""

from __future__ import annotations

import html
import json
import os
import re
from http.server import BaseHTTPRequestHandler, HTTPServer
from urllib.error import URLError
from urllib.request import Request, urlopen

PORT = int(os.environ.get("PRERENDER_PORT", "8088"))
SUPABASE_URL = os.environ.get("SUPABASE_URL", "http://127.0.0.1:8000")
SUPABASE_ANON_KEY = os.environ.get("SUPABASE_ANON_KEY", "")
BASE_URL = os.environ.get("PUBLIC_APP_URL", "https://app.allonssy.com")
DEFAULT_IMAGE = f"{BASE_URL}/icons/Icon-512.png"


def fetch_profile(profile_id: str) -> dict | None:
    url = f"{SUPABASE_URL}/rest/v1/profiles?id=eq.{profile_id}&select=id,full_name,business_name,job_title,bio,city,avatar_url,is_restaurant,is_unclaimed"
    headers = {"apikey": SUPABASE_ANON_KEY, "Authorization": f"Bearer {SUPABASE_ANON_KEY}"} if SUPABASE_ANON_KEY else {}
    req = Request(url, headers=headers)
    try:
        with urlopen(req, timeout=5) as resp:
            data = json.loads(resp.read().decode("utf-8"))
            return data[0] if data else None
    except Exception:
        return None


def fetch_post(post_id: str) -> dict | None:
    url = f"{SUPABASE_URL}/rest/v1/posts?id=eq.{post_id}&select=id,content,market_title,market_price,image_url,location_name,post_type"
    headers = {"apikey": SUPABASE_ANON_KEY, "Authorization": f"Bearer {SUPABASE_ANON_KEY}"} if SUPABASE_ANON_KEY else {}
    req = Request(url, headers=headers)
    try:
        with urlopen(req, timeout=5) as resp:
            data = json.loads(resp.read().decode("utf-8"))
            return data[0] if data else None
    except Exception:
        return None


def render_html(title: str, description: str, image: str, target_url: str) -> str:
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

  <!-- Instant redirect for real humans if they reach here -->
  <meta http-equiv="refresh" content="0; url={safe_url}">
</head>
<body>
  <h1>{safe_title}</h1>
  <p>{safe_desc}</p>
  <p><a href="{safe_url}">Ouvrir sur Allonssy!</a></p>
</body>
</html>"""


class PrerenderHandler(BaseHTTPRequestHandler):
    def do_GET(self):
        path = self.path.split("?")[0]
        full_url = f"{BASE_URL}{self.path}"

        # Match /p/:id (Profile or Business)
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
                return self.send_preview(render_html(title, desc, img, full_url))

        # Match /post/:id or /foods/:id or /marketplace/product/:id
        post_match = re.match(r"^/(post|foods|marketplace/product|gigs/service)/([a-f0-9\-]+)$", path)
        if post_match:
            post_id = post_match.group(2)
            post = fetch_post(post_id)
            if post:
                title = post.get("market_title") or (post.get("content", "")[:60] + "...") or "Annonce Allonssy!"
                desc = post.get("content") or "Consultez cette offre sur Allonssy!"
                price = post.get("market_price")
                if price:
                    title += f" • {price} €"
                img = post.get("image_url") or DEFAULT_IMAGE
                return self.send_preview(render_html(title, desc, img, full_url))

        # Default fallback for home / directory
        title = "Allonssy! — Commerces, Restos & Entraide Locale"
        desc = "Découvrez les commerces, restaurants, artisans vérifiés et services entre voisins à Ris-Orangis."
        return self.send_preview(render_html(title, desc, DEFAULT_IMAGE, full_url))

    def send_preview(self, content: str):
        data = content.encode("utf-8")
        self.send_response(200)
        self.send_header("Content-Type", "text/html; charset=utf-8")
        self.send_header("Content-Length", str(len(data)))
        self.end_headers()
        self.wfile.write(data)

    def log_message(self, format, *args):
        # Concise logging
        pass


def main():
    server = HTTPServer(("127.0.0.1", PORT), PrerenderHandler)
    print(f"[*] Allonssy OpenGraph Prerender running on 127.0.0.1:{PORT}")
    try:
        server.serve_forever()
    except KeyboardInterrupt:
        pass


if __name__ == "__main__":
    main()
