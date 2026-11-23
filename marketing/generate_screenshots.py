#!/usr/bin/env python3
"""
Generates high-resolution 1080x2400 mobile UI mockups for Allonssy.
These are used by the automated video generator to showcase real app screens.
"""

import os
from pathlib import Path
from PIL import Image, ImageDraw, ImageFont

ROOT_DIR = Path(__file__).resolve().parent.parent
SCREENSHOTS_DIR = ROOT_DIR / "assets" / "branding" / "screenshots"
SCREENSHOTS_DIR.mkdir(parents=True, exist_ok=True)
BRANDING_DIR = ROOT_DIR / "assets" / "branding"

FONT_REG = "C:\\Windows\\Fonts\\segoeui.ttf"
FONT_BOLD = "C:\\Windows\\Fonts\\segoeuib.ttf"
if not os.path.exists(FONT_REG):
    FONT_REG = "/usr/share/fonts/truetype/dejavu/DejaVuSans.ttf"
    FONT_BOLD = "/usr/share/fonts/truetype/dejavu/DejaVuSans-Bold.ttf"

def get_fonts():
    try:
        f_title = ImageFont.truetype(FONT_BOLD, 46)
        f_sub = ImageFont.truetype(FONT_REG, 34)
        f_bold = ImageFont.truetype(FONT_BOLD, 36)
        f_pill = ImageFont.truetype(FONT_BOLD, 30)
        f_body = ImageFont.truetype(FONT_REG, 32)
        f_small = ImageFont.truetype(FONT_REG, 26)
        f_price = ImageFont.truetype(FONT_BOLD, 48)
    except Exception:
        f_title = f_sub = f_bold = f_pill = f_body = f_small = f_price = ImageFont.load_default()
    return f_title, f_sub, f_bold, f_pill, f_body, f_small, f_price

def create_base_canvas():
    w, h = 1080, 2400
    canvas = Image.new("RGBA", (w, h), (245, 241, 232, 255)) # Cream bg #F5F1E8
    draw = ImageDraw.Draw(canvas)

    # Top Status Bar (fake battery, time, wifi)
    f_title, f_sub, f_bold, f_pill, f_body, f_small, f_price = get_fonts()
    draw.text((80, 45), "09:41", font=f_bold, fill=(18, 33, 29, 255))
    draw.text((920, 45), "5G 100%", font=f_small, fill=(18, 33, 29, 255))

    # App Header Bar (Y: 100 to 220)
    logo_path = BRANDING_DIR / "allonssy-wordmark.png"
    if logo_path.exists():
        logo = Image.open(logo_path).convert("RGBA")
        logo.thumbnail((320, 90), Image.Resampling.LANCZOS)
        canvas.paste(logo, (60, 115), logo)
    else:
        draw.text((60, 120), "Allonssy!", font=f_title, fill=(15, 118, 110, 255))

    # Location pill at header right
    loc_text = "📍 Ris-Orangis (2 km)"
    draw.rounded_rectangle([(650, 120), (1020, 185)], radius=30, fill=(230, 221, 206, 255))
    draw.text((675, 135), loc_text, font=f_small, fill=(15, 118, 110, 255))

    # Bottom Nav Bar (Y: 2200 to 2400)
    draw.rectangle([(0, 2220), (1080, 2400)], fill=(255, 252, 247, 255))
    draw.line([(0, 2220), (1080, 2220)], fill=(230, 221, 206, 255), width=2)
    nav_items = ["🏠 Feed", "🔍 Search", "➕ Post", "🛍️ Market", "💬 Chat"]
    for i, item in enumerate(nav_items):
        item_x = 50 + i * 205
        draw.text((item_x, 2270), item, font=f_pill, fill=(15, 118, 110, 255) if i == 0 else (100, 116, 139, 255))

    return canvas, draw

def generate_feed_screen():
    canvas, draw = create_base_canvas()
    f_title, f_sub, f_bold, f_pill, f_body, f_small, f_price = get_fonts()

    # Filter chips (Radius km, Trending, Announcements)
    chips = [("📍 2 km Radius", True), ("🔥 Trending", False), ("📢 Local News", False), ("🍔 Food", False)]
    chip_x = 60
    for text, active in chips:
        bg_col = (15, 118, 110, 255) if active else (230, 221, 206, 255)
        fg_col = (255, 255, 255, 255) if active else (51, 65, 85, 255)
        bbox = draw.textbbox((0, 0), text, font=f_pill)
        cw = bbox[2] - bbox[0] + 44
        draw.rounded_rectangle([(chip_x, 230), (chip_x + cw, 295)], radius=25, fill=bg_col)
        draw.text((chip_x + 22, 245), text, font=f_pill, fill=fg_col)
        chip_x += cw + 18

    # Card 1: Community Post
    card1_y = 330
    draw.rounded_rectangle([(60, card1_y), (1020, card1_y + 600)], radius=35, fill=(255, 252, 247, 255), outline=(230, 221, 206, 255), width=2)
    # Avatar
    draw.ellipse([(100, card1_y + 40), (180, card1_y + 120)], fill=(15, 118, 110, 255))
    draw.text((122, card1_y + 55), "CL", font=f_bold, fill=(255, 255, 255, 255))
    draw.text((210, card1_y + 45), "Claire Lambert", font=f_bold, fill=(18, 33, 29, 255))
    draw.text((210, card1_y + 90), "Neighborhood Council • 25m ago • 450m away", font=f_small, fill=(100, 116, 139, 255))
    # Post Content
    post_text = "🌳 Neighborhood Cleanup & Barbecue!\nJoin us this Saturday at 10 AM at Parc de la Mairie.\nBags and gloves provided. Free grilled burgers afterwards! 🍔"
    draw.text((100, card1_y + 160), post_text, font=f_body, fill=(30, 41, 59, 255), spacing=10)
    # Media Banner Box inside card
    draw.rounded_rectangle([(100, card1_y + 350), (980, card1_y + 490)], radius=20, fill=(209, 250, 229, 255))
    draw.text((140, card1_y + 395), "🌳 Community Event • 34 Neighbors Attending", font=f_bold, fill=(6, 95, 70, 255))
    # Actions
    draw.text((100, card1_y + 530), "❤️ 48 Likes    💬 16 Comments    ↗️ Share", font=f_pill, fill=(15, 118, 110, 255))

    # Card 2: Food Ad Post
    card2_y = 970
    draw.rounded_rectangle([(60, card2_y), (1020, card2_y + 580)], radius=35, fill=(255, 252, 247, 255), outline=(230, 221, 206, 255), width=2)
    draw.ellipse([(100, card2_y + 40), (180, card2_y + 120)], fill=(204, 122, 0, 255))
    draw.text((122, card2_y + 55), "BN", font=f_bold, fill=(255, 255, 255, 255))
    draw.text((210, card2_y + 45), "Boulangerie Artisanale", font=f_bold, fill=(18, 33, 29, 255))
    draw.text((210, card2_y + 90), "Local Baker • 1h ago • 300m away", font=f_small, fill=(100, 116, 139, 255))
    draw.text((100, card2_y + 160), "🥖 Fresh Organic Sourdough & Croissants!\nBatch just came out of the oven hot. Show this Allonssy post\nfor a free café with any 2 pastries! ☕🥐", font=f_body, fill=(30, 41, 59, 255), spacing=10)
    draw.rounded_rectangle([(100, card2_y + 350), (980, card2_y + 470)], radius=20, fill=(254, 243, 199, 255))
    draw.text((140, card2_y + 395), "🥐 Special Deal: -20% Afternoon Tea Box", font=f_bold, fill=(146, 64, 14, 255))
    draw.text((100, card2_y + 510), "❤️ 92 Likes    💬 24 Comments    ↗️ Directions", font=f_pill, fill=(204, 122, 0, 255))

    # Card 3: Sneak peek
    card3_y = 1590
    draw.rounded_rectangle([(60, card3_y), (1020, card3_y + 580)], radius=35, fill=(255, 252, 247, 255), outline=(230, 221, 206, 255), width=2)
    draw.ellipse([(100, card3_y + 40), (180, card3_y + 120)], fill=(15, 118, 110, 255))
    draw.text((122, card3_y + 55), "MD", font=f_bold, fill=(255, 255, 255, 255))
    draw.text((210, card3_y + 45), "Marc Dubois", font=f_bold, fill=(18, 33, 29, 255))
    draw.text((210, card3_y + 90), "Resident • 3h ago • 1.2 km away", font=f_small, fill=(100, 116, 139, 255))
    draw.text((100, card3_y + 160), "🚲 Anyone looking for a road bike? Selling my vintage Peugeot\nin perfect riding condition. See marketplace tab!", font=f_body, fill=(30, 41, 59, 255))

    out_p = SCREENSHOTS_DIR / "screen_feed.png"
    canvas.save(out_p, "PNG")
    print(f"Generated {out_p}")

def generate_marketplace_screen():
    canvas, draw = create_base_canvas()
    f_title, f_sub, f_bold, f_pill, f_body, f_small, f_price = get_fonts()

    # Category Chips
    chips = [("All Items", True), ("🚴 Bicycles", False), ("🛋️ Furniture", False), ("💻 Electronics", False)]
    chip_x = 60
    for text, active in chips:
        bg_col = (15, 118, 110, 255) if active else (230, 221, 206, 255)
        fg_col = (255, 255, 255, 255) if active else (51, 65, 85, 255)
        bbox = draw.textbbox((0, 0), text, font=f_pill)
        cw = bbox[2] - bbox[0] + 44
        draw.rounded_rectangle([(chip_x, 230), (chip_x + cw, 295)], radius=25, fill=bg_col)
        draw.text((chip_x + 22, 245), text, font=f_pill, fill=fg_col)
        chip_x += cw + 18

    # Item 1: Vintage Bike
    y1 = 330
    draw.rounded_rectangle([(60, y1), (1020, y1 + 560)], radius=35, fill=(255, 252, 247, 255), outline=(230, 221, 206, 255), width=2)
    # Image placeholder
    draw.rounded_rectangle([(90, y1 + 30), (450, y1 + 360)], radius=25, fill=(241, 245, 249, 255))
    draw.text((180, y1 + 150), "🚲 PHOTO", font=f_bold, fill=(100, 116, 139, 255))
    # Details
    draw.text((490, y1 + 40), "Vintage Peugeot Bike", font=f_bold, fill=(18, 33, 29, 255))
    draw.text((490, y1 + 95), "10-speed • Pristine condition", font=f_small, fill=(100, 116, 139, 255))
    draw.text((490, y1 + 140), "📍 800m away • Marc D.", font=f_small, fill=(15, 118, 110, 255))
    draw.text((490, y1 + 220), "€85", font=f_price, fill=(15, 118, 110, 255))
    # Action buttons
    draw.rounded_rectangle([(90, y1 + 420), (520, y1 + 510)], radius=20, fill=(15, 118, 110, 255))
    draw.text((180, y1 + 445), "💬 Make Offer", font=f_bold, fill=(255, 255, 255, 255))
    draw.rounded_rectangle([(560, y1 + 420), (990, y1 + 510)], radius=20, fill=(230, 221, 206, 255))
    draw.text((670, y1 + 445), "❤️ Save Post", font=f_bold, fill=(30, 41, 59, 255))

    # Item 2: Solid Oak Table
    y2 = 930
    draw.rounded_rectangle([(60, y2), (1020, y2 + 560)], radius=35, fill=(255, 252, 247, 255), outline=(230, 221, 206, 255), width=2)
    draw.rounded_rectangle([(90, y2 + 30), (450, y2 + 360)], radius=25, fill=(241, 245, 249, 255))
    draw.text((180, y2 + 150), "🪵 PHOTO", font=f_bold, fill=(100, 116, 139, 255))
    draw.text((490, y2 + 40), "Solid Oak Coffee Table", font=f_bold, fill=(18, 33, 29, 255))
    draw.text((490, y2 + 95), "Custom hand-crafted wood", font=f_small, fill=(100, 116, 139, 255))
    draw.text((490, y2 + 140), "📍 1.2 km away • Julie T.", font=f_small, fill=(15, 118, 110, 255))
    draw.text((490, y2 + 220), "€45", font=f_price, fill=(15, 118, 110, 255))
    draw.rounded_rectangle([(90, y2 + 420), (520, y2 + 510)], radius=20, fill=(15, 118, 110, 255))
    draw.text((180, y2 + 445), "💬 Make Offer", font=f_bold, fill=(255, 255, 255, 255))
    draw.rounded_rectangle([(560, y2 + 420), (990, y2 + 510)], radius=20, fill=(230, 221, 206, 255))
    draw.text((670, y2 + 445), "❤️ Save Post", font=f_bold, fill=(30, 41, 59, 255))

    # Item 3: PS5
    y3 = 1530
    draw.rounded_rectangle([(60, y3), (1020, y3 + 560)], radius=35, fill=(255, 252, 247, 255), outline=(230, 221, 206, 255), width=2)
    draw.rounded_rectangle([(90, y3 + 30), (450, y3 + 360)], radius=25, fill=(241, 245, 249, 255))
    draw.text((180, y3 + 150), "🎮 PHOTO", font=f_bold, fill=(100, 116, 139, 255))
    draw.text((490, y3 + 40), "PlayStation 5 Console", font=f_bold, fill=(18, 33, 29, 255))
    draw.text((490, y3 + 95), "Includes 2 Controllers & 3 Games", font=f_small, fill=(100, 116, 139, 255))
    draw.text((490, y3 + 140), "📍 2.5 km away • Thomas B.", font=f_small, fill=(15, 118, 110, 255))
    draw.text((490, y3 + 220), "€350", font=f_price, fill=(15, 118, 110, 255))

    out_p = SCREENSHOTS_DIR / "screen_marketplace.png"
    canvas.save(out_p, "PNG")
    print(f"Generated {out_p}")

def generate_services_screen():
    canvas, draw = create_base_canvas()
    f_title, f_sub, f_bold, f_pill, f_body, f_small, f_price = get_fonts()

    # Category Chips
    chips = [("All Services", True), ("⚡ Electrician", False), ("🐾 Pet Care", False), ("🔧 Plumbing", False)]
    chip_x = 60
    for text, active in chips:
        bg_col = (15, 118, 110, 255) if active else (230, 221, 206, 255)
        fg_col = (255, 255, 255, 255) if active else (51, 65, 85, 255)
        bbox = draw.textbbox((0, 0), text, font=f_pill)
        cw = bbox[2] - bbox[0] + 44
        draw.rounded_rectangle([(chip_x, 230), (chip_x + cw, 295)], radius=25, fill=bg_col)
        draw.text((chip_x + 22, 245), text, font=f_pill, fill=fg_col)
        chip_x += cw + 18

    # Service Card 1
    y1 = 330
    draw.rounded_rectangle([(60, y1), (1020, y1 + 430)], radius=35, fill=(255, 252, 247, 255), outline=(230, 221, 206, 255), width=2)
    draw.ellipse([(100, y1 + 40), (200, y1 + 140)], fill=(15, 118, 110, 255))
    draw.text((120, y1 + 60), "⚡", font=f_title, fill=(255, 255, 255, 255))
    draw.text((230, y1 + 45), "Marc Lefebvre • Certified Electrician", font=f_bold, fill=(18, 33, 29, 255))
    draw.text((230, y1 + 95), "⭐ 4.9 (42 reviews) • 📍 400m away • Verified Artisan", font=f_small, fill=(100, 116, 139, 255))
    draw.text((100, y1 + 180), "Emergency home repairs, panel upgrades, and lighting.\nAvailable 7 days a week. Quick 30-minute arrival locally.", font=f_body, fill=(30, 41, 59, 255))
    draw.rounded_rectangle([(100, y1 + 290), (450, y1 + 380)], radius=20, fill=(15, 118, 110, 255))
    draw.text((160, y1 + 315), "💬 Direct Chat", font=f_bold, fill=(255, 255, 255, 255))
    draw.text((500, y1 + 315), "Rate: €40 / hour", font=f_price, fill=(204, 122, 0, 255))

    # Service Card 2
    y2 = 800
    draw.rounded_rectangle([(60, y2), (1020, y2 + 430)], radius=35, fill=(255, 252, 247, 255), outline=(230, 221, 206, 255), width=2)
    draw.ellipse([(100, y2 + 40), (200, y2 + 140)], fill=(204, 122, 0, 255))
    draw.text((120, y2 + 60), "🐾", font=f_title, fill=(255, 255, 255, 255))
    draw.text((230, y2 + 45), "Sophie Martin • Pet Sitting & Walks", font=f_bold, fill=(18, 33, 29, 255))
    draw.text((230, y2 + 95), "⭐ 5.0 (68 reviews) • 📍 900m away • Insured", font=f_small, fill=(100, 116, 139, 255))
    draw.text((100, y2 + 180), "Daily dog walks, cat sitting during holidays & vacations.\nLoving animal caregiver with 8+ years experience.", font=f_body, fill=(30, 41, 59, 255))
    draw.rounded_rectangle([(100, y2 + 290), (450, y2 + 380)], radius=20, fill=(15, 118, 110, 255))
    draw.text((160, y2 + 315), "💬 Direct Chat", font=f_bold, fill=(255, 255, 255, 255))
    draw.text((500, y2 + 315), "Rate: €15 / walk", font=f_price, fill=(204, 122, 0, 255))

    # Service Card 3
    y3 = 1270
    draw.rounded_rectangle([(60, y3), (1020, y3 + 430)], radius=35, fill=(255, 252, 247, 255), outline=(230, 221, 206, 255), width=2)
    draw.ellipse([(100, y3 + 40), (200, y3 + 140)], fill=(15, 118, 110, 255))
    draw.text((120, y3 + 60), "🔧", font=f_title, fill=(255, 255, 255, 255))
    draw.text((230, y3 + 45), "Alexandre Petit • Master Plumber", font=f_bold, fill=(18, 33, 29, 255))
    draw.text((230, y3 + 95), "⭐ 4.8 (39 reviews) • 📍 1.4 km away", font=f_small, fill=(100, 116, 139, 255))
    draw.text((100, y3 + 180), "Leak detection, boiler repairs, bathroom installations.\nFree transparent quotes, no hidden travel charges.", font=f_body, fill=(30, 41, 59, 255))
    draw.rounded_rectangle([(100, y3 + 290), (450, y3 + 380)], radius=20, fill=(15, 118, 110, 255))
    draw.text((160, y3 + 315), "💬 Direct Chat", font=f_bold, fill=(255, 255, 255, 255))
    draw.text((500, y3 + 315), "Free Quote", font=f_price, fill=(15, 118, 110, 255))

    out_p = SCREENSHOTS_DIR / "screen_services.png"
    canvas.save(out_p, "PNG")
    print(f"Generated {out_p}")

def generate_chat_screen():
    canvas, draw = create_base_canvas()
    f_title, f_sub, f_bold, f_pill, f_body, f_small, f_price = get_fonts()

    # Chat Partner Header Bar
    draw.rounded_rectangle([(60, 230), (1020, 360)], radius=30, fill=(255, 252, 247, 255), outline=(230, 221, 206, 255), width=2)
    draw.ellipse([(90, 250), (170, 330)], fill=(15, 118, 110, 255))
    draw.text((110, 265), "MD", font=f_bold, fill=(255, 255, 255, 255))
    draw.text((190, 255), "Marc Dubois (Seller)", font=f_bold, fill=(18, 33, 29, 255))
    draw.text((190, 305), "Re: Vintage Peugeot Bike • €85", font=f_small, fill=(15, 118, 110, 255))

    # Negotiation Banner Box
    draw.rounded_rectangle([(60, 390), (1020, 570)], radius=30, fill=(254, 243, 199, 255), outline=(245, 158, 11, 255), width=2)
    draw.text((100, 420), "🤝 REAL-TIME OFFER NEGOTIATION", font=f_bold, fill=(146, 64, 14, 255))
    draw.text((100, 475), "Agreed Price: €80.00  (Saved €5)", font=f_price, fill=(15, 118, 110, 255))
    draw.text((700, 485), "STATUS: ACCEPTED ✅", font=f_bold, fill=(6, 95, 70, 255))

    # Message Bubbles
    # Buyer message 1
    draw.rounded_rectangle([(280, 620), (980, 750)], radius=25, fill=(15, 118, 110, 255))
    draw.text((320, 645), "Hi Marc! Still available? Can I pick it up\nthis afternoon?", font=f_body, fill=(255, 255, 255, 255))
    draw.text((880, 715), "10:14 ✓✓", font=f_small, fill=(209, 250, 229, 255))

    # Seller message 1
    draw.rounded_rectangle([(80, 780), (780, 890)], radius=25, fill=(255, 252, 247, 255), outline=(230, 221, 206, 255), width=2)
    draw.text((120, 805), "Yes! I'm home near the train station.", font=f_body, fill=(30, 41, 59, 255))
    draw.text((690, 855), "10:15", font=f_small, fill=(100, 116, 139, 255))

    # Buyer offer bubble
    draw.rounded_rectangle([(320, 930), (980, 1130)], radius=25, fill=(240, 253, 244, 255), outline=(34, 197, 94, 255), width=2)
    draw.text((360, 955), "💰 MADE AN OFFER: €75.00", font=f_bold, fill=(21, 128, 61, 255))
    draw.text((360, 1015), "Would you take €75 cash on pickup?", font=f_body, fill=(30, 41, 59, 255))
    draw.text((880, 1090), "10:16 ✓✓", font=f_small, fill=(100, 116, 139, 255))

    # Seller counter-offer bubble
    draw.rounded_rectangle([(80, 1170), (780, 1370)], radius=25, fill=(254, 243, 199, 255), outline=(245, 158, 11, 255), width=2)
    draw.text((120, 1195), "🔄 COUNTER-OFFER: €80.00", font=f_bold, fill=(180, 83, 9, 255))
    draw.text((120, 1255), "I'll do €80 and throw in the U-lock!", font=f_body, fill=(30, 41, 59, 255))
    draw.text((690, 1330), "10:17", font=f_small, fill=(100, 116, 139, 255))

    # Buyer accepted
    draw.rounded_rectangle([(280, 1410), (980, 1540)], radius=25, fill=(15, 118, 110, 255))
    draw.text((320, 1435), "Deal! Deal accepted ✅ See you at 2 PM.", font=f_body, fill=(255, 255, 255, 255))
    draw.text((880, 1505), "10:18 ✓✓", font=f_small, fill=(209, 250, 229, 255))

    out_p = SCREENSHOTS_DIR / "screen_chat.png"
    canvas.save(out_p, "PNG")
    print(f"Generated {out_p}")

if __name__ == "__main__":
    generate_feed_screen()
    generate_marketplace_screen()
    generate_services_screen()
    generate_chat_screen()
    print("All UI mockups created successfully!")
