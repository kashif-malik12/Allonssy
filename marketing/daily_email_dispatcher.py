#!/usr/bin/env python3
"""
Allonssy Daily Social Post & Video Dispatcher (7-Day Autopilot Growth Engine)
----------------------------------------------------------------------------
Runs via GitHub Actions daily (or locally) to render today's 1080x1920 video
and dispatch an email to ali.kashifmalik@gmail.com with:
  1. The 1080p MP4 attached and linked via GitHub Pages for 1-tap download
  2. Ready-to-copy captions & hashtags for TikTok, Instagram Reels & YouTube Shorts
  3. Pre-filled 1-click Reddit / Community post link
"""

import os
import sys
import json
import base64
import urllib.parse
from datetime import date
from pathlib import Path
import requests
from dotenv import dotenv_values

ROOT_DIR = Path(__file__).resolve().parent.parent
if str(ROOT_DIR) not in sys.path:
    sys.path.insert(0, str(ROOT_DIR))

from marketing.auto_video_generator import build_video

# Safe dynamic secret resolution (never hardcoded)
TRADISTER_ENV = r"E:\Gdrive\1Business\1a Tradister IT SASU\tradister-finops-cloud\.env"
CONFIG = dotenv_values(TRADISTER_ENV) if os.path.exists(TRADISTER_ENV) else {}

RESEND_API_KEY = os.environ.get("RESEND_API_KEY") or CONFIG.get("RESEND_API_KEY")
SENDER_EMAIL = os.environ.get("OUTREACH_SENDER_EMAIL") or CONFIG.get("OUTREACH_SENDER_EMAIL") or "kashif@tradister-cloud.com"
SENDER_NAME = "Allonssy Daily Growth"
TO_EMAIL = "ali.kashifmalik@gmail.com"

# Local or CI state file
GLOBAL_STATE_DIR = Path(r"C:\Users\Kashif Malik\.gemini\antigravity\secrets")
if GLOBAL_STATE_DIR.exists():
    STATE_FILE = GLOBAL_STATE_DIR / "allonssy_daily_post_state.json"
else:
    STATE_FILE = ROOT_DIR / ".daily_post_state.json"

PLAY_STORE_URL = "https://play.google.com/store/apps/details?id=com.allonssy.app"
WEBSITE_URL = "https://app.allonssy.com"
CREATOR_HUB_URL = "https://kashif-malik12.github.io/Allonssy/creator.html"
GITHUB_RAW_BASE = "https://github.com/kashif-malik12/Allonssy/raw/main/docs/videos"

SCHEDULE = [
    {
        "day": 1,
        "target": "r/SideProject",
        "flair_needed": "Side Project",
        "title": "[SideProject] Allonssy - A clean, hyperlocal community & marketplace app for real towns to replace bloated Facebook groups",
        "body": f"""Hey r/SideProject!

Like many of you, I grew frustrated by how noisy and chaotic neighborhood Facebook groups and Nextdoor have become: full of scams, aggressive algorithm ads, political rants, and spam bots.

I wanted a modern, privacy-focused community app that actually feels like your local town square. So I built Allonssy:

✨ What it does:
• 📍 Radius-Based Feed: Filter updates by 2 km, 5 km, or 10 km. See what is actually happening within walking distance.
• 🛍️ 0% Fee Local Marketplace: List furniture, bikes, and gadgets in 10 seconds. Direct neighbor-to-neighbor pickup.
• 💬 Real-Time Offer Chat: Built-in counter-offer buttons and live read receipts (teal double-ticks) so you never get ghosted.
• 🔧 2-Tier Local Directory: Discover verified local electricians, plumbers, bakers, and pet sitters with transparent rates.
• 🌍 Bilingual: Seamless toggle between English and French.

Tech Stack: Flutter 3.x, Supabase (self-hosted PostgreSQL + Realtime), Deno Edge Functions, Web + Android.

Android Play Store: {PLAY_STORE_URL}
Web App: {WEBSITE_URL}

I would love your honest feedback, critique on the UI, and feature suggestions!""",
        "description": "The premier community for builders (200k+ members). High engagement for well-designed Flutter indie apps."
    },
    {
        "day": 2,
        "target": "r/androidapps",
        "flair_needed": "Developer",
        "title": "[DEV] Allonssy - Hyperlocal social network, 0% commission marketplace & verified artisan directory (No algorithmic ads)",
        "body": f"""Hey r/androidapps!

A few months ago, I set out to build an indie alternative to mainstream corporate neighborhood networks. Allonssy is a clean, modern Android & Web app focused on real neighborhoods:

💰 Pricing & Model:
• Price: 100% Free to use
• Ads: Zero algorithmic video popups or junk ads
• Marketplace Commissions: 0% ($0 fees for neighbor trades)

🛡️ Key Features:
• 📍 Local Radius Feed: Choose your exact radius (2 km, 5 km, 10 km, public)
• 🚴 Free Local Marketplace: Buy & sell with 1-tap offer negotiation
• ⚡ 2-Tier Artisan & Service Directory: 7 categories and 26 subcategories
• 💬 Real-Time Chat: Powered by Supabase Realtime with delivery & read receipts
• 🌐 Bilingual: English & French native support

Google Play Store: {PLAY_STORE_URL}
Web App: {WEBSITE_URL}

Looking forward to your thoughts and bug reports!""",
        "description": "Top Android app community (900k+ members). Essential to use the [DEV] tag and select the 'Developer' flair."
    },
    {
        "day": 3,
        "target": "r/smallbusiness",
        "flair_needed": "Resource / Tool",
        "title": "I built a 2-tier verified local directory for neighborhood artisans, bakers, and freelancers (Allonssy)",
        "body": f"""Hey small business owners and local freelancers!

Mainstream social platforms now charge exorbitant ad fees just to let local shops reach people living 500 meters away. Meanwhile, delivery apps take 30% cuts from neighborhood restaurants and bakers.

We built Allonssy to give local independent businesses their neighborhood spotlight back:
• 🥐 Dedicated Food Ads & Daily Specials: Bakeries and bistros can broadcast flash specials directly to neighbors.
• 🔧 2-Tier Directory: Plumbers, electricians, cleaners, and pet caregivers get verified local profiles without monthly fees.
• 💬 Direct Customer Messaging: Chat directly with nearby customers with zero commission middleman taking a cut.

Web App: {WEBSITE_URL}
Google Play: {PLAY_STORE_URL}

If you run a local business or provide home services, I'd love to know what features would help you connect best with neighbors!""",
        "description": "Active community of 1M+ business owners and independent tradespeople looking for local visibility."
    },
    {
        "day": 4,
        "target": "r/france",
        "flair_needed": "Projet / Tech",
        "title": "[Projet] Allonssy : l'application locale pour échanger entre voisins, vendre d'occasion sans frais et trouver des artisans de confiance",
        "body": f"""Bonjour à tous !

Fatigué du spam et des arnaques sur les groupes Facebook de quartier et Leboncoin pour de simples échanges entre voisins, j'ai développé **Allonssy** : une application mobile et web hyperlocale pensée pour nos villes et villages.

✨ Les fonctionnalités clés :
• 📍 Fil d'actualité local par rayon (2 km, 5 km, 10 km) : pour suivre ce qui se passe réellement dans votre quartier.
• 🛍️ Marketplace entre voisins à 0% de commission : pour donner ou vendre facilement ses objets en direct.
• 🤝 Négociation en temps réel dans le chat : contre-offres en 1 clic et confirmation de lecture.
• 🥐 Bons plans et commerces locaux : promotions du jour des boulangers et restaurateurs du coin.
• 🔧 Annuaire d'artisans et services de proximité (plombiers, électriciens, garde d'animaux).
• 🇫🇷 100% bilingue français et anglais.

Disponible gratuitement :
• Sur Google Play : {PLAY_STORE_URL}
• En version Web : {WEBSITE_URL}

Vos retours et suggestions sont les très bienvenus pour améliorer l'application !""",
        "description": "Premier subreddit francophone (1.5M+ membres). Idéal pour présenter une initiative locale et solidaire."
    },
    {
        "day": 5,
        "target": "r/alphaandbetausers",
        "flair_needed": "Android",
        "title": "[Android/Web] Allonssy - Hyperlocal community network with real-time offer bargaining & local directory (Seeking feedback)",
        "body": f"""Hey everyone,

I'm seeking testers and feedback on Allonssy: a community and local trading app built with Flutter and Supabase.

Problems it solves:
1. No more getting ghosted on marketplace items: built-in smart counter-offer system and live read receipts.
2. No spam algorithms: you choose the exact geographic radius of posts.
3. Easy access to local pros: emergency plumbers, babysitters, and bakers nearby.

Android: {PLAY_STORE_URL}
Web: {WEBSITE_URL}

I would deeply appreciate feedback on performance, UI polish, and onboarding flow!""",
        "description": "Dedicated testing subreddit where developers share projects for early user feedback."
    },
    {
        "day": 6,
        "target": "r/expats",
        "flair_needed": "Resource",
        "title": "For expats living in or moving to France: I built a bilingual EN/FR local app to connect with neighbors & find services (Allonssy)",
        "body": f"""Hey fellow expats!

When relocating to a new town or neighborhood in France, finding trusted English/French speaking tradespeople, local garage sales, and community events can feel overwhelming.

I built Allonssy as a bilingual bridge for local communities:
• 🌍 Full Bilingual Support: Instant switch between English and French.
• 📍 Neighborhood Radius: Connect with people right in your commune or arrondissement.
• 🛠️ Local Marketplace & Services: Buy furniture locally without delivery hassle and find vetted home services.
• 💬 In-App Chat: Safe direct messaging with neighborhood users.

Google Play: {PLAY_STORE_URL}
Web: {WEBSITE_URL}

Hope this helps anyone settling into their new French neighborhood!""",
        "description": "Expat community (300k+ members). High interest in tools that bridge language gaps in European cities."
    },
    {
        "day": 7,
        "target": "r/indiebiz",
        "flair_needed": "Discussion",
        "title": "Building an indie alternative to Nextdoor & Facebook groups: 0 algorithmic ads, pure local radius feed (Allonssy)",
        "body": f"""Hey indie hackers!

Big tech platforms have largely ruined local social media by prioritizing sensationalist algorithmic engagement and sponsored spam over real community connection.

With Allonssy, I took an indie approach:
• Real distance radius instead of addictive recommendation algorithms.
• Lightweight Flutter client with instant web access.
• 0% marketplace commission to encourage local reuse and circular economy.
• Built-in real-time negotiation to eliminate flaky buyers.

App Web: {WEBSITE_URL}
Play Store: {PLAY_STORE_URL}

Happy to answer questions about our Flutter + self-hosted Supabase architecture or early organic community growth!""",
        "description": "Indie hacker and bootstrap entrepreneur community focused on building sustainable software."
    }
]

def load_state():
    if STATE_FILE.exists():
        try:
            with open(STATE_FILE, "r") as f:
                return json.load(f)
        except Exception:
            pass
    return {"last_day_sent": 0, "last_sent_date": ""}

def save_state(state):
    try:
        STATE_FILE.parent.mkdir(parents=True, exist_ok=True)
        with open(STATE_FILE, "w") as f:
            json.dump(state, f, indent=2)
    except Exception as e:
        print(f"Warning: could not save state to {STATE_FILE}: {e}")

def send_post_email(item):
    if not RESEND_API_KEY:
        print("ERROR: RESEND_API_KEY is not configured.")
        return False

    print(f"🎬 Generating video for Day {item['day']}...")
    video_info = build_video(day=item["day"])

    # Direct GitHub raw download link (works 100% immediately without requiring GitHub Pages)
    video_web_url = f"{GITHUB_RAW_BASE}/{video_info['name']}"
    pages_video_url = f"https://kashif-malik12.github.io/Allonssy/videos/{video_info['name']}"

    # Pre-filled Reddit submission link
    reddit_params = {
        "title": item["title"],
        "text": item["body"]
    }
    submit_url = f"https://www.reddit.com/{item['target']}/submit?{urllib.parse.urlencode(reddit_params)}"

    html_content = f"""
    <!DOCTYPE html>
    <html>
    <head>
      <meta charset="utf-8">
      <style>
        body {{ font-family: -apple-system, BlinkMacSystemFont, 'Segoe UI', Roboto, sans-serif; background: #0E241F; color: #1E293B; margin: 0; padding: 24px 12px; }}
        .card {{ background: #ffffff; border-radius: 14px; padding: 24px; max-width: 640px; margin: 0 auto; border: 1px solid #e2e8f0; box-shadow: 0 4px 6px -1px rgba(0,0,0,0.05); }}
        .badge {{ display: inline-block; background: #E6F4F1; color: #0F766E; padding: 6px 14px; border-radius: 999px; font-size: 13px; font-weight: bold; margin-bottom: 12px; }}
        .badge-video {{ background: #fdf2f8; color: #9d174d; border: 1px solid #fbcfe8; }}
        .badge-reddit {{ background: #ffedd5; color: #c2410c; border: 1px solid #fed7aa; }}
        .flair-pill {{ display: inline-block; background: #fef3c7; color: #92400e; padding: 4px 10px; border-radius: 6px; font-size: 12px; font-weight: 600; border: 1px solid #fde68a; }}
        .section-box {{ background: #F5F1E8; border: 1px solid #E6DDCE; border-radius: 12px; padding: 18px; margin-bottom: 20px; }}
        .warning-box {{ background: #fffbeb; border-left: 4px solid #f59e0b; padding: 12px; border-radius: 6px; margin: 15px 0; font-size: 13px; color: #78350f; }}
        h2 {{ color: #0F766E; margin-top: 6px; margin-bottom: 8px; }}
        h3 {{ color: #12211D; margin-top: 0; font-size: 17px; }}
        .btn {{ display: inline-block; background: #0F766E; color: #ffffff !important; padding: 14px 26px; border-radius: 10px; text-decoration: none; font-weight: bold; font-size: 15px; margin: 10px 4px; text-align: center; }}
        .btn:hover {{ background: #0D655E; }}
        .btn-sub {{ background: #CC7A00; }}
        .caption-code {{ display: block; background: #ffffff; padding: 12px; border-radius: 8px; font-size: 13px; line-height: 1.5; color: #334155; margin-top: 8px; border: 1px solid #cbd5e1; }}
        .preview {{ background: #ffffff; padding: 14px; border-radius: 8px; font-size: 13px; line-height: 1.5; white-space: pre-wrap; color: #334155; border: 1px solid #cbd5e1; }}
        .footer {{ font-size: 12px; color: #64748b; margin-top: 24px; text-align: center; border-top: 1px solid #e2e8f0; padding-top: 14px; }}
      </style>
    </head>
    <body>
      <div class="card">
        <span class="badge">🚀 Allonssy Autopilot Growth • Day {item['day']} of {len(SCHEDULE)}</span>
        <h2>Your Daily Growth Dispatch</h2>
        <p style="color: #64748b; font-size: 14px; margin-bottom: 20px;">Two quick 1-minute actions to grow Allonssy today:</p>

        <!-- PART 1: VIDEO -->
        <div class="section-box">
          <span class="badge badge-video">🎬 Action 1: Upload Video to TikTok, Instagram Reels & Shorts</span>
          <h3>{video_info['title']}</h3>
          <p style="font-size: 13px; color: #475569;">Your 1080x1920 video is rendered and ready to post:</p>
          
          <div style="text-align: center; margin: 15px 0;">
            <a href="{video_web_url}" class="btn" style="background: #0F766E;" target="_blank">
              📥 1-Tap Download Video (Instant MP4)
            </a>
            <a href="{CREATOR_HUB_URL}" class="btn btn-sub" target="_blank">
              🌐 Open Mobile Creator Hub
            </a>
          </div>

          <div style="background: #fdf2f8; border-radius: 6px; padding: 10px; margin: 10px 0; font-size: 12px; color: #831843;">
            📱 <strong>Upload Targets:</strong> <strong>TikTok</strong> • <strong>Instagram Reels</strong> • <strong>YouTube Shorts</strong><br>
            <em>(Post this single 9:16 vertical video across all platforms in under 90 seconds!)</em>
          </div>

          <p style="font-size: 13px; font-weight: bold; color: #0f172a; margin-top: 12px; margin-bottom: 4px;">Copy-Paste Caption & Hashtags:</p>
          <div class="caption-code">{video_info['caption']} #reels #explorepage</div>
        </div>

        <!-- PART 2: REDDIT -->
        <div class="section-box">
          <span class="badge badge-reddit">🔥 Action 2: Publish Today's Reddit Post</span>
          <h3>Subreddit: {item['target']}</h3>
          <p style="color: #64748b; font-size: 13px;">{item['description']}</p>
          
          <div class="warning-box">
            ⚠️ <strong>Submission Checklist:</strong><br>
            • Mode: <strong>Post (Text tab)</strong> — not Link/Image.<br>
            • Required Flair: <span class="flair-pill">{item['flair_needed']}</span>
          </div>

          <div style="text-align: center;">
            <a href="{submit_url}" class="btn" style="background: #FF4500;" target="_blank">👉 Open Pre-Filled Reddit Submission</a>
          </div>

          <p style="font-size: 13px; color: #334155; margin-bottom: 6px;"><strong>Title:</strong> {item['title']}</p>
          <div class="preview">{item['body']}</div>
        </div>

        <div class="footer">
          Allonssy Daily Autopilot Growth Engine • Tradister SAS
        </div>
      </div>
    </body>
    </html>
    """

    attachments = []
    if os.path.exists(video_info.get("path", "")):
        try:
            with open(video_info["path"], "rb") as f:
                b64_content = base64.b64encode(f.read()).decode("utf-8")
            attachments.append({
                "filename": video_info["name"],
                "content": b64_content
            })
            print(f"📎 Attached {video_info['name']} directly to email.")
        except Exception as e:
            print(f"Attachment error: {e}")

    payload = {
        "from": f"{SENDER_NAME} <{SENDER_EMAIL}>",
        "to": [TO_EMAIL],
        "subject": f"🔥 Allonssy Growth Day {item['day']}: 🎬 Video Attached + 🤖 {item['target']} Post!",
        "html": html_content
    }
    if attachments:
        payload["attachments"] = attachments

    headers = {
        "Authorization": f"Bearer {RESEND_API_KEY}",
        "Content-Type": "application/json"
    }

    try:
        res = requests.post("https://api.resend.com/emails", headers=headers, json=payload, timeout=20)
        print(f"Dispatched Day {item['day']} ({item['target']}) -> Status {res.status_code}")
        if res.status_code not in (200, 201):
            print(f"Resend Error Response: {res.text}")
        return res.status_code in (200, 201)
    except Exception as e:
        print(f"Failed to send email: {e}")
        return False

def run_next(force=False):
    today_str = str(date.today())
    state = load_state()
    
    if not force and state.get("last_sent_date") == today_str:
        print(f"Post already sent today ({today_str}). Use --force to send again.")
        return

    current_day = (state.get("last_day_sent", 0) % len(SCHEDULE)) + 1
    item = next((s for s in SCHEDULE if s["day"] == current_day), SCHEDULE[0])

    success = send_post_email(item)
    if success:
        state["last_day_sent"] = current_day
        state["last_sent_date"] = today_str
        save_state(state)
        print(f"Successfully dispatched Day {current_day} ({item['target']}).")

if __name__ == "__main__":
    if len(sys.argv) > 1 and ("--next" in sys.argv or "--force" in sys.argv):
        force_send = "--force" in sys.argv
        run_next(force=force_send)
    else:
        state = load_state()
        print(f"Current state: Last day sent was Day {state.get('last_day_sent', 0)} on {state.get('last_sent_date', 'N/A')}")
