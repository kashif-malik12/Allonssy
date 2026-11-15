#!/usr/bin/env python3
"""
daily_post_publisher.py
Scheduled automated daily post publisher for Allonssy (Ris-Orangis, 91130).
Publishes fresh, engaging community updates, local tips, and culinary highlights.
Designed to be run via daily cron (e.g., at 08:30 AM).
"""

import sys
import uuid
import datetime
import random
import subprocess

DAILY_TOPICS = [
    # Monday: Artisanal commerce spotlight
    {
        "author_email": "infos.ris-orangis@allonssy.com",
        "author_name": "Ris-Orangis Infos Locales",
        "post_type": "post",
        "content": "🥐 [COMMERCE LOCAL] Pour démarrer la semaine du bon pied, coup de projecteur sur la Boulangerie du Moulin à Vent au 32 rue Pierre Brossolette. Pains de tradition au levain et viennoiseries fraîches dès 6h30. Belle semaine à tous les habitants de Ris-Orangis !",
        "image_url": "https://images.unsplash.com/photo-1509440159596-0249088772ff?w=800&auto=format&fit=crop&q=80",
    },
    # Tuesday: Culture & reading
    {
        "author_email": "sortir.ris-orangis@allonssy.com",
        "author_name": "Sortir à Ris-Orangis",
        "post_type": "post",
        "content": "📚 [CULTURE & LOISIRS] À la recherche d'un coin lecture ou d'activités pour petits et grands ? La Médiathèque municipale Elsa Triolet vous accueille avec un large choix d'ouvrages et des ateliers numériques gratuits. Espace calme ouvert à tous.",
        "image_url": "https://images.unsplash.com/photo-1521587760476-6c12a4b040da?w=800&auto=format&fit=crop&q=80",
    },
    # Wednesday: Municipal civic reminders
    {
        "author_email": "infos.ris-orangis@allonssy.com",
        "author_name": "Ris-Orangis Infos Locales",
        "post_type": "post",
        "content": "🏛️ [VIE PRATIQUE] Rappel pour les familles de Ris-Orangis : la campagne municipale de calcul du quotient familial pour l'année 2027 est ouverte à l'Hôtel de Ville et en Mairie annexe du Moulin-à-Vent pour les activités périscolaires et séjours jeunesse.",
        "image_url": "https://images.unsplash.com/photo-1577495508048-b635879837f1?w=800&auto=format&fit=crop&q=80",
    },
    # Thursday: Restaurant recommendation
    {
        "author_email": "infos.ris-orangis@allonssy.com",
        "author_name": "Ris-Orangis Infos Locales",
        "post_type": "post",
        "content": "🍽️ [BONNES TABLES] Envie d'une pause gourmande ce midi ? Découvrez Côté Bistrot au 69 rue Albert Rémy : cuisine bistronomique de saison, formules du midi et cadre chaleureux. Consultez leur carte complète dans l'onglet Restaurants de l'application !",
        "image_url": "https://images.unsplash.com/photo-1544025162-d76694265947?w=800&auto=format&fit=crop&q=80",
    },
    # Friday: Weekend gourmet ideas
    {
        "author_email": "infos.ris-orangis@allonssy.com",
        "author_name": "Ris-Orangis Infos Locales",
        "post_type": "post",
        "content": "🍕 [WEEK-END GOURMAND] Vendredi soir en famille ou entre amis ? Retrouvez Pizza Time Ris-Orangis au 50 Rue Edmond Bonté pour leurs pizzas artisanales à emporter ou en livraison. Pâte fraîche pétrie chaque jour !",
        "image_url": "https://images.unsplash.com/photo-1513104890138-7c749659a591?w=800&auto=format&fit=crop&q=80",
    },
    # Saturday: Weekend burgers & local spot
    {
        "author_email": "sortir.ris-orangis@allonssy.com",
        "author_name": "Sortir à Ris-Orangis",
        "post_type": "post",
        "content": "🍔 [SORTIES DU SAMEDI] Envie d'un burger gourmet pour le week-end ? L'équipe de BOON Burgers & Brasserie vous accueille au 14 Avenue de la Libération avec des viandes françaises grillées à la flamme et frites maison.",
        "image_url": "https://images.unsplash.com/photo-1568901346375-23c9450c58cd?w=800&auto=format&fit=crop&q=80",
    },
    # Sunday: Tranquility & walks
    {
        "author_email": "sortir.ris-orangis@allonssy.com",
        "author_name": "Sortir à Ris-Orangis",
        "post_type": "post",
        "content": "🌿 [DIMANCHE DÉTENTE] Balade dominicale : profitez du calme des berges de Seine et du Parc de Trousseau pour prendre l'air avant d'attaquer la nouvelle semaine. Et pour les amateurs de saveurs orientales, La Tour du Maroc vous accueille rue Edmond Bonté. Bon dimanche à tous !",
        "image_url": "https://images.unsplash.com/photo-1541518763669-27fef04b14ea?w=800&auto=format&fit=crop&q=80",
    },
]

def publish_daily_post():
    weekday = datetime.datetime.now().weekday()  # 0 = Monday ... 6 = Sunday
    topic = DAILY_TOPICS[weekday % len(DAILY_TOPICS)]
    post_id = str(uuid.uuid4())

    email_esc = topic["author_email"].replace("'", "''")
    content_esc = topic["content"].replace("'", "''")
    image_sql = f"'{topic['image_url']}'" if topic.get("image_url") else "NULL"
    post_type = topic.get("post_type", "post")
    market_cat_sql = f"'{topic['market_category']}'" if topic.get("market_category") else "NULL"

    sql = f"""
DO $$
DECLARE
    v_user_id uuid;
    v_lat double precision;
    v_lng double precision;
    v_account_type text;
BEGIN
    SELECT id, latitude, longitude, account_type
    INTO v_user_id, v_lat, v_lng, v_account_type
    FROM public.profiles
    WHERE email = '{email_esc}'
    LIMIT 1;

    IF v_user_id IS NULL THEN
        -- Fallback to first available active profile
        SELECT id, latitude, longitude, account_type
        INTO v_user_id, v_lat, v_lng, v_account_type
        FROM public.profiles
        WHERE city = 'Ris-Orangis' AND is_disabled = false
        LIMIT 1;
    END IF;

    IF v_user_id IS NOT NULL THEN
        INSERT INTO public.posts (
            id, user_id, content, image_url, visibility, location_name,
            latitude, longitude, created_at, author_profile_type, post_type,
            market_category, share_scope, is_unclaimed
        ) VALUES (
            '{post_id}',
            v_user_id,
            '{content_esc}',
            {image_sql},
            'public',
            'Ris-Orangis (91130)',
            COALESCE(v_lat, 48.6508),
            COALESCE(v_lng, 2.4143),
            now(),
            COALESCE(v_account_type, 'person'),
            '{post_type}',
            {market_cat_sql},
            'public',
            false
        );
    END IF;
END $$;
"""
    cmd = ["docker", "exec", "-i", "supabase-db", "psql", "-U", "postgres", "-d", "postgres"]
    res = subprocess.run(cmd, input=sql, text=True, capture_output=True)
    if res.returncode == 0:
        print(f"[{datetime.datetime.now().isoformat()}] Published daily post {post_id} for weekday {weekday} ({topic['author_name']})")
    else:
        print(f"[{datetime.datetime.now().isoformat()}] Error publishing daily post: {res.stderr}", file=sys.stderr)
        sys.exit(1)

if __name__ == "__main__":
    publish_daily_post()
