#!/usr/bin/env python3
"""
meta_auto_publisher.py
100% Hands-Free Multi-Channel Social Auto-Publisher for Allonssy.
Runs daily at 08:15 UTC via cron on the VPS.

Automatically publishes:
1. Facebook Page: Allonssy - Bons Plans & Entraide 91 (ID: 1515002858354179)
   -> 1 Hot Marketplace bargain or local restaurant spotlight
2. Facebook Page: Essonne Actu & Débats - 91 (ID: 1492903483898849)
   -> 1 Breaking local news article with discussion prompt & clean slug link
3. Instagram: @allonssy8 (ID: 17841470142563615)
   -> Photo + rich caption + Essonne hashtags
"""
from __future__ import annotations

import json
import os
import re
import subprocess
import time
import unicodedata
import urllib.parse
import urllib.request
from datetime import datetime
from pathlib import Path

HOME = Path.home()
ENV_FILE = HOME / "supabase-project" / ".env"
LOG_DIR = HOME / "monitoring"
LOG_FILE = LOG_DIR / "meta_auto_publish.log"

BASE_URL = "https://app.allonssy.com"

# Meta IDs & Tokens
PAGE_ALLONSSY_ID = "1515002858354179"
PAGE_ACTU_ID = "1492903483898849"
IG_USER_ID = "17841470142563615"

PAGE_ALLONSSY_TOKEN = os.environ.get(
    "META_PAGE_ALLONSSY_TOKEN",
    "EAAWjg0SOJOYBTPUv1AEnoZApDcQ4xCT6i0GHKMCpz1aGw1O3txVSrZCnzkQcnWCzNn8AZCXmLnlB7imvSVfZApDBA6OUWbwyJnfxrzZCQkyoQHsMoEPVJr1gWuSL4mZCyZAugP9kg8yljAFAl15VguTi56Jv9jIkXFXD19EgvJ41Wu02tFtw4HAMbT8CQpyELBKjrsRT58eldw7sIZCzDwhmKOHo4UznaqBdysMWtAiUjZBLaOFSiJZBetysIP"
)

PAGE_ACTU_TOKEN = os.environ.get(
    "META_PAGE_ACTU_TOKEN",
    "EAAWjg0SOJOYBTMyt4ZBsFivykgdHo5I7CSTZAbAzP6LSqzBqFzzQRoAnHNNEfsa7yZCZAU6M2PFshV1IHTIWzi1ZBFxhjLAhjg2ft8UZCt5iajZBzZCbnYWR1tHaU8TQKtUWuYy0KNqTWTx28xDoPLm09coKSH6m05vElH1kUtZCLvyNHfao1mkBdAtvFMHERXBV5jqtTTZAv8kE7ZBIsng9R5dzZCNSzDLymsNQiMB6sdg0bqUQXjOGdmATwT9t"
)


def log(msg: str):
    timestamp = datetime.now().isoformat()
    line = f"[{timestamp}] {msg}"
    print(line)
    try:
        LOG_DIR.mkdir(parents=True, exist_ok=True)
        with open(LOG_FILE, "a", encoding="utf-8") as f:
            f.write(line + "\n")
    except Exception:
        pass


def make_slug(text: str) -> str:
    s = unicodedata.normalize("NFKD", text).encode("ascii", "ignore").decode("utf-8").lower()
    s = re.sub(r"[^a-z0-9]+", "-", s).strip("-")
    return s[:45]


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
        log(f"DB Error: {e}")
        return []


def post_to_facebook(page_id: str, access_token: str, message: str, link: str | None = None) -> dict | None:
    url = f"https://graph.facebook.com/v19.0/{page_id}/feed"
    payload = {
        "message": message,
        "access_token": access_token
    }
    if link:
        payload["link"] = link

    data = urllib.parse.urlencode(payload).encode("utf-8")
    req = urllib.request.Request(url, data=data, headers={"User-Agent": "Mozilla/5.0"})
    try:
        with urllib.request.urlopen(req, timeout=20) as resp:
            return json.loads(resp.read().decode("utf-8"))
    except urllib.error.HTTPError as e:
        log(f"FB Publish Error {e.code}: {e.read().decode('utf-8', 'ignore')}")
        return None
    except Exception as e:
        log(f"FB Request Error: {e}")
        return None


def post_to_instagram(image_url: str, caption: str, access_token: str) -> dict | None:
    # 1. Create Media Container
    container_url = f"https://graph.facebook.com/v19.0/{IG_USER_ID}/media"
    data = urllib.parse.urlencode({
        "image_url": image_url,
        "caption": caption,
        "access_token": access_token
    }).encode("utf-8")

    req = urllib.request.Request(container_url, data=data, headers={"User-Agent": "Mozilla/5.0"})
    try:
        with urllib.request.urlopen(req, timeout=25) as resp:
            res = json.loads(resp.read().decode("utf-8"))
            container_id = res.get("id")
            if not container_id:
                log(f"Failed to get IG container id: {res}")
                return None

        # Give Meta 3 seconds to process image
        time.sleep(3)

        # 2. Publish Media
        pub_url = f"https://graph.facebook.com/v19.0/{IG_USER_ID}/media_publish"
        pub_data = urllib.parse.urlencode({
            "creation_id": container_id,
            "access_token": access_token
        }).encode("utf-8")

        pub_req = urllib.request.Request(pub_url, data=pub_data, headers={"User-Agent": "Mozilla/5.0"})
        with urllib.request.urlopen(pub_req, timeout=25) as pub_resp:
            return json.loads(pub_resp.read().decode("utf-8"))

    except urllib.error.HTTPError as e:
        log(f"IG Publish Error {e.code}: {e.read().decode('utf-8', 'ignore')}")
        return None
    except Exception as e:
        log(f"IG Request Error: {e}")
        return None


def publish_allonssy_brand():
    log("Publishing daily highlight to Allonssy Page & Instagram...")
    # Get 1 hot marketplace item or restaurant
    market_items = query_db("""
    SELECT json_agg(m) FROM (
        SELECT id, market_title, market_price, original_price, location_name, content, image_url
        FROM posts
        WHERE post_type = 'market' AND image_url IS NOT NULL
        ORDER BY random()
        LIMIT 1
    ) m;
    """)

    m = market_items[0] if market_items else None
    if not m:
        log("No marketplace item found for Allonssy page.")
        return

    m_title = m.get("market_title", "Bon plan")
    m_city = m.get("location_name", "Grand Paris Sud")
    m_price = m.get("market_price", 0)
    m_link = f"{BASE_URL}/bonplan/{make_slug(m_title)}-{make_slug(m_city)}--{m['id']}"
    img_url = m.get("image_url") or "https://images.unsplash.com/photo-1585829365295-ab7cd400c167?w=1080&auto=format&fit=crop&q=80"

    fb_copy = f"""📍 BON PLAN OCCASION DU JOUR À {m_city.upper()} 🛒

Un voisin vient de mettre en vente :
👉 {m_title} à seulement {m_price} € !

Retrouvez la description complète, les photos et contactez le vendeur sans intermédiaire ni frais de livraison :
🔗 {m_link}

Rejoignez les habitants de Ris-Orangis, Grigny et Évry-Courcouronnes sur Allonssy !

#BonsPlans91 #{m_city.replace(' ', '')} #Occasion #GrandParisSud #Allonssy"""

    # 1. Post to Facebook Page Allonssy
    fb_res = post_to_facebook(PAGE_ALLONSSY_ID, PAGE_ALLONSSY_TOKEN, fb_copy, m_link)
    if fb_res:
        log(f"✅ Published to Allonssy FB Page: {fb_res.get('id')}")

    # 2. Post to Instagram @allonssy8
    ig_caption = f"""🔥 BON PLAN DE LA SEMAINE À {m_city.upper()}

Un habitant vend :
📦 {m_title} pour seulement {m_price} € !

Remise en main propre entre voisins sans frais d'envoi.
👉 Lien direct dans la bio ou téléchargez Allonssy sur le Google Play Store !

#Allonssy #RisOrangis #Evry #Grigny #Essonne #Essonne91 #GrandParisSud #BonPlan91 #Marketplace91"""

    ig_res = post_to_instagram(img_url, ig_caption, PAGE_ALLONSSY_TOKEN)
    if ig_res:
        log(f"✅ Published to Instagram @allonssy8: {ig_res.get('id')}")


def publish_essonne_actu():
    log("Publishing breaking local news to Essonne Actu & Débats...")
    news_items = query_db("""
    SELECT json_agg(nw) FROM (
        SELECT id, content, location_name, image_url
        FROM posts
        WHERE external_source = 'live_news'
        ORDER BY created_at DESC
        LIMIT 1
    ) nw;
    """)

    nw = news_items[0] if news_items else None
    if not nw:
        log("No news found for Essonne Actu page.")
        return

    raw_lines = [l.strip() for l in nw.get("content", "").split("\n") if l.strip()]
    headline = raw_lines[0] if raw_lines else "Actualité locale"
    summary = raw_lines[1] if len(raw_lines) > 1 else ""
    city = nw.get("location_name", "Grand Paris Sud")
    city_tag = city.split()[0].replace("-", "").replace("É", "E").replace("é", "e")
    nw_link = f"{BASE_URL}/actu/{make_slug(headline)}-{make_slug(city)}--{nw['id']}"

    actu_copy = f"""📰 ÇA SE PASSE À {city.upper()} 🗣️

{headline}

{summary}

Qu'en pensez-vous ? Réagissez dans les commentaires ou rejoignez le débat des riverains sur notre portail citoyen :
🔗 {nw_link}

Suivez en direct l'actualité de Ris-Orangis, Grigny, Évry et de l'Essonne sur Essonne Actu & Débats !

#Actu91 #{city_tag} #GrandParisSud #Essonne #Information #Allonssy"""

    res = post_to_facebook(PAGE_ACTU_ID, PAGE_ACTU_TOKEN, actu_copy, nw_link)
    if res:
        log(f"✅ Published to Essonne Actu FB Page: {res.get('id')}")


def main():
    log("Starting daily Meta automated social publishing...")
    publish_allonssy_brand()
    publish_essonne_actu()
    log("Finished Meta auto-publishing.")


if __name__ == "__main__":
    main()
