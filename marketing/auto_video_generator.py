#!/usr/bin/env python3
"""
Allonssy Automated Video Creation Engine (TikTok / Shorts / Reels)
------------------------------------------------------------------
Generates 1080x1920 9:16 vertical promotional videos completely locally or in CI
using Pillow, edge-tts (ultra-realistic Microsoft Neural AI Voice), and ffmpeg.
Includes 7 rotating high-conversion video themes for daily autopilot growth.
"""

import os
import sys
import glob
import subprocess
import asyncio
from pathlib import Path
from PIL import Image, ImageDraw, ImageFont, ImageFilter
import edge_tts

ROOT_DIR = Path(__file__).resolve().parent.parent
OUTPUT_DIR = ROOT_DIR / "output" / "videos"
BRANDING_DIR = ROOT_DIR / "assets" / "branding"
SCREENSHOTS_DIR = BRANDING_DIR / "screenshots"

FONT_PATH = "C:\\Windows\\Fonts\\segoeuib.ttf"
if not os.path.exists(FONT_PATH):
    FONT_PATH = "C:\\Windows\\Fonts\\arialbd.ttf"
if not os.path.exists(FONT_PATH):
    for linux_font in [
        "/usr/share/fonts/truetype/liberation/LiberationSans-Bold.ttf",
        "/usr/share/fonts/truetype/dejavu/DejaVuSans-Bold.ttf",
        "/usr/share/fonts/truetype/freefont/FreeSansBold.ttf"
    ]:
        if os.path.exists(linux_font):
            FONT_PATH = linux_font
            break

VOICE_NAME = "en-US-ChristopherNeural"  # Professional, crisp, engaging US male narrator

VIDEO_THEMES = {
    1: {
        "title": "Why Facebook Groups & Local Apps Are Broken",
        "caption": "Tired of spam, politics & scam ads in your town Facebook groups? 🤦‍♂️ Built Allonssy: a clean local community, marketplace & service directory app for your neighborhood! Free on Google Play & Web 👉 link in bio! #localcommunity #neighborhood #indiedev #france #risorangis #marketplace #appstore",
        "scenes": [
            {
                "hook_top": "NEIGHBORHOOD APPS ARE BROKEN 🛑",
                "hook_sub": "Spam, paywalls, and annoying ads everywhere.",
                "voiceover": "Why are neighborhood apps and Facebook groups filled with spam, scams, and algorithmic junk?",
                "screenshot_name": "screen_feed.png",
                "badge_text": "🚫 STOP SPAM & ALGORITHM JUNK"
            },
            {
                "hook_top": "MEET ALLONSSY 🚀",
                "hook_sub": "Clean, modern community app for your town.",
                "voiceover": "I built Allonssy: a clean, hyperlocal community app designed for real towns and neighborhoods.",
                "screenshot_name": "screen_feed.png",
                "badge_text": "📍 RADIUS-BASED LOCAL FEED"
            },
            {
                "hook_top": "MARKETPLACE & DIRECTORY 🛍️",
                "hook_sub": "Buy, sell, find trusted plumbers & food deals.",
                "voiceover": "Browse verified local posts, buy and sell second-hand items with zero fees, and find trusted local artisans.",
                "screenshot_name": "screen_marketplace.png",
                "badge_text": "⚡ 0% FEES • DIRECT PICKUP"
            },
            {
                "hook_top": "TRY ALLONSSY TODAY 👉",
                "hook_sub": "Free on Google Play & Web (app.allonssy.com).",
                "voiceover": "Connect with your real neighborhood today. Download Allonssy free on Google Play or visit app.allonssy.com.",
                "screenshot_name": "screen_chat.png",
                "badge_text": "📲 GET ALLONSSY ON GOOGLE PLAY"
            }
        ]
    },
    2: {
        "title": "Buy & Sell Locally With Zero Fees",
        "caption": "Stop paying 15% platform fees to sell a bicycle or couch to someone living 500m away! 🚲 Allonssy lets you list in 10s with 1-tap offer negotiation & direct pickup. Free on Play Store! #marketplace #secondhand #declutter #buylocal #localdeals #thrifting #community",
        "scenes": [
            {
                "hook_top": "STOP PAYING 15% SELLING FEES 💸",
                "hook_sub": "Sell items in your neighborhood in seconds.",
                "voiceover": "Stop losing fifteen percent in seller fees and shipping costs when you just want to sell to someone nearby.",
                "screenshot_name": "screen_marketplace.png",
                "badge_text": "🚫 ZERO SELLER FEES"
            },
            {
                "hook_top": "INSTANT LOCAL MARKETPLACE 🚲",
                "hook_sub": "List furniture, bikes, tech with 0% commission.",
                "voiceover": "Allonssy lets you list anything in your neighborhood in ten seconds with zero commission.",
                "screenshot_name": "screen_marketplace.png",
                "badge_text": "⚡ LIST IN UNDER 10 SECONDS"
            },
            {
                "hook_top": "REAL-TIME OFFER BARGAINING 🤝",
                "hook_sub": "1-Tap counter-offers and live read receipts.",
                "voiceover": "Negotiate deals with one tap offer chat, counter offers, and real-time read receipts.",
                "screenshot_name": "screen_chat.png",
                "badge_text": "💬 SMART 1-TAP COUNTER OFFERS"
            },
            {
                "hook_top": "FREE ON ANDROID & WEB 📲",
                "hook_sub": "No hidden fees. Safe local pickup.",
                "voiceover": "Sell clutter and find local bargains. Download Allonssy free on Google Play.",
                "screenshot_name": "screen_feed.png",
                "badge_text": "👉 100% FREE LOCAL MARKETPLACE"
            }
        ]
    },
    3: {
        "title": "Emergency Plumber or Babysitter? Find Local Help Fast",
        "caption": "Need an emergency plumber, electrician, or pet sitter near your home? ⚡ Allonssy has a 2-tier verified local directory with real ratings & direct chat! #localbusiness #artisans #plumber #electrician #petsitter #neighborhood #handyman",
        "scenes": [
            {
                "hook_top": "NEED A LOCAL ARTISAN FAST? ⚡",
                "hook_sub": "Finding reliable electricians & handymen is tough.",
                "voiceover": "Ever have a plumbing leak on Sunday or desperately need a reliable babysitter near your house?",
                "screenshot_name": "screen_services.png",
                "badge_text": "⚡ INSTANT LOCAL HELP"
            },
            {
                "hook_top": "VERIFIED LOCAL DIRECTORY 🔧",
                "hook_sub": "Artisans, bakers, pet care & tutors.",
                "voiceover": "Allonssy features a verified directory of local artisans, mechanics, and pet caregivers right around you.",
                "screenshot_name": "screen_services.png",
                "badge_text": "⭐ 2-TIER VERIFIED DIRECTORY"
            },
            {
                "hook_top": "CHAT & HIRE DIRECTLY 💬",
                "hook_sub": "Transparent hourly rates, no middlemen fees.",
                "voiceover": "Check verified neighborhood reviews, message them directly, and get transparent quotes without middlemen.",
                "screenshot_name": "screen_chat.png",
                "badge_text": "🤝 DIRECT MESSAGING & QUOTES"
            },
            {
                "hook_top": "CONNECT WITH YOUR TOWN 📲",
                "hook_sub": "Search 'Allonssy' on the Play Store.",
                "voiceover": "Support your local economy and find trusted help. Get Allonssy completely free today.",
                "screenshot_name": "screen_feed.png",
                "badge_text": "⚡ FIND TRUSTED LOCAL PROS"
            }
        ]
    },
    4: {
        "title": "Secret Food Deals & Artisan Bakeries Near You",
        "caption": "Support local bakers and neighborhood bistros without 30% delivery app fees! 🥖 Fresh pastries, daily specials, and exclusive discounts on Allonssy. #foodie #bakery #croissant #boulangerie #supportlocal #paris #eats #fooddeals",
        "scenes": [
            {
                "hook_top": "SUPPORT LOCAL FOOD HEROES 🥖",
                "hook_sub": "Stop paying 30% delivery app markups.",
                "voiceover": "Tired of big delivery apps charging thirty percent markups to your favorite neighborhood bakeries and bistros?",
                "screenshot_name": "screen_feed.png",
                "badge_text": "🥖 0% DELIVERY MARKUPS"
            },
            {
                "hook_top": "DIRECT NEIGHBORHOOD FOOD ADS 🍕",
                "hook_sub": "Fresh croissants, pizzas & daily lunch specials.",
                "voiceover": "On Allonssy, local restaurants and bakers post daily fresh specials directly to their neighborhood.",
                "screenshot_name": "screen_feed.png",
                "badge_text": "🍕 FRESH DAILY LOCAL SPECIALS"
            },
            {
                "hook_top": "EXCLUSIVE LOCAL DISCOUNTS ☕",
                "hook_sub": "Flash afternoon discounts & authentic meals.",
                "voiceover": "Discover secret food deals, support local artisans, and enjoy fresh authentic food right around the corner.",
                "screenshot_name": "screen_marketplace.png",
                "badge_text": "🎉 EXCLUSIVE NEIGHBORHOOD OFFERS"
            },
            {
                "hook_top": "DISCOVER YOUR NEIGHBORHOOD 📲",
                "hook_sub": "Download free on Android & Web.",
                "voiceover": "Taste the best of your town. Download Allonssy free on Google Play or visit app.allonssy.com.",
                "screenshot_name": "screen_feed.png",
                "badge_text": "🥐 FRESH LOCAL FOOD DEALS"
            }
        ]
    },
    5: {
        "title": "The Real-Time Offer Chat System You Wish Facebook Had",
        "caption": "Tired of people asking 'is this available' on Facebook Marketplace and ghosting? 🤦‍♂️ Allonssy has built-in 1-tap counter-offers and live read receipts! #marketplace #facebookmarketplace #tech #flutter #indiedev #mobileapp #community",
        "scenes": [
            {
                "hook_top": "TIRED OF GETTING GHOSTED? 🤦‍♂️",
                "hook_sub": "Selling on Facebook Marketplace is exhausting.",
                "voiceover": "Are you tired of people asking 'is this available' on Facebook Marketplace and then ghosting you forever?",
                "screenshot_name": "screen_chat.png",
                "badge_text": "👻 NO MORE GHOSTING"
            },
            {
                "hook_top": "SMART OFFER NEGOTIATIONS 🤝",
                "hook_sub": "Counter-offers, accept, and schedule pickup.",
                "voiceover": "Allonssy has built-in smart offer negotiation. Buyers make offers, sellers can counter-offer with one tap.",
                "screenshot_name": "screen_chat.png",
                "badge_text": "🔄 1-TAP COUNTER OFFERS"
            },
            {
                "hook_top": "REAL-TIME READ RECEIPTS 💬",
                "hook_sub": "Know exactly when your message is read.",
                "voiceover": "Live delivery ticks and read receipts mean no more wondering if the buyer saw your reply.",
                "screenshot_name": "screen_chat.png",
                "badge_text": "✓✓ TEAL DOUBLE TICK RECEIPTS"
            },
            {
                "hook_top": "EXPERIENCE BETTER TRADING 📲",
                "hook_sub": "Search 'Allonssy' on Google Play.",
                "voiceover": "Trade safely with real neighbors. Download Allonssy on Google Play or use app.allonssy.com.",
                "screenshot_name": "screen_marketplace.png",
                "badge_text": "👉 SMART LOCAL TRADING"
            }
        ]
    },
    6: {
        "title": "The Bilingual French & English Community Network",
        "caption": "Living or moving to France? 🇫🇷 Allonssy is the bilingual French & English app to connect with neighbors, find second-hand gems, and discover local artisans! #france #expatinfrance #paris #livinginfrance #bonjour #learnfrench #frenchlife",
        "scenes": [
            {
                "hook_top": "CONNECT IN FRANCE EASILY 🇫🇷",
                "hook_sub": "Expats & locals united in one neighborhood app.",
                "voiceover": "Moving to France or living in a French town and want to connect with your local community?",
                "screenshot_name": "screen_feed.png",
                "badge_text": "🇫🇷 EXPATS & LOCALS UNITED"
            },
            {
                "hook_top": "BILINGUAL FRENCH & ENGLISH 🌍",
                "hook_sub": "Switch instantly between French and English.",
                "voiceover": "Allonssy is built from the ground up to be bilingual in French and English with seamless language switching.",
                "screenshot_name": "screen_services.png",
                "badge_text": "🌍 100% BILINGUAL FR / EN"
            },
            {
                "hook_top": "DISCOVER EVERYTHING LOCAL 📍",
                "hook_sub": "Events, garage sales, marketplace, and services.",
                "voiceover": "Find local garage sales, community cleanups, trusted services, and neighborhood news in one place.",
                "screenshot_name": "screen_marketplace.png",
                "badge_text": "🏡 REAL LOCAL NEIGHBORHOODS"
            },
            {
                "hook_top": "JOIN ALLONSSY TODAY 📲",
                "hook_sub": "Available on Android and Web worldwide.",
                "voiceover": "Make your town feel like home. Download Allonssy free on Google Play or visit app.allonssy.com.",
                "screenshot_name": "screen_feed.png",
                "badge_text": "🇫🇷 JOIN YOUR LOCAL COMMUNITY"
            }
        ]
    },
    7: {
        "title": "Indie-Built Local Social: No Ads, No Data Selling",
        "caption": "I built Allonssy because mainstream tech turned local social networks into algorithmic ad machines. Support an indie developer building for real communities! #buildinpublic #indiedev #solodev #flutter #tech #socialmedia #localfirst",
        "scenes": [
            {
                "hook_top": "WHY I BUILT ALLONSSY 🛠️",
                "hook_sub": "Indie developer fighting corporate social decay.",
                "voiceover": "I spent months building Allonssy because mainstream social networks stopped caring about real local communities.",
                "screenshot_name": "screen_feed.png",
                "badge_text": "🛠️ BUILT BY AN INDIE DEV"
            },
            {
                "hook_top": "CLEAN, FAST & COMMUNITY-FIRST ⚡",
                "hook_sub": "Built with Flutter & real-time messaging.",
                "voiceover": "Allonssy gives you a clean radius-based feed, instant chat, local marketplace, and zero shady ad trackers.",
                "screenshot_name": "screen_marketplace.png",
                "badge_text": "⚡ FAST, SECURE & PRIVATE"
            },
            {
                "hook_top": "SUPPORT INDIE SOFTWARE 💡",
                "hook_sub": "Built for neighborhoods that want to thrive.",
                "voiceover": "Support independent developers who care about user experience and local business growth.",
                "screenshot_name": "screen_services.png",
                "badge_text": "🌟 100% COMMUNITY-FOCUSED"
            },
            {
                "hook_top": "GET ALLONSSY ON GOOGLE PLAY 📲",
                "hook_sub": "Search 'Allonssy' or visit app.allonssy.com.",
                "voiceover": "Join the local movement. Download Allonssy free on Google Play or check out app.allonssy.com.",
                "screenshot_name": "screen_chat.png",
                "badge_text": "👉 DOWNLOAD ALLONSSY TODAY"
            }
        ]
    }
}

def get_audio_duration(audio_path):
    cmd = [
        "ffprobe", "-v", "error",
        "-show_entries", "format=duration",
        "-of", "default=noprint_wrappers=1:nokey=1",
        str(audio_path)
    ]
    res = subprocess.run(cmd, stdout=subprocess.PIPE, stderr=subprocess.PIPE, text=True, check=True)
    return float(res.stdout.strip())

async def generate_tts(text, output_path):
    communicate = edge_tts.Communicate(text, VOICE_NAME, rate="+5%")
    await communicate.save(str(output_path))

def create_rounded_mask(size, radius):
    mask = Image.new("L", size, 0)
    draw = ImageDraw.Draw(mask)
    draw.rounded_rectangle([(0, 0), size], radius=radius, fill=255)
    return mask

def render_scene_frame(scene, screenshot_path, out_path, frame_w=1080, frame_h=1920):
    base = Image.new("RGBA", (frame_w, frame_h), (18, 33, 29, 255))
    draw = ImageDraw.Draw(base)

    # Modern Dark Emerald & Teal Gradient (#0E241F to #0F766E)
    for y in range(frame_h):
        ratio = y / frame_h
        r = int(14 * (1 - ratio) + 15 * ratio)
        g = int(36 * (1 - ratio) + 118 * ratio)
        b = int(31 * (1 - ratio) + 110 * ratio)
        draw.line([(0, y), (frame_w, y)], fill=(r, g, b))

    # Glowing amber and emerald atmospheric accents
    glow_teal = (20, 184, 166, 32)
    glow_amber = (245, 158, 11, 28)
    draw.ellipse([-160, 120, 480, 720], fill=glow_teal)
    draw.ellipse([640, 1150, 1280, 1750], fill=glow_amber)

    # App Wordmark / Logo Watermark at top
    logo_path = BRANDING_DIR / "allonssy-wordmark.png"
    if not logo_path.exists():
        logo_path = BRANDING_DIR / "social" / "allonssy_logo.png"

    if logo_path.exists():
        logo = Image.open(logo_path).convert("RGBA")
        logo.thumbnail((420, 110), Image.Resampling.LANCZOS)
        logo_x = (frame_w - logo.width) // 2
        base.paste(logo, (logo_x, 70), logo)

    # Fonts
    font_hook = ImageFont.truetype(FONT_PATH, 50)
    font_sub = ImageFont.truetype(FONT_PATH, 34)
    font_badge = ImageFont.truetype(FONT_PATH, 28)

    # Top Hook Title
    hook_text = scene["hook_top"]
    sub_text = scene["hook_sub"]
    badge_text = scene["badge_text"]

    bbox_hook = draw.textbbox((0, 0), hook_text, font=font_hook)
    hook_w = bbox_hook[2] - bbox_hook[0]
    hook_x = (frame_w - hook_w) // 2
    hook_y = 205

    draw.text((hook_x + 3, hook_y + 3), hook_text, font=font_hook, fill=(0, 0, 0, 180))
    draw.text((hook_x, hook_y), hook_text, font=font_hook, fill=(253, 224, 71, 255)) # Warm Gold Yellow

    # Subtext
    bbox_sub = draw.textbbox((0, 0), sub_text, font=font_sub)
    sub_w = bbox_sub[2] - bbox_sub[0]
    sub_x = (frame_w - sub_w) // 2
    sub_y = hook_y + 75
    draw.text((sub_x, sub_y), sub_text, font=font_sub, fill=(241, 245, 249, 255))

    # Center Smartphone Mockup Frame
    phone_w = 680
    phone_h = 1180
    phone_x = (frame_w - phone_w) // 2
    phone_y = 395

    # Phone drop shadow
    shadow = Image.new("RGBA", (phone_w + 60, phone_h + 60), (0, 0, 0, 0))
    s_draw = ImageDraw.Draw(shadow)
    s_draw.rounded_rectangle([(30, 30), (phone_w + 30, phone_h + 30)], radius=45, fill=(0, 0, 0, 140))
    shadow = shadow.filter(ImageFilter.GaussianBlur(25))
    base.paste(shadow, (phone_x - 30, phone_y - 20), shadow)

    # Phone Outer Bezel
    bezel = Image.new("RGBA", (phone_w, phone_h), (255, 255, 255, 0))
    b_draw = ImageDraw.Draw(bezel)
    b_draw.rounded_rectangle([(0, 0), (phone_w, phone_h)], radius=45, fill=(24, 34, 32, 255), outline=(51, 65, 85, 255), width=6)

    # Phone Punchhole camera notch
    b_draw.ellipse([(phone_w // 2 - 12, 18), (phone_w // 2 + 12, 42)], fill=(10, 15, 14, 255))

    # Screenshot inside phone
    if screenshot_path and os.path.exists(screenshot_path):
        screen_img = Image.open(screenshot_path).convert("RGBA")
        inner_w = phone_w - 28
        inner_h = phone_h - 28
        
        screen_ratio = screen_img.width / screen_img.height
        target_ratio = inner_w / inner_h
        if screen_ratio > target_ratio:
            new_h = screen_img.height
            new_w = int(new_h * target_ratio)
            left = (screen_img.width - new_w) // 2
            screen_img = screen_img.crop((left, 0, left + new_w, new_h))
        else:
            new_w = screen_img.width
            new_h = int(new_w / target_ratio)
            top = (screen_img.height - new_h) // 2
            screen_img = screen_img.crop((0, top, new_w, top + new_h))

        screen_resized = screen_img.resize((inner_w, inner_h), Image.Resampling.LANCZOS)
        inner_mask = create_rounded_mask((inner_w, inner_h), radius=35)
        bezel.paste(screen_resized, (14, 14), inner_mask)

    base.paste(bezel, (phone_x, phone_y), bezel)

    # Bottom Pill Badge
    bbox_badge = draw.textbbox((0, 0), badge_text, font=font_badge)
    badge_w = bbox_badge[2] - bbox_badge[0] + 50
    badge_h = 60
    badge_x = (frame_w - badge_w) // 2
    badge_y = 1660

    draw.rounded_rectangle([(badge_x, badge_y), (badge_x + badge_w, badge_y + badge_h)], radius=30, fill=(15, 118, 110, 255), outline=(20, 184, 166, 255), width=2)
    text_x = badge_x + 25
    text_y = badge_y + 14
    draw.text((text_x, text_y), badge_text, font=font_badge, fill=(255, 255, 255, 255))

    base.convert("RGB").save(str(out_path), "PNG", quality=95)

def build_video(day=1):
    OUTPUT_DIR.mkdir(parents=True, exist_ok=True)
    tmp_dir = OUTPUT_DIR / f"temp_day_{day}"
    tmp_dir.mkdir(parents=True, exist_ok=True)

    theme = VIDEO_THEMES.get(day, VIDEO_THEMES[1])
    scenes = theme["scenes"]

    # Ensure screenshots exist, fallback if needed
    if not SCREENSHOTS_DIR.exists() or not list(SCREENSHOTS_DIR.glob("*.png")):
        gen_script = ROOT_DIR / "marketing" / "generate_screenshots.py"
        if gen_script.exists():
            subprocess.run([sys.executable, str(gen_script)], check=False)

    scene_clips = []
    print(f"🎬 Rendering Allonssy Video for Day {day}: '{theme['title']}'...")

    for i, scene in enumerate(scenes, 1):
        audio_path = tmp_dir / f"scene_{i}.mp3"
        asyncio.run(generate_tts(scene["voiceover"], audio_path))
        duration = get_audio_duration(audio_path) + 0.4

        shot_name = scene.get("screenshot_name", "screen_feed.png")
        shot_path = SCREENSHOTS_DIR / shot_name
        if not shot_path.exists():
            # Fallback to any existing screenshot
            all_shots = list(SCREENSHOTS_DIR.glob("*.png"))
            shot_path = all_shots[0] if all_shots else BRANDING_DIR / "allonssy-feature-graphic-1024x500.png"

        frame_path = tmp_dir / f"scene_{i}.png"
        render_scene_frame(scene, shot_path, frame_path)

        clip_path = tmp_dir / f"clip_{i}.mp4"
        cmd = [
            "ffmpeg", "-y",
            "-loop", "1", "-i", str(frame_path),
            "-i", str(audio_path),
            "-vf", "zoompan=z='min(zoom+0.0005,1.04)':d=125:x='iw/2-(iw/zoom/2)':y='ih/2-(ih/zoom/2)':s=1080x1920:fps=30",
            "-c:v", "libx264", "-preset", "fast", "-crf", "18",
            "-pix_fmt", "yuv420p",
            "-c:a", "aac", "-ar", "48000", "-ac", "2", "-b:a", "192k",
            "-t", str(duration),
            "-shortest",
            str(clip_path)
        ]
        subprocess.run(cmd, stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL, check=True)
        scene_clips.append(clip_path)

    concat_list_path = tmp_dir / "concat_list.txt"
    with open(concat_list_path, "w") as f:
        for clip in scene_clips:
            f.write(f"file '{clip.resolve()}'\n")

    final_video_name = f"Allonssy_Video_Day{day}.mp4"
    final_video_path = OUTPUT_DIR / final_video_name

    concat_cmd = [
        "ffmpeg", "-y",
        "-f", "concat", "-safe", "0",
        "-i", str(concat_list_path),
        "-c", "copy",
        str(final_video_path)
    ]
    subprocess.run(concat_cmd, stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL, check=True)

    # Cleanup temp
    for f in tmp_dir.glob("*"):
        try:
            f.unlink()
        except Exception:
            pass
    try:
        tmp_dir.rmdir()
    except Exception:
        pass

    # Copy to docs/videos for GitHub Pages instant download hub
    docs_video_dir = ROOT_DIR / "docs" / "videos"
    docs_video_dir.mkdir(parents=True, exist_ok=True)
    import shutil
    shutil.copy2(str(final_video_path), str(docs_video_dir / final_video_name))

    print(f"🎉 SUCCESS: Video rendered -> {final_video_path}")
    return {
        "path": final_video_path,
        "name": final_video_name,
        "caption": theme["caption"],
        "title": theme["title"]
    }

if __name__ == "__main__":
    day_num = int(sys.argv[1]) if len(sys.argv) > 1 and sys.argv[1].isdigit() else 1
    build_video(day=day_num)
