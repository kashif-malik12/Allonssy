#!/usr/bin/env python3
"""
live_news_publisher.py
Fetches live official and verified local press news for:
  - Ris-Orangis (91130)
  - Évry-Courcouronnes (91000)
  - Grigny (91350)
  - Essonne / Grand Paris Sud
Filters, deduplicates against database, routes to respective municipal news agencies,
and publishes fresh news articles to the Allonssy feed.
"""

import datetime
import email.utils
import html
import re
import subprocess
import sys
import urllib.request
import uuid
import xml.etree.ElementTree as ET

FEEDS = [
    {
        "name": "Google News Ris-Orangis",
        "url": "https://news.google.com/rss/search?q=Ris-Orangis&hl=fr&gl=FR&ceid=FR:fr",
        "default_city": "Ris-Orangis",
        "priority": 1,
    },
    {
        "name": "Google News Évry-Courcouronnes",
        "url": "https://news.google.com/rss/search?q=%22Evry-Courcouronnes%22+OR+%22Evry%22+Essonne&hl=fr&gl=FR&ceid=FR:fr",
        "default_city": "Évry-Courcouronnes",
        "priority": 1,
    },
    {
        "name": "Google News Grigny",
        "url": "https://news.google.com/rss/search?q=%22Grigny%22+Essonne&hl=fr&gl=FR&ceid=FR:fr",
        "default_city": "Grigny",
        "priority": 1,
    },
    {
        "name": "Google News Grand Paris Sud & Essonne",
        "url": "https://news.google.com/rss/search?q=%22Grand+Paris+Sud%22+OR+%22Essonne%22+actu&hl=fr&gl=FR&ceid=FR:fr",
        "default_city": "Grand Paris Sud",
        "priority": 2,
    },
]

IMAGE_PRESETS = [
    "https://images.unsplash.com/photo-1585829365295-ab7cd400c167?w=800&auto=format&fit=crop&q=80",  # Town hall / civic
    "https://images.unsplash.com/photo-1504711434969-e33886168f5c?w=800&auto=format&fit=crop&q=80",  # Press & news
    "https://images.unsplash.com/photo-1495020689067-958852a7765e?w=800&auto=format&fit=crop&q=80",  # Newspaper reading
    "https://images.unsplash.com/photo-1586339949916-3e9457bef6d3?w=800&auto=format&fit=crop&q=80",  # Breaking updates
    "https://images.unsplash.com/photo-1477959858617-67f85cf4f1df?w=800&auto=format&fit=crop&q=80",  # Cityscape
    "https://images.unsplash.com/photo-1519501025264-65ba15a82390?w=800&auto=format&fit=crop&q=80",  # Urban evening
    "https://images.unsplash.com/photo-1562774053-701939374585?w=800&auto=format&fit=crop&q=80",  # University / schools
    "https://images.unsplash.com/photo-1530549387789-4c1017266635?w=800&auto=format&fit=crop&q=80",  # Sports / events
    "https://images.unsplash.com/photo-1534088568595-a066f410bcda?w=800&auto=format&fit=crop&q=80",  # Weather
    "https://images.unsplash.com/photo-1449824913935-59a10b8d2000?w=800&auto=format&fit=crop&q=80",  # Street life
    "https://images.unsplash.com/photo-1486406146926-c627a92ad1ab?w=800&auto=format&fit=crop&q=80",  # Local economy
    "https://images.unsplash.com/photo-1517245386807-bb43f82c33c4?w=800&auto=format&fit=crop&q=80",  # Community debate
]

CITY_CONFIG = {
    "Ris-Orangis": {
        "email": "infos.ris-orangis@allonssy.com",
        "location": "Ris-Orangis (91130)",
        "lat": 48.6508,
        "lng": 2.4143,
    },
    "Évry-Courcouronnes": {
        "email": "infos.evry@allonssy.com",
        "location": "Évry-Courcouronnes (91000)",
        "lat": 48.6298,
        "lng": 2.4418,
    },
    "Grigny": {
        "email": "infos.grigny@allonssy.com",
        "location": "Grigny (91350)",
        "lat": 48.6536,
        "lng": 2.3838,
    },
    "Grand Paris Sud": {
        "email": "actu.essonne@allonssy.com",
        "location": "Grand Paris Sud (91)",
        "lat": 48.6298,
        "lng": 2.4418,
    },
}


def clean_html(raw_html: str) -> str:
    cleanr = re.compile(r'<.*?>')
    text = re.sub(cleanr, ' ', raw_html)
    text = html.unescape(text)
    return re.sub(r'\s+', ' ', text).strip()


def detect_city(title: str, desc: str, default_city: str) -> str:
    text = f"{title} {desc}".lower()
    if "ris-orangis" in text or "ris orangis" in text:
        return "Ris-Orangis"
    if "evry" in text or "évry" in text or "courcouronnes" in text:
        return "Évry-Courcouronnes"
    if "grigny" in text:
        return "Grigny"
    return default_city if default_city in CITY_CONFIG else "Grand Paris Sud"


def get_existing_external_ids() -> set[str]:
    """Query postgres for all already published live_news external_ids to prevent duplicates."""
    sql = "SELECT external_id FROM public.posts WHERE external_source = 'live_news' AND external_id IS NOT NULL;"
    cmd = ["docker", "exec", "-i", "supabase-db", "psql", "-U", "postgres", "-d", "postgres", "-t", "-A"]
    try:
        res = subprocess.run(cmd, input=sql, text=True, capture_output=True, check=True)
        return set(line.strip() for line in res.stdout.splitlines() if line.strip())
    except Exception as e:
        print(f"Warning: could not fetch existing external_ids: {e}", file=sys.stderr)
        return set()


def fetch_feed_items(url: str, default_city: str) -> list[dict]:
    req = urllib.request.Request(url, headers={'User-Agent': 'Mozilla/5.0 (Windows NT 10.0; Win64; x64)'})
    with urllib.request.urlopen(req, timeout=12) as resp:
        xml_data = resp.read()
    root = ET.fromstring(xml_data)
    items = []
    for it in root.findall('.//item'):
        title = it.find('title').text if it.find('title') is not None else ''
        link = it.find('link').text if it.find('link') is not None else ''
        pub_date_str = it.find('pubDate').text if it.find('pubDate') is not None else ''
        desc = it.find('description').text if it.find('description') is not None else ''
        guid = it.find('guid').text if it.find('guid') is not None else link

        parsed_date = None
        if pub_date_str:
            try:
                parsed_date = email.utils.parsedate_to_datetime(pub_date_str)
            except Exception:
                pass

        items.append({
            "title": title.strip(),
            "link": link.strip(),
            "guid": guid.strip(),
            "pub_date": parsed_date,
            "description": clean_html(desc),
            "default_city": default_city,
        })
    return items


def publish_news_article(article: dict, img_url: str) -> bool:
    post_id = str(uuid.uuid4())
    title = article["title"]
    source = "Presse Locale"
    if " - " in title:
        parts = title.rsplit(" - ", 1)
        title = parts[0].strip()
        source = parts[1].strip()

    desc = article["description"]
    # Strip trailing source name if Google News just repeated the title + source
    if source and desc.endswith(source):
        desc = desc[:-len(source)].strip(" -–—·|")
    if len(desc) > 280:
        desc = desc[:277] + "..."

    city_key = detect_city(title, desc, article.get("default_city", "Grand Paris Sud"))
    city_info = CITY_CONFIG.get(city_key, CITY_CONFIG["Grand Paris Sud"])

    content = f"📰 [ACTU • {city_key.upper()}] {title}\n\n"
    # Only include description if it adds new information beyond the headline
    if desc and desc.lower()[:45] != title.lower()[:45]:
        content += f"{desc}\n\n"
    content += f"📌 Source : {source}\n💬 Qu'en pensez-vous ? Réagissez en commentaire avec vos voisins !"

    content_esc = content.replace("'", "''")
    ext_id_esc = article["guid"].replace("'", "''")
    img_sql = f"'{img_url}'"

    sql = f"""
DO $$
DECLARE
    v_user_id uuid;
BEGIN
    SELECT id INTO v_user_id
    FROM public.profiles
    WHERE email = '{city_info["email"]}'
    LIMIT 1;

    IF v_user_id IS NULL THEN
        -- Fallback to Ris-Orangis news profile if specific city not found
        SELECT id INTO v_user_id FROM public.profiles WHERE email = 'infos.ris-orangis@allonssy.com' LIMIT 1;
    END IF;

    IF v_user_id IS NOT NULL THEN
        INSERT INTO public.posts (
            id, user_id, content, image_url, visibility, location_name,
            latitude, longitude, created_at, author_profile_type, post_type,
            share_scope, is_unclaimed, external_source, external_id
        ) VALUES (
            '{post_id}',
            v_user_id,
            '{content_esc}',
            {img_sql},
            'public',
            '{city_info["location"]}',
            {city_info["lat"]},
            {city_info["lng"]},
            now(),
            'org',
            'post',
            'public',
            false,
            'live_news',
            '{ext_id_esc}'
        );
    END IF;
END $$;
"""
    cmd = ["docker", "exec", "-i", "supabase-db", "psql", "-U", "postgres", "-d", "postgres"]
    res = subprocess.run(cmd, input=sql, text=True, capture_output=True)
    if res.returncode == 0:
        print(f"[{datetime.datetime.now().isoformat()}] Published news for {city_key}: {title} ({source})")
        return True
    else:
        print(f"Error publishing news: {res.stderr}", file=sys.stderr)
        return False


def main():
    existing_ids = get_existing_external_ids()
    print(f"Found {len(existing_ids)} previously published news IDs.")

    cutoff_date = datetime.datetime.now(datetime.timezone.utc) - datetime.timedelta(days=3)
    candidates = []

    for feed in FEEDS:
        try:
            items = fetch_feed_items(feed["url"], feed["default_city"])
            print(f"Fetched {len(items)} items from {feed['name']}.")
            for it in items:
                if it["guid"] in existing_ids or it["link"] in existing_ids:
                    continue
                if it["pub_date"] and it["pub_date"] < cutoff_date:
                    continue
                candidates.append((feed["priority"], it))
        except Exception as e:
            print(f"Error fetching {feed['name']}: {e}", file=sys.stderr)

    # Sort candidates by priority, then date
    candidates.sort(key=lambda x: (x[0], -(x[1]["pub_date"].timestamp() if x[1]["pub_date"] else 0)))

    # Deduplicate candidate titles
    unique_candidates = []
    seen_titles = set()
    for _, it in candidates:
        norm_title = it["title"].lower()[:40]
        if norm_title not in seen_titles:
            seen_titles.add(norm_title)
            unique_candidates.append(it)

    print(f"Identified {len(unique_candidates)} fresh news candidates.")

    published_count = 0
    max_to_publish = 4  # 1-2 per key city

    for it in unique_candidates:
        if published_count >= max_to_publish:
            break
        img_url = IMAGE_PRESETS[published_count % len(IMAGE_PRESETS)]
        if publish_news_article(it, img_url):
            existing_ids.add(it["guid"])
            published_count += 1

    print(f"Done. Published {published_count} new articles.")

    # Automatically refresh the news portal and SEO sitemap
    if published_count > 0:
        try:
            print("Refreshing actualites.html portal...")
            subprocess.run(["python3", "/home/deploy/bin/generate_news_portal.py"], check=False)
            print("Refreshing sitemap.xml...")
            subprocess.run(["python3", "/home/deploy/bin/generate_seo_sitemap.py"], check=False)
        except Exception as e:
            print(f"Post-publish refresh error: {e}", file=sys.stderr)


if __name__ == "__main__":
    main()
