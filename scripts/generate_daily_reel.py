#!/usr/bin/env python3
"""
generate_daily_reel.py
Automatically generates 2 crisp vertical 9:16 (1080x1920) MP4 videos every morning for TikTok & Instagram Reels:
  1. reel_bonplan.mp4 -> Today's top Marketplace bargain in Ris-Orangis / Grigny / Évry
  2. reel_actu.mp4    -> Latest Breaking Local News in Essonne / Grand Paris Sud

Uses Pillow for crisp French editorial card composition + imageio-ffmpeg static binary for smooth H.264 encoding.
Outputs directly to /var/www/local_social_web/social_assets/ for 1-tap mobile download!
"""
from __future__ import annotations

import io
import json
import subprocess
import textwrap
import urllib.request
from datetime import datetime
from pathlib import Path

from PIL import Image, ImageDraw, ImageFont
import imageio_ffmpeg

OUT_DIR = Path("/var/www/local_social_web/social_assets")
FONT_BOLD = "/usr/share/fonts/truetype/dejavu/DejaVuSans-Bold.ttf"
FONT_REG = "/usr/share/fonts/truetype/dejavu/DejaVuSans.ttf"

W, H = 1080, 1920


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
        print(f"DB error: {e}")
        return []


def download_image(url: str) -> Image.Image:
    fallback_url = "https://images.unsplash.com/photo-1585829365295-ab7cd400c167?w=1080&auto=format&fit=crop&q=80"
    for candidate in (url, fallback_url):
        if not candidate:
            continue
        try:
            req = urllib.request.Request(candidate, headers={"User-Agent": "Mozilla/5.0"})
            with urllib.request.urlopen(req, timeout=15) as resp:
                return Image.open(io.BytesIO(resp.read())).convert("RGB")
        except Exception as e:
            print(f"Image fetch warning ({candidate}): {e}")
    return Image.new("RGB", (900, 900), (15, 118, 110))


def make_gradient(w: int, h: int, top_rgb: tuple[int, int, int], bot_rgb: tuple[int, int, int]) -> Image.Image:
    img = Image.new("RGB", (w, h), top_rgb)
    draw = ImageDraw.Draw(img)
    for y in range(h):
        t = y / max(1, h - 1)
        r = int(top_rgb[0] * (1 - t) + bot_rgb[0] * t)
        g = int(top_rgb[1] * (1 - t) + bot_rgb[1] * t)
        b = int(top_rgb[2] * (1 - t) + bot_rgb[2] * t)
        draw.line([(0, y), (w, y)], fill=(r, g, b))
    return img


def center_crop_resize(img: Image.Image, target_w: int, target_h: int) -> Image.Image:
    iw, ih = img.size
    target_ratio = target_w / target_h
    src_ratio = iw / ih
    if src_ratio > target_ratio:
        new_w = int(ih * target_ratio)
        left = (iw - new_w) // 2
        img = img.crop((left, 0, left + new_w, ih))
    else:
        new_h = int(iw / target_ratio)
        top = (ih - new_h) // 2
        img = img.crop((0, top, iw, top + new_h))
    return img.resize((target_w, target_h), Image.Resampling.LANCZOS)


def round_corners(img: Image.Image, radius: int) -> Image.Image:
    mask = Image.new("L", img.size, 0)
    draw = ImageDraw.Draw(mask)
    draw.rounded_rectangle([(0, 0), img.size], radius=radius, fill=255)
    out = Image.new("RGBA", img.size, (0, 0, 0, 0))
    out.paste(img, (0, 0), mask)
    return out


def draw_centered_text(draw: ImageDraw.ImageDraw, text: str, y: int, font: ImageFont.FreeTypeFont, fill: tuple, max_chars: int = 26, line_spacing: int = 16) -> int:
    lines = textwrap.wrap(text, width=max_chars)[:3]
    curr_y = y
    for line in lines:
        bbox = draw.textbbox((0, 0), line, font=font)
        tw = bbox[2] - bbox[0]
        th = bbox[3] - bbox[1]
        draw.text(((W - tw) // 2, curr_y), line, font=font, fill=fill)
        curr_y += th + line_spacing
    return curr_y


def compose_vertical_frame(
    badge_text: str,
    title: str,
    highlight_pill: str,
    photo_url: str,
    footer_cta: str,
    theme: str = "teal",
) -> Image.Image:
    if theme == "news":
        bg = make_gradient(W, H, (15, 23, 42), (30, 41, 59))
        badge_bg = (220, 38, 38)
        pill_bg = (239, 68, 68)
        accent = (248, 113, 113)
    else:
        bg = make_gradient(W, H, (11, 79, 74), (19, 78, 74))
        badge_bg = (245, 158, 11)
        pill_bg = (217, 119, 6)
        accent = (253, 230, 138)

    bg = bg.convert("RGBA")
    draw = ImageDraw.Draw(bg)

    f_badge = ImageFont.truetype(FONT_BOLD, 34)
    f_title = ImageFont.truetype(FONT_BOLD, 56)
    f_pill = ImageFont.truetype(FONT_BOLD, 42)
    f_cta = ImageFont.truetype(FONT_BOLD, 38)
    f_sub = ImageFont.truetype(FONT_REG, 30)

    # 1. Top brand label
    brand_txt = "ALLONSSY! • GRAND PARIS SUD (91)"
    bb = draw.textbbox((0, 0), brand_txt, font=f_sub)
    draw.text(((W - (bb[2] - bb[0])) // 2, 110), brand_txt, font=f_sub, fill=accent)

    # 2. Category / City pill badge
    b_box = draw.textbbox((0, 0), badge_text, font=f_badge)
    bw = (b_box[2] - b_box[0]) + 72
    bh = (b_box[3] - b_box[1]) + 34
    bx = (W - bw) // 2
    by = 175
    draw.rounded_rectangle([bx, by, bx + bw, by + bh], radius=bh // 2, fill=badge_bg)
    draw.text((bx + 36, by + 14), badge_text, font=f_badge, fill=(255, 255, 255))

    # 3. Main Image Card
    photo = download_image(photo_url)
    card_w, card_h = 920, 820
    photo_cropped = center_crop_resize(photo, card_w, card_h)
    photo_rounded = round_corners(photo_cropped, 42)
    # White subtle frame
    frame_x, frame_y = (W - card_w) // 2, 295
    draw.rounded_rectangle(
        [frame_x - 8, frame_y - 8, frame_x + card_w + 8, frame_y + card_h + 8],
        radius=48,
        fill=(255, 255, 255, 230),
    )
    bg.paste(photo_rounded, (frame_x, frame_y), photo_rounded)

    # 4. Headline
    next_y = draw_centered_text(draw, title, 1175, f_title, (255, 255, 255), max_chars=24, line_spacing=18)

    # 5. Highlight Pill (Price or Debate prompt)
    p_box = draw.textbbox((0, 0), highlight_pill, font=f_pill)
    pw = min(W - 100, (p_box[2] - p_box[0]) + 84)
    ph = (p_box[3] - p_box[1]) + 42
    px = (W - pw) // 2
    py = max(next_y + 30, 1420)
    draw.rounded_rectangle([px, py, px + pw, py + ph], radius=24, fill=pill_bg)
    draw.text(((W - (p_box[2] - p_box[0])) // 2, py + 18), highlight_pill, font=f_pill, fill=(255, 255, 255))

    # 6. Bottom CTA Bar
    cta_y = 1620
    draw.rounded_rectangle([80, cta_y, W - 80, cta_y + 150], radius=30, fill=(255, 255, 255, 245))
    c_box = draw.textbbox((0, 0), footer_cta, font=f_cta)
    draw.text(((W - (c_box[2] - c_box[0])) // 2, cta_y + 30), footer_cta, font=f_cta, fill=(15, 118, 110))
    url_txt = "app.allonssy.com/go.html  •  Google Play"
    u_box = draw.textbbox((0, 0), url_txt, font=f_sub)
    draw.text(((W - (u_box[2] - u_box[0])) // 2, cta_y + 92), url_txt, font=f_sub, fill=(55, 65, 81))

    return bg.convert("RGB")


def render_mp4_from_image(img_path: Path, out_mp4: Path, duration_sec: int = 10) -> bool:
    ffmpeg_exe = imageio_ffmpeg.get_ffmpeg_exe()
    # Smooth subtle Ken Burns zoom-in + fade in/out, 30fps, H.264 yuv420p (100% TikTok/Reels compatible)
    frames = duration_sec * 30
    vf = (
        f"scale=1200:-1,"
        f"zoompan=z='min(zoom+0.0005,1.08)':d={frames}:x='iw/2-(iw/zoom/2)':y='ih/2-(ih/zoom/2)':s=1080x1920:fps=30,"
        f"fade=t=in:st=0:d=0.6,fade=t=out:st={duration_sec - 0.8}:d=0.8"
    )
    cmd = [
        ffmpeg_exe,
        "-y",
        "-loop", "1",
        "-i", str(img_path),
        "-vf", vf,
        "-t", str(duration_sec),
        "-c:v", "libx264",
        "-preset", "fast",
        "-pix_fmt", "yuv420p",
        "-movflags", "+faststart",
        str(out_mp4),
    ]
    res = subprocess.run(cmd, capture_output=True, text=True, check=False)
    if res.returncode != 0:
        print(f"FFmpeg error: {res.stderr[-400:]}")
        return False
    return True


def main():
    OUT_DIR.mkdir(parents=True, exist_ok=True)
    print(f"[{datetime.now().isoformat()}] Generating daily 9:16 vertical videos for TikTok & Reels...")

    # 1. Marketplace Bon Plan Reel
    market_rows = query_db("""
    SELECT json_agg(m) FROM (
        SELECT id, market_title, market_price, location_name, image_url
        FROM posts
        WHERE post_type = 'market' AND image_url IS NOT NULL
        ORDER BY random()
        LIMIT 1
    ) m;
    """)
    if market_rows:
        m = market_rows[0]
        city = (m.get("location_name") or "Ris-Orangis").split("(")[0].strip().upper()
        title = m.get("market_title") or "Bon Plan Voisins"
        price = m.get("market_price") or 0
        img_frame = compose_vertical_frame(
            badge_text=f"BON PLAN • {city}",
            title=title,
            highlight_pill=f"SEULEMENT {price} EUR • 0 EUR PORT",
            photo_url=m.get("image_url", ""),
            footer_cta="Voir l'annonce entre voisins",
            theme="teal",
        )
        jpg_path = OUT_DIR / "reel_bonplan.jpg"
        mp4_path = OUT_DIR / "reel_bonplan.mp4"
        img_frame.save(jpg_path, quality=92)
        if render_mp4_from_image(jpg_path, mp4_path, duration_sec=10):
            print(f"✅ Generated {mp4_path} ({mp4_path.stat().st_size // 1024} KB)")

    # 2. Breaking Local News Reel
    news_rows = query_db("""
    SELECT json_agg(nw) FROM (
        SELECT id, content, location_name, image_url
        FROM posts
        WHERE external_source = 'live_news'
        ORDER BY created_at DESC
        LIMIT 1
    ) nw;
    """)
    if news_rows:
        nw = news_rows[0]
        city = (nw.get("location_name") or "Essonne 91").split("(")[0].strip().upper()
        first_line = (nw.get("content") or "").split("\n")[0]
        clean_headline = first_line.replace("📰", "").strip()
        if "]" in clean_headline:
            clean_headline = clean_headline.split("]", 1)[1].strip()
        img_frame = compose_vertical_frame(
            badge_text=f"ACTU LOCALE • {city}",
            title=clean_headline,
            highlight_pill="ET VOUS, QU'EN PENSEZ-VOUS ?",
            photo_url=nw.get("image_url", ""),
            footer_cta="Rejoindre le debat sur Allonssy",
            theme="news",
        )
        jpg_path = OUT_DIR / "reel_actu.jpg"
        mp4_path = OUT_DIR / "reel_actu.mp4"
        img_frame.save(jpg_path, quality=92)
        if render_mp4_from_image(jpg_path, mp4_path, duration_sec=10):
            print(f"✅ Generated {mp4_path} ({mp4_path.stat().st_size // 1024} KB)")


if __name__ == "__main__":
    main()
