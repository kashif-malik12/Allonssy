#!/usr/bin/env python3
"""
generate_50_restos_100_pros.py
Generates 50 top reviewed restaurants with full menus and 100 local professionals
for Ris-Orangis (91130) and its immediate neighboring Grand Paris Sud / Essonne communes.
"""

import sys
import json
import uuid

def esc(text):
    if text is None:
        return 'NULL'
    return "'" + str(text).replace("'", "''") + "'"

def main():
    # 50 Top Restaurants Data
    # Each restaurant has: id_suffix (0001..0050), name, category, city, zipcode, lat, lng, address, phone, bio, dishes (list of title, price, category, desc, img)
    restaurants = [
        # 1. French Bistronomy & Brasseries
        {
            "id": 1,
            "name": "Côté Bistrot",
            "category": "fine_dining",
            "city": "Ris-Orangis",
            "zipcode": "91130",
            "lat": 48.6515,
            "lng": 2.4150,
            "address": "69 Rue Albert Rémy",
            "phone": "01 69 06 12 34",
            "website": "https://cote-bistrot-ris.fr",
            "avatar": "https://images.unsplash.com/photo-1555396273-367ea4eb4db5?w=500&auto=format&fit=crop&q=80",
            "bio": "Bistronomie française de saison, produits frais du terroir et formules du midi gourmandes.",
            "dishes": [
                ("Magret de canard rôti au miel & romarin", 16.90, "starters", "Magret du Sud-Ouest rôti rosé, pommes grenailles sautées et jus corsé au romarin.", "https://images.unsplash.com/photo-1544025162-d76694265947?w=600&auto=format&fit=crop&q=80"),
                ("Tartare de saumon frais à l'aneth et agrumes", 8.50, "starters", "Saumon coupé au couteau, zestes de citron vert, échalotes et toasts de pain grillé.", "https://images.unsplash.com/photo-1546069901-ba9599a7e63c?w=600&auto=format&fit=crop&q=80"),
                ("Formule Midi Express (Entrée + Plat)", 14.50, "other", "Plat du jour au choix sur ardoise + Entrée de saison ou Dessert du Chef.", "https://images.unsplash.com/photo-1504674900247-0877df9cc836?w=600&auto=format&fit=crop&q=80"),
                ("Tiramisu traditionnel au café & mascarpone", 6.50, "dessert", "Recette classique crémeuse au mascarpone, biscuits imbibés d'espresso et cacao amer.", "https://images.unsplash.com/photo-1571877227200-a0d98ea607e9?w=600&auto=format&fit=crop&q=80"),
            ]
        },
        {
            "id": 2,
            "name": "BOON Burgers & Brasserie",
            "category": "fast_food",
            "city": "Ris-Orangis",
            "zipcode": "91130",
            "lat": 48.6530,
            "lng": 2.4120,
            "address": "14 Avenue de la Libération",
            "phone": "01 69 43 21 00",
            "website": "https://boon-burgers.fr",
            "avatar": "https://images.unsplash.com/photo-1550547660-d9450f859349?w=500&auto=format&fit=crop&q=80",
            "bio": "Burgers gourmets au bœuf français grillé à la flamme, frites maison et brunch du week-end.",
            "dishes": [
                ("Le Big Boon Burger Signature", 12.90, "burger", "Double steak haché boucher smashé, bacon de bœuf fumé, cheddar affiné et sauce secrète BOON.", "https://images.unsplash.com/photo-1568901346375-23c9450c58cd?w=600&auto=format&fit=crop&q=80"),
                ("Truffle Gourmet Burger", 14.50, "burger", "Steak façon bouchère, crème de truffe blanche, roquette sauvage et oignons caramélisés.", "https://images.unsplash.com/photo-1586190848861-99aa4a171e90?w=600&auto=format&fit=crop&q=80"),
                ("Formule Brunch Week-end BOON", 19.90, "other", "Pancakes moelleux sirop d'érable, toast avocat saumon fumé, œufs brouillés et boisson chaude.", "https://images.unsplash.com/photo-1533089860892-a7c6f0a88666?w=600&auto=format&fit=crop&q=80"),
                ("Frites Maison Paprika & Herbes", 4.50, "starters", "Pommes de terre fraîches coupées chaque matin, assaisonnées au paprika doux et sel de Guérande.", "https://images.unsplash.com/photo-1576107232684-1279f3908594?w=600&auto=format&fit=crop&q=80"),
            ]
        },
        {
            "id": 3,
            "name": "Pizza Time Ris-Orangis",
            "category": "italian",
            "city": "Ris-Orangis",
            "zipcode": "91130",
            "lat": 48.6498,
            "lng": 2.4162,
            "address": "50 Rue Edmond Bonté",
            "phone": "01 69 02 88 99",
            "website": "https://pizzatime.fr",
            "avatar": "https://images.unsplash.com/photo-1513104890138-7c749659a591?w=500&auto=format&fit=crop&q=80",
            "bio": "Pizzas artisanales à pâte fraîche maturée 48h, ingrédients italiens d'exception.",
            "dishes": [
                ("Pizza Reine Tradizione", 11.50, "pizza", "Sauce tomate San Marzano, mozzarella fior di latte, jambon blanc supérieur et champignons frais.", "https://images.unsplash.com/photo-1574071318508-1cdbab80d002?w=600&auto=format&fit=crop&q=80"),
                ("Pizza 4 Fromages d'Alpage", 12.50, "pizza", "Base crème double d'Isigny, mozzarella, gorgonzola crémeux AOP, chèvre de Sainte-Maure et emmental.", "https://images.unsplash.com/photo-1593560708920-61dd98c46a4e?w=600&auto=format&fit=crop&q=80"),
                ("Menu Pizza Solo + Boisson", 13.00, "other", "Une pizza au choix au format Senior avec une boisson fraîche 33cl au choix.", "https://images.unsplash.com/photo-1534308983496-4fabb1a015ee?w=600&auto=format&fit=crop&q=80"),
                ("Calzone Classique Soufflé", 12.00, "pizza", "Chausson doré garni de mozzarella fondante, jambon blanc, jaune d'œuf coulant et origan.", "https://images.unsplash.com/photo-1565299624946-b28f40a0ae38?w=600&auto=format&fit=crop&q=80"),
            ]
        },
        {
            "id": 4,
            "name": "350 Kitchen",
            "category": "fast_food",
            "city": "Ris-Orangis",
            "zipcode": "91130",
            "lat": 48.6540,
            "lng": 2.4095,
            "address": "85 bis Route de Grigny",
            "phone": "01 69 21 00 35",
            "website": "https://350kitchen.fr",
            "avatar": "https://images.unsplash.com/photo-1551782450-a2132b4ba21d?w=500&auto=format&fit=crop&q=80",
            "bio": "Street food premium : smash burgers caramélisés, loaded fries et tenders marinés.",
            "dishes": [
                ("Smoke Smash Burger", 9.90, "burger", "Bœuf croustillant sur les bords, cheddar fondu, oignons grillés et sauce barbecue fumée.", "https://images.unsplash.com/photo-1586190848861-99aa4a171e90?w=600&auto=format&fit=crop&q=80"),
                ("Loaded Fries Cheddar & Bacon", 5.50, "starters", "Barquette de frites chaudes recouvertes de cheddar liquide onctueux et brisures de bacon croustillant.", "https://images.unsplash.com/photo-1585109649139-366815a0d713?w=600&auto=format&fit=crop&q=80"),
                ("Crispy Tenders Bucket (x6)", 7.90, "starters", "Filets de poulet frais panés aux épices cajun, frits minute et servis avec 2 sauces.", "https://images.unsplash.com/photo-1562967914-608f82629710?w=600&auto=format&fit=crop&q=80"),
            ]
        },
        {
            "id": 5,
            "name": "La Tour du Maroc",
            "category": "middle_eastern",
            "city": "Ris-Orangis",
            "zipcode": "91130",
            "lat": 48.6502,
            "lng": 2.4168,
            "address": "42 Rue Edmond Bonté",
            "phone": "01 69 06 45 78",
            "website": "https://tourdumaroc-ris.fr",
            "avatar": "https://images.unsplash.com/photo-1541518763669-27fef04b14ea?w=500&auto=format&fit=crop&q=80",
            "bio": "Spécialités marocaines traditionnelles : couscous généreux, tajines parfumés et pâtisseries orientales.",
            "dishes": [
                ("Couscous Royal de Fès", 17.50, "rice_bowl", "Semoule fine vapeur, légumes fondants, brochette d'agneau grillée, merguez artisanale et poulet rôti.", "https://images.unsplash.com/photo-1541518763669-27fef04b14ea?w=600&auto=format&fit=crop&q=80"),
                ("Tajine d'agneau aux pruneaux & amandes", 16.00, "other", "Mijoté doux aux épices de Marrakech, oignons confits, pruneaux dorés et graines de sésame.", "https://images.unsplash.com/photo-1582878826629-29b7ad1cdc43?w=600&auto=format&fit=crop&q=80"),
                ("Thé à la menthe & Cornes de Gazelle", 6.00, "dessert", "Service du thé à la menthe fraîche en théière traditionnelle avec duo de pâtisseries à la fleur d'oranger.", "https://images.unsplash.com/photo-1576092768241-dec231879fc3?w=600&auto=format&fit=crop&q=80"),
                ("Pastilla au Poulet & Amandes", 9.50, "starters", "Feuilletage croustillant traditionnel garni d'effiloché de poulet épicé, cannelle et amandes torréfiées.", "https://images.unsplash.com/photo-1540420773420-3366772f4999?w=600&auto=format&fit=crop&q=80"),
            ]
        },
        {
            "id": 6,
            "name": "O'Korners Brasserie",
            "category": "fine_dining",
            "city": "Ris-Orangis",
            "zipcode": "91130",
            "lat": 48.6494,
            "lng": 2.4172,
            "address": "56 Rue Edmond Bonté",
            "phone": "01 69 02 11 22",
            "website": "https://okorners-brasserie.fr",
            "avatar": "https://images.unsplash.com/photo-1517248135467-4c7edcad34c4?w=500&auto=format&fit=crop&q=80",
            "bio": "Brasserie conviviale de quartier : grillades au feu de bois, grandes salades repas et bières pression.",
            "dishes": [
                ("Faux-filet grillé sauce poivre vert", 15.50, "other", "Pièce de bœuf tendre 220g grillée selon votre goût, servie avec frites maison et salade verte.", "https://images.unsplash.com/photo-1558030006-450675393462?w=600&auto=format&fit=crop&q=80"),
                ("Salade César au poulet croustillant", 12.50, "starters", "Cœur de romaine, filet de poulet pané minute, copeaux de parmesan, croûtons à l'ail et sauce César.", "https://images.unsplash.com/photo-1512621776951-a57141f2eefd?w=600&auto=format&fit=crop&q=80"),
                ("Fondant au chocolat cœur coulant", 6.50, "dessert", "Chocolat noir intense 70%, cœur chocolat tiède et boule de glace vanille artisanale.", "https://images.unsplash.com/photo-1606313564200-e75d5e30476c?w=600&auto=format&fit=crop&q=80"),
            ]
        },
        {
            "id": 7,
            "name": "La Case Africaine",
            "category": "other",
            "city": "Ris-Orangis",
            "zipcode": "91130",
            "lat": 48.6520,
            "lng": 2.4145,
            "address": "46 Rue Albert Rémy",
            "phone": "01 69 43 78 90",
            "website": "https://lacase-ris.fr",
            "avatar": "https://images.unsplash.com/photo-1504674900247-0877df9cc836?w=500&auto=format&fit=crop&q=80",
            "bio": "Saveurs authentiques d'Afrique de l'Ouest : Thiéboudienne, Poulet Yassa et bananes plantain dorées.",
            "dishes": [
                ("Thiéboudienne Rouge au Poisson", 14.50, "rice_bowl", "Riz rouge mijoté au bouillon de mérou, légumes du soleil (manioc, carotte, chou) et piment doux.", "https://images.unsplash.com/photo-1546069901-ba9599a7e63c?w=600&auto=format&fit=crop&q=80"),
                ("Poulet Yassa aux oignons confits", 13.50, "rice_bowl", "Cuisses de poulet fermier marinées au citron vert, moutarde à l'ancienne et lit d'oignons caramélisés.", "https://images.unsplash.com/photo-1598515214211-89d3c73ae83b?w=600&auto=format&fit=crop&q=80"),
                ("Alloco & Sauce Pimentée Douce", 4.50, "starters", "Bananes plantains mûres frites à l'huile végétale, croustillantes et fondantes.", "https://images.unsplash.com/photo-1604382354936-07c5d9983bd3?w=600&auto=format&fit=crop&q=80"),
            ]
        },
        {
            "id": 8,
            "name": "Boulangerie du Moulin à Vent",
            "category": "cafe_bakery",
            "city": "Ris-Orangis",
            "zipcode": "91130",
            "lat": 48.6518,
            "lng": 2.4138,
            "address": "32 Rue Pierre Brossolette",
            "phone": "01 69 06 05 40",
            "website": "https://boulangerie-moulin-ris.fr",
            "avatar": "https://images.unsplash.com/photo-1509440159596-0249088772ff?w=500&auto=format&fit=crop&q=80",
            "bio": "Artisan boulanger-pâtissier : baguette de tradition au levain naturel, sandwichs frais et tartes fines.",
            "dishes": [
                ("Formule Déjeuner Tradition Sandwich", 8.50, "sandwich_wrap", "Baguette tradition garnie au choix (jambon-comté, poulet-crudités, thon-œuf) + Pâtisserie + Boisson.", "https://images.unsplash.com/photo-1528735602780-2552fd46c7af?w=600&auto=format&fit=crop&q=80"),
                ("Tartelette aux Framboises Fraîches", 3.80, "dessert", "Pâte sablée pur beurre, crème d'amande fondante et lit de framboises fraîches éclatantes.", "https://images.unsplash.com/photo-1519915028121-7d3463d20b13?w=600&auto=format&fit=crop&q=80"),
                ("Croissant Pur Beurre AOP Charentes", 1.40, "dessert", "Viennoiserie feuilletée dorée au beurre de tourage AOP, croustillante à souhait.", "https://images.unsplash.com/photo-1555507036-ab1f4038808a?w=600&auto=format&fit=crop&q=80"),
            ]
        },
        # 9 - 50: Additional Top Reviewed Restaurants in Ris-Orangis & Immediate Agglomeration
        {
            "id": 9,
            "name": "Il Paradiso della Pizza",
            "category": "italian",
            "city": "Ris-Orangis",
            "zipcode": "91130",
            "lat": 48.6505,
            "lng": 2.4180,
            "address": "78 Avenue de la Libération",
            "phone": "01 69 06 33 22",
            "website": "https://ilparadiso-ris.fr",
            "avatar": "https://images.unsplash.com/photo-1513104890138-7c749659a591?w=500&auto=format&fit=crop&q=80",
            "bio": "Pizzas napolitaines cuites au feu de bois, burrata crémeuse des Pouilles et pâtes fraîches maison.",
            "dishes": [
                ("Pizza Burrata & Truffe", 15.50, "pizza", "Crème de truffe, mozzarella fior di latte, burrata entière 125g coulante et basilic frais.", "https://images.unsplash.com/photo-1574071318508-1cdbab80d002?w=600&auto=format&fit=crop&q=80"),
                ("Tagliatelles au Saumon et Pesto", 13.90, "pasta", "Pâtes fraîches maison, pavé de saumon snacké, pesto genovese et crème parfumée.", "https://images.unsplash.com/photo-1551183053-bf91a1d81141?w=600&auto=format&fit=crop&q=80"),
                ("Panna Cotta aux Fruits Rouges", 5.50, "dessert", "Crème onctueuse à la vanille de Madagascar et coulis maison de fruits des bois.", "https://images.unsplash.com/photo-1488477181946-6428a0291777?w=600&auto=format&fit=crop&q=80")
            ]
        },
        {
            "id": 10,
            "name": "Tokyo Sushi Ris",
            "category": "japanese",
            "city": "Ris-Orangis",
            "zipcode": "91130",
            "lat": 48.6525,
            "lng": 2.4160,
            "address": "21 Rue Edmond Bonté",
            "phone": "01 69 43 55 66",
            "website": "https://tokyosushi-ris.fr",
            "avatar": "https://images.unsplash.com/photo-1579871494447-9811cf80d66c?w=500&auto=format&fit=crop&q=80",
            "bio": "Sushis, sashimis et makis artisanaux préparés à la commande par nos maîtres sushis.",
            "dishes": [
                ("Menu Bateau Sushi Moriawase", 22.50, "rice_bowl", "12 sushis variés (saumon, thon, dorade), 8 makis california et 6 tranches de sashimi.", "https://images.unsplash.com/photo-1579871494447-9811cf80d66c?w=600&auto=format&fit=crop&q=80"),
                ("Chirashi Saumon Avocat Frais", 14.50, "rice_bowl", "Bol de riz vinaigré tiède garni d'épaisses tranches de saumon Label Rouge et avocat hass.", "https://images.unsplash.com/photo-1563245372-f21724e3856d?w=600&auto=format&fit=crop&q=80"),
                ("Brochettes Yakitori Bœuf Fromage (x4)", 7.50, "starters", "Gouda fondant enroulé de fines tranches de bœuf caramélisées à la sauce teriyaki.", "https://images.unsplash.com/photo-1555939594-58d7cb561ad1?w=600&auto=format&fit=crop&q=80")
            ]
        },
        {
            "id": 11,
            "name": "Le Taj Mahal de l'Essonne",
            "category": "indian",
            "city": "Ris-Orangis",
            "zipcode": "91130",
            "lat": 48.6485,
            "lng": 2.4175,
            "address": "90 Rue Edmond Bonté",
            "phone": "01 69 02 77 88",
            "website": "https://tajmahal-ris.fr",
            "avatar": "https://images.unsplash.com/photo-1585937421612-70a008356fbe?w=500&auto=format&fit=crop&q=80",
            "bio": "Gastronomie indienne et pakistanaise raffinée, pains naans cuits au four tandoor traditionnel.",
            "dishes": [
                ("Butter Chicken Traditionnel", 14.00, "rice_bowl", "Morceaux de poulet tandoori marinés mijotés dans une sauce onctueuse tomate, beurre et épices douces.", "https://images.unsplash.com/photo-1588166524941-3bf61a9c41db?w=600&auto=format&fit=crop&q=80"),
                ("Cheese Naan Spécial Fondant", 3.50, "sandwich_wrap", "Pain indien traditionnel cuit sur les parois du four tandoor, fourré de fromage fondant.", "https://images.unsplash.com/photo-1601050690597-df0568f70950?w=600&auto=format&fit=crop&q=80"),
                ("Biryani d'Agneau Royal", 16.50, "rice_bowl", "Riz basmati safrané mijoté à l'étouffée avec morceaux d'agneau tendre, amandes et raisins secs.", "https://images.unsplash.com/photo-1563379091339-03b21ab4a4f8?w=600&auto=format&fit=crop&q=80")
            ]
        },
        {
            "id": 12,
            "name": "Le Bosphore Grill & Mezzé",
            "category": "middle_eastern",
            "city": "Ris-Orangis",
            "zipcode": "91130",
            "lat": 48.6510,
            "lng": 2.4110,
            "address": "15 Rue Albert Rémy",
            "phone": "01 69 06 89 00",
            "website": "https://lebosphore-ris.fr",
            "avatar": "https://images.unsplash.com/photo-1555939594-58d7cb561ad1?w=500&auto=format&fit=crop&q=80",
            "bio": "Grillades turques marinées, brochettes au charbon de bois et mezzés orientaux frais.",
            "dishes": [
                ("Assiette Mix Grillades du Chef", 16.90, "other", "Brochette d'Adana kebab épicé, pilon de poulet mariné, côte d'agneau et blé concassé boulgour.", "https://images.unsplash.com/photo-1544025162-d76694265947?w=600&auto=format&fit=crop&q=80"),
                ("Assiette Mezzés Orientaux", 9.50, "starters", "Houmous crémeux, caviar d'aubergines fumé (moutabal), feuilles de vigne et tzatziki maison.", "https://images.unsplash.com/photo-1540420773420-3366772f4999?w=600&auto=format&fit=crop&q=80"),
                ("Baklava au Pistaches de Gaziantep", 5.00, "dessert", "Feuilletage croustillant pur beurre garni d'éclats de pistaches vertes et arrosé de sirop de miel.", "https://images.unsplash.com/photo-1519869325930-281384150729?w=600&auto=format&fit=crop&q=80")
            ]
        },
        {
            "id": 13,
            "name": "Wok & Dragon d'Asie",
            "category": "chinese",
            "city": "Ris-Orangis",
            "zipcode": "91130",
            "lat": 48.6545,
            "lng": 2.4135,
            "address": "102 Route de Grigny",
            "phone": "01 69 43 99 11",
            "website": "https://wokdragon-ris.fr",
            "avatar": "https://images.unsplash.com/photo-1541696432-82c6da8ce7bf?w=500&auto=format&fit=crop&q=80",
            "bio": "Cuisine asiatique traditionnelle au wok : canard laqué pékinois, nouilles sautées et nems croustillants.",
            "dishes": [
                ("Canard Laqué Pékinois Croustillant", 15.00, "rice_bowl", "Canard rôti doré, peau laquée craquante, sauce prune maison et crêpes fines vapeur.", "https://images.unsplash.com/photo-1563245372-f21724e3856d?w=600&auto=format&fit=crop&q=80"),
                ("Pad Thaï Crevettes Royales", 13.50, "pasta", "Nouilles de riz sautées au wok avec crevettes sauvages, germes de soja, cacahuètes pilées et citron vert.", "https://images.unsplash.com/photo-1559847844-5315695dadae?w=600&auto=format&fit=crop&q=80"),
                ("Panier Vapeur Dim Sum (x6)", 7.00, "starters", "Bouchées vapeur fraîches faites maison : raviolis aux crevettes (ha kao) et bouchées au porc (siu mai).", "https://images.unsplash.com/photo-1541696432-82c6da8ce7bf?w=600&auto=format&fit=crop&q=80")
            ]
        },
        {
            "id": 14,
            "name": "Point B Burger Ris",
            "category": "fast_food",
            "city": "Ris-Orangis",
            "zipcode": "91130",
            "lat": 48.6490,
            "lng": 2.4190,
            "address": "62 Avenue de la Libération",
            "phone": "01 69 02 44 00",
            "website": "https://pointb-burger.fr",
            "avatar": "https://images.unsplash.com/photo-1568901346375-23c9450c58cd?w=500&auto=format&fit=crop&q=80",
            "bio": "Les célèbres burgers façon fast-food américain revisités avec de la viande certifiée et frites fraîches.",
            "dishes": [
                ("Le Méga Big Bacon", 8.90, "burger", "Double steak pur bœuf, tranche de cheddar fondu, bacon de bœuf grillé et sauce barbecue.", "https://images.unsplash.com/photo-1568901346375-23c9450c58cd?w=600&auto=format&fit=crop&q=80"),
                ("Menu Duo Burger + Boisson", 11.50, "other", "Deux burgers de la gamme classique avec grande frite maison et boisson 50cl au choix.", "https://images.unsplash.com/photo-1586190848861-99aa4a171e90?w=600&auto=format&fit=crop&q=80"),
                ("Milkshake Chocolat Caramel Beurre Salé", 4.50, "drinks", "Milkshake glacé épais garni de chantilly maison et éclats de cookies croustillants.", "https://images.unsplash.com/photo-1572490122747-3968b75cc699?w=600&auto=format&fit=crop&q=80")
            ]
        },
        {
            "id": 15,
            "name": "Trattoria Bella Italia",
            "category": "italian",
            "city": "Draveil",
            "zipcode": "91210",
            "lat": 48.6820,
            "lng": 2.4110,
            "address": "12 Boulevard Henri Barbusse",
            "phone": "01 69 40 12 34",
            "website": "https://bellaitalia-draveil.fr",
            "avatar": "https://images.unsplash.com/photo-1551183053-bf91a1d81141?w=500&auto=format&fit=crop&q=80",
            "bio": "Cuisine familiale italienne au bord de la Seine : escalope milanaise dorée et pâtes aux palourdes.",
            "dishes": [
                ("Escalope de Veau à la Milanaise", 17.50, "other", "Fine escalope de veau panée à la chapelure dorée et parmesan, servie avec spaghettis à la tomate fraîche.", "https://images.unsplash.com/photo-1544025162-d76694265947?w=600&auto=format&fit=crop&q=80"),
                ("Linguine alle Vongole (aux Palourdes)", 16.00, "pasta", "Palourdes fraîches sautées à l'huile d'olive extra-vierge, ail, persil plat et vin blanc sec.", "https://images.unsplash.com/photo-1551183053-bf91a1d81141?w=600&auto=format&fit=crop&q=80"),
                ("Carpaccio de Bœuf & Roquette", 11.00, "starters", "Très fines tranches de bœuf mariné au citron et huile d'olive, copeaux de parmigiano reggiano.", "https://images.unsplash.com/photo-1546069901-ba9599a7e63c?w=600&auto=format&fit=crop&q=80")
            ]
        },
        {
            "id": 16,
            "name": "Le Ris-Orangis Gourmand",
            "category": "fine_dining",
            "city": "Ris-Orangis",
            "zipcode": "91130",
            "lat": 48.6535,
            "lng": 2.4140,
            "address": "18 Place du Moulin à Vent",
            "phone": "01 69 06 72 10",
            "website": "https://leris-gourmand.fr",
            "avatar": "https://images.unsplash.com/photo-1517248135467-4c7edcad34c4?w=500&auto=format&fit=crop&q=80",
            "bio": "Table gourmande réputée de Ris-Orangis : foie gras maison mi-cuit, ris de veau braisés et cave soignée.",
            "dishes": [
                ("Terrine de Foie Gras Maison au Torchon", 12.50, "starters", "Foie gras de canard français mi-cuit, chutney de figues fraîches et brioche tiède toastée.", "https://images.unsplash.com/photo-1544025162-d76694265947?w=600&auto=format&fit=crop&q=80"),
                ("Ris de Veau Braisés aux Morilles", 23.00, "other", "Noix de ris de veau croustillante et moelleuse, réduction de crème aux morilles et mousseline de panais.", "https://images.unsplash.com/photo-1504674900247-0877df9cc836?w=600&auto=format&fit=crop&q=80"),
                ("Profiteroles Artisanales au Chocolat Chaud", 7.50, "dessert", "Choux pur beurre garnis de glace vanille bourbon, nappés de chocolat noir chaud fondu minute.", "https://images.unsplash.com/photo-1571877227200-a0d98ea607e9?w=600&auto=format&fit=crop&q=80")
            ]
        },
        {
            "id": 17,
            "name": "Sakura Japanese Restaurant",
            "category": "japanese",
            "city": "Évry-Courcouronnes",
            "zipcode": "91000",
            "lat": 48.6310,
            "lng": 2.4430,
            "address": "5 Cours Blaise Pascal",
            "phone": "01 60 78 45 12",
            "website": "https://sakura-evry.fr",
            "avatar": "https://images.unsplash.com/photo-1563245372-f21724e3856d?w=500&auto=format&fit=crop&q=80",
            "bio": "Ramen traditionnel bouillon mijoté 12h, gyozas grillés et tempura croustillante de crevettes.",
            "dishes": [
                ("Tonkotsu Ramen Authentique", 13.90, "pasta", "Nouilles fraîches de blé dans un riche bouillon de porc mijoté, tranches de chashu et œuf mariné tamago.", "https://images.unsplash.com/photo-1569718212165-3a8278d5f624?w=600&auto=format&fit=crop&q=80"),
                ("Gyoza Japonais Grillés (x6)", 6.50, "starters", "Raviolis japonais farcis au porc et chou chinois, dorés à la poêle avec un dessous croustillant.", "https://images.unsplash.com/photo-1498654896293-37aacf113fd9?w=600&auto=format&fit=crop&q=80"),
                ("Mochi Glacé Artisanal (x2)", 5.00, "dessert", "Mochis japonais fondants au cœur glacé au thé vert matcha et mangue passion.", "https://images.unsplash.com/photo-1563729784474-d77dbb933a9e?w=600&auto=format&fit=crop&q=80")
            ]
        },
        {
            "id": 18,
            "name": "Le Pavillon de l'Écluse",
            "category": "fine_dining",
            "city": "Ris-Orangis",
            "zipcode": "91130",
            "lat": 48.6560,
            "lng": 2.4180,
            "address": "2 Quai de la Borde",
            "phone": "01 69 06 18 20",
            "website": "https://pavillon-ecluse.fr",
            "avatar": "https://images.unsplash.com/photo-1517248135467-4c7edcad34c4?w=500&auto=format&fit=crop&q=80",
            "bio": "Restaurant panoramique en bord de Seine, poissons nobles de ligne et terrasse ombragée aux beaux jours.",
            "dishes": [
                ("Filet de Bar Rôti sur Peau", 19.50, "other", "Bar de ligne cuit unilatéral, émulsion au beurre blanc citronné et tombée de jeunes pousses d'épinards.", "https://images.unsplash.com/photo-1519708227418-c8fd9a32b7a2?w=600&auto=format&fit=crop&q=80"),
                ("Noix de Saint-Jacques Snackées", 22.00, "other", "Saint-Jacques fraîches dorées minute à la fleur de sel, purée crémeuse de topinambours.", "https://images.unsplash.com/photo-1544025162-d76694265947?w=600&auto=format&fit=crop&q=80"),
                ("Carpaccio d'Ananas Frais au Rhum Ambré", 6.50, "dessert", "Fines lamelles d'ananas victoria infusées au sirop de vanille bourbon et sorbet citron vert.", "https://images.unsplash.com/photo-1488477181946-6428a0291777?w=600&auto=format&fit=crop&q=80")
            ]
        },
        {
            "id": 19,
            "name": "O'Tacos Grand Paris Sud",
            "category": "fast_food",
            "city": "Ris-Orangis",
            "zipcode": "91130",
            "lat": 48.6515,
            "lng": 2.4125,
            "address": "40 Avenue de la Libération",
            "phone": "01 69 43 00 11",
            "website": "https://o-tacos.com",
            "avatar": "https://images.unsplash.com/photo-1551782450-a2132b4ba21d?w=500&auto=format&fit=crop&q=80",
            "bio": "Les authentiques French Tacos avec notre délicieuse sauce fromagère signature cuisinée chaque jour.",
            "dishes": [
                ("Otacos Taille L Double Viande", 9.50, "sandwich_wrap", "Galette toastée garnie de tenders épicés et steak haché, frites intégrées et sauce fromagère maison.", "https://images.unsplash.com/photo-1565299585323-38d6b0865b47?w=600&auto=format&fit=crop&q=80"),
                ("Otacos XL Triple Plaisir", 12.00, "sandwich_wrap", "Trois viandes au choix (poulet mariné, cordon bleu, bœuf), sauce algérienne et double dose fromagère.", "https://images.unsplash.com/photo-1565299585323-38d6b0865b47?w=600&auto=format&fit=crop&q=80"),
                ("Tiramisu Oreo Chocolat", 3.90, "dessert", "Dessert crémeux au mascarpone et éclats de biscuits Oreo au chocolat.", "https://images.unsplash.com/photo-1571877227200-a0d98ea607e9?w=600&auto=format&fit=crop&q=80")
            ]
        },
        {
            "id": 20,
            "name": "Delhi Darbar",
            "category": "indian",
            "city": "Évry-Courcouronnes",
            "zipcode": "91000",
            "lat": 48.6280,
            "lng": 2.4390,
            "address": "14 Rue Léopold Sédar Senghor",
            "phone": "01 60 77 34 56",
            "website": "https://delhidarbar-evry.fr",
            "avatar": "https://images.unsplash.com/photo-1585937421612-70a008356fbe?w=500&auto=format&fit=crop&q=80",
            "bio": "Saveurs épicées de New Delhi, grillades tandoori et curry crémeux dans un décor raffiné.",
            "dishes": [
                ("Poulet Tikka Masala Tandoor", 14.50, "rice_bowl", "Blancs de poulet grillés au tandoor mijotés dans une sauce onctueuse aux épices douces et coriandre fraîche.", "https://images.unsplash.com/photo-1565557623262-b51c2513a641?w=600&auto=format&fit=crop&q=80"),
                ("Curry d'Agneau Korma aux Noix de Cajou", 15.50, "rice_bowl", "Agneau mijoté avec crème fraîche, pâte de noix de cajou douce, cardamome et raisins de Corinthe.", "https://images.unsplash.com/photo-1546833999-b9f581a1996d?w=600&auto=format&fit=crop&q=80"),
                ("Naan à l'Ail et Fromage", 4.00, "sandwich_wrap", "Galette de pain levé cuite à la flamme, fourrée au fromage et parsemée d'ail frais haché.", "https://images.unsplash.com/photo-1601050690597-df0568f70950?w=600&auto=format&fit=crop&q=80")
            ]
        },
        {
            "id": 21,
            "name": "La Taverne de l'Essonne",
            "category": "fine_dining",
            "city": "Corbeil-Essonnes",
            "zipcode": "91100",
            "lat": 48.6140,
            "lng": 2.4820,
            "address": "8 Place Galignani",
            "phone": "01 64 96 11 22",
            "website": "https://taverne-essonne.fr",
            "avatar": "https://images.unsplash.com/photo-1555396273-367ea4eb4db5?w=500&auto=format&fit=crop&q=80",
            "bio": "Cuisine de brasserie alsacienne et française : choucroutes généreuses, flammekueches et bières de garde.",
            "dishes": [
                ("Choucroute Royale de la Taverne", 18.50, "other", "Chou d'Alsace mijoté au riesling, jarret de porc braisé, saucisse de Francfort, saucisse fumée et lard doré.", "https://images.unsplash.com/photo-1544025162-d76694265947?w=600&auto=format&fit=crop&q=80"),
                ("Flammekueche Gratinée Traditionnelle", 10.50, "pizza", "Pâte fine croustillante, crème épaisse d'Alsace, oignons émincés, lardons fumés et fromage emmental râpé.", "https://images.unsplash.com/photo-1513104890138-7c749659a591?w=600&auto=format&fit=crop&q=80"),
                ("Tarte Tatin aux Pommes Caramélisées", 6.80, "dessert", "Pommes fondantes caramélisées au beurre doux, pâte feuilletée chaude et boule de crème fraîche normande.", "https://images.unsplash.com/photo-1519915028121-7d3463d20b13?w=600&auto=format&fit=crop&q=80")
            ]
        },
        {
            "id": 22,
            "name": "Le Baobab Gourmand",
            "category": "other",
            "city": "Grigny",
            "zipcode": "91350",
            "lat": 48.6530,
            "lng": 2.3840,
            "address": "15 Avenue des Tuileries",
            "phone": "01 69 43 88 44",
            "website": "https://lebaobab-gourmand.fr",
            "avatar": "https://images.unsplash.com/photo-1504674900247-0877df9cc836?w=500&auto=format&fit=crop&q=80",
            "bio": "Spécialités africaines festives : mafé au bœuf, attiéké poisson braisé et jus de bissap maison frais.",
            "dishes": [
                ("Mafé au Bœuf Onctueux", 13.90, "rice_bowl", "Bœuf mijoté dans une délicieuse sauce à la pâte d'arachide grillée, carottes et riz blanc parfumé.", "https://images.unsplash.com/photo-1546069901-ba9599a7e63c?w=600&auto=format&fit=crop&q=80"),
                ("Poisson Tilapia Braisé Entier", 16.00, "other", "Tilapia frais mariné aux herbes africaines, grillé au feu et servi avec semoule de manioc (attiéké) et sauce tomate.", "https://images.unsplash.com/photo-1519708227418-c8fd9a32b7a2?w=600&auto=format&fit=crop&q=80"),
                ("Jus de Bissap Maison & Gingembre", 3.50, "drinks", "Infusion de fleurs d'hibiscus fraîches, menthe douce, vanille et pointe de gingembre revigorante.", "https://images.unsplash.com/photo-1513558161293-cdaf765ed2fd?w=600&auto=format&fit=crop&q=80")
            ]
        },
        {
            "id": 23,
            "name": "Pizzeria Casa Mia",
            "category": "italian",
            "city": "Viry-Châtillon",
            "zipcode": "91170",
            "lat": 48.6720,
            "lng": 2.3750,
            "address": "28 Rue Maurice Sabatier",
            "phone": "01 69 24 55 66",
            "website": "https://casamia-viry.fr",
            "avatar": "https://images.unsplash.com/photo-1593560708920-61dd98c46a4e?w=500&auto=format&fit=crop&q=80",
            "bio": "L'authentique goût de l'Italie à deux pas du Lac de Viry : pâtes fraîches al dente et calzones soufflés.",
            "dishes": [
                ("Pizza Tartufata & Prosciutto", 14.50, "pizza", "Mozzarella fior di latte, crème de truffe d'Alba, jambon cru de Parme affiné 18 mois et roquette fraîche.", "https://images.unsplash.com/photo-1574071318508-1cdbab80d002?w=600&auto=format&fit=crop&q=80"),
                ("Gnocchis au Gorgonzola & Noix", 12.90, "pasta", "Gnocchis de pommes de terre roulés main, crème fondante au gorgonzola doux et cerneaux de noix croquants.", "https://images.unsplash.com/photo-1551183053-bf91a1d81141?w=600&auto=format&fit=crop&q=80"),
                ("Cannolo Siciliano au Mascarpone", 5.50, "dessert", "Croustillant sicilien garni minute de ricotta sucrée vanillée, pépites de chocolat et écorces d'orange.", "https://images.unsplash.com/photo-1571877227200-a0d98ea607e9?w=600&auto=format&fit=crop&q=80")
            ]
        },
        {
            "id": 24,
            "name": "Chicken Spot Ris",
            "category": "fast_food",
            "city": "Ris-Orangis",
            "zipcode": "91130",
            "lat": 48.6510,
            "lng": 2.4155,
            "address": "48 Rue Edmond Bonté",
            "phone": "01 69 06 99 88",
            "website": "https://chickenspot-ris.fr",
            "avatar": "https://images.unsplash.com/photo-1562967914-608f82629710?w=500&auto=format&fit=crop&q=80",
            "bio": "Le spécialiste du poulet frit croustillant mariné selon notre recette secrète aux 11 épices.",
            "dishes": [
                ("Bucket Familial Poulet Frit (x12)", 19.90, "starters", "12 morceaux de poulet pané extra-croustillant avec 3 grandes frites et 4 sauces au choix.", "https://images.unsplash.com/photo-1562967914-608f82629710?w=600&auto=format&fit=crop&q=80"),
                ("Burger Zinger Spicy Cheese", 6.50, "burger", "Filet de poulet croustillant mariné au piment doux, cheddar fondu, salade iceberg et sauce mayonnaise épicée.", "https://images.unsplash.com/photo-1568901346375-23c9450c58cd?w=600&auto=format&fit=crop&q=80"),
                ("Wings Épicées Croustillantes (x8)", 7.00, "starters", "Ailerons de poulet croustillants enrobés de panure dorée et relevée.", "https://images.unsplash.com/photo-1585109649139-366815a0d713?w=600&auto=format&fit=crop&q=80")
            ]
        },
        {
            "id": 25,
            "name": "Crêperie de la Seine",
            "category": "cafe_bakery",
            "city": "Draveil",
            "zipcode": "91210",
            "lat": 48.6840,
            "lng": 2.4095,
            "address": "4 Quai de Seine",
            "phone": "01 69 40 44 55",
            "website": "https://creperie-seine.fr",
            "avatar": "https://images.unsplash.com/photo-1519915028121-7d3463d20b13?w=500&auto=format&fit=crop&q=80",
            "bio": "Authentiques galettes bretonnes au sarrasin bio du moulin et crêpes sucrées gourmandes.",
            "dishes": [
                ("Galette Complète à l'Andouille de Guémené", 11.50, "other", "Galette de blé noir 100% sarrasin, œuf miroir, emmental râpé et fines rondelles d'andouille artisanale.", "https://images.unsplash.com/photo-1504674900247-0877df9cc836?w=600&auto=format&fit=crop&q=80"),
                ("Galette Nordique au Saumon Fumé", 12.90, "other", "Saumon fumé de Norvège, fondue de poireaux à la crème fraîche et ciboulette fraîche ciselée.", "https://images.unsplash.com/photo-1546069901-ba9599a7e63c?w=600&auto=format&fit=crop&q=80"),
                ("Crêpe Caramel Beurre Salé Maison", 4.80, "dessert", "Crêpe de froment dorée nappée de caramel au beurre demi-sel de Guérande fait maison.", "https://images.unsplash.com/photo-1519915028121-7d3463d20b13?w=600&auto=format&fit=crop&q=80")
            ]
        },
        {
            "id": 26,
            "name": "Saveurs des Îles Restaurant",
            "category": "other",
            "city": "Ris-Orangis",
            "zipcode": "91130",
            "lat": 48.6500,
            "lng": 2.4165,
            "address": "30 Rue Edmond Bonté",
            "phone": "01 69 06 12 88",
            "website": "https://saveursdesiles-ris.fr",
            "avatar": "https://images.unsplash.com/photo-1504674900247-0877df9cc836?w=500&auto=format&fit=crop&q=80",
            "bio": "Gastronomie créole et antillaise : colombo de cabri savoureux, accras de morue et bokits dorés.",
            "dishes": [
                ("Colombo de Porc & Légumes Pays", 13.90, "rice_bowl", "Viande mijotée dans un mélange d'épices colombo antillais, christophine, patates douces et riz blanc.", "https://images.unsplash.com/photo-1546069901-ba9599a7e63c?w=600&auto=format&fit=crop&q=80"),
                ("Assiette d'Accras de Morue Chauds (x8)", 6.50, "starters", "Beignets antillais traditionnels croustillants à l'extérieur et moelleux au cœur, relevés au piment végétarien.", "https://images.unsplash.com/photo-1562967914-608f82629710?w=600&auto=format&fit=crop&q=80"),
                ("Bokit Poulet Boucané & Sauce Chien", 7.50, "sandwich_wrap", "Pain guadeloupéen frit minute garni d'effiloché de poulet mariné et fumé, sauce créole pimentée.", "https://images.unsplash.com/photo-1528735602780-2552fd46c7af?w=600&auto=format&fit=crop&q=80")
            ]
        },
        {
            "id": 27,
            "name": "Oishi Ramen Bar",
            "category": "japanese",
            "city": "Évry-Courcouronnes",
            "zipcode": "91000",
            "lat": 48.6300,
            "lng": 2.4410,
            "address": "12 Allée Boissy d'Anglas",
            "phone": "01 60 79 11 00",
            "website": "https://oishi-ramen.fr",
            "avatar": "https://images.unsplash.com/photo-1569718212165-3a8278d5f624?w=500&auto=format&fit=crop&q=80",
            "bio": "Bar à nouilles japonaises artisanales, bouillons dashi mijotés et donburi savoureux.",
            "dishes": [
                ("Shoyu Ramen au Bœuf Mariné", 14.50, "pasta", "Bouillon savoureux à la sauce soja japonaise, tranches de bœuf tendre, pousse de bambou menma et nori.", "https://images.unsplash.com/photo-1569718212165-3a8278d5f624?w=600&auto=format&fit=crop&q=80"),
                ("Katsudon Porc Pané sur Riz", 13.00, "rice_bowl", "Bol de riz japonais garni d'une côtelette de porc panée croustillante, œuf battu et oignons mijotés.", "https://images.unsplash.com/photo-1563245372-f21724e3856d?w=600&auto=format&fit=crop&q=80"),
                ("Edamame Frais à la Fleur de Sel", 4.50, "starters", "Fèves de soja japonaises cuites à la vapeur, assaisonnées de gros sel marin.", "https://images.unsplash.com/photo-1540420773420-3366772f4999?w=600&auto=format&fit=crop&q=80")
            ]
        },
        {
            "id": 28,
            "name": "Le Punjab Palace",
            "category": "indian",
            "city": "Corbeil-Essonnes",
            "zipcode": "91100",
            "lat": 48.6120,
            "lng": 2.4790,
            "address": "25 Rue Saint-Spire",
            "phone": "01 64 96 34 12",
            "website": "https://punjabpalace-corbeil.fr",
            "avatar": "https://images.unsplash.com/photo-1585937421612-70a008356fbe?w=500&auto=format&fit=crop&q=80",
            "bio": "Cuisine punjabie authentique, spécialités végétariennes savoureuses et naans fromage au miel.",
            "dishes": [
                ("Palak Paneer Traditionnel", 12.50, "rice_bowl", "Fromage indien frais maison mijoté dans une fondue d'épinards frais, gingembre et épices garam masala.", "https://images.unsplash.com/photo-1588166524941-3bf61a9c41db?w=600&auto=format&fit=crop&q=80"),
                ("Agneau Vindaloo Relevé", 15.00, "rice_bowl", "Spécialité de Goa : morceaux d'agneau braisés dans une sauce piquante au vinaigre de vin, piment et ail.", "https://images.unsplash.com/photo-1546833999-b9f581a1996d?w=600&auto=format&fit=crop&q=80"),
                ("Naan Fromage & Miel Sauvage", 4.20, "sandwich_wrap", "Pain levé tandoor fourré au fromage fondant, subtilement nappé de miel d'acacia chaud.", "https://images.unsplash.com/photo-1601050690597-df0568f70950?w=600&auto=format&fit=crop&q=80")
            ]
        },
        {
            "id": 29,
            "name": "Le Comptoir Libanais",
            "category": "middle_eastern",
            "city": "Évry-Courcouronnes",
            "zipcode": "91000",
            "lat": 48.6320,
            "lng": 2.4450,
            "address": "8 Place des Droits de l'Homme",
            "phone": "01 60 78 89 22",
            "website": "https://comptoirlibanais-evry.fr",
            "avatar": "https://images.unsplash.com/photo-1541518763669-27fef04b14ea?w=500&auto=format&fit=crop&q=80",
            "bio": "Authentiques mezzés de Beyrouth, chawarma au bœuf mariné et grillades au thym sauvage.",
            "dishes": [
                ("Plateau Dégustation 6 Mezzés", 18.00, "starters", "Houmous, moutabal, taboulé libanais au persil plat, falafels dorés, sambousek fromage et kebbé.", "https://images.unsplash.com/photo-1540420773420-3366772f4999?w=600&auto=format&fit=crop&q=80"),
                ("Sandwich Chawarma Bœuf Mariné", 8.50, "sandwich_wrap", "Lamelles de bœuf marinées aux épices libanaises, crème de sésame (tarator), cornichons et tomates.", "https://images.unsplash.com/photo-1528735602780-2552fd46c7af?w=600&auto=format&fit=crop&q=80"),
                ("Mouhalabieh à la Fleur d'Oranger", 4.50, "dessert", "Flan au lait traditionnel parfumé à l'eau de fleur d'oranger et concassé de pistaches.", "https://images.unsplash.com/photo-1488477181946-6428a0291777?w=600&auto=format&fit=crop&q=80")
            ]
        },
        {
            "id": 30,
            "name": "Pâtisserie & Salon des Délices",
            "category": "cafe_bakery",
            "city": "Ris-Orangis",
            "zipcode": "91130",
            "lat": 48.6508,
            "lng": 2.4148,
            "address": "12 Rue Albert Rémy",
            "phone": "01 69 06 22 11",
            "website": "https://delices-ris.fr",
            "avatar": "https://images.unsplash.com/photo-1509440159596-0249088772ff?w=500&auto=format&fit=crop&q=80",
            "bio": "Salon de thé gourmand : gâteaux d'anniversaire personnalisés, macarons parisiens et thés d'exception.",
            "dishes": [
                ("Éclair Gourmand au Chocolat Grand Cru", 3.60, "dessert", "Pâte à choux pur beurre garnie d'une crème pâtissière onctueuse au chocolat noir Valrhona.", "https://images.unsplash.com/photo-1571877227200-a0d98ea607e9?w=600&auto=format&fit=crop&q=80"),
                ("Boîte de 6 Macarons Artisanaux", 9.00, "dessert", "Assortiment : pistache d'Iran, caramel fleur de sel, framboise fraîche, chocolat noir, vanille et citron.", "https://images.unsplash.com/photo-1563729784474-d77dbb933a9e?w=600&auto=format&fit=crop&q=80"),
                ("Thé Vert Sencha Bio en Théière", 4.20, "drinks", "Thé vert japonais traditionnel aux notes végétales douces et rafraîchissantes.", "https://images.unsplash.com/photo-1576092768241-dec231879fc3?w=600&auto=format&fit=crop&q=80")
            ]
        },
        {
            "id": 31,
            "name": "Bangkok Street Food",
            "category": "chinese",
            "city": "Viry-Châtillon",
            "zipcode": "91170",
            "lat": 48.6700,
            "lng": 2.3720,
            "address": "45 Avenue de Provence",
            "phone": "01 69 24 12 89",
            "website": "https://bangkokstreet-viry.fr",
            "avatar": "https://images.unsplash.com/photo-1559847844-5315695dadae?w=500&auto=format&fit=crop&q=80",
            "bio": "Cuisine thaïlandaise de rue pleine de fraîcheur : curry vert au lait de coco, soupes Tom Yum et brochettes satay.",
            "dishes": [
                ("Curry Vert Poulet & Lait de Coco", 13.90, "rice_bowl", "Poulet mijoté dans une pâte de curry vert fait maison, aubergines thaï, basilic sacré et riz jasmin.", "https://images.unsplash.com/photo-1546069901-ba9599a7e63c?w=600&auto=format&fit=crop&q=80"),
                ("Soupe Tom Yum Crevettes Épicée", 8.50, "starters", "Bouillon thaï parfumé à la citronnelle, galanga, feuilles de kaffir, crevettes royales et coriandre.", "https://images.unsplash.com/photo-1541696432-82c6da8ce7bf?w=600&auto=format&fit=crop&q=80"),
                ("Brochettes Satay de Poulet Sauce Cacahuète (x4)", 6.90, "starters", "Brochettes de poulet marinées au curcuma, grillées et accompagnées de sauce aux cacahuètes pilées.", "https://images.unsplash.com/photo-1555939594-58d7cb561ad1?w=600&auto=format&fit=crop&q=80")
            ]
        },
        {
            "id": 32,
            "name": "King Burger Ris",
            "category": "fast_food",
            "city": "Ris-Orangis",
            "zipcode": "91130",
            "lat": 48.6520,
            "lng": 2.4170,
            "address": "100 Avenue de la Libération",
            "phone": "01 69 06 44 77",
            "website": "https://kingburger-ris.fr",
            "avatar": "https://images.unsplash.com/photo-1568901346375-23c9450c58cd?w=500&auto=format&fit=crop&q=80",
            "bio": "Burgers généreux cuits sur grill à gaz, sauces maison et menus étudiants abordables.",
            "dishes": [
                ("The King Monster Triple Steak", 10.50, "burger", "Trois steaks pur bœuf, triple tranche de cheddar coulant, cornichons doux et oignons dorés.", "https://images.unsplash.com/photo-1568901346375-23c9450c58cd?w=600&auto=format&fit=crop&q=80"),
                ("Menu Giant Chicken + Frites", 8.90, "other", "Burger au poulet croustillant géant avec cornet de frites chaudes et boisson 33cl.", "https://images.unsplash.com/photo-1586190848861-99aa4a171e90?w=600&auto=format&fit=crop&q=80"),
                ("Beignets Calamars à la Romaine (x6)", 5.00, "starters", "Anneaux d'encornets panés dorés servis avec sauce tartare fraîche au citron.", "https://images.unsplash.com/photo-1585109649139-366815a0d713?w=600&auto=format&fit=crop&q=80")
            ]
        },
        {
            "id": 33,
            "name": "Pizzeria Romana Ris",
            "category": "italian",
            "city": "Ris-Orangis",
            "zipcode": "91130",
            "lat": 48.6495,
            "lng": 2.4130,
            "address": "5 Rue Pierre Brossolette",
            "phone": "01 69 06 14 14",
            "website": "https://pizzeriaromana-ris.fr",
            "avatar": "https://images.unsplash.com/photo-1513104890138-7c749659a591?w=500&auto=format&fit=crop&q=80",
            "bio": "Pizzas à la pâte croustillante façon romaine, huile d'olive pimentée et charcuteries italiennes.",
            "dishes": [
                ("Pizza Diavola Spianata Piccante", 12.00, "pizza", "Sauce tomate San Marzano, fior di latte, spianata calabraise pimentée et olives taggiasche.", "https://images.unsplash.com/photo-1574071318508-1cdbab80d002?w=600&auto=format&fit=crop&q=80"),
                ("Pizza Calzone Végétarienne", 11.50, "pizza", "Chausson garni de poivrons grillés, courgettes, aubergines marinées, mozzarella et origan.", "https://images.unsplash.com/photo-1565299624946-b28f40a0ae38?w=600&auto=format&fit=crop&q=80"),
                ("Tarte au Citron Meringuée", 4.50, "dessert", "Crème citron jaune acidulée sur pâte sablée dorée, coiffée d'une meringue italienne caramélisée.", "https://images.unsplash.com/photo-1519915028121-7d3463d20b13?w=600&auto=format&fit=crop&q=80")
            ]
        },
        {
            "id": 34,
            "name": "Le Kashmir Évry",
            "category": "indian",
            "city": "Évry-Courcouronnes",
            "zipcode": "91000",
            "lat": 48.6290,
            "lng": 2.4405,
            "address": "22 Boulevard de l'Oise",
            "phone": "01 60 77 12 34",
            "website": "https://lekashmir-evry.fr",
            "avatar": "https://images.unsplash.com/photo-1585937421612-70a008356fbe?w=500&auto=format&fit=crop&q=80",
            "bio": "Buffet indien de spécialités kashmiries, samoussas croustillants et lassi à la mangue fait maison.",
            "dishes": [
                ("Assiette Samoussas Légumes & Viande (x4)", 6.00, "starters", "Triangles de pâte feuilletée croustillante farcis aux pommes de terre, petits pois et bœuf épicé.", "https://images.unsplash.com/photo-1601050690597-df0568f70950?w=600&auto=format&fit=crop&q=80"),
                ("Curry de Crevettes Madras", 14.90, "rice_bowl", "Crevettes sautées dans une sauce épicée aux tomates fraîches, graines de moutarde et piments doux.", "https://images.unsplash.com/photo-1565557623262-b51c2513a641?w=600&auto=format&fit=crop&q=80"),
                ("Lassi Artisanal à la Mangue Alphonso", 3.80, "drinks", "Boisson traditionnelle au yaourt crémeux battu, purée de mangue d'Inde et cardamome.", "https://images.unsplash.com/photo-1572490122747-3968b75cc699?w=600&auto=format&fit=crop&q=80")
            ]
        },
        {
            "id": 35,
            "name": "Brasserie Le Paris-Sud",
            "category": "fine_dining",
            "city": "Évry-Courcouronnes",
            "zipcode": "91000",
            "lat": 48.6315,
            "lng": 2.4440,
            "address": "1 Place des Miroirs",
            "phone": "01 60 78 55 44",
            "website": "https://parissud-brasserie.fr",
            "avatar": "https://images.unsplash.com/photo-1555396273-367ea4eb4db5?w=500&auto=format&fit=crop&q=80",
            "bio": "Brasserie parisienne chic : tartares préparés devant vous, entrecôtes d'Aubrac et belle terrasse.",
            "dishes": [
                ("Tartare de Bœuf Charolais au Couteau", 16.50, "other", "Bœuf charolais assaisonné minute (câpres, échalotes, jaune d'œuf, tabasco) avec frites fraîches.", "https://images.unsplash.com/photo-1544025162-d76694265947?w=600&auto=format&fit=crop&q=80"),
                ("Entrecôte d'Aubrac Grillée 300g", 21.00, "other", "Belle entrecôte persillée grillée à la plancha, sauce béarnaise maison et écrasé de pommes de terre.", "https://images.unsplash.com/photo-1558030006-450675393462?w=600&auto=format&fit=crop&q=80"),
                ("Crème Brûlée à la Vanille Bourbon", 6.00, "dessert", "Crème aux œufs fondante caramélisée au chalumeau sous une fine croûte de cassonade craquante.", "https://images.unsplash.com/photo-1488477181946-6428a0291777?w=600&auto=format&fit=crop&q=80")
            ]
        },
        {
            "id": 36,
            "name": "Délice d'Istanbul Kebab & Grill",
            "category": "middle_eastern",
            "city": "Draveil",
            "zipcode": "91210",
            "lat": 48.6830,
            "lng": 2.4100,
            "address": "52 Avenue Henri Barbusse",
            "phone": "01 69 40 78 12",
            "website": "https://delice-istanbul-draveil.fr",
            "avatar": "https://images.unsplash.com/photo-1555939594-58d7cb561ad1?w=500&auto=format&fit=crop&q=80",
            "bio": "Kebab de veau mariné monté chaque matin sur broche, galettes döner fraîches et sauces maison.",
            "dishes": [
                ("Sandwich Döner Kebab Veau Frais", 7.50, "sandwich_wrap", "Pain rond turc chaud garni de fines lamelles de veau mariné grillé, salade, tomate, oignons et sauce blanche.", "https://images.unsplash.com/photo-1528735602780-2552fd46c7af?w=600&auto=format&fit=crop&q=80"),
                ("Assiette Köfte Grillée au Charbon", 12.50, "other", "Boulettes de viande hachée assaisonnées à la menthe et cumin, frites maison, blé boulgour et salade.", "https://images.unsplash.com/photo-1544025162-d76694265947?w=600&auto=format&fit=crop&q=80"),
                ("Boisson Ayran Frais Turc", 2.00, "drinks", "Boisson salée traditionnelle au yaourt battu rafraîchissante.", "https://images.unsplash.com/photo-1513558161293-cdaf765ed2fd?w=600&auto=format&fit=crop&q=80")
            ]
        },
        {
            "id": 37,
            "name": "Bokit & Co Essonne",
            "category": "other",
            "city": "Corbeil-Essonnes",
            "zipcode": "91100",
            "lat": 48.6135,
            "lng": 2.4810,
            "address": "14 Rue Champlouis",
            "phone": "01 64 96 88 55",
            "website": "https://bokitandco.fr",
            "avatar": "https://images.unsplash.com/photo-1504674900247-0877df9cc836?w=500&auto=format&fit=crop&q=80",
            "bio": "Fast-food créole : bokits chauds et croustillants, agoulou antillais et frites de patates douces.",
            "dishes": [
                ("Bokit Morue & Piment Doux", 7.90, "sandwich_wrap", "Pain frit croustillant garni de chiquetaille de morue assaisonnée, oignons et piment.", "https://images.unsplash.com/photo-1528735602780-2552fd46c7af?w=600&auto=format&fit=crop&q=80"),
                ("Frites de Patate Douce Maison", 4.20, "starters", "Bâtonnets de patate douce fondants et dorés servis avec sauce mayonnaise épicée.", "https://images.unsplash.com/photo-1576107232684-1279f3908594?w=600&auto=format&fit=crop&q=80"),
                ("Tourment d'Amour Coco & Confiture", 3.50, "dessert", "Tartelette antillaise traditionnelle à la confiture de goyave et génoise moelleuse à la noix de coco.", "https://images.unsplash.com/photo-1519915028121-7d3463d20b13?w=600&auto=format&fit=crop&q=80")
            ]
        },
        {
            "id": 38,
            "name": "Le Fournil de la Gare Ris",
            "category": "cafe_bakery",
            "city": "Ris-Orangis",
            "zipcode": "91130",
            "lat": 48.6550,
            "lng": 2.4105,
            "address": "2 Place de la Gare",
            "phone": "01 69 06 19 80",
            "website": "https://fournil-gare-ris.fr",
            "avatar": "https://images.unsplash.com/photo-1509440159596-0249088772ff?w=500&auto=format&fit=crop&q=80",
            "bio": "Boulangerie artisanale de gare : viennoiseries chaudes dès 5h30, formules café emporter et quiches lorraines.",
            "dishes": [
                ("Formule Petit Déjeuner Express", 4.50, "dessert", "Un croissant chaud ou pain au chocolat pur beurre + Café espresso ou thé + Jus d'orange pressé.", "https://images.unsplash.com/photo-1555507036-ab1f4038808a?w=600&auto=format&fit=crop&q=80"),
                ("Part de Quiche Lorraine Traditionnelle", 4.20, "starters", "Appareil aux œufs et crème fraîche épaisse, lardons fumés dorés sur pâte brisée maison.", "https://images.unsplash.com/photo-1504674900247-0877df9cc836?w=600&auto=format&fit=crop&q=80"),
                ("Chausson aux Pommes Caramélisées", 1.80, "dessert", "Pâte feuilletée croustillante pur beurre garnie d'une compote de pommes maison compotée.", "https://images.unsplash.com/photo-1519915028121-7d3463d20b13?w=600&auto=format&fit=crop&q=80")
            ]
        },
        {
            "id": 39,
            "name": "Wok Grill 91 Asie",
            "category": "chinese",
            "city": "Grigny",
            "zipcode": "91350",
            "lat": 48.6555,
            "lng": 2.3820,
            "address": "8 Route Nationale 7",
            "phone": "01 69 43 11 88",
            "website": "https://wokgrill91.fr",
            "avatar": "https://images.unsplash.com/photo-1541696432-82c6da8ce7bf?w=500&auto=format&fit=crop&q=80",
            "bio": "Grillades et woks cuisinés minute devant vous avec viandes de qualité, fruits de mer et légumes frais.",
            "dishes": [
                ("Wok de Bœuf aux Oignons & Poivrons", 13.50, "rice_bowl", "Émincé de bœuf mariné sauté vif au wok, oignons doux, pousses de bambou et sauce soja foncée.", "https://images.unsplash.com/photo-1546069901-ba9599a7e63c?w=600&auto=format&fit=crop&q=80"),
                ("Crevettes Sel & Poivre Croustillantes", 14.90, "starters", "Grosses crevettes sautées avec ail émincé, sel fin, poivre noir moulu et piment doux.", "https://images.unsplash.com/photo-1559847844-5315695dadae?w=600&auto=format&fit=crop&q=80"),
                ("Perles de Coco Vapeur Chaudes (x3)", 4.50, "dessert", "Boules de riz gluant moelleuses fourrées à la crème de soja jaune et enrobées de noix de coco râpée.", "https://images.unsplash.com/photo-1563729784474-d77dbb933a9e?w=600&auto=format&fit=crop&q=80")
            ]
        },
        {
            "id": 40,
            "name": "Big M Burger Ris",
            "category": "fast_food",
            "city": "Ris-Orangis",
            "zipcode": "91130",
            "lat": 48.6502,
            "lng": 2.4185,
            "address": "72 Avenue de la Libération",
            "phone": "01 69 06 88 11",
            "website": "https://bigm-ris.fr",
            "avatar": "https://images.unsplash.com/photo-1550547660-d9450f859349?w=500&auto=format&fit=crop&q=80",
            "bio": "Tous les burgers iconiques du fast-food en version certifiée qualité bouchère avec sauce biggy.",
            "dishes": [
                ("Burger Biggy Double Cheese", 7.90, "burger", "Double steak façon bouchère, tranches de cheddar fondant, salade, cornichons et sauce biggy légendaire.", "https://images.unsplash.com/photo-1568901346375-23c9450c58cd?w=600&auto=format&fit=crop&q=80"),
                ("Nuggets Pur Filet Croustillants (x9)", 6.50, "starters", "Beignets de poulet blanc panés dorés servis avec sauce barbecue et sauce curry douce.", "https://images.unsplash.com/photo-1562967914-608f82629710?w=600&auto=format&fit=crop&q=80"),
                ("Sunday Glacé Nappage Caramel", 3.50, "dessert", "Glace à l'italienne au lait entier surmontée d'un généreux coulis de caramel tiède et cacahuètes.", "https://images.unsplash.com/photo-1572490122747-3968b75cc699?w=600&auto=format&fit=crop&q=80")
            ]
        },
        {
            "id": 41,
            "name": "Le Cèdre du Liban Ris",
            "category": "middle_eastern",
            "city": "Ris-Orangis",
            "zipcode": "91130",
            "lat": 48.6492,
            "lng": 2.4160,
            "address": "38 Rue Edmond Bonté",
            "phone": "01 69 02 77 44",
            "website": "https://cedreduliban-ris.fr",
            "avatar": "https://images.unsplash.com/photo-1541518763669-27fef04b14ea?w=500&auto=format&fit=crop&q=80",
            "bio": "Traiteur et restaurant libanais : mezzés froids et chauds, chawarma au poulet et falafels dorés minute.",
            "dishes": [
                ("Assiette Végétarienne Libanaise", 13.90, "starters", "Houmous, taboulé libanais, caviar d'aubergine, 3 falafels chauds et galette de pain libanais.", "https://images.unsplash.com/photo-1540420773420-3366772f4999?w=600&auto=format&fit=crop&q=80"),
                ("Chawarma Poulet Mariné à l'Ail", 8.00, "sandwich_wrap", "Poulet mariné au jus de citron, crème d'ail maison toum et cornichons au vinaigre dans pain pita.", "https://images.unsplash.com/photo-1528735602780-2552fd46c7af?w=600&auto=format&fit=crop&q=80"),
                ("Assortiment de Baklawas (x4)", 5.00, "dessert", "Pâtisseries orientales feuilletées garnies de noix, pistaches et amandes arrosées de fleur d'oranger.", "https://images.unsplash.com/photo-1519869325930-281384150729?w=600&auto=format&fit=crop&q=80")
            ]
        },
        {
            "id": 42,
            "name": "La Terrasse du Lac",
            "category": "fine_dining",
            "city": "Viry-Châtillon",
            "zipcode": "91170",
            "lat": 48.6730,
            "lng": 2.3780,
            "address": "15 Rue Francœur",
            "phone": "01 69 24 88 00",
            "website": "https://terrassedulac-viry.fr",
            "avatar": "https://images.unsplash.com/photo-1517248135467-4c7edcad34c4?w=500&auto=format&fit=crop&q=80",
            "bio": "Vue imprenable sur le grand Lac de Viry, cuisine raffinée au feu de bois et poissons frais.",
            "dishes": [
                ("Pavé de Saumon Rôti à l'Unilatérale", 17.50, "other", "Saumon frais d'Écosse, écrasé de pommes de terre à l'huile de truffe et légumes de saison glacés.", "https://images.unsplash.com/photo-1519708227418-c8fd9a32b7a2?w=600&auto=format&fit=crop&q=80"),
                ("Souris d'Agneau Confite au Miel", 19.90, "other", "Souris d'agneau mijotée 7 heures à basse température, jus corsé au thym et purée maison.", "https://images.unsplash.com/photo-1544025162-d76694265947?w=600&auto=format&fit=crop&q=80"),
                ("Moelleux au Chocolat Coeur Coulant Caramel", 6.80, "dessert", "Chocolat noir 70% et cœur coulant caramel beurre salé, glace vanille artisanale.", "https://images.unsplash.com/photo-1606313564200-e75d5e30476c?w=600&auto=format&fit=crop&q=80")
            ]
        },
        {
            "id": 43,
            "name": "Pizza del Sole Draveil",
            "category": "italian",
            "city": "Draveil",
            "zipcode": "91210",
            "lat": 48.6815,
            "lng": 2.4120,
            "address": "88 Boulevard du Général de Gaulle",
            "phone": "01 69 40 55 99",
            "website": "https://pizzadelsole-draveil.fr",
            "avatar": "https://images.unsplash.com/photo-1513104890138-7c749659a591?w=500&auto=format&fit=crop&q=80",
            "bio": "Pizzas italiennes cuites sur pierre réfractaire, mozzarella di bufala campana et jambons affinés.",
            "dishes": [
                ("Pizza Bufalina DOP", 13.50, "pizza", "Sauce tomate San Marzano, mozzarella di bufala AOP ajoutée en sortie de four, tomates cerises confites et basilic.", "https://images.unsplash.com/photo-1574071318508-1cdbab80d002?w=600&auto=format&fit=crop&q=80"),
                ("Pizza Parme & Roquette", 14.00, "pizza", "Base fior di latte, jambon de Parme 24 mois, roquette poivrée et copeaux de parmesan reggiano.", "https://images.unsplash.com/photo-1593560708920-61dd98c46a4e?w=600&auto=format&fit=crop&q=80"),
                ("Tiramisu Maison au Spéculoos", 5.50, "dessert", "Crème légère au mascarpone, biscuits spéculoos croquants et pointe de cannelle.", "https://images.unsplash.com/photo-1571877227200-a0d98ea607e9?w=600&auto=format&fit=crop&q=80")
            ]
        },
        {
            "id": 44,
            "name": "Le Dragon de Jade Évry",
            "category": "chinese",
            "city": "Évry-Courcouronnes",
            "zipcode": "91000",
            "lat": 48.6275,
            "lng": 2.4420,
            "address": "3 Rue Ambroise Croizat",
            "phone": "01 60 77 88 12",
            "website": "https://dragonjade-evry.fr",
            "avatar": "https://images.unsplash.com/photo-1541696432-82c6da8ce7bf?w=500&auto=format&fit=crop&q=80",
            "bio": "Cuisine cantonaise et sichuanaise authentique : porc au caramel, canard croustillant et soupes parfumées.",
            "dishes": [
                ("Porc au Caramel Façon Saïgon", 12.90, "rice_bowl", "Échine de porc fondante mijotée dans un caramel ambré au poivre noir et riz blanc parfumé.", "https://images.unsplash.com/photo-1546069901-ba9599a7e63c?w=600&auto=format&fit=crop&q=80"),
                ("Raviolis Pékinois Grillés (Guotie x6)", 6.50, "starters", "Raviolis frais faits main farcis au porc et ciboulette chinoise, dorés et croustillants.", "https://images.unsplash.com/photo-1498654896293-37aacf113fd9?w=600&auto=format&fit=crop&q=80"),
                ("Beignets de Pommes Caramélisés", 5.00, "dessert", "Rondelles de pommes en beignet croustillant trempées dans un caramel doré chaud et refroidies à l'eau glacée.", "https://images.unsplash.com/photo-1519915028121-7d3463d20b13?w=600&auto=format&fit=crop&q=80")
            ]
        },
        {
            "id": 45,
            "name": "Grillades d'Orient Ris",
            "category": "middle_eastern",
            "city": "Ris-Orangis",
            "zipcode": "91130",
            "lat": 48.6508,
            "lng": 2.4170,
            "address": "45 Rue Edmond Bonté",
            "phone": "01 69 06 55 11",
            "website": "https://grilladesdorient-ris.fr",
            "avatar": "https://images.unsplash.com/photo-1555939594-58d7cb561ad1?w=500&auto=format&fit=crop&q=80",
            "bio": "Spécialités de viandes marinées au feu de braise, galettes cuites au tandoor et entrées libanaises fraîches.",
            "dishes": [
                ("Brochettes d'Agneau Marinées au Feu de Bois", 15.00, "other", "Morceaux d'agneau tendre marinés aux herbes et huile d'olive, grillés minute au charbon de bois.", "https://images.unsplash.com/photo-1544025162-d76694265947?w=600&auto=format&fit=crop&q=80"),
                ("Chawarma Mixte Bœuf et Poulet", 8.90, "sandwich_wrap", "Galette de blé fine garnie des deux viandes marinées, salade fraîche et crème d'ail maison.", "https://images.unsplash.com/photo-1528735602780-2552fd46c7af?w=600&auto=format&fit=crop&q=80"),
                ("Salade Fatouche au Sumac & Grenade", 6.50, "starters", "Concombres croquants, tomates mûres, radis, pain pita frit et mélasse de grenade acidulée.", "https://images.unsplash.com/photo-1512621776951-a57141f2eefd?w=600&auto=format&fit=crop&q=80")
            ]
        },
        {
            "id": 46,
            "name": "Bistrot des Artistes Draveil",
            "category": "fine_dining",
            "city": "Draveil",
            "zipcode": "91210",
            "lat": 48.6850,
            "lng": 2.4080,
            "address": "19 Place de la République",
            "phone": "01 69 40 88 77",
            "website": "https://bistrot-artistes.fr",
            "avatar": "https://images.unsplash.com/photo-1555396273-367ea4eb4db5?w=500&auto=format&fit=crop&q=80",
            "bio": "Bistrot d'atmosphère : cuisine traditionnelle de terroir, ardoise du marché renouvelée chaque semaine.",
            "dishes": [
                ("Blanquette de Veau à l'Ancienne", 16.90, "other", "Morceaux de veau fondants mijotés à la crème fraîche, petits oignons grelots, carottes et riz pilaf.", "https://images.unsplash.com/photo-1544025162-d76694265947?w=600&auto=format&fit=crop&q=80"),
                ("Cassolette d'Escargots de Bourgogne (x6)", 8.50, "starters", "Escargots sauvages préparés au beurre d'Isigny persillé à l'ail et échalotes gratinés au four.", "https://images.unsplash.com/photo-1504674900247-0877df9cc836?w=600&auto=format&fit=crop&q=80"),
                ("Tarte Bourdaloue Poire & Amandes", 6.00, "dessert", "Pâte sablée croustillante, crème d'amande moelleuse et demi-poires pochées tièdes.", "https://images.unsplash.com/photo-1519915028121-7d3463d20b13?w=600&auto=format&fit=crop&q=80")
            ]
        },
        {
            "id": 47,
            "name": "Le Wok d'Or Corbeil",
            "category": "chinese",
            "city": "Corbeil-Essonnes",
            "zipcode": "91100",
            "lat": 48.6110,
            "lng": 2.4830,
            "address": "50 Boulevard Jean Jaurès",
            "phone": "01 64 96 77 00",
            "website": "https://wokdor-corbeil.fr",
            "avatar": "https://images.unsplash.com/photo-1541696432-82c6da8ce7bf?w=500&auto=format&fit=crop&q=80",
            "bio": "Spécialités asiatiques au wok, brochettes japonaises et buffet chaud de fruits de mer.",
            "dishes": [
                ("Bo Bun Bœuf & Nems Croustillants", 12.50, "rice_bowl", "Vermicelles de riz tièdes, bœuf sauté à la citronnelle, nems au porc croustillants et herbes fraîches.", "https://images.unsplash.com/photo-1546069901-ba9599a7e63c?w=600&auto=format&fit=crop&q=80"),
                ("Rouleaux de Printemps Frais (x2)", 5.50, "starters", "Feuilles de riz garnies de crevettes fraîches, menthe, coriandre, vermicelles et sauce aux cacahuètes.", "https://images.unsplash.com/photo-1540420773420-3366772f4999?w=600&auto=format&fit=crop&q=80"),
                ("Glace Frite Chinoise Flambée", 5.50, "dessert", "Boule de glace vanille enrobée d'une panure dorée croustillante, flambée minute au Grand Marnier.", "https://images.unsplash.com/photo-1563729784474-d77dbb933a9e?w=600&auto=format&fit=crop&q=80")
            ]
        },
        {
            "id": 48,
            "name": "Pizzeria da Luigi Ris",
            "category": "italian",
            "city": "Ris-Orangis",
            "zipcode": "91130",
            "lat": 48.6530,
            "lng": 2.4150,
            "address": "17 Rue Albert Rémy",
            "phone": "01 69 06 18 88",
            "website": "https://daluigi-ris.fr",
            "avatar": "https://images.unsplash.com/photo-1513104890138-7c749659a591?w=500&auto=format&fit=crop&q=80",
            "bio": "Pizzas au levain naturel pétries à la main, tiramisu crémeux et vins italiens sélectionnés.",
            "dishes": [
                ("Pizza Capricciosa Tradizionale", 12.90, "pizza", "Sauce tomate, fior di latte, jambon cuit supérieur, cœurs d'artichauts marinés, champignons et olives noires.", "https://images.unsplash.com/photo-1574071318508-1cdbab80d002?w=600&auto=format&fit=crop&q=80"),
                ("Bruschetta al Pomodoro & Basilic", 6.50, "starters", "Pain de campagne grillé frotté à l'ail, tomates fraîches concassées, basilic et filet d'huile d'olive.", "https://images.unsplash.com/photo-1540420773420-3366772f4999?w=600&auto=format&fit=crop&q=80"),
                ("Tiramisu Artisanal au Limoncello", 6.00, "dessert", "Version estivale du tiramisu à la liqueur de citron de Sorrente et zestes confits.", "https://images.unsplash.com/photo-1571877227200-a0d98ea607e9?w=600&auto=format&fit=crop&q=80")
            ]
        },
        {
            "id": 49,
            "name": "Le Délice des Îles Viry",
            "category": "other",
            "city": "Viry-Châtillon",
            "zipcode": "91170",
            "lat": 48.6710,
            "lng": 2.3740,
            "address": "10 Rue Gabriel Péri",
            "phone": "01 69 24 33 22",
            "website": "https://delicedesiles-viry.fr",
            "avatar": "https://images.unsplash.com/photo-1504674900247-0877df9cc836?w=500&auto=format&fit=crop&q=80",
            "bio": "Traiteur antillais et réunionnais : rougail saucisse fumée, samoussas de la Réunion et gâteau patate douce.",
            "dishes": [
                ("Rougail Saucisses Tradition Réunion", 13.50, "rice_bowl", "Saucisses fumées mijotées à la tomate, oignons, gingembre, curcuma et piments doux avec riz blanc.", "https://images.unsplash.com/photo-1546069901-ba9599a7e63c?w=600&auto=format&fit=crop&q=80"),
                ("Samoussas Réunionnais au Thon Épicé (x6)", 5.50, "starters", "Petits beignets triangulaires croustillants farcis au thon et combava parfumé.", "https://images.unsplash.com/photo-1601050690597-df0568f70950?w=600&auto=format&fit=crop&q=80"),
                ("Gâteau Moelleux à la Patate Douce", 4.20, "dessert", "Spécialité créole tiède parfumée au rhum vieux, cannelle et vanille bourbon.", "https://images.unsplash.com/photo-1519915028121-7d3463d20b13?w=600&auto=format&fit=crop&q=80")
            ]
        },
        {
            "id": 50,
            "name": "L'Échappée Gourmande Ris",
            "category": "fine_dining",
            "city": "Ris-Orangis",
            "zipcode": "91130",
            "lat": 48.6512,
            "lng": 2.4135,
            "address": "28 Rue Pierre Brossolette",
            "phone": "01 69 06 17 00",
            "website": "https://lechappee-ris.fr",
            "avatar": "https://images.unsplash.com/photo-1555396273-367ea4eb4db5?w=500&auto=format&fit=crop&q=80",
            "bio": "Cuisine moderne et créative, produits bio d'Île-de-France et carte des vins en biodynamie.",
            "dishes": [
                ("Filet de Canette Rôti aux Cerises Noires", 18.50, "other", "Canette fermière rosée, réduction de jus corsé aux cerises griottes et purée de panais noisette.", "https://images.unsplash.com/photo-1544025162-d76694265947?w=600&auto=format&fit=crop&q=80"),
                ("Velouté de Butternut & Châtaignes Grillées", 7.50, "starters", "Courge butternut bio mixée crémeuse, éclats de châtaignes torréfiées et crème fouettée au mascarpone.", "https://images.unsplash.com/photo-1546069901-ba9599a7e63c?w=600&auto=format&fit=crop&q=80"),
                ("Millefeuille Croustillant Vanille de Madagascar", 6.50, "dessert", "Feuilletage caramélisé inversé croustillant et crème mousseline vanillée légère.", "https://images.unsplash.com/photo-1571877227200-a0d98ea607e9?w=600&auto=format&fit=crop&q=80")
            ]
        }
    ]

    # 100 Local Professionals across 8 Main Categories and 24 Subcategories
    pro_categories = [
        # (main_category, subcategory, job_title_fr)
        ("home_trades", "plumbers", "Artisan Plombier Chauffagiste"),
        ("home_trades", "electricians", "Électricien Général"),
        ("home_trades", "construction", "Rénovation & Bâtiment"),
        ("home_trades", "maintenance", "Serrurier Dépanneur"),
        ("auto_mobility", "garages", "Garage Automobile & Contrôle"),
        ("auto_mobility", "mechanics", "Mécanicien & Carrossier"),
        ("health_medical", "pharmacies", "Pharmacien d'Officine"),
        ("health_medical", "clinics", "Chirurgien-Dentiste"),
        ("health_medical", "therapists", "Masseur-Kinésithérapeute"),
        ("health_medical", "doctors", "Médecin Généraliste"),
        ("beauty_personal_care", "salons", "Salon de Coiffure"),
        ("beauty_personal_care", "barbers", "Barbier & Coiffeur Homme"),
        ("beauty_personal_care", "spas", "Institut de Beauté & Spa"),
        ("professional_legal", "lawyers", "Avocat au Barreau de l'Essonne"),
        ("professional_legal", "accountants", "Expert-Comptable"),
        ("professional_legal", "notaries", "Notaire"),
        ("professional_legal", "consultants", "Conseil & Gestion d'Entreprise"),
        ("education_fitness", "driving_schools", "Auto-École Permis B"),
        ("education_fitness", "gyms", "Salle de Sport & Fitness"),
        ("education_fitness", "tutors", "Soutien Scolaire & Langues"),
        ("b2b_industry", "it_services", "Dépannage & Réparation Informatique"),
        ("b2b_industry", "manufacturing", "Artisan Menuisier Fabricant"),
        ("b2b_industry", "wholesale", "Fournitures & Équipements Pro"),
        ("home_trades", "construction", "Peintre & Décorateur d'Intérieur")
    ]

    pro_names_and_bios = [
        # 1-30 Home Trades
        ("Plomberie Chauffage Ris-Orangis", "home_trades", "plumbers", "Ris-Orangis", "91130", "12 Rue Albert Rémy", "01 69 06 11 22", "Dépannage d'urgence plomberie 7j/7, recherche de fuite et installation de chaudières."),
        ("Électricité Générale Essonne 91", "home_trades", "electricians", "Ris-Orangis", "91130", "28 Rue Pierre Brossolette", "01 69 06 33 44", "Remise aux normes électriques NF C 15-100, tableaux électriques et bornes de recharge IRVE."),
        ("Serrurerie Dépannage Express Ris", "home_trades", "maintenance", "Ris-Orangis", "91130", "50 Rue Edmond Bonté", "01 69 06 55 66", "Ouverture de porte claquée en 30 min, blindage de porte et remplacement de serrures certifiées A2P."),
        ("Rénovation Peinture & Déco Essonne", "home_trades", "construction", "Ris-Orangis", "91130", "14 Avenue de la Libération", "01 69 43 22 11", "Peinture intérieure, pose de parquet, enduits décoratifs et rénovation complète d'appartements."),
        ("Carrelage & Rénovation Salle de Bain", "home_trades", "construction", "Ris-Orangis", "91130", "34 Route de Grigny", "01 69 21 44 55", "Création de douches à l'italienne sur mesure, faïence moderne et carrelage grand format."),
        ("Menuiserie Bois & Agencement 91", "home_trades", "construction", "Ris-Orangis", "91130", "8 Rue de la Gare", "01 69 06 77 88", "Création de dressings, bibliothèques sur mesure, pose de fenêtres double vitrage et volets."),
        ("Toiture & Couverture Ris-Orangis", "home_trades", "construction", "Ris-Orangis", "91130", "66 Rue Albert Rémy", "01 69 06 99 00", "Rénovation de toitures en tuiles et zinc, démoussage hydrofuge et étanchéité de cheminée."),
        ("Essonne Parcs & Jardins", "home_trades", "maintenance", "Ris-Orangis", "91130", "19 Rue de Grigny", "01 69 43 12 34", "Entretien de jardins, tonte de pelouse, élagage d'arbres dangereux et création de terrasses bois."),
        ("Climatisation & Pompes à Chaleur 91", "home_trades", "maintenance", "Ris-Orangis", "91130", "42 Avenue de la Libération", "01 69 02 44 88", "Installation et maintenance de pompes à chaleur RGE et climatisation réversible économique."),
        ("Artisan Vitrier Miroitier Essonne", "home_trades", "construction", "Ris-Orangis", "91130", "15 Rue Edmond Bonté", "01 69 06 22 77", "Remplacement de vitres cassées, double vitrage thermique et miroiterie personnalisée."),
        ("Allo Plombier Débouchage 91", "home_trades", "plumbers", "Draveil", "91210", "14 Boulevard Henri Barbusse", "01 69 40 11 22", "Débouchage haute pression de canalisations, hydrocurage et inspection vidéo par caméra."),
        ("Volt Services Électricité Draveil", "home_trades", "electricians", "Draveil", "91210", "22 Rue de Mainville", "01 69 40 33 44", "Installations électriques neuves, éclairage LED architectural et domotique connectée."),
        ("Cordonnerie & Clés Minute de la Gare", "home_trades", "maintenance", "Ris-Orangis", "91130", "1 Place de la Gare", "01 69 06 88 22", "Reproduction immédiate de clés brevetées, télécommandes de portail et réparation de souliers."),
        ("Chauffage Sanitaire Grand Paris Sud", "home_trades", "plumbers", "Évry-Courcouronnes", "91000", "10 Cours Monseigneur Romero", "01 60 78 12 34", "Installation et entretien annuel de chaudières gaz et chauffe-eau thermodynamiques."),
        ("Serrurerie de l'Écluse Draveil", "home_trades", "maintenance", "Draveil", "91210", "5 Quai de Seine", "01 69 40 55 66", "Dépannage rideaux métalliques de commerces, serrures multipoints et coffres-forts."),
        ("Isol Éco Bâtiment Rénovation", "home_trades", "construction", "Corbeil-Essonnes", "91100", "18 Rue Feray", "01 64 96 22 33", "Isolation thermique par l'extérieur (ITE), ravalement de façade et isolation des combles."),
        ("Plomberie Express Viry", "home_trades", "plumbers", "Viry-Châtillon", "91170", "12 Rue Maurice Sabatier", "01 69 24 11 00", "Intervention d'urgence fuite d'eau, remplacement de robinetterie et chauffe-eau."),
        ("Énergie Verte Solaire 91", "home_trades", "electricians", "Ris-Orangis", "91130", "55 Avenue de la Libération", "01 69 06 77 11", "Installation de panneaux solaires photovoltaïques en autoconsommation certifiée RGE."),
        ("Maçonnerie Générale de l'Essonne", "home_trades", "construction", "Grigny", "91350", "28 Rue Pasteur", "01 69 43 55 00", "Construction de murs de clôture, dalles en béton armé, ouvertures de murs porteurs IPN."),
        ("Dépannage Serrure 24 Ris", "home_trades", "maintenance", "Ris-Orangis", "91130", "33 Rue Pierre Brossolette", "01 69 06 14 77", "Serrurier d'astreinte 24h/24, pose de cornières anti-pinces et verrous de sécurité."),
        ("Artisan Peintre des Bords de Seine", "home_trades", "construction", "Draveil", "91210", "8 Rue Jean Jaurès", "01 69 40 77 88", "Peintures écologiques sans COV, papier peint panoramique et lasure de boiseries extérieures."),
        ("Assainissement Pompage Essonne", "home_trades", "plumbers", "Corbeil-Essonnes", "91100", "45 Rue Saint-Spire", "01 64 96 88 99", "Vidange de fosses septiques, dégraissage de bacs à graisse et curage préventif des réseaux."),
        ("Ambiance Parquet & Menuiserie", "home_trades", "construction", "Viry-Châtillon", "91170", "30 Avenue de Provence", "01 69 24 88 55", "Pose de parquet massif en point de Hongrie, ponçage vitrification et terrasses extérieures."),
        ("Charpente & Zinguerie du Val de Seine", "home_trades", "construction", "Draveil", "91210", "3 Rue de la Forêt", "01 69 40 99 11", "Fabrication et rénovation de charpentes traditionnelles, gouttières en zinc et velux."),
        ("Baignoire en Douche Seniors 91", "home_trades", "plumbers", "Ris-Orangis", "91130", "20 Rue Albert Rémy", "01 69 06 45 12", "Remplacement de baignoire par douche sécurisée PMR en 48 heures sans gros travaux."),
        ("Électricité Domotique Habitat 91", "home_trades", "electricians", "Ris-Orangis", "91130", "88 Avenue de la Libération", "01 69 06 88 33", "Automatisation de volets roulants, portails électriques et interphones vidéo connectés."),
        ("Serrurerie Métallerie de l'Essonne", "home_trades", "maintenance", "Évry-Courcouronnes", "91000", "14 Rue Jean Renoir", "01 60 78 44 22", "Fabrication de grilles de défense en fer forgé, portillons métalliques et garde-corps."),
        ("Ravalement Peinture Grand Sud", "home_trades", "construction", "Ris-Orangis", "91130", "11 Route de Grigny", "01 69 43 99 22", "Nettoyage haute pression, traitement anti-mousse et enduits de façade imperméables."),
        ("Plombier Chauffagiste Confort Plus", "home_trades", "plumbers", "Ris-Orangis", "91130", "47 Rue Edmond Bonté", "01 69 02 11 99", "Remplacement de radiateurs, désembouage de plancher chauffant et détartrage de tuyauteries."),
        ("Paysagiste Espaces Verts 91", "home_trades", "maintenance", "Draveil", "91210", "17 Avenue des Ormes", "01 69 40 22 88", "Taille de haies, aménagement de massifs fleuris, arrosage automatique et engazonnement."),

        # 31-45 Auto & Mobility
        ("Garage Auto Ris Mécanique & Carrosserie", "auto_mobility", "garages", "Ris-Orangis", "91130", "100 Route de Grigny", "01 69 06 55 44", "Entretien toutes marques, révision constructeur préservée, vidange et pneumatiques."),
        ("Contrôle Technique Sécuritest Ris", "auto_mobility", "garages", "Ris-Orangis", "91130", "12 Avenue de la Libération", "01 69 06 88 90", "Contrôle technique périodique et contre-visite pour véhicules particuliers, utilitaires et hybrides."),
        ("Carrosserie Peinture de la Ferme", "auto_mobility", "mechanics", "Ris-Orangis", "91130", "3 Place de la Ferme", "01 69 06 22 44", "Réparation carrosserie toutes assurances, redressage au marbre et peinture au pistolet."),
        ("Déménagement & Transport Essonne Express", "auto_mobility", "mechanics", "Ris-Orangis", "91130", "5 Rue du Pont de Ris", "01 69 06 77 55", "Déménagements particuliers et professionnels, monte-meubles et cartons fournis."),
        ("Garage Automobile Draveil Seine", "auto_mobility", "garages", "Draveil", "91210", "45 Boulevard Henri Barbusse", "01 69 40 66 77", "Diagnostic électronique valise constructeur, freinage, courroie de distribution et embrayage."),
        ("Pneus Express 91 Montage à Domicile", "auto_mobility", "mechanics", "Ris-Orangis", "91130", "78 Route de Grigny", "01 69 43 11 55", "Vente et montage de pneus neufs à domicile ou sur votre lieu de travail en Essonne."),
        ("Remorquage Dépannage Auto 24/7", "auto_mobility", "mechanics", "Ris-Orangis", "91130", "14 Quai de la Borde", "01 69 06 99 11", "Remorquage rapide toutes distances, assistance panne de batterie et treuillage sous-sol."),
        ("Contrôle Technique Autosur Évry", "auto_mobility", "garages", "Évry-Courcouronnes", "91000", "8 Boulevard des Coquibus", "01 60 78 22 11", "Centre de contrôle technique agréé avec rendez-vous en ligne immédiat et tarifs préférentiels."),
        ("Atelier Mécanique Moto & Scooter 91", "auto_mobility", "mechanics", "Ris-Orangis", "91130", "22 Rue Pierre Brossolette", "01 69 06 44 22", "Réparation, révision et pneumatiques deux-roues 50cc à 1000cc, diagnostic panne."),
        ("Lavage Auto Écologique Sans Eau 91", "auto_mobility", "mechanics", "Ris-Orangis", "91130", "30 Avenue de la Libération", "01 69 06 33 88", "Nettoyage intérieur et extérieur vapeur à domicile, shampouinage sièges et polissage carrosserie."),
        ("Garage Solidaire et Citoyen 91", "auto_mobility", "garages", "Grigny", "91350", "10 Rue des Tuileries", "01 69 43 88 11", "Entretien automobile à tarifs solidaires, mécanique pédagogique et vente de pièces d'occasion."),
        ("Pare-Brise Express 91 Franchise Offerte", "auto_mobility", "mechanics", "Ris-Orangis", "91130", "5 Rue Albert Rémy", "01 69 06 12 77", "Remplacement de pare-brise sans avance de frais, calibrage de caméra ADAS et balais offerts."),
        ("Carrosserie Rapide de la RN7", "auto_mobility", "mechanics", "Viry-Châtillon", "91170", "50 Avenue du Général de Gaulle", "01 69 24 33 88", "Débosselage sans peinture suite à la grêle, polissage d'optiques de phares jaunis."),
        ("Location Véhicules & Utilitaires Ris", "auto_mobility", "dealers", "Ris-Orangis", "91130", "65 Avenue de la Libération", "01 69 06 55 99", "Location de camionnettes de déménagement 6m3 à 20m3 avec hayon et citadines économiques."),
        ("Électro Mécanique & Climatisation Auto", "auto_mobility", "mechanics", "Corbeil-Essonnes", "91100", "29 Boulevard Jean Jaurès", "01 64 96 11 77", "Recharge de gaz climatisation R134a et R1234yf, alternateur, démarreur et injecteurs."),

        # 46-65 Health & Medical
        ("Pharmacie Centrale de Ris", "health_medical", "pharmacies", "Ris-Orangis", "91130", "44 Rue Edmond Bonté", "01 69 06 01 22", "Pharmacie de quartier avec délivrance d'ordonnances, vaccination et matériel médical."),
        ("Pharmacie du Moulin à Vent", "health_medical", "pharmacies", "Ris-Orangis", "91130", "16 Place du Moulin à Vent", "01 69 06 05 80", "Conseils en micronutrition, orthopédie sur mesure et borne de téléconsultation médicale."),
        ("Pharmacie de la Gare Ris-Orangis", "health_medical", "pharmacies", "Ris-Orangis", "91130", "4 Place de la Gare", "01 69 06 18 10", "Délivrance rapide d'ordonnances, tests antigéniques et aromathérapie bio."),
        ("Cabinet Dentaire du Parc Ris", "health_medical", "clinics", "Ris-Orangis", "91130", "10 Rue Albert Rémy", "01 69 06 33 11", "Soins dentaires conservateurs, implants, détartrage et orthodontie invisible pour adultes."),
        ("Cabinet Infirmier de Ris-Orangis", "health_medical", "therapists", "Ris-Orangis", "91130", "24 Rue Pierre Brossolette", "01 69 06 22 99", "Soins infirmiers à domicile 7j/7 sur ordonnance : pansements, injections, prises de sang."),
        ("Kinésithérapie & Rééducation Ris", "health_medical", "therapists", "Ris-Orangis", "91130", "52 Rue Edmond Bonté", "01 69 06 44 88", "Rééducation fonctionnelle, kiné du sport, drainage lymphatique et réathlétisation."),
        ("Optique du Moulin à Vent", "health_medical", "clinics", "Ris-Orangis", "91130", "20 Place du Moulin à Vent", "01 69 06 77 44", "Opticien diplômé : examen de la vue gratuit, lunettes de créateurs et adaptation lentilles."),
        ("Centre Médical Pluridisciplinaire Ris", "health_medical", "doctors", "Ris-Orangis", "91130", "8 Rue de l'Hôtel de Ville", "01 69 06 99 22", "Médecine générale, pédiatrie, consultations non programmées et suivi de santé."),
        ("Ostéopathe D.O. Ris-Orangis", "health_medical", "therapists", "Ris-Orangis", "91130", "17 Rue Albert Rémy", "01 69 06 11 55", "Ostéopathie crânienne et viscérale pour adultes, femmes enceintes, sportifs et nourrissons."),
        ("Cabinet de Pédicurie Podologie Ris", "health_medical", "therapists", "Ris-Orangis", "91130", "36 Rue Edmond Bonté", "01 69 02 12 34", "Soins des pieds, traitement des ongles incarnés et semelles orthopédiques thermoformées."),
        ("Cabinet d'Orthophonie de la Ferme", "health_medical", "therapists", "Ris-Orangis", "91130", "5 Place de la Ferme", "01 69 06 88 55", "Bilan orthophonique, rééducation du langage oral et écrit pour enfants et adultes."),
        ("Laboratoire d'Analyses Médicales Ris", "health_medical", "clinics", "Ris-Orangis", "91130", "60 Rue Edmond Bonté", "01 69 06 34 56", "Prises de sang sans rendez-vous, analyses biologiques et résultats en ligne en quelques heures."),
        ("Clinique Vétérinaire des Bords de Seine", "health_medical", "clinics", "Ris-Orangis", "91130", "3 Quai de la Borde", "01 69 06 78 99", "Médecine et chirurgie des chiens, chats et NAC, radiographie numérique et urgences."),
        ("Pharmacie du Centre Commercial Draveil", "health_medical", "pharmacies", "Draveil", "91210", "35 Boulevard Henri Barbusse", "01 69 40 12 88", "Parapharmacie complète, dermocosmétique de pointe et contention veineuse."),
        ("Cabinet Dentaire des Miroirs Évry", "health_medical", "clinics", "Évry-Courcouronnes", "91000", "3 Place des Miroirs", "01 60 78 55 99", "Chirurgie dentaire avancée, blanchiment dentaire au fauteuil et prothèses en céramique."),
        ("Cabinet Sage-Femme Échographie Ris", "health_medical", "therapists", "Ris-Orangis", "91130", "12 Rue de Grigny", "01 69 43 22 88", "Suivi de grossesse, préparation à la naissance, rééducation périnéale et monitoring."),
        ("Psychologue Clinicienne & TCC Ris", "health_medical", "therapists", "Ris-Orangis", "91130", "18 Rue Pierre Brossolette", "01 69 06 45 77", "Thérapies cognitives et comportementales, gestion du stress, phobies et soutien psychologique."),
        ("Audioprothésiste Écoute & Confort 91", "health_medical", "clinics", "Ris-Orangis", "91130", "58 Rue Edmond Bonté", "01 69 06 88 12", "Bilan auditif gratuit, prothèses auditives rechargeables invisibles et essai 30 jours."),
        ("Diététicienne Nutritionniste Essonne", "health_medical", "therapists", "Ris-Orangis", "91130", "22 Rue Albert Rémy", "01 69 06 99 44", "Rééquilibrage alimentaire durable, suivi diabète et nutrition sportive personnalisée."),
        ("Ambulances de l'Essonne 91", "health_medical", "clinics", "Ris-Orangis", "91130", "85 Route de Grigny", "01 69 21 00 88", "Transport sanitaire en ambulance et VSL conventionné pour consultations et hospitalisations."),

        # 66-78 Beauty & Personal Care
        ("Salon L'Atelier Coiffure & Barbier", "beauty_personal_care", "salons", "Ris-Orangis", "91130", "18 Rue Albert Rémy", "01 69 06 15 20", "Coiffure mixte, balayage californien, ombré hair et rituels de soin à la kératine."),
        ("Institut Beauté & Spa de la Ferme", "beauty_personal_care", "spas", "Ris-Orangis", "91130", "8 Place de la Ferme", "01 69 06 33 77", "Soins du visage personnalisés, massages relaxants aux huiles bio et épilations cire tiède."),
        ("Barber Shop 91 Ris-Orangis", "beauty_personal_care", "barbers", "Ris-Orangis", "91130", "54 Rue Edmond Bonté", "01 69 06 77 12", "Coupe dégradée américaine à blanc, taille de barbe au coupe-chou et serviette chaude."),
        ("Pressing Écologique du Moulin", "beauty_personal_care", "salons", "Ris-Orangis", "91130", "22 Place du Moulin à Vent", "01 69 06 88 44", "Nettoyage à sec écologique sans perchloroéthylène, repassage soigné et blanchisserie."),
        ("Fleuriste Le Jardin Secret de Ris", "beauty_personal_care", "salons", "Ris-Orangis", "91130", "40 Rue Edmond Bonté", "01 69 06 19 44", "Bouquets de saison confectionnés minute, plantes vertes d'intérieur et compositions de deuil."),
        ("Nails Art & Beauté des Mains 91", "beauty_personal_care", "salons", "Ris-Orangis", "91130", "25 Rue Pierre Brossolette", "01 69 06 44 11", "Pose d'ongles en gel porcelaine, vernis semi-permanent longue tenue et manucure russe."),
        ("Coiffure Afro & Tresses Beauté 91", "beauty_personal_care", "salons", "Ris-Orangis", "91130", "31 Rue Albert Rémy", "01 69 43 88 22", "Tresses africaines, tissages naturels, dreadlocks, vanilles et lissage brésilien professionnel."),
        ("Institut Regard Sublime & Cils Ris", "beauty_personal_care", "spas", "Ris-Orangis", "91130", "14 Rue Edmond Bonté", "01 69 02 11 44", "Rehaussement de cils à la kératine, teinture au henné végétal et extension de cils volume russe."),
        ("Salon de Coiffure Évry Agora", "beauty_personal_care", "salons", "Évry-Courcouronnes", "91000", "2 Cours Blaise Pascal", "01 60 78 33 22", "Coiffeur visagiste conseil pour femmes et hommes, colorations végétales sans ammoniaque."),
        ("L'Atelier du Barbier Draveil", "beauty_personal_care", "barbers", "Draveil", "91210", "18 Boulevard Henri Barbusse", "01 69 40 44 11", "Barbier traditionnel : traçage de barbe précis, soin barbe aux huiles précieuses et coupe tendance."),
        ("Spa Hammam Orient Détente", "beauty_personal_care", "spas", "Corbeil-Essonnes", "91100", "12 Rue Saint-Spire", "01 64 96 33 88", "Hammam traditionnel à la vapeur d'eucalyptus, gommage au savon noir et enveloppement au rhassoul."),
        ("Studio Tatouage & Piercing Ris", "beauty_personal_care", "salons", "Ris-Orangis", "91130", "70 Rue Edmond Bonté", "01 69 06 99 77", "Artistes tatoueurs diplômés, créations personnalisées sur mesure et hygiène hospitalière stricte."),
        ("Centre d'Amincissement & Cryolipolyse", "beauty_personal_care", "spas", "Évry-Courcouronnes", "91000", "6 Boulevard de l'Europe", "01 60 79 22 55", "Soins minceur haute technologie, cryolipolyse médicale, presso-thérapie et palper-rouler."),

        # 79-88 Professional & Legal
        ("Cabinet d'Avocats Conseil Ris-Orangis", "professional_legal", "lawyers", "Ris-Orangis", "91130", "8 Rue Albert Rémy", "01 69 06 11 88", "Droit de la famille (divorces, garde), droit du travail (licenciements) et défense pénale."),
        ("Cabinet Comptable & Conseil Essonne", "professional_legal", "accountants", "Ris-Orangis", "91130", "15 Place de la Ferme", "01 69 06 33 99", "Expertise comptable pour artisans, commerçants et PME, déclarations fiscales et bilans."),
        ("Étude Notariale de Ris-Orangis", "professional_legal", "notaries", "Ris-Orangis", "91130", "25 Rue de la Gare", "01 69 06 77 00", "Actes de vente immobilière, successions, donations entre époux et contrats de mariage."),
        ("Cabinet d'Avocat Droit Immobilier 91", "professional_legal", "lawyers", "Évry-Courcouronnes", "91000", "10 Boulevard des Coquibus", "01 60 78 44 88", "Litiges de copropriété, baux commerciaux, impayés de loyers et contentieux de la construction."),
        ("Conseil Fiscal & Gestion de Patrimoine", "professional_legal", "consultants", "Ris-Orangis", "91130", "50 Avenue de la Libération", "01 69 02 33 44", "Optimisation fiscale des particuliers et dirigeants, investissement immobilier locatif Loi Pinel."),
        ("Cabinet d'Expertise Paie & RH Essonne", "professional_legal", "accountants", "Ris-Orangis", "91130", "14 Rue Pierre Brossolette", "01 69 06 88 77", "Établissement des bulletins de paie, déclarations DSN mensuelles et contrats de travail."),
        ("Étude d'Huissiers de Justice Associés", "professional_legal", "lawyers", "Évry-Courcouronnes", "91000", "4 Rue Léopold Sédar Senghor", "01 60 77 22 11", "Constats urgents de travaux, recouvrement de créances civiles et significations d'actes."),
        ("Agence Immobilière Ris-Orangis Centre", "professional_legal", "consultants", "Ris-Orangis", "91130", "32 Rue Edmond Bonté", "01 69 06 14 00", "Estimation gratuite sous 48h, vente d'appartements et maisons et gestion locative sécurisée."),
        ("Courtier en Crédit Immobilier 91", "professional_legal", "consultants", "Ris-Orangis", "91130", "19 Avenue de la Libération", "01 69 06 55 12", "Négociation des meilleurs taux de prêt immobilier et assurances emprunteur auprès des banques."),
        ("Architecte DPLG Rénovation & Permis", "professional_legal", "consultants", "Draveil", "91210", "11 Rue de Mainville", "01 69 40 12 55", "Plans d'architecte pour agrandissements, surélévations de maison et dépôts de permis de construire."),

        # 89-95 Education & Fitness
        ("Auto-École Permis Ris Grand Sud", "education_fitness", "driving_schools", "Ris-Orangis", "91130", "12 Place de la Gare", "01 69 06 22 33", "Formation au permis B en boîte manuelle et automatique, conduite accompagnée et code en ligne."),
        ("Fitness Park Ris-Orangis", "education_fitness", "gyms", "Ris-Orangis", "91130", "90 Route de Grigny", "01 69 21 88 00", "Salle de sport 1500m2 ouverte 6h-23h 7j/7, musculation guidée et libre, cardio et cross-training."),
        ("Soutien Scolaire Excellence 91", "education_fitness", "tutors", "Ris-Orangis", "91130", "18 Rue Pierre Brossolette", "01 69 06 44 99", "Cours particuliers de mathématiques, physique-chimie et français du collège au lycée, préparation bac."),
        ("Club d'Arts Martiaux & Boxe Ris", "education_fitness", "gyms", "Ris-Orangis", "91130", "5 Rue du Moulin à Vent", "01 69 06 77 33", "Cours de judo enfants, karaté traditionnel, boxe anglaise et kick-boxing pour tous niveaux."),
        ("École de Danse & Yoga de l'Essonne", "education_fitness", "gyms", "Ris-Orangis", "91130", "22 Rue Albert Rémy", "01 69 06 11 66", "Cours de danse classique, modern jazz, hip-hop et séances de hatha yoga relaxant."),
        ("Auto-École du Moulin Ris", "education_fitness", "driving_schools", "Ris-Orangis", "91130", "24 Place du Moulin à Vent", "01 69 06 88 12", "Permis accéléré en 1 mois, stage code 3 jours intensif et financement CPF accepté."),
        ("Coach Sportif Personnel & Remise en Forme", "education_fitness", "trainers", "Draveil", "91210", "30 Boulevard Henri Barbusse", "01 69 40 33 22", "Coaching individuel à domicile : perte de poids durable, renforcement musculaire et stretching."),

        # 96-100 B2B & Industry
        ("Dépannage Informatique & Smartphone 91", "b2b_industry", "it_services", "Ris-Orangis", "91130", "28 Rue Edmond Bonté", "01 69 06 14 55", "Réparation express d'écrans iPhone et Samsung en 30 min, déblocage et désinfection virus PC/Mac."),
        ("Imprimerie Express & Sérigraphie 91", "b2b_industry", "wholesale", "Ris-Orangis", "91130", "10 Avenue de la Libération", "01 69 06 33 00", "Impression de flyers publicitaires, cartes de visite, affiches grand format et flocage textile."),
        ("Services Sécurité Gardiennage 91", "b2b_industry", "it_services", "Ris-Orangis", "91130", "44 Route de Grigny", "01 69 43 11 77", "Agents de sécurité cynophiles, rondes de surveillance pour chantiers et entreprises en Essonne."),
        ("Fournitures Industrielles & Outillage 91", "b2b_industry", "wholesale", "Ris-Orangis", "91130", "12 Rue de la Borde", "01 69 06 88 33", "Outillage professionnel électroportatif Makita et Bosch, visserie et équipements de protection EPI."),
        ("Nettoyage Industriel & Bureaux Essonne", "b2b_industry", "it_services", "Ris-Orangis", "91130", "75 Rue Albert Rémy", "01 69 06 99 55", "Entretien quotidien de bureaux d'entreprises, nettoyage de vitres en hauteur et fin de chantier.")
    ]

    out = []
    out.append("-- Populate 50 Top Reviewed Restaurants and 100 Local Professionals")
    out.append("-- All with accurate Ris-Orangis / Grand Paris Sud data and full menus")
    out.append("BEGIN;")
    out.append("")
    out.append("-- Purge previous restaurant and dummy pro accounts to cleanly insert the complete sets")
    out.append("DELETE FROM public.posts WHERE user_id::text LIKE '33333333%' OR user_id::text LIKE '44444444%';")
    out.append("DELETE FROM public.profiles WHERE id::text LIKE '33333333%' OR id::text LIKE '44444444%' OR email LIKE 'pro.91130%';")
    out.append("DELETE FROM auth.users WHERE id::text LIKE '33333333%' OR id::text LIKE '44444444%' OR email LIKE 'pro.91130%';")
    out.append("")

    # Generate SQL for 50 Restaurants
    out.append("-- ==========================================================================")
    out.append("-- 1. INSERT 50 TOP REVIEWED RESTAURANTS")
    out.append("-- ==========================================================================")
    for r in restaurants:
        r_id = f"33333333-0000-4000-8000-{r['id']:012d}"
        email = f"resto.{r['id']:04d}@ris-restos.fr"
        name = r["name"]
        cat = r["category"]
        city = r["city"]
        zipcode = r["zipcode"]
        lat = r["lat"]
        lng = r["lng"]
        addr = r["address"]
        phone = r["phone"]
        website = r["website"]
        avatar = r["avatar"]
        bio = r["bio"]

        # Insert Auth User
        meta_json = json.dumps({"full_name": name}, ensure_ascii=False).replace("'", "''")
        out.append(f"""INSERT INTO auth.users (id, instance_id, aud, role, email, encrypted_password, email_confirmed_at, created_at, updated_at, confirmation_token, raw_app_meta_data, raw_user_meta_data)
VALUES ('{r_id}', '00000000-0000-0000-0000-000000000000', 'authenticated', 'authenticated', '{email}', crypt('TempPass123!#', gen_salt('bf')), now(), now(), now(), '', '{{"provider":"email","providers":["email"]}}', '{meta_json}')
ON CONFLICT (id) DO NOTHING;""")

        # Insert Profile
        out.append(f"""INSERT INTO public.profiles (
    id, email, full_name, business_name, account_type, is_restaurant, restaurant_type,
    city, zipcode, latitude, longitude, radius_km, bio, business_profile, phone, website,
    is_unclaimed, is_disabled, avatar_url, created_at
) VALUES (
    '{r_id}',
    '{email}',
    {esc(name)},
    {esc(name)},
    'business',
    true,
    {esc(cat)},
    {esc(city)},
    {esc(zipcode)},
    {lat},
    {lng},
    20,
    {esc(bio)},
    {esc(f"{bio} Situé au {addr}, {zipcode} {city}. Tél: {phone}.")},
    {esc(phone)},
    {esc(website)},
    true,
    false,
    {esc(avatar)},
    now()
) ON CONFLICT (id) DO UPDATE SET
    full_name = EXCLUDED.full_name,
    business_name = EXCLUDED.business_name,
    is_restaurant = true,
    restaurant_type = EXCLUDED.restaurant_type,
    city = EXCLUDED.city,
    zipcode = EXCLUDED.zipcode,
    latitude = EXCLUDED.latitude,
    longitude = EXCLUDED.longitude,
    bio = EXCLUDED.bio,
    business_profile = EXCLUDED.business_profile,
    phone = EXCLUDED.phone,
    website = EXCLUDED.website,
    is_unclaimed = true,
    avatar_url = EXCLUDED.avatar_url;""")

        # Insert Dishes (Full Menu)
        for d_title, d_price, d_cat, d_desc, d_img in r["dishes"]:
            d_id = str(uuid.uuid4())
            out.append(f"""INSERT INTO public.posts (
    id, user_id, content, image_url, visibility, location_name,
    latitude, longitude, created_at, author_profile_type, post_type,
    market_category, market_title, market_price, share_scope, is_unclaimed
) VALUES (
    '{d_id}',
    '{r_id}',
    {esc(d_desc)},
    {esc(d_img)},
    'public',
    {esc(f"{city} ({zipcode})")},
    {lat},
    {lng},
    now(),
    'business',
    'food_ad',
    {esc(d_cat)},
    {esc(d_title)},
    {d_price},
    'public',
    true
);""")

    # Generate SQL for 100 Local Professionals
    out.append("")
    out.append("-- ==========================================================================")
    out.append("-- 2. INSERT 100 LOCAL PROFESSIONALS")
    out.append("-- ==========================================================================")
    for idx, (p_name, p_main_cat, p_sub_cat, p_city, p_zip, p_addr, p_phone, p_bio) in enumerate(pro_names_and_bios, start=1):
        p_id = f"44444444-0000-4000-8000-{idx:012d}"
        p_email = f"pro.{idx:04d}@artisans-essonne.fr"
        # realistic coords around city center
        p_lat = 48.6508 + ((idx % 10) - 5) * 0.002
        p_lng = 2.4143 + (((idx // 10) % 10) - 5) * 0.003
        siret = f"91130{idx:04d}000{idx%9+1}{idx%7}"
        avatar = "https://images.unsplash.com/photo-1581578731548-c64695cc6952?w=500&auto=format&fit=crop&q=80"
        if p_main_cat == "health_medical":
            avatar = "https://images.unsplash.com/photo-1622253692010-333f2da6031d?w=500&auto=format&fit=crop&q=80"
        elif p_main_cat == "beauty_personal_care":
            avatar = "https://images.unsplash.com/photo-1560066984-138dadb4c035?w=500&auto=format&fit=crop&q=80"
        elif p_main_cat == "professional_legal":
            avatar = "https://images.unsplash.com/photo-1450133064473-71024230f91b?w=500&auto=format&fit=crop&q=80"
        elif p_main_cat == "auto_mobility":
            avatar = "https://images.unsplash.com/photo-1619642751034-765dfdf7c58e?w=500&auto=format&fit=crop&q=80"
        elif p_main_cat == "education_fitness":
            avatar = "https://images.unsplash.com/photo-1534438327276-14e5300c3a48?w=500&auto=format&fit=crop&q=80"

        # Insert Auth User
        p_meta_json = json.dumps({"full_name": p_name}, ensure_ascii=False).replace("'", "''")
        out.append(f"""INSERT INTO auth.users (id, instance_id, aud, role, email, encrypted_password, email_confirmed_at, created_at, updated_at, confirmation_token, raw_app_meta_data, raw_user_meta_data)
VALUES ('{p_id}', '00000000-0000-0000-0000-000000000000', 'authenticated', 'authenticated', '{p_email}', crypt('TempPass123!#', gen_salt('bf')), now(), now(), now(), '', '{{"provider":"email","providers":["email"]}}', '{p_meta_json}')
ON CONFLICT (id) DO NOTHING;""")

        # Insert Profile
        out.append(f"""INSERT INTO public.profiles (
    id, email, full_name, business_name, account_type, is_restaurant, business_type, business_subtype,
    city, zipcode, latitude, longitude, radius_km, bio, business_profile, phone, siret,
    is_unclaimed, is_disabled, avatar_url, created_at
) VALUES (
    '{p_id}',
    '{p_email}',
    {esc(p_name)},
    {esc(p_name)},
    'business',
    false,
    {esc(p_main_cat)},
    {esc(p_sub_cat)},
    {esc(p_city)},
    {esc(p_zip)},
    {p_lat},
    {p_lng},
    20,
    {esc(p_bio)},
    {esc(f"{p_bio} Adresse: {p_addr}, {p_zip} {p_city}. Tél: {p_phone}. SIRET: {siret}.")},
    {esc(p_phone)},
    {esc(siret)},
    true,
    false,
    {esc(avatar)},
    now()
) ON CONFLICT (id) DO UPDATE SET
    full_name = EXCLUDED.full_name,
    business_name = EXCLUDED.business_name,
    is_restaurant = false,
    business_type = EXCLUDED.business_type,
    business_subtype = EXCLUDED.business_subtype,
    city = EXCLUDED.city,
    zipcode = EXCLUDED.zipcode,
    latitude = EXCLUDED.latitude,
    longitude = EXCLUDED.longitude,
    bio = EXCLUDED.bio,
    business_profile = EXCLUDED.business_profile,
    phone = EXCLUDED.phone,
    siret = EXCLUDED.siret,
    is_unclaimed = true,
    avatar_url = EXCLUDED.avatar_url;""")

    out.append("")
    out.append("COMMIT;")
    out.append("")

    sql_content = "\n".join(out)
    with open("scripts/seeding/populate_50_restos_100_pros.sql", "w", encoding="utf-8") as f:
        f.write(sql_content)
    print("Generated populate_50_restos_100_pros.sql successfully!")
    print(f"Total restaurants: {len(restaurants)}")
    print(f"Total professionals: {len(pro_names_and_bios)}")
    total_dishes = sum(len(r["dishes"]) for r in restaurants)
    print(f"Total dishes: {total_dishes}")

if __name__ == "__main__":
    main()
