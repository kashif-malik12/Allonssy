#!/usr/bin/env python3
"""
Daily Social Growth Dispatcher for Allonssy.
Picks the best daily local content (marketplace deal, community need, restaurant highlight, news),
generates 3 high-converting Facebook Group posts, and emails them to kashif@tradsiter.com
with 1-click Facebook share buttons!
"""
from __future__ import annotations

import json
import os
import smtplib
import subprocess
import urllib.parse
from datetime import datetime, timezone
from email.message import EmailMessage
from pathlib import Path

HOME = Path.home()
SUPABASE_ENV = HOME / "supabase-project" / ".env"
RECIPIENT = "kashif@tradsiter.com"
BASE_URL = "https://app.allonssy.com"


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

    return {"market": market, "need": need, "resto": resto}


def format_fb_share_url(link: str, quote: str) -> str:
    params = {
        "u": link,
        "quote": quote
    }
    return f"https://www.facebook.com/sharer/sharer.php?{urllib.parse.urlencode(params)}"


def build_posts(data: dict) -> list[dict]:
    posts = []

    # Post 1: Marketplace Deal
    m = data.get("market")
    if m:
        m_link = f"{BASE_URL}/post/{m['id']}"
        m_title = m.get("market_title", "Bon plan")
        m_city = m.get("location_name", "Grand Paris Sud")
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
            "title": f"🛒 Post Marketplace : {m_title}",
            "copy": copy,
            "link": m_link,
            "share_url": format_fb_share_url(m_link, copy)
        })

    # Post 2: Community Entraide & Needs
    n = data.get("need")
    if n:
        n_link = f"{BASE_URL}/post/{n['id']}"
        n_title = n.get("market_title", "Besoin d'un coup de main")
        n_city = n.get("location_name", "Grand Paris Sud")
        n_price = n.get("market_price")
        remun = f" (Rémunération proposée : {n_price} €)" if n_price else ""

        copy = f"""🤝 ENTRAIDE DE PROXIMITÉ À {n_city.upper()}

Un voisin a besoin d'un coup de main :
« {n_title} »{remun}

Si vous êtes disponible pour l'aider ou si vous cherchez vous aussi un artisan / bricoleur / baby-sitter dans le quartier, vous pouvez lui répondre directement ici :
🔗 {n_link}

Allonssy permet à tous les habitants de se rendre service localement et simplement.

#Entraide #{n_city.replace(' ', '')} #Voisins #Services91 #Allonssy"""
        posts.append({
            "title": f"🤝 Post Entraide & Besoin : {n_title}",
            "copy": copy,
            "link": n_link,
            "share_url": format_fb_share_url(n_link, copy)
        })

    # Post 3: Local Restaurant Discovery
    r = data.get("resto")
    if r:
        r_link = f"{BASE_URL}/p/{r['id']}"
        r_name = r.get("business_name", "Restaurant local")
        r_city = r.get("city", "Ris-Orangis")
        r_bio = r.get("bio", "Superbe adresse à découvrir.")

        copy = f"""🍔 DÉCOUVERTE RESTO DU JOUR À {r_city.upper()} 🍽️

Envie de bien manger ce midi ou ce soir ?
Découvrez {r_name} situé à {r_city} !
« {r_bio} »

Consultez leur carte, menu du jour et spécialités directement sur leur fiche Allonssy :
🔗 {r_link}

Soutenez vos commerçants et restaurateurs locaux !

#Food91 #Resto{r_city.replace(' ', '')} #{r_city.replace(' ', '')} #SortirEnEssonne #Allonssy"""
        posts.append({
            "title": f"🍽️ Post Découverte Restaurant : {r_name}",
            "copy": copy,
            "link": r_link,
            "share_url": format_fb_share_url(r_link, copy)
        })

    return posts


def send_email(posts: list[dict]):
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

    subject = f"📣 Vos 3 posts Facebook du jour pour Allonssy ({datetime.now().strftime('%d/%m/%Y')})"

    html_parts = []
    text_parts = []

    for i, p in enumerate(posts, 1):
        text_parts.append(f"""========================================
OPTION {i} : {p['title']}
========================================
{p['copy']}

👉 Bouton 1-Clic pour Partager sur Facebook :
{p['share_url']}
""")

        html_parts.append(f"""
        <div style="background: #ffffff; border: 1px solid #E5E7EB; border-radius: 12px; padding: 20px; margin-bottom: 24px; box-shadow: 0 2px 6px rgba(0,0,0,0.04);">
          <h3 style="margin-top: 0; color: #0F766E; font-size: 16px;">Option {i} : {p['title']}</h3>
          <pre style="background: #F9FAFB; padding: 14px; border-radius: 8px; font-family: inherit; font-size: 14px; white-space: pre-wrap; line-height: 1.5; color: #1F2937;">{p['copy']}</pre>
          <div style="margin-top: 14px; text-align: right;">
            <a href="{p['share_url']}" target="_blank" style="display: inline-block; background: #1877F2; color: #ffffff; text-decoration: none; padding: 10px 20px; border-radius: 8px; font-weight: bold; font-size: 14px;">📲 1-Clic : Partager sur Facebook</a>
          </div>
        </div>
        """)

    full_html = f"""<!DOCTYPE html>
<html>
<body style="font-family: -apple-system, BlinkMacSystemFont, 'Segoe UI', Roboto, Helvetica, Arial, sans-serif; background-color: #F5F1E8; padding: 20px; color: #12211D;">
  <div style="max-width: 650px; margin: 0 auto;">
    <div style="background: #0F766E; padding: 24px; border-radius: 16px 16px 0 0; color: #ffffff; text-align: center;">
      <h2 style="margin: 0; font-size: 22px;">📣 Vos 3 Posts Facebook du Jour</h2>
      <p style="margin: 6px 0 0; opacity: 0.9; font-size: 14px;">Prêts à être partagés dans les groupes de Ris-Orangis, Grigny & Évry</p>
    </div>
    
    <div style="background: #F8F9FA; padding: 24px; border-radius: 0 0 16px 16px;">
      <p style="margin-top: 0; font-size: 15px; line-height: 1.5;">
        Bonjour Kashif,<br>
        Voici vos 3 publications d'engagement sélectionnées pour aujourd'hui. Il vous suffit de cliquer sur <b>« Partager sur Facebook »</b> ou de copier le texte dans vos groupes locaux de quartier !
      </p>

      {"".join(html_parts)}

      <div style="background: #E5E7EB; padding: 14px; border-radius: 10px; font-size: 13px; color: #4B5563; text-align: center;">
        Groupes cibles recommandés :<br>
        <b>« Tu sais que tu viens de Ris-Orangis quand... »</b> • <b>« Entraide Ris-Orangis »</b> • <b>« Bons Plans Évry »</b>
      </div>
    </div>
  </div>
</body>
</html>"""

    msg = EmailMessage()
    msg["Subject"] = subject
    msg["From"] = f"{sender_name} <{sender}>"
    msg["To"] = RECIPIENT
    msg.set_content("\n".join(text_parts))
    msg.add_alternative(full_html, subtype="html")

    with smtplib.SMTP_SSL(smtp_host, smtp_port, timeout=20) as s:
        s.login(smtp_user, smtp_pass)
        s.send_message(msg)

    print(f"✅ Daily social growth briefing sent to {RECIPIENT}!")


def main():
    print("Selecting daily highlights from database...")
    data = get_daily_highlights()
    posts = build_posts(data)
    if not posts:
        print("No highlights found.")
        return
    print(f"Generated {len(posts)} social posts. Sending email...")
    send_email(posts)


if __name__ == "__main__":
    main()
