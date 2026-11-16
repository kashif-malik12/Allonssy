#!/usr/bin/env python3
"""
Real-time new post notification daemon for Allonssy.
Alerts kashif@tradsiter.com via Resend SMTP whenever a new post/need/market item is created.
"""
from __future__ import annotations

import json
import os
import smtplib
import subprocess
from datetime import datetime, timezone
from email.message import EmailMessage
from pathlib import Path

HOME = Path.home()
SUPABASE_ENV = HOME / "supabase-project" / ".env"
STATE_DIR = HOME / "monitoring"
STATE_FILE = STATE_DIR / "last_notified_post_ts.txt"
RECIPIENT = "kashif@tradsiter.com"
APP_URL = "https://app.allonssy.com"

POST_TYPE_LABELS = {
    "service_request": "Demande de service / Entraide",
    "service_offer": "Offre de service",
    "market": "Article Marketplace (Achat/Vente)",
    "post": "Publication locale",
    "lost_found": "Objet perdu / trouvé",
    "food_ad": "Annonce restaurant / food",
}

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

def get_last_ts() -> str:
    STATE_DIR.mkdir(parents=True, exist_ok=True)
    if not STATE_FILE.exists():
        # Initialize to current UTC time so we don't spam for past seeded posts
        now_iso = datetime.now(timezone.utc).isoformat()
        STATE_FILE.write_text(now_iso, encoding="utf-8")
        return now_iso
    return STATE_FILE.read_text(encoding="utf-8").strip()

def set_last_ts(ts: str) -> None:
    STATE_FILE.write_text(ts, encoding="utf-8")

def query_new_posts(since_ts: str) -> list[dict]:
    # Query postgres container
    sql = f"""
    SELECT json_agg(p) FROM (
        SELECT 
            posts.id,
            posts.post_type,
            posts.market_title,
            posts.market_price,
            posts.content,
            posts.location_name,
            posts.created_at,
            profiles.full_name AS author_name,
            profiles.email AS author_email,
            profiles.phone AS author_phone,
            profiles.city AS author_city
        FROM posts
        LEFT JOIN profiles ON posts.user_id = profiles.id
        WHERE posts.created_at > '{since_ts}'::timestamptz
          AND posts.id::text NOT LIKE '66666666-%'
        ORDER BY posts.created_at ASC
    ) p;
    """
    cmd = [
        "docker", "exec", "-i", "supabase-db",
        "psql", "-U", "postgres", "-d", "postgres",
        "-t", "-A", "-c", sql
    ]
    res = subprocess.run(cmd, capture_output=True, text=True, check=False)
    raw = (res.stdout or "").strip()
    if not raw or raw == "null" or raw == "":
        return []
    try:
        return json.loads(raw)
    except Exception as e:
        print(f"JSON parse error: {e}, raw: {raw[:200]}")
        return []

def send_alert_email(post: dict) -> None:
    env = read_env(SUPABASE_ENV)
    smtp_host = env.get("SMTP_HOST", "smtp.resend.com")
    smtp_port = int(env.get("SMTP_PORT", "465"))
    smtp_user = env.get("SMTP_USER", "resend")
    smtp_pass = env.get("SMTP_PASS")
    sender = env.get("SMTP_ADMIN_EMAIL", "hello@allonssy.com")
    sender_name = env.get("SMTP_SENDER_NAME", "Allonssy Alertes")

    if not smtp_pass:
        print("Missing SMTP password, cannot send email")
        return

    ptype = post.get("post_type") or "post"
    ptype_label = POST_TYPE_LABELS.get(ptype, ptype)
    city = post.get("location_name") or post.get("author_city") or "Grand Paris Sud"
    title = post.get("market_title") or (post.get("content", "")[:50] + "...")
    author_name = post.get("author_name") or "Utilisateur anonyme"
    author_email = post.get("author_email") or "Non renseigné"
    author_phone = post.get("author_phone") or "Non renseigné"
    price = post.get("market_price")
    price_str = f"{price} €" if price is not None else "Non spécifié"
    post_id = post.get("id")
    post_url = f"{APP_URL}/p/{post_id}"

    subject = f"🔔 [Allonssy] Nouveau {ptype_label} à {city} : {title}"

    text_body = f"""Bonjour Kashif,

Un nouveau post vient d'être publié sur Allonssy !

━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
TYPE        : {ptype_label}
VILLE       : {city}
TITRE       : {title}
PRIX        : {price_str}
AUTEUR      : {author_name}
EMAIL       : {author_email}
TÉLÉPHONE   : {author_phone}
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

DESCRIPTION :
{post.get('content', '')}

👉 LIEN DIRECT POUR RÉPONDRE OU INTERAGIR :
{post_url}

--
Allonssy Real-Time Engine
"""

    html_body = f"""<!DOCTYPE html>
<html>
<head><meta charset="utf-8"></head>
<body style="font-family: -apple-system, BlinkMacSystemFont, 'Segoe UI', Roboto, Helvetica, Arial, sans-serif; background-color: #F5F1E8; padding: 20px; color: #12211D;">
  <div style="max-width: 580px; margin: 0 auto; background: #ffffff; border-radius: 16px; overflow: hidden; box-shadow: 0 4px 12px rgba(0,0,0,0.08);">
    <div style="background: #0F766E; padding: 20px 24px; color: #ffffff;">
      <h2 style="margin: 0; font-size: 20px;">🔔 Nouveau contenu sur Allonssy !</h2>
      <p style="margin: 4px 0 0; opacity: 0.9; font-size: 14px;">{ptype_label} • {city}</p>
    </div>
    
    <div style="padding: 24px;">
      <h3 style="margin: 0 0 12px; color: #0F766E; font-size: 18px;">{title}</h3>
      
      <p style="background: #F8F9FA; padding: 14px; border-radius: 10px; font-size: 15px; line-height: 1.5; margin: 0 0 16px; white-space: pre-wrap;">{post.get('content', '')}</p>
      
      <table style="width: 100%; border-collapse: collapse; margin-bottom: 24px; font-size: 14px;">
        <tr><td style="padding: 6px 0; color: #666;">Prix / Tarif :</td><td style="padding: 6px 0; font-weight: bold;">{price_str}</td></tr>
        <tr><td style="padding: 6px 0; color: #666;">Auteur :</td><td style="padding: 6px 0; font-weight: bold;">{author_name}</td></tr>
        <tr><td style="padding: 6px 0; color: #666;">Email :</td><td style="padding: 6px 0;">{author_email}</td></tr>
        <tr><td style="padding: 6px 0; color: #666;">Téléphone :</td><td style="padding: 6px 0;">{author_phone}</td></tr>
      </table>

      <div style="text-align: center;">
        <a href="{post_url}" style="display: inline-block; background: #0F766E; color: #ffffff; text-decoration: none; padding: 12px 28px; border-radius: 12px; font-weight: bold; font-size: 15px;">👉 Voir le post & Répondre</a>
      </div>
    </div>
    
    <div style="background: #EFE9DC; padding: 12px 24px; text-align: center; font-size: 12px; color: #666;">
      Allonssy Real-Time Engine • Ris-Orangis, Grigny & Évry
    </div>
  </div>
</body>
</html>
"""

    msg = EmailMessage()
    msg["Subject"] = subject
    msg["From"] = f"{sender_name} <{sender}>"
    msg["To"] = RECIPIENT
    msg.set_content(text_body)
    msg.add_alternative(html_body, subtype="html")

    with smtplib.SMTP_SSL(smtp_host, smtp_port, timeout=20) as s:
        s.login(smtp_user, smtp_pass)
        s.send_message(msg)

    print(f"Sent alert for post {post_id} to {RECIPIENT}")

def main():
    since_ts = get_last_ts()
    new_posts = query_new_posts(since_ts)
    if not new_posts:
        return

    latest_ts = since_ts
    for post in new_posts:
        try:
            send_alert_email(post)
        except Exception as e:
            print(f"Error sending alert for {post.get('id')}: {e}")
        p_ts = post.get("created_at")
        if p_ts and p_ts > latest_ts:
            latest_ts = p_ts

    set_last_ts(latest_ts)
    print(f"Processed {len(new_posts)} new posts. Cursor updated to {latest_ts}")

if __name__ == "__main__":
    main()
