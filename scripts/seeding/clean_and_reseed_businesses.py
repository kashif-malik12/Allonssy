# scripts/seeding/clean_and_reseed_businesses.py
# Removes corporate chain head offices and seeds 25 curated, hyperlocal Ris-Orangis artisans & professionals.

import uuid

ARTISANS = [
    {
        "name": "Plomberie Chauffage Ris-Orangis",
        "job": "Artisan Plombier Chauffagiste RGE",
        "category": "home_trades",
        "subtype": "plumbers",
        "lat": 48.6512, "lng": 2.4135,
        "siret": "91130000100012",
        "phone": "01 69 06 14 20",
        "bio": "Dépannage plomberie d'urgence 7j/7, recherche de fuite, débouchage canalisation, installation chaudière gaz et chauffe-eau thermodynamique à Ris-Orangis et environs.",
        "address": "14 Avenue de la Libération, 91130 Ris-Orangis"
    },
    {
        "name": "Électricité Générale Essonne 91",
        "job": "Artisan Électricien Qualifié",
        "category": "home_trades",
        "subtype": "electricians",
        "lat": 48.6525, "lng": 2.4148,
        "siret": "91130000200025",
        "phone": "06 42 18 90 33",
        "bio": "Mise aux normes électriques NFC 15-100, remplacement de tableau électrique, domotique, dépannage rapide panne de courant à Ris-Orangis et Grand Paris Sud.",
        "address": "28 Rue Pierre Brossolette, 91130 Ris-Orangis"
    },
    {
        "name": "Serrurerie Dépannage Express Ris",
        "job": "Maître Serrurier & Métallier",
        "category": "home_trades",
        "subtype": "maintenance",
        "lat": 48.6538, "lng": 2.4110,
        "siret": "91130000300038",
        "phone": "01 69 43 22 10",
        "bio": "Ouverture de porte claquée sans dégât, changement de cylindre haute sécurité A2P, blindage de porte et pose de volets roulants sécurisés 24h/24.",
        "address": "5 Place de la Gare, 91130 Ris-Orangis"
    },
    {
        "name": "Rénovation Peinture & Déco Essonne",
        "job": "Peintre en Bâtiment & Décorateur",
        "category": "home_trades",
        "subtype": "construction",
        "lat": 48.6498, "lng": 2.4162,
        "siret": "91130000400041",
        "phone": "06 55 12 87 64",
        "bio": "Peinture intérieure, ravalement de façade, pose de parquet flottant, enduit lisse et isolation thermique des murs à Ris-Orangis. Devis gratuit sous 48h.",
        "address": "9 Rue du Clos Langlet, 91130 Ris-Orangis"
    },
    {
        "name": "Garage Auto Ris Mécanique & Carrosserie",
        "job": "Mécanicien Réparateur Agréé",
        "category": "auto_mobility",
        "subtype": "garages",
        "lat": 48.6475, "lng": 2.4180,
        "siret": "91130000500054",
        "phone": "01 69 02 88 44",
        "bio": "Entretien toutes marques, révision constructeur garantie, freinage, kit de distribution, diagnostic valise électronique, carrosserie et pré-contrôle technique.",
        "address": "72 Route de Grigny, 91130 Ris-Orangis"
    },
    {
        "name": "Menuiserie Bois & Agencement 91",
        "job": "Artisan Menuisier Ébéniste",
        "category": "home_trades",
        "subtype": "construction",
        "lat": 48.6505, "lng": 2.4125,
        "siret": "91130000600067",
        "phone": "06 78 91 23 45",
        "bio": "Fabrication et pose de fenêtres PVC/Alu double vitrage, placards sur mesure, dressings, portes d'entrée et terrasses en bois exotique.",
        "address": "18 Rue Edmond Rostand, 91130 Ris-Orangis"
    },
    {
        "name": "Essonne Parcs & Jardins",
        "job": "Paysagiste & Élagueur Grimpeur",
        "category": "home_trades",
        "subtype": "maintenance",
        "lat": 48.6542, "lng": 2.4175,
        "siret": "91130000700070",
        "phone": "01 69 21 34 56",
        "bio": "Création paysagère, tonte de pelouse, taille de haies, abattage délicat et élagage d'arbres, pose de clôtures et gazon en rouleau. Éligible crédit d'impôt 50%.",
        "address": "4 Rue Albert Rémy, 91130 Ris-Orangis"
    },
    {
        "name": "Toiture & Couverture Ris-Orangis",
        "job": "Artisan Couvreur Zingueur",
        "category": "home_trades",
        "subtype": "construction",
        "lat": 48.6480, "lng": 2.4150,
        "siret": "91130000800083",
        "phone": "06 14 25 36 47",
        "bio": "Rénovation de toiture tuiles et ardoises, étanchéité zinc, nettoyage et démoussage hydrofuge, pose de velux et isolation des combles perdus.",
        "address": "31 Rue de la Fontaine, 91130 Ris-Orangis"
    },
    {
        "name": "Carrelage & Rénovation Salle de Bain",
        "job": "Artisan Carreleur Mosaïste",
        "category": "home_trades",
        "subtype": "construction",
        "lat": 48.6518, "lng": 2.4102,
        "siret": "91130000900096",
        "phone": "06 88 99 11 22",
        "bio": "Pose de carrelage grand format, faïence murale, création de douches à l'italienne sur mesure, étanchéité sous carrelage et rénovation complète de sanitaires.",
        "address": "12 Rue de l'Avenir, 91130 Ris-Orangis"
    },
    {
        "name": "Salon L'Atelier Coiffure & Barbier",
        "job": "Artisan Coiffeur Visagiste & Barbier",
        "category": "beauty_personal_care",
        "subtype": "salons",
        "lat": 48.6510, "lng": 2.4140,
        "siret": "91130001000100",
        "phone": "01 69 06 55 80",
        "bio": "Coupes hommes, femmes et enfants, taille de barbe au rasoir traditionnel avec soin serviette chaude, balayage, mèches et coloration sans ammoniaque.",
        "address": "45 Rue Pierre Brossolette, 91130 Ris-Orangis"
    },
    {
        "name": "Institut Beauté & Spa de la Ferme",
        "job": "Esthéticienne & Praticienne Spa",
        "category": "beauty_personal_care",
        "subtype": "spas",
        "lat": 48.6530, "lng": 2.4120,
        "siret": "91130001100113",
        "phone": "01 69 43 89 70",
        "bio": "Soins du visage bio, massages bien-être aux huiles chaudes, épilation douce, manucure russe et pose de vernis semi-permanent dans un cadre relaxant.",
        "address": "Place de la Ferme du Temple, 91130 Ris-Orangis"
    },
    {
        "name": "Optique du Moulin à Vent",
        "job": "Opticien Lunetier Diplômé",
        "category": "health_medical",
        "subtype": "clinics",
        "lat": 48.6515, "lng": 2.4138,
        "siret": "91130001200126",
        "phone": "01 69 06 18 90",
        "bio": "Examen de la vue gratuit, lunettes de vue et solaires créateurs, verres progressifs haute précision français, adaptation lentilles de contact et tiers payant.",
        "address": "8 Place du Moulin à Vent, 91130 Ris-Orangis"
    },
    {
        "name": "Pharmacie Centrale de Ris",
        "job": "Docteur en Pharmacie",
        "category": "health_medical",
        "subtype": "pharmacies",
        "lat": 48.6502, "lng": 2.4145,
        "siret": "91130001300139",
        "phone": "01 69 06 01 22",
        "bio": "Délivrance ordonnances, conseils en parapharmacie, matériel médical et maintien à domicile, vaccination, orthopédie et aromathérapie certifiée.",
        "address": "2 Rue du Temple, 91130 Ris-Orangis"
    },
    {
        "name": "Auto-École Permis Ris Grand Sud",
        "job": "Moniteur Diplômé d'État",
        "category": "education_fitness",
        "subtype": "driving_schools",
        "lat": 48.6522, "lng": 2.4115,
        "siret": "91130001400142",
        "phone": "01 69 43 11 00",
        "bio": "Formation au permis B boîte manuelle et automatique, conduite accompagnée AAC, stage accéléré, code de la route en ligne et perfectionnement seniors.",
        "address": "19 Avenue de Rigny, 91130 Ris-Orangis"
    },
    {
        "name": "Dépannage Informatique & Smartphone 91",
        "job": "Technicien Réparateur Informatique",
        "category": "b2b_industry",
        "subtype": "it_services",
        "lat": 48.6490, "lng": 2.4155,
        "siret": "91130001500155",
        "phone": "06 99 88 77 66",
        "bio": "Réparation écran iPhone et Android en 30 min, dépannage PC/Mac, suppression de virus, récupération de données perdues et installation réseaux Wifi.",
        "address": "11 Rue Jean Jaurès, 91130 Ris-Orangis"
    },
    {
        "name": "Déménagement & Transport Essonne Express",
        "job": "Transporteur Professionnel & Déménageur",
        "category": "auto_mobility",
        "subtype": "mechanics",
        "lat": 48.6465, "lng": 2.4185,
        "siret": "91130001600168",
        "phone": "01 69 02 45 78",
        "bio": "Déménagement de particuliers et entreprises, monte-meuble jusqu'au 8ème étage, transport de charges lourdes (pianos) et stockage en garde-meuble sécurisé.",
        "address": "85 Route de Grigny, 91130 Ris-Orangis"
    },
    {
        "name": "Cordonnerie & Clés Minute de la Gare",
        "job": "Artisan Cordonnier & Clé Minute",
        "category": "home_trades",
        "subtype": "maintenance",
        "lat": 48.6545, "lng": 2.4098,
        "siret": "91130001700171",
        "phone": "01 69 43 05 60",
        "bio": "Réparation de chaussures cuir, ressemelage, couture maroquinerie, reproduction de clés minute maison et auto, plaques d'immatriculation et tampons encreurs.",
        "address": "2 Rue de la Gare, 91130 Ris-Orangis"
    },
    {
        "name": "Pressing Écologique du Moulin",
        "job": "Artisan Teinturier Blanchisseur",
        "category": "beauty_personal_care",
        "subtype": "salons",
        "lat": 48.6513, "lng": 2.4152,
        "siret": "91130001800184",
        "phone": "01 69 06 44 12",
        "bio": "Nettoyage à sec écologique sans perchloroéthylène (aquanettoyage), repassage soigné de chemises, nettoyage couettes, tapis et retouches couture express.",
        "address": "6 Place du Moulin à Vent, 91130 Ris-Orangis"
    },
    {
        "name": "Cabinet Infirmier de Ris-Orangis",
        "job": "Infirmier Diplômé d'État",
        "category": "health_medical",
        "subtype": "therapists",
        "lat": 48.6508, "lng": 2.4132,
        "siret": "91130001900197",
        "phone": "01 69 06 20 40",
        "bio": "Soins infirmiers à domicile et au cabinet sur rendez-vous 7j/7 : pansements simples et complexes, injections, prélèvements sanguins, perfusions et suivi diabète.",
        "address": "15 Rue Pierre Brossolette, 91130 Ris-Orangis"
    },
    {
        "name": "Kinésithérapie & Rééducation Essonne Ris",
        "job": "Masseur-Kinésithérapeute D.E.",
        "category": "health_medical",
        "subtype": "therapists",
        "lat": 48.6528, "lng": 2.4142,
        "siret": "91130002000201",
        "phone": "01 69 43 77 55",
        "bio": "Rééducation orthopédique et traumatologique, kiné du sport, drainage lymphatique, rééducation post-opératoire et balnéothérapie dans un cabinet équipé.",
        "address": "22 Rue d'Alsace, 91130 Ris-Orangis"
    },
    {
        "name": "Climatisation & Pompes à Chaleur 91",
        "job": "Artisan Frigoriste Certifié F-Gaz",
        "category": "home_trades",
        "subtype": "maintenance",
        "lat": 48.6472, "lng": 2.4168,
        "siret": "91130002100214",
        "phone": "06 23 45 67 89",
        "bio": "Installation et entretien de climatisation réversible, pompe à chaleur air/air et air/eau, VMC double flux. Certifié RGE QualiPAC pour les aides de l'État.",
        "address": "54 Rue du Clos Langlet, 91130 Ris-Orangis"
    },
    {
        "name": "Artisan Vitrier Miroitier Essonne",
        "job": "Artisan Vitrier Miroitier",
        "category": "home_trades",
        "subtype": "construction",
        "lat": 48.6533, "lng": 2.4128,
        "siret": "91130002200227",
        "phone": "01 69 43 90 12",
        "bio": "Remplacement de vitre cassée en urgence, pose de double et triple vitrage phonique, miroiterie sur mesure, crédences de cuisine en verre laqué et vitrines.",
        "address": "3 Rue de Bourgogne, 91130 Ris-Orangis"
    },
    {
        "name": "Fleuriste Le Jardin Secret de Ris",
        "job": "Artisan Fleuriste Créateur",
        "category": "beauty_personal_care",
        "subtype": "salons",
        "lat": 48.6506, "lng": 2.4146,
        "siret": "91130002300230",
        "phone": "01 69 06 33 21",
        "bio": "Bouquets de fleurs fraîches de saison, compositions florales pour mariages, anniversaires et deuils, plantes vertes d'intérieur et livraison à domicile.",
        "address": "10 Rue du Temple, 91130 Ris-Orangis"
    },
    {
        "name": "Cabinet Comptable & Conseil Essonne Ris",
        "job": "Expert-Comptable Diplômé",
        "category": "professional_legal",
        "subtype": "accountants",
        "lat": 48.6492, "lng": 2.4130,
        "siret": "91130002400243",
        "phone": "01 69 06 80 90",
        "bio": "Tenue de comptabilité, déclarations fiscales (TVA, liasse), fiches de paie et contrats de travail, création d'entreprise et optimisation pour commerçants et artisans.",
        "address": "12 Avenue de la Libération, 91130 Ris-Orangis"
    },
    {
        "name": "Cabinet d'Avocats Conseil Ris-Orangis",
        "job": "Avocat au Barreau de l'Essonne",
        "category": "professional_legal",
        "subtype": "lawyers",
        "lat": 48.6501, "lng": 2.4122,
        "siret": "91130002500256",
        "phone": "01 69 43 60 70",
        "bio": "Droit de la famille (divorce, garde d'enfants), droit du travail et licenciement, litiges commerciaux, baux d'habitation et défense pénale en Essonne.",
        "address": "25 Rue Edmond Rostand, 91130 Ris-Orangis"
    }
]

def generate_sql():
    lines = [
        "-- Clean obsolete corporate entities and seed 25 curated Ris-Orangis artisans",
        "BEGIN;",
        "",
        "-- 1. Delete old corporate chain profiles from profiles and auth.users",
        "DELETE FROM public.profiles WHERE is_unclaimed = true AND is_restaurant = false;",
        "DELETE FROM auth.users WHERE email LIKE 'pro.%@allonssy.local';",
        ""
    ]
    
    for a in ARTISANS:
        uid = str(uuid.uuid4())
        name = a["name"].replace("'", "''")
        job = a["job"].replace("'", "''")
        bio = a["bio"].replace("'", "''")
        cat = a["category"]
        sub = a["subtype"]
        lat = a["lat"]
        lng = a["lng"]
        siret = a["siret"]
        phone = a["phone"]
        addr = a["address"].replace("'", "''")
        email = f"pro.{siret}@allonssy.local"
        
        lines.append(f"""
INSERT INTO auth.users (
  id, aud, role, email, created_at, updated_at
) VALUES (
  '{uid}', 'authenticated', 'authenticated', '{email}', now(), now()
) ON CONFLICT (id) DO NOTHING;

INSERT INTO public.profiles (
  id, full_name, business_name, job_title, business_type, business_subtype,
  business_profile, siret, phone, city, zipcode, latitude, longitude,
  account_type, is_restaurant, is_unclaimed, external_source, external_place_id, is_disabled
) VALUES (
  '{uid}', '{name}', '{name}', '{job}', '{cat}', '{sub}',
  '{bio} (Adresse : {addr})', '{siret}', '{phone}', 'Ris-Orangis', '91130', {lat}, {lng},
  'business', false, true, 'curated_ris_orangis', '{siret}', false
);
""")

    lines.append("COMMIT;")
    lines.append("NOTIFY pgrst, 'reload schema';")
    return "\n".join(lines)

if __name__ == "__main__":
    sql = generate_sql()
    out = "scripts/seeding/clean_and_reseed_businesses_output.sql"
    with open(out, "w", encoding="utf-8") as f:
        f.write(sql)
    print(f"Generated clean seed SQL for 25 Ris-Orangis artisans at: {out}")
