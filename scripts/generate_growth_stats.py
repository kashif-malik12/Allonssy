#!/usr/bin/env python3
"""
generate_growth_stats.py
Builds the Live Growth & Real-User Analytics Tracker for Allonssy:
  - /var/www/local_social_web/growth_stats.html (live mobile-friendly dashboard)
  - /home/deploy/monitoring/growth_stats.json   (embedded into daily 07:30 email)

Tracks genuine human signups, genuine posts/comments, content inventory, SEO index size,
and automated Meta social publishing health.
"""
from __future__ import annotations

import html
import json
import subprocess
from datetime import datetime
from pathlib import Path

HOME = Path.home()
OUT_HTML = Path("/var/www/local_social_web/growth_stats.html")
OUT_JSON = HOME / "monitoring" / "growth_stats.json"
SITEMAP_FILE = Path("/var/www/local_social_web/sitemap.xml")
META_LOG = HOME / "monitoring" / "meta_auto_publish.log"


def query_scalar(sql: str) -> int:
    cmd = [
        "docker", "exec", "-i", "supabase-db",
        "psql", "-U", "postgres", "-d", "postgres",
        "-t", "-A", "-c", sql
    ]
    res = subprocess.run(cmd, capture_output=True, text=True, check=False)
    raw = (res.stdout or "").strip()
    try:
        return int(raw)
    except Exception:
        return 0


def query_json(sql: str) -> list[dict]:
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
    except Exception:
        return []


SEED_PROFILE_FILTER = """
    id::text NOT LIKE '00000000-%'
    AND id::text NOT LIKE '11111111-%'
    AND id::text NOT LIKE '22222222-%'
    AND id::text NOT LIKE '33333333-%'
    AND id::text NOT LIKE '44444444-%'
    AND id::text NOT LIKE '55555555-%'
    AND id::text NOT LIKE '66666666-%'
    AND COALESCE(is_unclaimed, false) = false
    AND (email IS NULL OR email NOT LIKE '%@allonssy.com')
"""

SEED_POST_FILTER = """
    posts.external_source IS NULL
    AND COALESCE(posts.is_unclaimed, false) = false
    AND posts.id::text NOT LIKE '00000000-%'
    AND posts.id::text NOT LIKE '22222222-%'
    AND posts.id::text NOT LIKE '33333333-%'
    AND posts.id::text NOT LIKE '44444444-%'
    AND posts.id::text NOT LIKE '55555555-%'
    AND posts.id::text NOT LIKE '66666666-%'
    AND (profiles.email IS NULL OR profiles.email NOT LIKE '%@allonssy.com')
"""


def collect_metrics() -> dict:
    real_users_total = query_scalar(f"SELECT count(*) FROM profiles WHERE {SEED_PROFILE_FILTER};")
    real_users_24h = query_scalar(f"SELECT count(*) FROM profiles WHERE {SEED_PROFILE_FILTER} AND created_at > now() - interval '24 hours';")
    real_users_7d = query_scalar(f"SELECT count(*) FROM profiles WHERE {SEED_PROFILE_FILTER} AND created_at > now() - interval '7 days';")

    real_posts_total = query_scalar(f"SELECT count(*) FROM posts LEFT JOIN profiles ON posts.user_id = profiles.id WHERE {SEED_POST_FILTER};")
    real_posts_7d = query_scalar(f"SELECT count(*) FROM posts LEFT JOIN profiles ON posts.user_id = profiles.id WHERE {SEED_POST_FILTER} AND posts.created_at > now() - interval '7 days';")

    comments_total = query_scalar("SELECT count(*) FROM post_comments;")
    comments_7d = query_scalar("SELECT count(*) FROM post_comments WHERE created_at > now() - interval '7 days';")

    inv_market = query_scalar("SELECT count(*) FROM posts WHERE post_type = 'market';")
    inv_services = query_scalar("SELECT count(*) FROM posts WHERE post_type IN ('service_offer', 'service_request');")
    inv_restos = query_scalar("SELECT count(*) FROM profiles WHERE is_restaurant = true;")
    inv_news = query_scalar("SELECT count(*) FROM posts WHERE external_source = 'live_news';")

    recent_users = query_json(f"""
    SELECT json_agg(u) FROM (
        SELECT full_name, city, account_type, to_char(created_at, 'DD/MM HH24:MI') AS joined
        FROM profiles
        WHERE {SEED_PROFILE_FILTER}
        ORDER BY created_at DESC
        LIMIT 8
    ) u;
    """)

    recent_real_posts = query_json(f"""
    SELECT json_agg(p) FROM (
        SELECT posts.id, posts.post_type, COALESCE(posts.market_title, left(posts.content, 55)) AS title,
               COALESCE(posts.location_name, profiles.city, 'Essonne') AS city,
               to_char(posts.created_at, 'DD/MM HH24:MI') AS posted
        FROM posts
        LEFT JOIN profiles ON posts.user_id = profiles.id
        WHERE {SEED_POST_FILTER}
        ORDER BY posts.created_at DESC
        LIMIT 8
    ) p;
    """)

    sitemap_urls = 0
    if SITEMAP_FILE.exists():
        sitemap_urls = SITEMAP_FILE.read_text(encoding="utf-8", errors="ignore").count("<url>")

    last_meta_pub = "En attente du prochain cycle (08:15 UTC)"
    if META_LOG.exists():
        lines = [l for l in META_LOG.read_text(encoding="utf-8", errors="ignore").splitlines() if "Published to" in l]
        if lines:
            last_meta_pub = lines[-1]

    return {
        "updated_at": datetime.now().strftime("%d/%m/%Y à %H:%M"),
        "real_users_total": real_users_total,
        "real_users_24h": real_users_24h,
        "real_users_7d": real_users_7d,
        "real_posts_total": real_posts_total,
        "real_posts_7d": real_posts_7d,
        "comments_total": comments_total,
        "comments_7d": comments_7d,
        "inv_market": inv_market,
        "inv_services": inv_services,
        "inv_restos": inv_restos,
        "inv_news": inv_news,
        "sitemap_urls": sitemap_urls,
        "last_meta_pub": last_meta_pub,
        "recent_users": recent_users,
        "recent_real_posts": recent_real_posts,
    }


def render_html(m: dict) -> str:
    user_rows = ""
    for u in m["recent_users"]:
        user_rows += f"""
        <tr>
          <td><b>{html.escape(str(u.get('full_name') or 'Nouveau membre'))}</b></td>
          <td>{html.escape(str(u.get('city') or '—'))}</td>
          <td><span class="pill">{html.escape(str(u.get('account_type') or 'person'))}</span></td>
          <td>{html.escape(str(u.get('joined') or ''))}</td>
        </tr>"""
    if not user_rows:
        user_rows = '<tr><td colspan="4" style="text-align:center;color:#6B7280;">En attente des premières inscriptions organiques...</td></tr>'

    post_rows = ""
    for p in m["recent_real_posts"]:
        post_rows += f"""
        <tr>
          <td><a href="https://app.allonssy.com/post/{p.get('id')}" target="_blank" style="color:#0F766E;font-weight:600;text-decoration:none;">{html.escape(str(p.get('title') or 'Post'))}</a></td>
          <td>{html.escape(str(p.get('city') or '—'))}</td>
          <td><span class="pill">{html.escape(str(p.get('post_type') or 'post'))}</span></td>
          <td>{html.escape(str(p.get('posted') or ''))}</td>
        </tr>"""
    if not post_rows:
        post_rows = '<tr><td colspan="4" style="text-align:center;color:#6B7280;">Aucune publication humaine récente pour le moment.</td></tr>'

    return f"""<!DOCTYPE html>
<html lang="fr">
<head>
  <meta charset="UTF-8">
  <meta name="viewport" content="width=device-width, initial-scale=1.0">
  <title>Allonssy! — Tracker de Croissance & Trafic</title>
  <style>
    * {{ box-sizing: border-box; }}
    body {{
      font-family: -apple-system, BlinkMacSystemFont, "Segoe UI", Roboto, Helvetica, Arial, sans-serif;
      background: #F3F4F6;
      color: #111827;
      margin: 0;
      padding: 16px;
    }}
    .wrap {{ max-width: 920px; margin: 0 auto; }}
    header {{
      background: linear-gradient(135deg, #0F766E, #115E59);
      color: #fff;
      padding: 24px;
      border-radius: 16px;
      margin-bottom: 20px;
      display: flex;
      justify-content: space-between;
      align-items: center;
      flex-wrap: wrap;
      gap: 12px;
    }}
    header h1 {{ margin: 0; font-size: 22px; }}
    header p {{ margin: 4px 0 0; opacity: 0.9; font-size: 13px; }}
    .nav-links {{ display: flex; gap: 8px; flex-wrap: wrap; }}
    .nav-links a {{
      background: rgba(255,255,255,0.16);
      color: #fff;
      text-decoration: none;
      padding: 8px 14px;
      border-radius: 8px;
      font-size: 13px;
      font-weight: 600;
    }}
    .grid {{
      display: grid;
      grid-template-columns: repeat(auto-fit, minmax(195px, 1fr));
      gap: 14px;
      margin-bottom: 20px;
    }}
    .kpi {{
      background: #fff;
      border-radius: 14px;
      padding: 18px;
      border: 1px solid #E5E7EB;
      box-shadow: 0 2px 6px rgba(0,0,0,0.03);
    }}
    .kpi .label {{ font-size: 12px; font-weight: 600; color: #6B7280; text-transform: uppercase; }}
    .kpi .val {{ font-size: 30px; font-weight: 800; color: #0F766E; margin: 6px 0 4px; }}
    .kpi .delta {{ font-size: 12px; color: #059669; font-weight: 600; }}
    .card {{
      background: #fff;
      border-radius: 14px;
      padding: 20px;
      border: 1px solid #E5E7EB;
      margin-bottom: 18px;
    }}
    .card h2 {{ margin: 0 0 14px; font-size: 16px; color: #111827; }}
    table {{ width: 100%; border-collapse: collapse; font-size: 13px; }}
    th, td {{ text-align: left; padding: 10px 8px; border-bottom: 1px solid #F3F4F6; }}
    th {{ color: #6B7280; font-size: 12px; text-transform: uppercase; }}
    .pill {{
      display: inline-block;
      background: #ECFDF5;
      color: #065F46;
      padding: 2px 8px;
      border-radius: 12px;
      font-size: 11px;
      font-weight: 700;
    }}
    .status-bar {{
      background: #ECFDF5;
      border: 1px solid #A7F3D0;
      color: #065F46;
      border-radius: 12px;
      padding: 14px 16px;
      font-size: 13px;
      margin-bottom: 18px;
      line-height: 1.5;
    }}
  </style>
</head>
<body>
  <div class="wrap">
    <header>
      <div>
        <h1>📊 Allonssy! Growth & Traffic Tracker</h1>
        <p>Mis à jour automatiquement le {m['updated_at']} • Ris-Orangis, Grigny & Évry</p>
      </div>
      <div class="nav-links">
        <a href="/social_briefing.html">📱 Social Copilot</a>
        <a href="/actualites.html">📰 Actu 91</a>
        <a href="/go.html">🔗 Link-in-Bio</a>
      </div>
    </header>

    <div class="grid">
      <div class="kpi">
        <div class="label">👥 Vrais Inscrits</div>
        <div class="val">{m['real_users_total']}</div>
        <div class="delta">+{m['real_users_24h']} (24h) • +{m['real_users_7d']} (7j)</div>
      </div>
      <div class="kpi">
        <div class="label">📝 Posts Humains</div>
        <div class="val">{m['real_posts_total']}</div>
        <div class="delta">+{m['real_posts_7d']} ces 7 derniers jours</div>
      </div>
      <div class="kpi">
        <div class="label">💬 Commentaires</div>
        <div class="val">{m['comments_total']}</div>
        <div class="delta">+{m['comments_7d']} cette semaine</div>
      </div>
      <div class="kpi">
        <div class="label">🔍 Pages SEO Google</div>
        <div class="val">{m['sitemap_urls']}</div>
        <div class="delta">Sitemap indexé en continu</div>
      </div>
    </div>

    <div class="status-bar">
      🤖 <b>Autopilot Réseaux Sociaux (Facebook Allonssy + Essonne Actu + Instagram @allonssy8) :</b> Actif (Jetons permanents)<br>
      📌 <b>Dernière publication auto :</b> <code>{html.escape(m['last_meta_pub'])}</code><br>
      📦 <b>Inventaire actif :</b> {m['inv_market']} Marketplace • {m['inv_services']} Entraide/Services • {m['inv_restos']} Restaurants • {m['inv_news']} Articles d'actualité
    </div>

    <div class="card">
      <h2>🧑‍🤝‍🧑 Derniers Vrais Membres Inscrits</h2>
      <table>
        <thead><tr><th>Nom</th><th>Ville</th><th>Type</th><th>Inscrit le</th></tr></thead>
        <tbody>{user_rows}</tbody>
      </table>
    </div>

    <div class="card">
      <h2>⚡ Dernières Publications de Vrais Habitants</h2>
      <table>
        <thead><tr><th>Publication</th><th>Ville</th><th>Type</th><th>Date</th></tr></thead>
        <tbody>{post_rows}</tbody>
      </table>
    </div>
  </div>
</body>
</html>
"""


def main():
    metrics = collect_metrics()
    OUT_JSON.parent.mkdir(parents=True, exist_ok=True)
    OUT_JSON.write_text(json.dumps(metrics, indent=2, ensure_ascii=False), encoding="utf-8")
    OUT_HTML.write_text(render_html(metrics), encoding="utf-8")
    print(f"✅ Growth stats updated: {metrics['real_users_total']} real users, {metrics['real_posts_total']} real posts, {metrics['sitemap_urls']} SEO pages")


if __name__ == "__main__":
    main()
