# scripts/seeding/seed_restaurant_menus.py
# Generates SQL for menu items (posts with post_type = 'food') for Ris-Orangis restaurants.

import uuid

MENUS = [
    {
        "restaurant_id": "fad49d90-6440-44b7-9038-9aff7079c529", # Boulangerie du Moulin à Vent
        "lat": 48.6508, "lng": 2.4143,
        "items": [
            {
                "title": "Formule Déjeuner Sandwich + Boisson + Pâtisserie",
                "category": "sandwich_wrap",
                "price": 8.50,
                "content": "Pain tradition maison, poulet rôti ou jambon emmental, salade fraîche, tomate. Servi avec une boisson 33cl et une pâtisserie au choix."
            },
            {
                "title": "Tradition & Croissants Pur Beurre",
                "category": "dessert",
                "price": 1.30,
                "content": "Baguette tradition au levain naturel, croûte croustillante et mie alvéolée. Viennoiseries pur beurre faites sur place chaque matin."
            },
            {
                "title": "Éclair au Chocolat Grand Cru",
                "category": "dessert",
                "price": 3.20,
                "content": "Pâte à choux artisanale garnie d'une crème pâtissière onctueuse au chocolat noir Valrhona, glaçage brillant."
            }
        ]
    },
    {
        "restaurant_id": "64ba0731-bbb2-4096-a304-d045ca7bb5b4", # Pizzeria Bella Ris
        "lat": 48.6515, "lng": 2.4120,
        "items": [
            {
                "title": "Pizza Margherita DOP Tradition",
                "category": "pizza",
                "price": 11.50,
                "content": "Sauce tomate San Marzano, Mozzarella di bufala Campana, basilic frais, filet d'huile d'olive extra vierge. Pâte fermentée 48h."
            },
            {
                "title": "Pizza Regina Gourmande",
                "category": "pizza",
                "price": 13.50,
                "content": "Sauce tomate San Marzano, mozzarella fior di latte, jambon blanc supérieur, champignons de Paris frais émincés, origan."
            },
            {
                "title": "Tiramisu Maison au Café Illy",
                "category": "dessert",
                "price": 5.50,
                "content": "Recette traditionnelle italienne au mascarpone crémeux, biscuits cuillère imbibés au café expresso, cacao amer saupoudré."
            }
        ]
    },
    {
        "restaurant_id": "2b331627-9e59-472d-bfd6-f788b9d59f66", # Brasserie Le Ris-Orangis
        "lat": 48.6500, "lng": 2.4160,
        "items": [
            {
                "title": "Entrecôte Grillée 250g & Frites Maison",
                "category": "high_protein",
                "price": 16.90,
                "content": "Pièce de bœuf race limousine sélectionnée, frites fraîches maison découpées au couteau, salade verte et sauce poivre vert flambé."
            },
            {
                "title": "Burger Brasserie au Cheddar Affiné",
                "category": "burger",
                "price": 14.50,
                "content": "Steak haché de bœuf français façon bouchère 150g, oignons caramélisés, cheddar fondu 9 mois, sauce burger secrète, pain brioché artisanal."
            },
            {
                "title": "Café Gourmand de la Brasserie",
                "category": "dessert",
                "price": 6.80,
                "content": "Expresso servi avec 3 mignardises maison : mini mousse au chocolat, crème brûlée à la vanille bourbon et financier pistache."
            }
        ]
    },
    {
        "restaurant_id": "279473b9-6347-4f9f-b153-78cc00ca5f65", # Sushi Sakura Ris
        "lat": 48.6520, "lng": 2.4130,
        "items": [
            {
                "title": "Menu Sakura Mixte (18 pièces)",
                "category": "rice_bowl",
                "price": 15.90,
                "content": "6 California Saumon Avocat, 6 Maki Thon, 4 Sushi Saumon, 2 Sushi Thon. Servi avec soupe miso maison, salade de chou et riz vinaigré."
            },
            {
                "title": "Chirashi Saumon Avocat Mariné",
                "category": "rice_bowl",
                "price": 14.20,
                "content": "Tranches épaisses de saumon label rouge norvégien, avocat mûr, graines de sésame grillées sur bol de riz japonais vinaigré tiède."
            },
            {
                "title": "Brochettes Bœuf Fromage Yakitori (4 pcs)",
                "category": "starters",
                "price": 7.90,
                "content": "Tranches fines de bœuf enroulées autour d'emmental fondant, nappées de sauce yakitori sucrée-salée et grillées au charbon."
            }
        ]
    },
    {
        "restaurant_id": "003477d1-130d-4ef7-82e9-1efceaef73b5", # Le Kebab de la Gare
        "lat": 48.6535, "lng": 2.4105,
        "items": [
            {
                "title": "Menu Kebab Traditionnel Frites + Boisson",
                "category": "sandwich_wrap",
                "price": 8.90,
                "content": "Pain pita ou galette chaude, viande marinée broche artisanale, salade, tomate, oignon, sauce blanche maison et sauce samouraï. Frites dorées et boisson 33cl."
            },
            {
                "title": "Assiette Royale Mixte 3 Viandes",
                "category": "high_protein",
                "price": 13.50,
                "content": "Généreuse assiette avec viande kebab grillée, brochette kefta aux herbes et tenders croustillants. Servi avec blé concassé, frites et salade."
            },
            {
                "title": "French Tacos 2 Viandes Sauce Fromagère",
                "category": "sandwich_wrap",
                "price": 9.50,
                "content": "Galette garnie de tenders croustillants et viande hachée épicée, frites à l'intérieur, nappé de notre fameuse sauce fromagère maison gratinée."
            }
        ]
    },
    {
        "restaurant_id": "2d39df29-b383-4122-8fab-4fc58eda346f", # Aux Délices d'Essonne
        "lat": 48.6495, "lng": 2.4170,
        "items": [
            {
                "title": "Formule Pause Gourmande Sandwich + Boisson + Tartelette",
                "category": "sandwich_wrap",
                "price": 8.40,
                "content": "Baguette graines, thon mayonnaise maison et œuf dur fermier, crudités fraîches. Servi avec boisson fraîche et tartelette aux fraises ou citron meringuée."
            },
            {
                "title": "Millefeuille Caramélisé Croustillant",
                "category": "dessert",
                "price": 3.90,
                "content": "Trois couches de pâte feuilletée inversée caramélisée au sucre glace, garnies d'une crème diplomate vanille de Madagascar."
            },
            {
                "title": "Quiche Lorraine Fermière & Salade Verte",
                "category": "starters",
                "price": 6.20,
                "content": "Pâte brisée pur beurre, lardons fumés dorés, appareil crème et œufs frais fermiers, gratinée à l'emmental français."
            }
        ]
    },
    {
        "restaurant_id": "29d91c6a-f3cb-46e7-83cf-a2c7de1187b2", # Taj Mahal Express
        "lat": 48.6485, "lng": 2.4190,
        "items": [
            {
                "title": "Poulet Tikka Masala & Riz Basmati",
                "category": "indian",
                "price": 13.50,
                "content": "Morceaux de poulet marinés aux épices tandoori puis mijotés dans une sauce onctueuse à la tomate, crème et coriandre fraîche. Servi avec riz basmati."
            },
            {
                "title": "Cheese Naan Fait Main au Tandoor",
                "category": "starters",
                "price": 3.50,
                "content": "Pain traditionnel indien farci au fromage fondu, cuit à la minute sur les parois du four tandoor traditionnel en terre cuite."
            },
            {
                "title": "Biryani Royal à l'Agneau",
                "category": "indian",
                "price": 15.50,
                "content": "Agneau fondant mijoté avec du riz basmati parfumé au safran, cardamome, clou de girofle, amandes effilées et raisins secs."
            }
        ]
    },
    {
        "restaurant_id": "6b7d4824-ede3-4b2d-b831-cdbf3299cb5e", # Wok & Grill Ris
        "lat": 48.6540, "lng": 2.4150,
        "items": [
            {
                "title": "Wok Nouilles Sautées au Bœuf & Légumes",
                "category": "pasta",
                "price": 11.90,
                "content": "Nouilles de blé cuites au wok à feu vif avec émincé de bœuf mariné au soja, pousses de bambou, carottes, brocolis et oignons frais."
            },
            {
                "title": "Bo Bun Traditionnel Poulet & Nems Croustillants",
                "category": "rice_bowl",
                "price": 12.50,
                "content": "Vermicelles de riz tièdes, salade fraîche, menthe, concombre, soja, émincé de poulet à la citronnelle, 3 nems croustillants, cacahuètes pilées et sauce nuoc-mâm."
            },
            {
                "title": "Nems Croustillants au Porc (4 pièces)",
                "category": "starters",
                "price": 5.90,
                "content": "Rouleaux frits artisanaux farcis au porc, champignons noirs et vermicelles. Servis avec feuilles de salade croquante et menthe fraîche."
            }
        ]
    }
]

def generate_sql():
    lines = [
        "-- Allonssy Restaurant Menus Seeding: Ris-Orangis",
        "BEGIN;",
        ""
    ]
    
    total = 0
    for r in MENUS:
        rid = r["restaurant_id"]
        lat = r["lat"]
        lng = r["lng"]
        
        for item in r["items"]:
            total += 1
            item_id = str(uuid.uuid4())
            title = item["title"].replace("'", "''")
            content = item["content"].replace("'", "''")
            cat = item["category"]
            price = item["price"]
            
            lines.append(f"""
INSERT INTO public.posts (
  id, user_id, content, post_type, market_category, market_title,
  market_price, visibility, latitude, longitude, location_name
) VALUES (
  '{item_id}',
  '{rid}',
  '{content}',
  'food_ad',
  '{cat}',
  '{title}',
  {price},
  'public',
  {lat},
  {lng},
  'Ris-Orangis (91130)'
);
""")

    lines.append("COMMIT;")
    lines.append("NOTIFY pgrst, 'reload schema';")
    return "\n".join(lines), total

if __name__ == "__main__":
    sql, count = generate_sql()
    out_path = "scripts/seeding/seed_restaurant_menus_output.sql"
    with open(out_path, "w", encoding="utf-8") as f:
        f.write(sql)
    print(f"Generated {count} restaurant menu dishes into {out_path}")
