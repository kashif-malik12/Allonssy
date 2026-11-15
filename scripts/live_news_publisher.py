#!/usr/bin/env python3
"""
live_news_publisher.py
Fetches live official and verified local press news for Ris-Orangis (91130) and Grand Paris Sud.
Filters, deduplicates against database, and publishes fresh news articles to the Allonssy feed.
"""

import sys
import uuid
import datetime
import urllib.request
import xml.etree.ElementTree as ET
import subprocess
import email.utils
import re

FEEDS = [
    {
        "name": "Google News Ris-Orangis",
        "url": "https://news.google.com/rss/search?q=Ris-Orangis&hl=fr&gl=FR&ceid=FR:fr",
        "priority": 1,
    },
    {
        "name": "Google News Grand Paris Sud",
        "url": "https://news.google.com/rss/search?q=%22Grand+Paris+Sud%22&hl=fr&gl=FR&ceid=FR:fr",
        "priority": 2,
    },
]

IMAGE_PRESETS = [
    "https://images.unsplash.com/photo-1585829365295-ab7cd400c167?w=800&auto=format&fit=crop&q=80", # Town hall / civic
    "https://images.unsplash.com/photo-1504711434969-e33886168f5c?w=800&auto=format&fit=crop&q=80", # Press & news
    "https://images.unsplash.com/photo-1495020689067-958852a7765e?w=800&auto=format&fit=crop&q=80", # Newspaper reading
    "https://images.unsplash.com/photo-1586339949916-3e9457bef6d3?w=800&auto=format&fit=crop&q=80", # Breaking updates
]

def clean_html(raw_html):
    cleanr = re.compile('<.*?>')
    return re.sub(cleanr, '', raw_html).strip()

def get_existing_external_ids():
    """Query postgres for all already published live_news external_ids to prevent duplicates."""
    sql = "SELECT external_id FROM public.posts WHERE external_source = 'live_news' AND external_id IS NOT NULL;"
    cmd = ["docker", "exec", "-i", "supabase-db", "psql", "-U", "postgres", "-d", "postgres", "-t", "-A"]
    try:
        res = subprocess.run(cmd, input=sql, text=True, capture_output=True, check=True)
        return set(line.strip() for line in res.stdout.splitlines() if line.strip())
    except Exception as e:
        print(f"Warning: could not fetch existing external_ids: {e}", file=sys.stderr)
        return set()

def fetch_feed_items(url):
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
        })
    return items

def publish_news_article(article, img_url):
    post_id = str(uuid.uuid4())
    title = article["title"]
    source = "Presse Locale"
    if " - " in title:
        parts = title.rsplit(" - ", 1)
        title = parts[0].strip()
        source = parts[1].strip()

    desc = article["description"]
    # Truncate clean description to 250 chars if too long
    if len(desc) > 300:
        desc = desc[:297] + "..."

    content = f"📰 [ACTUALITÉ LOCALE] {title}\n\n"
    if desc and desc != title:
        content += f"{desc}\n\n"
    content += f"📌 Source : {source}\n🔗 Lire l'article complet : {article['link']}"

    content_esc = content.replace("'", "''")
    ext_id_esc = article["guid"].replace("'", "''")
    img_sql = f"'{img_url}'"

    sql = f"""
DO $$
DECLARE
    v_user_id uuid;
    v_lat double precision;
    v_lng double precision;
BEGIN
    SELECT id, latitude, longitude
    INTO v_user_id, v_lat, v_lng
    FROM public.profiles
    WHERE email = 'infos.ris-orangis@allonssy.com'
    LIMIT 1;

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
            'Ris-Orangis (91130)',
            COALESCE(v_lat, 48.6508),
            COALESCE(v_lng, 2.4143),
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
        print(f"[{datetime.datetime.now().isoformat()}] Successfully published live news: {title} ({source})")
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
            items = fetch_feed_items(feed["url"])
            print(f"Fetched {len(items)} items from {feed['name']}.")
            for it in items:
                if it["guid"] in existing_ids or it["link"] in existing_ids:
                    continue
                # Date check
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

    # Limit to top 2-3 per run to keep feed balanced
    published_count = 0
    max_to_publish = 2

    for it in unique_candidates:
        if published_count >= max_to_publish:
            break
        img_url = IMAGE_PRESETS[published_count % len(IMAGE_PRESETS)]
        if publish_news_article(it, img_url):
            existing_ids.add(it["guid"])
            published_count += 1

    print(f"Done. Published {published_count} new articles.")

if __name__ == "__main__":
    main()
