#!/usr/bin/env python3
"""
generate_news_portal.py
Generates a dedicated, SEO-optimized, mobile-friendly Local News Portal at:
/var/www/local_social_web/actualites.html (and /var/www/local_social_web/news.html)

Displays all fresh news articles across Ris-Orangis, Grigny, Évry-Courcouronnes, and Essonne,
with city filters and deep-links to discuss on Allonssy!
"""
from __future__ import annotations

import html
import json
import subprocess
from datetime import datetime
from pathlib import Path

OUT_FILE = Path("/var/www/local_social_web/actualites.html")
OUT_ALIAS = Path("/var/www/local_social_web/news.html")
BASE_URL = "https://app.allonssy.com"


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


def get_recent_news(limit: int = 50) -> list[dict]:
    sql = f"""
    SELECT json_agg(nw) FROM (
        SELECT 
            p.id, 
            p.content, 
            p.image_url, 
            p.location_name, 
            p.created_at,
            pr.full_name AS author_name,
            pr.avatar_url AS author_avatar
        FROM posts p
        LEFT JOIN profiles pr ON p.user_id = pr.id
        WHERE p.external_source = 'live_news'
        ORDER BY p.created_at DESC
        LIMIT {limit}
    ) nw;
    """
    return query_db(sql)


def render_html(articles: list[dict]) -> str:
    now_str = datetime.now().strftime("%d/%m/%Y à %H:%M")

    cards_html = ""
    for a in articles:
        p_id = a.get("id")
        content = a.get("content", "")
        raw_lines = [l.strip() for l in content.split("\n") if l.strip()]
        
        headline = raw_lines[0] if raw_lines else "Actualité locale"
        headline = headline.replace("📰 [ACTUALITÉ LOCALE • ", "").replace("📰 [ACTUALITÉ LOCALE] ", "").rstrip("]")
        
        summary = ""
        source = "Presse Locale"
        source_link = ""
        
        for line in raw_lines[1:]:
            if line.startswith("📌 Source :"):
                source = line.replace("📌 Source :", "").strip()
            elif line.startswith("🔗 Lire l'article complet :"):
                source_link = line.replace("🔗 Lire l'article complet :", "").strip()
            elif not summary:
                summary = line

        loc = a.get("location_name", "Grand Paris Sud")
        city_slug = "all"
        if "Ris-Orangis" in loc:
            city_slug = "ris"
        elif "Évry" in loc or "Evry" in loc:
            city_slug = "evry"
        elif "Grigny" in loc:
            city_slug = "grigny"

        img = a.get("image_url") or "https://images.unsplash.com/photo-1585829365295-ab7cd400c167?w=800&auto=format&fit=crop&q=80"
        created_at = a.get("created_at", "")[:10]
        allonssy_post_url = f"{BASE_URL}/post/{p_id}"

        cards_html += f"""
        <article class="news-card" data-city="{city_slug}">
          <div class="card-img" style="background-image: url('{html.escape(img)}');">
            <span class="city-badge">{html.escape(loc)}</span>
          </div>
          <div class="card-body">
            <div class="meta">
              <span>📅 {html.escape(created_at)}</span> • <span>📰 Source : {html.escape(source)}</span>
            </div>
            <h2>{html.escape(headline)}</h2>
            <p>{html.escape(summary)}</p>
            <div class="card-actions">
              <a href="{allonssy_post_url}" class="btn-discuss">💬 Réagir sur Allonssy</a>
              {f'<a href="{html.escape(source_link)}" target="_blank" class="btn-source">Lire l\'article ↗</a>' if source_link else ''}
            </div>
          </div>
        </article>
        """

    return f"""<!DOCTYPE html>
<html lang="fr">
<head>
  <meta charset="UTF-8">
  <meta name="viewport" content="width=device-width, initial-scale=1.0">
  <title>Actualités Locales — Ris-Orangis, Grigny, Évry-Courcouronnes & Essonne (91) | Allonssy!</title>
  <meta name="description" content="Toutes les actualités locales en direct de Ris-Orangis (91130), Grigny (91350), Évry-Courcouronnes (91000) et Grand Paris Sud. Événements, vie citoyenne et débats entre voisins.">
  <link rel="canonical" href="{BASE_URL}/actualites.html">

  <!-- OpenGraph -->
  <meta property="og:type" content="website">
  <meta property="og:url" content="{BASE_URL}/actualites.html">
  <meta property="og:title" content="Actualités Locales du 91 — Allonssy!">
  <meta property="og:description" content="L'actualité en continu de Ris-Orangis, Grigny, Évry et de l'Essonne. Débats et réactions des riverains.">
  <meta property="og:image" content="{BASE_URL}/icons/Icon-512.png">

  <style>
    * {{ box-sizing: border-box; }}
    body {{
      font-family: -apple-system, BlinkMacSystemFont, "Segoe UI", Roboto, Helvetica, Arial, sans-serif;
      background: #F4F6F8;
      color: #1A202C;
      margin: 0;
      padding: 0;
      line-height: 1.5;
    }}
    header {{
      background: linear-gradient(135deg, #0F766E, #134E4A);
      color: #ffffff;
      padding: 36px 20px;
      text-align: center;
    }}
    header h1 {{ margin: 0; font-size: 28px; }}
    header p {{ margin: 8px 0 0; opacity: 0.9; font-size: 16px; max-width: 650px; margin-left: auto; margin-right: auto; }}
    
    .app-banner {{
      background: #FEF3C7;
      border-bottom: 1px solid #FDE68A;
      padding: 12px 20px;
      text-align: center;
      font-size: 14px;
      color: #92400E;
      font-weight: 500;
    }}
    .app-banner a {{
      color: #B45309;
      font-weight: bold;
      text-decoration: underline;
      margin-left: 8px;
    }}

    .container {{
      max-width: 1080px;
      margin: 0 auto;
      padding: 24px 16px;
    }}

    .filters {{
      display: flex;
      gap: 10px;
      margin-bottom: 24px;
      overflow-x: auto;
      padding-bottom: 6px;
    }}
    .filter-btn {{
      padding: 10px 18px;
      border: 1px solid #E2E8F0;
      background: #ffffff;
      border-radius: 30px;
      font-weight: 600;
      font-size: 14px;
      color: #4A5568;
      cursor: pointer;
      white-space: nowrap;
      transition: all 0.2s;
    }}
    .filter-btn.active {{
      background: #0F766E;
      color: #ffffff;
      border-color: #0F766E;
    }}

    .news-grid {{
      display: grid;
      grid-template-columns: repeat(auto-fill, minmax(320px, 1fr));
      gap: 24px;
    }}

    .news-card {{
      background: #ffffff;
      border-radius: 16px;
      overflow: hidden;
      border: 1px solid #E2E8F0;
      box-shadow: 0 4px 12px rgba(0,0,0,0.04);
      display: flex;
      flex-direction: column;
      transition: transform 0.2s;
    }}
    .news-card:hover {{
      transform: translateY(-3px);
    }}

    .card-img {{
      height: 180px;
      background-size: cover;
      background-position: center;
      position: relative;
    }}
    .city-badge {{
      position: absolute;
      top: 12px;
      left: 12px;
      background: rgba(15, 118, 110, 0.9);
      backdrop-filter: blur(4px);
      color: #ffffff;
      padding: 4px 12px;
      border-radius: 20px;
      font-size: 12px;
      font-weight: bold;
    }}

    .card-body {{
      padding: 20px;
      display: flex;
      flex-direction: column;
      flex-grow: 1;
    }}

    .meta {{
      font-size: 12px;
      color: #718096;
      margin-bottom: 10px;
    }}

    h2 {{
      font-size: 17px;
      line-height: 1.4;
      margin: 0 0 10px;
      color: #1A202C;
    }}

    p {{
      font-size: 14px;
      color: #4A5568;
      margin: 0 0 18px;
      flex-grow: 1;
      display: -webkit-box;
      -webkit-line-clamp: 3;
      -webkit-box-orient: vertical;
      overflow: hidden;
    }}

    .card-actions {{
      display: flex;
      gap: 8px;
      align-items: center;
    }}
    .btn-discuss {{
      flex: 1;
      text-align: center;
      background: #0F766E;
      color: #ffffff;
      padding: 10px 14px;
      border-radius: 8px;
      text-decoration: none;
      font-weight: bold;
      font-size: 13px;
    }}
    .btn-source {{
      font-size: 12px;
      color: #718096;
      text-decoration: none;
      padding: 10px 12px;
      border: 1px solid #E2E8F0;
      border-radius: 8px;
    }}

    footer {{
      background: #ffffff;
      border-top: 1px solid #E2E8F0;
      text-align: center;
      padding: 28px 16px;
      margin-top: 48px;
      font-size: 13px;
      color: #718096;
    }}
  </style>
</head>
<body>
  <div class="app-banner">
    📱 Vous habitez dans le 91 ? Téléchargez gratuitement l'app Allonssy pour échanger avec vos voisins, trouver des bons plans et soutenir vos commerçants !
    <a href="https://play.google.com/store/apps/details?id=com.allonssy.app" target="_blank">Télécharger sur Google Play ↗</a>
  </div>

  <header>
    <h1>📰 Allonssy! Actualités Locales</h1>
    <p>Le fil d'actualités citoyen et indépendant de Ris-Orangis, Grigny, Évry-Courcouronnes et Grand Paris Sud.</p>
  </header>

  <div class="container">
    <div class="filters">
      <button class="filter-btn active" onclick="filterCity('all')">Toutes les villes</button>
      <button class="filter-btn" onclick="filterCity('ris')">Ris-Orangis (91130)</button>
      <button class="filter-btn" onclick="filterCity('evry')">Évry-Courcouronnes (91000)</button>
      <button class="filter-btn" onclick="filterCity('grigny')">Grigny (91350)</button>
    </div>

    <div class="news-grid" id="newsGrid">
      {cards_html}
    </div>
  </div>

  <footer>
    <p>Allonssy! — Le réseau social local et citoyen du Grand Paris Sud (91).<br>
    Mis à jour le {now_str}.</p>
  </footer>

  <script>
    function filterCity(slug) {{
      document.querySelectorAll('.filter-btn').forEach(b => b.classList.remove('active'));
      event.target.classList.add('active');

      const cards = document.querySelectorAll('.news-card');
      cards.forEach(c => {{
        if (slug === 'all' || c.getAttribute('data-city') === slug) {{
          c.style.display = 'flex';
        }} else {{
          c.style.display = 'none';
        }}
      }});
    }}
  </script>
</body>
</html>
"""


def main():
    print("Fetching recent news articles from database...")
    articles = get_recent_news(limit=60)
    print(f"Found {len(articles)} news articles.")
    html_content = render_html(articles)

    OUT_FILE.write_text(html_content, encoding="utf-8")
    print(f"✅ News portal written to {OUT_FILE}")

    # Create alias at /news.html
    try:
        OUT_ALIAS.write_text(html_content, encoding="utf-8")
        print(f"✅ Alias written to {OUT_ALIAS}")
    except Exception as e:
        print(f"Alias error: {e}")


if __name__ == "__main__":
    main()
