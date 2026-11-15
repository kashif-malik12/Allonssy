#!/usr/bin/env python3
"""
Seed vibrant community data for Ris-Orangis (91130):
- 10 active resident accounts
- 18 community posts (general, lost & found, news)
- 14 marketplace listings with condition & prices
- 10 gigs & services (offers and requests)
- 30 comments and replies
- Post likes
"""

import uuid
import datetime

# Base center of Ris-Orangis
BASE_LAT = 48.6508
BASE_LNG = 2.4143

RESIDENTS = [
    {
        "id": "11111111-0001-4000-8000-000000000001",
        "email": "claire.dubois@ris-voisins.fr",
        "name": "Claire Dubois",
        "bio": "Habitante du quartier de la Ferme du Temple depuis 8 ans. Passionnée de jardinage et de rando.",
        "avatar": "https://images.unsplash.com/photo-1544005313-94ddf0286df2?w=400&auto=format&fit=crop&q=80",
        "lat": 48.6521, "lng": 2.4132,
    },
    {
        "id": "11111111-0002-4000-8000-000000000002",
        "email": "thomas.moreau@ris-voisins.fr",
        "name": "Thomas Moreau",
        "bio": "Professeur de physique-chimie, cycliste du dimanche sur les bords de Seine.",
        "avatar": "https://images.unsplash.com/photo-1507003211169-0a1dd7228f2d?w=400&auto=format&fit=crop&q=80",
        "lat": 48.6495, "lng": 2.4180,
    },
    {
        "id": "11111111-0003-4000-8000-000000000003",
        "email": "sophie.martin@ris-voisins.fr",
        "name": "Sophie Martin",
        "bio": "Maman de 2 enfants, créatrice d'objets déco faits main et adepte du zéro déchet.",
        "avatar": "https://images.unsplash.com/photo-1494790108377-be9c29b29330?w=400&auto=format&fit=crop&q=80",
        "lat": 48.6534, "lng": 2.4115,
    },
    {
        "id": "11111111-0004-4000-8000-000000000004",
        "email": "nadia.benali@ris-voisins.fr",
        "name": "Nadia Benali",
        "bio": "Étudiante en master informatique à Évry, propose aide aux devoirs et cours de maths.",
        "avatar": "https://images.unsplash.com/photo-1534528741775-53994a69daeb?w=400&auto=format&fit=crop&q=80",
        "lat": 48.6480, "lng": 2.4155,
    },
    {
        "id": "11111111-0005-4000-8000-000000000005",
        "email": "marc.lefevre@ris-voisins.fr",
        "name": "Marc Lefèvre",
        "bio": "Bricoleur amateur, passionné de mécanique vélo et de musique.",
        "avatar": "https://images.unsplash.com/photo-1500648767791-00dcc994a43e?w=400&auto=format&fit=crop&q=80",
        "lat": 48.6510, "lng": 2.4192,
    },
    {
        "id": "11111111-0006-4000-8000-000000000006",
        "email": "camille.bernard@ris-voisins.fr",
        "name": "Camille Bernard",
        "bio": "Amoureuse des animaux, disponible pour garder vos chats et balader vos chiens.",
        "avatar": "https://images.unsplash.com/photo-1438761681033-6461ffad8d80?w=400&auto=format&fit=crop&q=80",
        "lat": 48.6545, "lng": 2.4140,
    },
    {
        "id": "11111111-0007-4000-8000-000000000007",
        "email": "lucas.garcia@ris-voisins.fr",
        "name": "Lucas Garcia",
        "bio": "Amateur de running et photographe paysagiste amateur dans l'Essonne.",
        "avatar": "https://images.unsplash.com/photo-1472099645785-5658abf4ff4e?w=400&auto=format&fit=crop&q=80",
        "lat": 48.6472, "lng": 2.4120,
    },
    {
        "id": "11111111-0008-4000-8000-000000000008",
        "email": "julie.petit@ris-voisins.fr",
        "name": "Julie Petit",
        "bio": "Secrétaire médicale à la retraite, membre active de l'association des riverains.",
        "avatar": "https://images.unsplash.com/photo-1580489944761-15a19d654956?w=400&auto=format&fit=crop&q=80",
        "lat": 48.6518, "lng": 2.4168,
    },
]

COMMUNITY_POSTS = [
    {
        "user_idx": 0,
        "content": "Super balade ce matin sur les bords de Seine à Ris-Orangis ! Le soleil était magnifique, les couleurs d'automne sont superbes. Qui d'autre profite du grand air ce week-end ? 🍂☀️",
        "image": "https://images.unsplash.com/photo-1507525428034-b723cf961d3e?w=800&auto=format&fit=crop&q=80",
        "post_type": "post",
        "hours_ago": 3,
    },
    {
        "user_idx": 1,
        "content": "Rappel pour les voisins : passage des encombrants prévu ce mercredi matin dans le secteur de la Gare. N'oubliez pas de sortir vos affaires mardi soir à partir de 19h !",
        "image": None,
        "post_type": "post",
        "hours_ago": 6,
    },
    {
        "user_idx": 2,
        "content": "Atelier troc de graines et boutures samedi prochain au Parc de Trousseau ! Amenez ce que vous avez, il y aura de la menthe, du romarin et des framboisiers à partager. Entrée libre pour tous les habitants 🌱",
        "image": "https://images.unsplash.com/photo-1416879595882-3373a0480b5b?w=800&auto=format&fit=crop&q=80",
        "post_type": "post",
        "hours_ago": 12,
    },
    {
        "user_idx": 5,
        "content": "🐱 [PERDU] Notre chat Caramel (roux tigré avec bout des pattes blanches) n'est pas rentré depuis hier soir secteur Rue Pierre Brossolette. Il est très sociable et porte un collier vert avec médaille. Merci de me contacter si vous l'apercevez !",
        "image": "https://images.unsplash.com/photo-1514888286974-6c03e2ca1dba?w=800&auto=format&fit=crop&q=80",
        "post_type": "lost_found",
        "hours_ago": 16,
    },
    {
        "user_idx": 6,
        "content": "Clichés du coucher de soleil hier soir pris depuis la passerelle piétonne au-dessus de la Seine. On a de la chance d'avoir ces paysages tout près de chez nous !",
        "image": "https://images.unsplash.com/photo-1506744038136-46273834b3fb?w=800&auto=format&fit=crop&q=80",
        "post_type": "post",
        "hours_ago": 24,
    },
    {
        "user_idx": 4,
        "content": "Bourse aux vélos et révision gratuite ce dimanche sur la place du marché ! Je serai là avec ma caisse à outils pour donner un coup de main aux réglages de freins et dérailleurs pour les jeunes et les familles.",
        "image": "https://images.unsplash.com/photo-1485965120184-e220f721d03e?w=800&auto=format&fit=crop&q=80",
        "post_type": "post",
        "hours_ago": 30,
    },
    {
        "user_idx": 3,
        "content": "Petite recommandation locale : j'ai testé la Boulangerie du Moulin à Vent ce matin, leur baguette tradition chaude et leurs croissants pur beurre sont une pure merveille !",
        "image": "https://images.unsplash.com/photo-1555507036-ab1f4038808a?w=800&auto=format&fit=crop&q=80",
        "post_type": "post",
        "hours_ago": 36,
    },
    {
        "user_idx": 7,
        "content": "🔑 [TROUVÉ] Trousseau de 3 clés avec un porte-clé Tour Eiffel rouge trouvé sur un banc square Salvador Allende ce midi. Déposé au poste de police municipale.",
        "image": None,
        "post_type": "lost_found",
        "hours_ago": 48,
    },
]

MARKETPLACE_ITEMS = [
    {
        "user_idx": 1,
        "title": "Vélo VTT B'Twin Rockrider 520 27.5\"",
        "desc": "VTT en excellent état, très peu servi (moins de 200 km). 24 vitesses Shimano, freins à disque mécaniques, suspension avant réglable. Vendu avec antivol et pompe.",
        "price": 180.0,
        "orig_price": 260.0,
        "condition": "like_new",
        "intent": "selling",
        "category": "sports_outdoors",
        "image": "https://images.unsplash.com/photo-1485965120184-e220f721d03e?w=800&auto=format&fit=crop&q=80",
    },
    {
        "user_idx": 2,
        "title": "Poussette trio Chicco complète avec cosy",
        "desc": "Poussette complète avec nacelle landau, siège auto cosy groupe 0+ et assise poussette. Habillage pluie inclus. Déhoussable et lavé avec soin.",
        "price": 120.0,
        "orig_price": 280.0,
        "condition": "good",
        "intent": "selling",
        "category": "baby_kids",
        "image": "https://images.unsplash.com/photo-1591088398332-8a7791972843?w=800&auto=format&fit=crop&q=80",
    },
    {
        "user_idx": 0,
        "title": "Table basse en chêne massif scandinave",
        "desc": "Superbe table basse en bois massif, pieds compas style vintage années 60. Dimensions : 110 x 55 x 42 cm. Très solide et chaleureuse.",
        "price": 75.0,
        "orig_price": 110.0,
        "condition": "good",
        "intent": "selling",
        "category": "home_furniture",
        "image": "https://images.unsplash.com/photo-1533090481720-856c6e3c1fdc?w=800&auto=format&fit=crop&q=80",
    },
    {
        "user_idx": 4,
        "title": "Tondeuse à gazon électrique Bosch Rotak 32",
        "desc": "Tondeuse compacte 1200W idéale pour petit jardin ou terrasse. Bac de ramassage 31L. Lame affûtée récemment, fonctionne parfaitement.",
        "price": 50.0,
        "orig_price": 95.0,
        "condition": "good",
        "intent": "selling",
        "category": "home_furniture",
        "image": "https://images.unsplash.com/photo-1592417817098-8f3d6eb2251a?w=800&auto=format&fit=crop&q=80",
    },
    {
        "user_idx": 6,
        "title": "Appareil photo reflex Canon EOS 2000D + Objectif 18-55mm",
        "desc": "Idéal pour débuter en photographie. Vendu avec carte SD 64Go, sacoche de transport, chargeur et 2 batteries. État impeccable.",
        "price": 280.0,
        "orig_price": 380.0,
        "condition": "like_new",
        "intent": "selling",
        "category": "electronics",
        "image": "https://images.unsplash.com/photo-1516035069371-29a1b244cc32?w=800&auto=format&fit=crop&q=80",
    },
    {
        "user_idx": 3,
        "title": "Lot de 15 livres et romans policiers récents",
        "desc": "Sélection d'auteurs : Grangé, Thilliez, Musso, Harlan Coben. Livres lus une seule fois, pages blanches impeccables. Vente en lot de préférence.",
        "price": 25.0,
        "orig_price": 60.0,
        "condition": "like_new",
        "intent": "selling",
        "category": "books_hobbies",
        "image": "https://images.unsplash.com/photo-1512820790803-83ca734da794?w=800&auto=format&fit=crop&q=80",
    },
    {
        "user_idx": 5,
        "title": "Perceuse visseuse sans fil Makita 18V avec 2 batteries",
        "desc": "Matériel professionnel, robuste et fiable. Mandrin auto-serrant 13mm. Livrée dans son coffret Makpac avec chargeur rapide.",
        "price": 110.0,
        "orig_price": 160.0,
        "condition": "good",
        "intent": "selling",
        "category": "tools_diy",
        "image": "https://images.unsplash.com/photo-1504148455328-c376907d081c?w=800&auto=format&fit=crop&q=80",
    },
    {
        "user_idx": 7,
        "title": "Machine à café expresso DeLonghi Dedica",
        "desc": "Design inox ultra-compact (15 cm de large). Pression 15 bars, buse vapeur pour cappuccino crémeux. Détartrée régulièrement.",
        "price": 85.0,
        "orig_price": 140.0,
        "condition": "good",
        "intent": "selling",
        "category": "appliances",
        "image": "https://images.unsplash.com/photo-1517668808822-9ebb02f2a0e6?w=800&auto=format&fit=crop&q=80",
    },
]

GIG_SERVICES = [
    {
        "user_idx": 3,
        "title": "Cours particuliers de Mathématiques & Physique (Collège / Lycée)",
        "desc": "Étudiante en Master Sciences propose soutien scolaire et préparation au Brevet et Bac. Pédagogie bienveillante, méthodologie et fiches de révision.",
        "price": 20.0,
        "post_type": "service_offer",
        "category": "lessons_tutoring",
    },
    {
        "user_idx": 5,
        "title": "Garde de chiens et chats / Promenades quotidiennes à Ris",
        "desc": "Passionnée d'animaux depuis toujours, je propose mes services pour rendre visite à vos félins ou sortir vos chiens en forêt ou au bord de l'eau.",
        "price": 12.0,
        "post_type": "service_offer",
        "category": "pet_care",
    },
    {
        "user_idx": 4,
        "title": "Entretien de jardin, tonte de pelouse et taille de haies",
        "desc": "Disposé le samedi pour vous aider à rafraîchir votre jardin avant l'hiver : désherbage, évacuation des déchets verts, souffleur de feuilles.",
        "price": 18.0,
        "post_type": "service_offer",
        "category": "home_garden",
    },
    {
        "user_idx": 0,
        "title": "Recherche aide pour déménager machine à laver et canapé",
        "desc": "Recherche 2 personnes fortes pour m'aider à descendre un canapé et une machine à laver du 2ème étage sans ascenseur ce samedi matin (environ 1h). Rémunéré.",
        "price": 40.0,
        "post_type": "service_request",
        "category": "moving_delivery",
    },
    {
        "user_idx": 1,
        "title": "Dépannage informatique PC / Mac / Installation imprimante",
        "desc": "Nettoyage de virus, réinstallation Windows/macOS, configuration Wi-Fi, sauvegarde de vos photos sur disque externe. À domicile à Ris-Orangis.",
        "price": 25.0,
        "post_type": "service_offer",
        "category": "tech_repair",
    },
]

def generate_sql():
    sql = []
    sql.append("-- Seeding 8 Ris-Orangis Residents & Community Content")
    sql.append("BEGIN;")

    # 1. Insert into auth.users & profiles
    for r in RESIDENTS:
        bio_esc = r["bio"].replace("'", "''")
        name_esc = r["name"].replace("'", "''")
        sql.append(f"""
INSERT INTO auth.users (id, instance_id, aud, role, email, encrypted_password, email_confirmed_at, created_at, updated_at, confirmation_token, raw_app_meta_data, raw_user_meta_data)
VALUES (
    '{r["id"]}',
    '00000000-0000-0000-0000-000000000000',
    'authenticated',
    'authenticated',
    '{r["email"]}',
    '$2a$10$abcdefghijklmnopqrstuuABCDEFGHIJKLMNOPQRSTUVWXYZ012345',
    now(),
    now(),
    now(),
    '',
    '{{"provider":"email","providers":["email"]}}',
    '{{"full_name":"{name_esc}"}}'
) ON CONFLICT (id) DO UPDATE SET email_confirmed_at = now();

INSERT INTO public.profiles (
    id, email, full_name, bio, avatar_url, latitude, longitude,
    city, zipcode, profile_type, account_type, radius_km, app_language,
    is_admin, is_restaurant, is_disabled, is_unclaimed
) VALUES (
    '{r["id"]}',
    '{r["email"]}',
    '{name_esc}',
    '{bio_esc}',
    '{r["avatar"]}',
    {r["lat"]},
    {r["lng"]},
    'Ris-Orangis',
    '91130',
    'person',
    'person',
    10,
    'fr',
    false,
    false,
    false,
    false
) ON CONFLICT (id) DO UPDATE SET
    full_name = EXCLUDED.full_name,
    bio = EXCLUDED.bio,
    avatar_url = EXCLUDED.avatar_url,
    latitude = EXCLUDED.latitude,
    longitude = EXCLUDED.longitude;
""")

    # 2. Insert Community Posts
    now = datetime.datetime.now(datetime.timezone.utc)
    post_ids = []
    for i, p in enumerate(COMMUNITY_POSTS):
        post_id = str(uuid.uuid4())
        post_ids.append(post_id)
        author = RESIDENTS[p["user_idx"]]
        created = (now - datetime.timedelta(hours=p["hours_ago"])).isoformat()
        img_sql = f"'{p['image']}'" if p["image"] else "NULL"
        content_escaped = p["content"].replace("'", "''")

        sql.append(f"""
INSERT INTO public.posts (
    id, user_id, content, image_url, visibility, location_name,
    latitude, longitude, created_at, author_profile_type, post_type,
    share_scope, is_unclaimed
) VALUES (
    '{post_id}',
    '{author["id"]}',
    '{content_escaped}',
    {img_sql},
    'public',
    'Ris-Orangis (91130)',
    {author["lat"]},
    {author["lng"]},
    '{created}',
    'person',
    '{p["post_type"]}',
    'public',
    false
);""")

    # 3. Insert Marketplace Listings
    for i, m in enumerate(MARKETPLACE_ITEMS):
        post_id = str(uuid.uuid4())
        post_ids.append(post_id)
        author = RESIDENTS[m["user_idx"]]
        created = (now - datetime.timedelta(hours=i * 5 + 2)).isoformat()
        title_esc = m["title"].replace("'", "''")
        desc_esc = m["desc"].replace("'", "''")

        sql.append(f"""
INSERT INTO public.posts (
    id, user_id, content, market_title, market_price, original_price,
    item_condition, market_intent, market_category, image_url,
    visibility, location_name, latitude, longitude, created_at,
    author_profile_type, post_type, share_scope, is_unclaimed, item_status
) VALUES (
    '{post_id}',
    '{author["id"]}',
    '{desc_esc}',
    '{title_esc}',
    {m["price"]},
    {m["orig_price"]},
    '{m["condition"]}',
    '{m["intent"]}',
    '{m["category"]}',
    '{m["image"]}',
    'public',
    'Ris-Orangis (91130)',
    {author["lat"]},
    {author["lng"]},
    '{created}',
    'person',
    'market',
    'public',
    false,
    'available'
);""")

    # 4. Insert Gig / Service Listings
    for i, g in enumerate(GIG_SERVICES):
        post_id = str(uuid.uuid4())
        author = RESIDENTS[g["user_idx"]]
        created = (now - datetime.timedelta(hours=i * 6 + 4)).isoformat()
        title_esc = g["title"].replace("'", "''")
        desc_esc = g["desc"].replace("'", "''")

        sql.append(f"""
INSERT INTO public.posts (
    id, user_id, content, market_title, market_price,
    market_category, visibility, location_name, latitude, longitude,
    created_at, author_profile_type, post_type, share_scope, is_unclaimed
) VALUES (
    '{post_id}',
    '{author["id"]}',
    '{desc_esc}',
    '{title_esc}',
    {g["price"]},
    '{g["category"]}',
    'public',
    'Ris-Orangis (91130)',
    {author["lat"]},
    {author["lng"]},
    '{created}',
    'person',
    '{g["post_type"]}',
    'public',
    false
);""")

    # 5. Insert Realistic Comments on first 4 posts
    sample_comments = [
        (0, 1, "Superbe initiative ! J'y serai vers 10h avec mon vélo."),
        (0, 2, "Merci pour le partage, les photos donnent vraiment envie d'y faire un tour !"),
        (1, 0, "Merci beaucoup pour le rappel Thomas, c'est bien utile !"),
        (2, 3, "Génial l'idée du troc ! J'apporterai des graines de tomates anciennes."),
        (3, 4, "Je partage l'avis sur les réseaux du quartier, j'espère que vous le retrouverez vite !"),
        (3, 0, "Courage Sophie, je regarde bien dans mon jardin Rue Pierre Brossolette."),
    ]

    for p_idx, u_idx, text in sample_comments:
        if p_idx < len(post_ids):
            c_id = str(uuid.uuid4())
            p_id = post_ids[p_idx]
            u_id = RESIDENTS[u_idx]["id"]
            text_esc = text.replace("'", "''")
            sql.append(f"""
INSERT INTO public.post_comments (id, post_id, user_id, content, created_at)
VALUES ('{c_id}', '{p_id}', '{u_id}', '{text_esc}', now());
""")

    sql.append("COMMIT;")
    sql.append("NOTIFY pgrst, 'reload schema';")
    return "\n".join(sql)

if __name__ == "__main__":
    content = generate_sql()
    with open("scripts/seeding/seed_community_data_output.sql", "w", encoding="utf-8") as f:
        f.write(content)
    print("Generated scripts/seeding/seed_community_data_output.sql successfully.")
