#!/usr/bin/env python3
"""
Automated SEO Sitemap & Robots.txt Generator for Allonssy.
Queries Supabase database and publishes:
1. /var/www/local_social_web/sitemap.xml (All businesses, restaurants, marketplace products, services, news)
2. /var/www/local_social_web/robots.txt
"""
from __future__ import annotations

import json
import subprocess
from datetime import datetime, timezone
from pathlib import Path

BASE_URL = "https://app.allonssy.com"
WEB_ROOT = Path("/var/www/local_social_web")
SITEMAP_FILE = WEB_ROOT / "sitemap.xml"
ROBOTS_FILE = WEB_ROOT / "robots.txt"


def query_db(sql: str) -> list[dict]:
    cmd = [
        "docker", "exec", "-i", "supabase-db",
        "psql", "-U", "postgres", "-d", "postgres",
        "-t", "-A", "-c", sql
    ]
    res = subprocess.run(cmd, capture_output=True, text=True, check=False)
    raw = (res.stdout or "").strip()
    if not raw or raw == "null":
        return []
    try:
        return json.loads(raw)
    except Exception as e:
        print(f"JSON query error: {e}")
        return []


def generate_sitemap() -> str:
    # 1. Static Core Pages
    urls = [
        {"loc": f"{BASE_URL}/", "freq": "hourly", "prio": "1.0"},
        {"loc": f"{BASE_URL}/marketplace", "freq": "hourly", "prio": "0.9"},
        {"loc": f"{BASE_URL}/foods", "freq": "hourly", "prio": "0.9"},
        {"loc": f"{BASE_URL}/gigs", "freq": "hourly", "prio": "0.9"},
        {"loc": f"{BASE_URL}/businesses", "freq": "daily", "prio": "0.8"},
    ]

    # 2. Profiles (Restaurants & Professionals)
    sql_profiles = "SELECT json_agg(p) FROM (SELECT id, created_at, city FROM profiles WHERE is_disabled = false) p;"
    profiles = query_db(sql_profiles)
    for p in profiles:
        pid = p.get("id")
        created = (p.get("created_at") or "")[:10]
        urls.append({
            "loc": f"{BASE_URL}/p/{pid}",
            "lastmod": created,
            "freq": "weekly",
            "prio": "0.8"
        })

    # 3. Posts (Marketplace, Services, News, Food Ads)
    sql_posts = "SELECT json_agg(p) FROM (SELECT id, post_type, created_at FROM posts WHERE visibility = 'public') p;"
    posts = query_db(sql_posts)
    for p in posts:
        post_id = p.get("id")
        ptype = p.get("post_type")
        created = (p.get("created_at") or "")[:10]
        prio = "0.7" if ptype == "market" else ("0.8" if ptype == "post" else "0.6")
        urls.append({
            "loc": f"{BASE_URL}/post/{post_id}",
            "lastmod": created,
            "freq": "weekly",
            "prio": prio
        })

    xml_lines = [
        '<?xml version="1.0" encoding="UTF-8"?>',
        '<urlset xmlns="http://www.sitemaps.org/schemas/sitemap/0.9">',
    ]

    for u in urls:
        loc = u["loc"]
        freq = u.get("freq", "weekly")
        prio = u.get("prio", "0.7")
        lastmod_tag = f"<lastmod>{u['lastmod']}</lastmod>" if "lastmod" in u and u["lastmod"] else ""
        xml_lines.append(f'  <url><loc>{loc}</loc>{lastmod_tag}<changefreq>{freq}</changefreq><priority>{prio}</priority></url>')

    xml_lines.append('</urlset>')
    return "\n".join(xml_lines), len(urls)


def main():
    if not WEB_ROOT.exists():
        print(f"Error: {WEB_ROOT} does not exist.")
        return

    print("Generating sitemap.xml...")
    sitemap_xml, total_urls = generate_sitemap()
    SITEMAP_FILE.write_text(sitemap_xml, encoding="utf-8")
    print(f"✅ sitemap.xml written to {SITEMAP_FILE} ({total_urls} indexed URLs)")

    print("Generating robots.txt...")
    robots_content = f"""User-agent: *
Allow: /

Sitemap: {BASE_URL}/sitemap.xml
"""
    ROBOTS_FILE.write_text(robots_content, encoding="utf-8")
    print(f"✅ robots.txt written to {ROBOTS_FILE}")


if __name__ == "__main__":
    main()
