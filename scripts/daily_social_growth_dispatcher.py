#!/usr/bin/env python3
"""
Daily Multi-Channel Social Growth Dispatcher for Allonssy.
Picks the best daily local content (marketplace deal, community need, restaurant highlight, news),
generates ready-to-use marketing packs for:
  1. Facebook Groups (3 posts with 1-click share buttons)
  2. Instagram (Feed captions, carousel copy, story ideas & Essonne hashtag sets)
  3. TikTok (Viral 15-30s short-form video scripts with hooks, visual cues & sound ideas)

Emails the daily pack to kashif@tradister.com and ali.kashifmalik@gmail.com,
AND publishes a mobile-friendly 1-tap dashboard at /var/www/local_social_web/social_briefing.html!
"""
from __future__ import annotations

import html
import json
import os
import smtplib
import subprocess
import urllib.parse
from datetime import datetime, timezone
from email.message import EmailMessage
from pathlib import Path
import re

HOME = Path.home()
SUPABASE_ENV = HOME / "supabase-project" / ".env"
WEB_DIR = Path("/var/www/local_social_web")
DASHBOARD_FILE = WEB_DIR / "social_briefing.html"
BASE_URL = "https://app.allonssy.com"

# Multi-recipient list (falls back to ALERT_EMAIL_TO env var)
RECIPIENTS = [
    r.strip() for r in os.environ.get(
        "ALERT_EMAIL_TO",
        "kashif@tradister.com,ali.kashifmalik@gmail.com"
    ).split(",") if r.strip()
]


def read_env(path: Path) -> dict[str, str]:
    values: dict[str, str] = {}
    if not path.exists():
        return values
    for raw_line in path.read_text(encoding="utf-8").splitlines():
        line = raw_line.strip()
        if not line or line.startswith("#") or "=" not in line:
            continue
        key, value = line.split("=", 1)
        values[key.strip()] = value.strip().strip('"')
    return values


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


def get_daily_highlights() -> dict:
    # 1. Hot Marketplace Item
    market_items = query_db("""
    SELECT json_agg(m) FROM (
        SELECT id, market_title, market_price, original_price, location_name, content, image_url
        FROM posts
        WHERE post_type = 'market' AND image_url IS NOT NULL
        ORDER BY random()
        LIMIT 1
    ) m;
    """)
    market = market_items[0] if market_items else None

    # 2. Service Request (Community Need)
    need_items = query_db("""
    SELECT json_agg(n) FROM (
        SELECT id, market_title, location_name, content, market_price
        FROM posts
        WHERE post_type = 'service_request'
        ORDER BY random()
        LIMIT 1
    ) n;
    """)
    need = need_items[0] if need_items else None

    # 3. Local Restaurant Highlight
    resto_items = query_db("""
    SELECT json_agg(r) FROM (
        SELECT id, business_name, city, bio, avatar_url
        FROM profiles
        WHERE is_restaurant = true
        ORDER BY random()
        LIMIT 1
    ) r;
    """)
    resto = resto_items[0] if resto_items else None

    # 4. Fresh Local News Article
    news_items = query_db("""
    SELECT json_agg(nw) FROM (
        SELECT id, content, location_name, image_url
        FROM posts
        WHERE external_source = 'live_news'
        ORDER BY created_at DESC
        LIMIT 1
    ) nw;
    """)
    news = news_items[0] if news_items else None

    return {"market": market, "need": need, "resto": resto, "news": news}


import unicodedata

def make_slug(text: str) -> str:
    # Normalize accents cleanly (é -> e, â -> a, etc.)
    s = unicodedata.normalize('NFKD', text).encode('ascii', 'ignore').decode('utf-8').lower()
    s = re.sub(r'[^a-z0-9]+', '-', s).strip('-')
    return s[:45]


def format_fb_share_url(link: str, quote: str) -> str:
    params = {"u": link, "quote": quote}
    return f"https://www.facebook.com/sharer/sharer.php?{urllib.parse.urlencode(params)}"


def build_facebook_posts(data: dict) -> list[dict]:
    posts = []

    m = data.get("market")
    if m:
        m_title = m.get("market_title", "Bon plan")
        m_city = m.get("location_name", "Grand Paris Sud")
        m_link = f"{BASE_URL}/bonplan/{make_slug(m_title)}-{make_slug(m_city)}--{m['id']}"
        m_price = m.get("market_price", 0)
        orig = m.get("original_price")
        price_txt = f"{m_price} €" + (f" (au lieu de {orig} €)" if orig else "")

        copy = f"""📍 BON PLAN OCCASION À {m_city.upper()} 🛒

Un voisin vient de mettre en vente :
👉 {m_title} à seulement {price_txt} !

Pour voir les photos, la description complète ou contacter directement le vendeur sans intermédiaires ni frais de livraison :
🔗 {m_link}

Retrouvez d'autres objets vendus près de chez vous sur Allonssy (Ris-Orangis, Grigny, Évry) !

#BonsPlans91 #{m_city.replace(' ', '')} #Occasion #GrandParisSud #Allonssy"""
        posts.append({
            "badge": "🛒 Marketplace",
            "title": f"Bon plan : {m_title} ({price_txt})",
            "city": m_city,
            "copy": copy,
            "link": m_link,
            "share_url": format_fb_share_url(m_link, copy)
        })

    n = data.get("need")
    if n:
        n_title = n.get("market_title", "Besoin d'un coup de main")
        n_city = n.get("location_name", "Grand Paris Sud")
        n_link = f"{BASE_URL}/entraide/{make_slug(n_title)}-{make_slug(n_city)}--{n['id']}"
        n_price = n.get("market_price")
        remun = f" (Rémunération : {n_price} €)" if n_price else ""

        copy = f"""🤝 ENTRAIDE DE PROXIMITÉ À {n_city.upper()}

Un voisin a besoin d'un coup de main :
« {n_title} »{remun}

Si vous êtes disponible pour l'aider ou si vous cherchez vous aussi un artisan / baby-sitter / bricoleur dans le quartier, vous pouvez lui répondre directement ici :
🔗 {n_link}

Allonssy permet à tous les habitants de se rendre service localement et simplement.

#Entraide #{n_city.replace(' ', '')} #Voisins #Services91 #Allonssy"""
        posts.append({
            "badge": "🤝 Entraide",
            "title": f"Besoin voisin : {n_title}",
            "city": n_city,
            "copy": copy,
            "link": n_link,
            "share_url": format_fb_share_url(n_link, copy)
        })

    r = data.get("resto")
    if r:
        r_name = r.get("business_name", "Restaurant local")
        r_city = r.get("city", "Ris-Orangis")
        r_link = f"{BASE_URL}/p/{make_slug(r_name)}-{make_slug(r_city)}--{r['id']}"
        r_bio = r.get("bio", "Superbe adresse à découvrir.")

        copy = f"""🍔 DÉCOUVERTE RESTO DU JOUR À {r_city.upper()} 🍽️

Envie de bien manger ce midi ou ce soir ?
Découvrez {r_name} situé à {r_city} !
« {r_bio} »

Consultez leur carte, formules et spécialités directement sur leur fiche Allonssy :
🔗 {r_link}

Soutenez vos commerçants et restaurateurs locaux !

#Food91 #Resto{r_city.replace(' ', '')} #{r_city.replace(' ', '')} #SortirEnEssonne #Allonssy"""
        posts.append({
            "badge": "🍽️ Restaurant",
            "title": f"Découverte : {r_name} ({r_city})",
            "city": r_city,
            "copy": copy,
            "link": r_link,
            "share_url": format_fb_share_url(r_link, copy)
        })

    # Post 4: Fresh Local News & Debate
    nw = data.get("news")
    if nw:
        raw_lines = [l.strip() for l in nw.get("content", "").split("\n") if l.strip()]
        headline = raw_lines[0] if raw_lines else "Actualité locale"
        summary = raw_lines[1] if len(raw_lines) > 1 else ""
        city = nw.get("location_name", "Grand Paris Sud")
        city_tag = city.split()[0].replace("-", "").replace("É", "E").replace("é", "e")
        nw_link = f"{BASE_URL}/actu/{make_slug(headline)}-{make_slug(city)}--{nw['id']}"

        copy = f"""📰 ÇA SE PASSE À {city.upper()} 🗣️

{headline}

{summary}

Qu'en pensez-vous ? Réagissez avec les habitants du quartier et découvrez l'article complet ici :
🔗 {nw_link}

Suivez en direct l'actualité de Ris-Orangis, Grigny et Évry-Courcouronnes sur Allonssy !

#Actu91 #{city_tag} #GrandParisSud #Essonne #Voisins #Allonssy"""
        posts.append({
            "badge": "📰 Actu & Débat",
            "title": f"{headline[:55]}...",
            "city": city,
            "copy": copy,
            "link": nw_link,
            "share_url": format_fb_share_url(nw_link, copy)
        })

    return posts


def build_instagram_pack(data: dict) -> list[dict]:
    items = []
    hashtags = "#RisOrangis #EvryCourcouronnes #Grigny #Essonne #Essonne91 #GrandParisSud #BonPlan91 #Resto91 #SortirDansLe91 #Marketplace91 #Entraide91 #91000 #91130 #91350 #Allonssy"

    r = data.get("resto")
    if r:
        caption = f"""✨ PÉPITE FOOD DU 91 ✨

Ce midi ou ce soir, on met à l'honneur @{r.get('business_name')} à {r.get('city')} ! 🍴

« {r.get('bio')} »

Découvrez leur menu complet, leurs horaires et leurs formules sur Allonssy.
👉 Lien direct dans la bio ou téléchargez l'app Allonssy sur le Play Store !

{hashtags}"""
        items.append({
            "type": "Post / Reel Food",
            "title": f"Pépite Food : {r.get('business_name')}",
            "caption": caption,
            "story_idea": f"Story interactive : 'Tu as déjà testé {r.get('business_name')} à {r.get('city')} ?' (Sondage Oui/Non + Lien vers app.allonssy.com)"
        })

    m = data.get("market")
    if m:
        caption = f"""🔥 BON PLAN DE LA SEMAINE À {m.get('location_name', 'RIS-ORANGIS').upper()}

Un habitant vend :
📦 {m.get('market_title')} pour seulement {m.get('market_price')} € !

Pas de frais de port, pas d'attente : remise en main propre entre voisins.
👉 Trouvez d'autres affaires près de chez vous sur l'app Allonssy (lien en bio).

{hashtags}"""
        items.append({
            "type": "Post / Story Marketplace",
            "title": f"Bon plan : {m.get('market_title')}",
            "caption": caption,
            "story_idea": f"Photo de l'article + sticker Prix '{m.get('market_price')} €' + Sticker Lien : app.allonssy.com"
        })

    nw = data.get("news")
    if nw:
        raw_lines = [l.strip() for l in nw.get("content", "").split("\n") if l.strip()]
        headline = raw_lines[0] if raw_lines else "Actualité locale"
        summary = raw_lines[1] if len(raw_lines) > 1 else ""
        caption = f"""🚨 FLASH INFO 91 🚨

{headline}

{summary}

Et vous, qu'en pensez-vous ? Réagissez dans les commentaires 👇
L'article complet et les échanges sont disponibles sur l'app Allonssy (lien en bio).

{hashtags}"""
        items.append({
            "type": "Flash Info / Débat",
            "title": f"Actu : {headline[:40]}...",
            "caption": caption,
            "story_idea": f"Story Sondage : 'Tu en penses quoi ?' + Boîte à questions 'Votre avis' + Sticker Lien vers l'app"
        })

    return items


def build_tiktok_pack(data: dict) -> list[dict]:
    scripts = []
    m = data.get("market")
    r = data.get("resto")
    n = data.get("need")

    # Script 1: Local Neighborhood Hack / Student / Resident
    scripts.append({
        "title": "🎬 TikTok 1 : Le réflexe secret des habitants du 91 (15-20s)",
        "hook": "« Si tu habites à Ris-Orangis, Grigny ou Évry, arrête de scroller deux secondes... »",
        "visual": "Plan selfie face caméra ou vidéo marchant dans la ville / montrant l'écran de l'application.",
        "dialogue": f"""« Pourquoi payer des frais de port sur Vinted ou Leboncoin alors que tes voisins vendent exactement ce que tu cherches à 5 minutes à pied ?
Regarde : aujourd'hui sur l'app Allonssy, y a {m.get('market_title') if m else 'un vélo vintage'} pour {m.get('market_price', 25) if m else 25} € à {m.get('location_name', 'Ris-Orangis') if m else 'Ris-Orangis'}, et quelqu'un cherche un coup de main pour {n.get('market_title', 'du baby-sitting') if n else 'du bricolage'}.
Télécharge Allonssy sur Google Play ou clique sur le lien dans ma bio, c'est 100% gratuit ! »""",
        "text_on_screen": "L'appli secrète du 91 📍 (Pas de frais de livraison)",
        "sound": "Son trending / Beat chill type French rap instru ou lo-fi groovy",
        "hashtags": "#Essonne #RisOrangis #Evry #Grigny #GrandParisSud #PourToi #BonsPlans"
    })

    # Script 2: Food & Restaurant Discovery
    if r:
        scripts.append({
            "title": f"🎬 TikTok 2 : Où manger à {r.get('city')} ce week-end ? (20-25s)",
            "hook": f"« Tu cherches une bonne adresse food à {r.get('city')} qui change des fast-foods habituels ? »",
            "visual": f"Plans rapides sur les plats, la vitrine ou la fiche Allonssy du restaurant {r.get('business_name')}.",
            "dialogue": f"""« Je vous présente {r.get('business_name')} à {r.get('city')}.
{r.get('bio')}
Toutes les infos, le menu et les avis sont dispos sur l'appli locale Allonssy.
Abonne-toi pour plus d'adresses dans le 91 et lien en bio pour télécharger l'appli ! »""",
            "text_on_screen": f"Pépite Food à {r.get('city')} 🤤🍴",
            "sound": "Son tendance Food TikTok / son immersif ASMR ou musique rythmée",
            "hashtags": "#FoodTikTok #Resto91 #Essonne #SortirDansLe91 #Foodie"
        })

    return scripts


def render_web_dashboard(fb_posts: list[dict], ig_pack: list[dict], tiktok_pack: list[dict]) -> str:
    now_str = datetime.now().strftime("%d/%m/%Y")
    
    fb_cards = ""
    for i, p in enumerate(fb_posts, 1):
        safe_copy = html.escape(p["copy"])
        fb_cards += f"""
        <div class="card">
          <div class="card-header">
            <span class="badge fb-badge">{html.escape(p['badge'])}</span>
            <span class="city">{html.escape(p.get('city', ''))}</span>
          </div>
          <h4>{html.escape(p['title'])}</h4>
          <pre id="fb-copy-{i}">{safe_copy}</pre>
          <div class="actions">
            <button onclick="copyText('fb-copy-{i}')" class="btn btn-secondary">📋 Copier le texte</button>
            <a href="{p['share_url']}" target="_blank" class="btn btn-fb">📲 1-Clic : Partager sur Facebook</a>
          </div>
        </div>
        """

    ig_cards = ""
    for i, p in enumerate(ig_pack, 1):
        safe_caption = html.escape(p["caption"])
        ig_cards += f"""
        <div class="card">
          <div class="card-header">
            <span class="badge ig-badge">📸 {html.escape(p['type'])}</span>
          </div>
          <h4>{html.escape(p['title'])}</h4>
          <p style="font-size: 13px; color: #4B5563; margin-bottom: 8px;">💡 <b>Idée Story :</b> {html.escape(p.get('story_idea', ''))}</p>
          <pre id="ig-copy-{i}">{safe_caption}</pre>
          <div class="actions">
            <button onclick="copyText('ig-copy-{i}')" class="btn btn-ig">📸 Copier Caption Instagram</button>
          </div>
        </div>
        """

    tt_cards = ""
    for i, p in enumerate(tiktok_pack, 1):
        tt_cards += f"""
        <div class="card">
          <div class="card-header">
            <span class="badge tt-badge">🎵 TikTok</span>
          </div>
          <h4>{html.escape(p['title'])}</h4>
          <div class="tt-box">
            <p><b>🎯 Hook (3s) :</b> <span style="color: #E11D48;">{html.escape(p['hook'])}</span></p>
            <p><b>👀 Visuel :</b> {html.escape(p['visual'])}</p>
            <p><b>💬 Script parlé :</b></p>
            <pre id="tt-script-{i}">{html.escape(p['dialogue'])}</pre>
            <p><b>📱 Texte écran :</b> <code>{html.escape(p['text_on_screen'])}</code></p>
            <p><b>🎶 Son suggéré :</b> {html.escape(p['sound'])}</p>
            <p><b>🏷️ Hashtags :</b> <code>{html.escape(p['hashtags'])}</code></p>
          </div>
          <div class="actions">
            <button onclick="copyText('tt-script-{i}')" class="btn btn-tt">🎬 Copier le Script TikTok</button>
          </div>
        </div>
        """

    return f"""<!DOCTYPE html>
<html lang="fr">
<head>
  <meta charset="UTF-8">
  <meta name="viewport" content="width=device-width, initial-scale=1.0">
  <title>Allonssy! Social Media Growth Copilot ({now_str})</title>
  <style>
    body {{
      font-family: -apple-system, BlinkMacSystemFont, "Segoe UI", Roboto, Helvetica, Arial, sans-serif;
      background: #F3F4F6;
      margin: 0;
      padding: 16px;
      color: #111827;
    }}
    .container {{
      max-width: 820px;
      margin: 0 auto;
    }}
    header {{
      background: linear-gradient(135deg, #0F766E, #115E59);
      color: #ffffff;
      padding: 24px;
      border-radius: 16px;
      text-align: center;
      margin-bottom: 24px;
      box-shadow: 0 4px 12px rgba(15, 118, 110, 0.2);
    }}
    header h1 {{ margin: 0; font-size: 24px; }}
    header p {{ margin: 8px 0 0; opacity: 0.9; font-size: 14px; }}
    
    .nav-tabs {{
      display: flex;
      gap: 8px;
      margin-bottom: 20px;
      overflow-x: auto;
      padding-bottom: 4px;
    }}
    .tab-btn {{
      flex: 1;
      padding: 12px;
      background: #ffffff;
      border: 1px solid #E5E7EB;
      border-radius: 10px;
      font-weight: bold;
      font-size: 14px;
      cursor: pointer;
      text-align: center;
      transition: all 0.2s;
    }}
    .tab-btn.active {{
      background: #0F766E;
      color: #ffffff;
      border-color: #0F766E;
    }}
    
    .section-content {{ display: none; }}
    .section-content.active {{ display: block; }}
    
    .card {{
      background: #ffffff;
      border-radius: 14px;
      padding: 20px;
      margin-bottom: 20px;
      border: 1px solid #E5E7EB;
      box-shadow: 0 2px 6px rgba(0,0,0,0.03);
    }}
    .card-header {{
      display: flex;
      justify-content: space-between;
      align-items: center;
      margin-bottom: 12px;
    }}
    .badge {{
      display: inline-block;
      padding: 4px 10px;
      border-radius: 20px;
      font-size: 12px;
      font-weight: bold;
    }}
    .fb-badge {{ background: #EBF5FF; color: #1877F2; }}
    .ig-badge {{ background: #FDF2F8; color: #DB2777; }}
    .tt-badge {{ background: #F3F4F6; color: #111827; }}
    .city {{ font-size: 13px; color: #6B7280; font-weight: 500; }}
    
    h4 {{ margin: 0 0 10px; font-size: 17px; color: #111827; }}
    pre {{
      background: #F9FAFB;
      border: 1px solid #E5E7EB;
      padding: 14px;
      border-radius: 8px;
      font-family: inherit;
      font-size: 14px;
      white-space: pre-wrap;
      line-height: 1.5;
      color: #1F2937;
      margin: 0 0 14px;
    }}
    .tt-box {{
      background: #F9FAFB;
      border-radius: 10px;
      padding: 14px;
      font-size: 14px;
      line-height: 1.5;
      margin-bottom: 14px;
    }}
    .tt-box p {{ margin: 0 0 8px; }}
    .tt-box p:last-child {{ margin-bottom: 0; }}
    code {{ background: #E5E7EB; padding: 2px 6px; border-radius: 4px; font-size: 13px; }}
    
    .actions {{
      display: flex;
      gap: 10px;
      flex-wrap: wrap;
    }}
    .btn {{
      padding: 10px 18px;
      border-radius: 8px;
      font-weight: bold;
      font-size: 14px;
      text-decoration: none;
      cursor: pointer;
      border: none;
      transition: opacity 0.2s;
    }}
    .btn:hover {{ opacity: 0.9; }}
    .btn-secondary {{ background: #F3F4F6; color: #374151; }}
    .btn-fb {{ background: #1877F2; color: #ffffff; }}
    .btn-ig {{ background: linear-gradient(45deg, #F58529, #DD2A7B, #8134AF); color: #ffffff; }}
    .btn-tt {{ background: #000000; color: #ffffff; }}
    
    .toast {{
      position: fixed;
      bottom: 24px;
      left: 50%;
      transform: translateX(-50%);
      background: #10B981;
      color: #ffffff;
      padding: 10px 24px;
      border-radius: 30px;
      font-weight: bold;
      font-size: 14px;
      display: none;
      box-shadow: 0 4px 12px rgba(0,0,0,0.15);
      z-index: 1000;
    }}
  </style>
</head>
<body>
  <div class="container">
    <header>
      <h1>📱 Allonssy! Social Marketing Copilot</h1>
      <p>Vos publications du {now_str} • Ris-Orangis, Grigny & Évry</p>
    </header>

    <div class="nav-tabs">
      <button class="tab-btn active" onclick="switchTab('fb')">👥 Facebook Groups ({len(fb_posts)})</button>
      <button class="tab-btn" onclick="switchTab('ig')">📸 Instagram ({len(ig_pack)})</button>
      <button class="tab-btn" onclick="switchTab('tt')">🎵 TikTok Scripts ({len(tiktok_pack)})</button>
    </div>

    <!-- Facebook Section -->
    <div id="section-fb" class="section-content active">
      <div style="background: #EBF5FF; border: 1px solid #BFDBFE; border-radius: 10px; padding: 12px 16px; margin-bottom: 16px; font-size: 13px; color: #1E40AF;">
        📌 <b>Groupes recommandés :</b> « Tu sais que tu viens de Ris-Orangis quand... » • « Entraide Ris-Orangis » • « Bons plans Évry-Courcouronnes »
      </div>
      {fb_cards}
    </div>

    <!-- Instagram Section -->
    <div id="section-ig" class="section-content">
      <div style="background: #FDF2F8; border: 1px solid #FBCFE8; border-radius: 10px; padding: 12px 16px; margin-bottom: 16px; font-size: 13px; color: #9D174D;">
        📸 <b>Astuce Instagram :</b> Copiez le caption avec ses hashtags ciblés Essonne, publiez la photo du restaurant/produit et ajoutez le lien en Story avec le sticker Lien vers <code>https://app.allonssy.com</code>.
      </div>
      {ig_cards}
    </div>

    <!-- TikTok Section -->
    <div id="section-tt" class="section-content">
      <div style="background: #F3F4F6; border: 1px solid #E5E7EB; border-radius: 10px; padding: 12px 16px; margin-bottom: 16px; font-size: 13px; color: #111827;">
        🎵 <b>Format TikTok Viral :</b> Enregistrez face caméra ou filmez l'appli sur votre téléphone. Les 3 premières secondes (Hook) sont capitales pour retenir les jeunes d'Évry et Ris-Orangis !
      </div>
      {tt_cards}
    </div>
  </div>

  <div id="toast" class="toast">Texte copié dans le presse-papier ! ✅</div>

  <script>
    function switchTab(name) {{
      document.querySelectorAll('.tab-btn').forEach(b => b.classList.remove('active'));
      document.querySelectorAll('.section-content').forEach(s => s.classList.remove('active'));
      
      const idx = name === 'fb' ? 0 : (name === 'ig' ? 1 : 2);
      document.querySelectorAll('.tab-btn')[idx].classList.add('active');
      document.getElementById('section-' + name).classList.add('active');
    }}

    function copyText(id) {{
      const text = document.getElementById(id).innerText;
      navigator.clipboard.writeText(text).then(() => {{
        const toast = document.getElementById('toast');
        toast.style.display = 'block';
        setTimeout(() => {{ toast.style.display = 'none'; }}, 2500);
      }});
    }}
  </script>
</body>
</html>
"""


def send_email(fb_posts: list[dict], ig_pack: list[dict], tiktok_pack: list[dict]):
    env = read_env(SUPABASE_ENV)
    smtp_host = env.get("SMTP_HOST", "smtp.resend.com")
    smtp_port = int(env.get("SMTP_PORT", "465"))
    smtp_user = env.get("SMTP_USER", "resend")
    smtp_pass = env.get("SMTP_PASS")
    sender = env.get("SMTP_ADMIN_EMAIL", "hello@allonssy.com")
    sender_name = env.get("SMTP_SENDER_NAME", "Allonssy Marketing Copilot")

    if not smtp_pass:
        print("Missing SMTP pass")
        return

    today_str = datetime.now().strftime("%d/%m/%Y")
    subject = f"📣 Vos publications Facebook, Instagram & TikTok du jour ({today_str})"
    dashboard_url = f"{BASE_URL}/social_briefing.html"

    # HTML Parts
    fb_html = ""
    for i, p in enumerate(fb_posts, 1):
        fb_html += f"""
        <div style="background: #ffffff; border: 1px solid #E5E7EB; border-radius: 12px; padding: 18px; margin-bottom: 20px;">
          <h4 style="margin: 0 0 10px; color: #1877F2; font-size: 16px;">👥 Facebook {i} : {p['title']}</h4>
          <pre style="background: #F9FAFB; padding: 12px; border-radius: 8px; font-family: inherit; font-size: 13px; white-space: pre-wrap; line-height: 1.5; color: #1F2937;">{html.escape(p['copy'])}</pre>
          <div style="margin-top: 10px; text-align: right;">
            <a href="{p['share_url']}" target="_blank" style="display: inline-block; background: #1877F2; color: #ffffff; text-decoration: none; padding: 8px 16px; border-radius: 6px; font-weight: bold; font-size: 13px;">📲 1-Clic : Partager sur Facebook</a>
          </div>
        </div>
        """

    ig_html = ""
    for i, p in enumerate(ig_pack, 1):
        ig_html += f"""
        <div style="background: #ffffff; border: 1px solid #E5E7EB; border-radius: 12px; padding: 18px; margin-bottom: 20px;">
          <h4 style="margin: 0 0 10px; color: #DB2777; font-size: 16px;">📸 Instagram {i} : {p['title']}</h4>
          <p style="font-size: 13px; color: #4B5563; margin-bottom: 8px;"><b>Idée Story :</b> {html.escape(p.get('story_idea', ''))}</p>
          <pre style="background: #F9FAFB; padding: 12px; border-radius: 8px; font-family: inherit; font-size: 13px; white-space: pre-wrap; line-height: 1.5; color: #1F2937;">{html.escape(p['caption'])}</pre>
        </div>
        """

    tt_html = ""
    for i, p in enumerate(tiktok_pack, 1):
        tt_html += f"""
        <div style="background: #ffffff; border: 1px solid #E5E7EB; border-radius: 12px; padding: 18px; margin-bottom: 20px;">
          <h4 style="margin: 0 0 10px; color: #111827; font-size: 16px;">🎵 {p['title']}</h4>
          <p style="font-size: 13px; margin: 4px 0;"><b>🎯 Hook :</b> <span style="color: #E11D48;">{html.escape(p['hook'])}</span></p>
          <p style="font-size: 13px; margin: 4px 0;"><b>💬 Script :</b></p>
          <pre style="background: #F9FAFB; padding: 12px; border-radius: 8px; font-family: inherit; font-size: 13px; white-space: pre-wrap; line-height: 1.5; color: #1F2937;">{html.escape(p['dialogue'])}</pre>
          <p style="font-size: 12px; color: #6B7280; margin: 4px 0;"><b>🎶 Son :</b> {html.escape(p['sound'])} | <b>🏷️</b> {html.escape(p['hashtags'])}</p>
        </div>
        """

    full_html = f"""<!DOCTYPE html>
<html>
<body style="font-family: -apple-system, BlinkMacSystemFont, 'Segoe UI', Roboto, Helvetica, Arial, sans-serif; background-color: #F3F4F6; padding: 20px; color: #111827;">
  <div style="max-width: 680px; margin: 0 auto;">
    <div style="background: #0F766E; padding: 24px; border-radius: 16px 16px 0 0; color: #ffffff; text-align: center;">
      <h2 style="margin: 0; font-size: 22px;">📱 Vos Publications Réseaux Sociaux du Jour</h2>
      <p style="margin: 6px 0 0; opacity: 0.9; font-size: 14px;">Facebook • Instagram • TikTok • Ris-Orangis, Grigny & Évry</p>
    </div>
    
    <div style="background: #F8F9FA; padding: 24px; border-radius: 0 0 16px 16px;">
      <p style="margin-top: 0; font-size: 15px; line-height: 1.5;">
        Bonjour Kashif,<br>
        Voici votre pack de communication du jour pour animer la communauté et attirer du trafic local :
      </p>

      <div style="text-align: center; margin: 20px 0;">
        <a href="{dashboard_url}" target="_blank" style="display: inline-block; background: #0F766E; color: #ffffff; text-decoration: none; padding: 12px 24px; border-radius: 10px; font-weight: bold; font-size: 15px; box-shadow: 0 3px 8px rgba(15,118,110,0.3);">
          ⚡ Ouvrir le Dashboard Mobile (Copie en 1 Clic)
        </a>
      </div>

      <h3 style="color: #1877F2; margin-top: 28px; border-bottom: 2px solid #E5E7EB; padding-bottom: 8px;">👥 Publications Groupes Facebook</h3>
      {fb_html}

      <h3 style="color: #DB2777; margin-top: 28px; border-bottom: 2px solid #E5E7EB; padding-bottom: 8px;">📸 Posts & Stories Instagram</h3>
      {ig_html}

      <h3 style="color: #111827; margin-top: 28px; border-bottom: 2px solid #E5E7EB; padding-bottom: 8px;">🎵 Scripts Vidéos Courtes TikTok</h3>
      {tt_html}

      <div style="background: #E5E7EB; padding: 14px; border-radius: 10px; font-size: 13px; color: #4B5563; text-align: center; margin-top: 24px;">
        Allonssy Marketing Copilot • Grand Paris Sud
      </div>
    </div>
  </div>
</body>
</html>"""

    msg = EmailMessage()
    msg["Subject"] = subject
    msg["From"] = f"{sender_name} <{sender}>"
    msg["To"] = ", ".join(RECIPIENTS)
    msg.set_content(f"Ouvrez votre dashboard social Allonssy : {dashboard_url}")
    msg.add_alternative(full_html, subtype="html")

    with smtplib.SMTP_SSL(smtp_host, smtp_port, timeout=20) as s:
        s.login(smtp_user, smtp_pass)
        s.send_message(msg)

    print(f"✅ Daily multi-channel briefing sent to {', '.join(RECIPIENTS)}!")


def main():
    print("Selecting daily highlights from database...")
    data = get_daily_highlights()
    fb_posts = build_facebook_posts(data)
    ig_pack = build_instagram_pack(data)
    tiktok_pack = build_tiktok_pack(data)

    # 1. Generate live web dashboard for mobile 1-tap copy
    try:
        WEB_DIR.mkdir(parents=True, exist_ok=True)
        html_content = render_web_dashboard(fb_posts, ig_pack, tiktok_pack)
        DASHBOARD_FILE.write_text(html_content, encoding="utf-8")
        print(f"✅ Mobile Social Dashboard written to {DASHBOARD_FILE}")
    except Exception as e:
        print(f"Dashboard write error: {e}")

    # 2. Dispatch emails
    print(f"Sending daily multi-channel briefing to {', '.join(RECIPIENTS)}...")
    send_email(fb_posts, ig_pack, tiktok_pack)


if __name__ == "__main__":
    main()
