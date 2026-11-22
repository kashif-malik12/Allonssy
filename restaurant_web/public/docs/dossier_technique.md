# DOSSIER TECHNIQUE ET JURIDIQUE DE CONFORMITÉ FISCALE
## Système de Caisse Sécurisé – Allonssy Restaurant POS (v1.0.0)

**Cadre Légal :** Article 286, I-3° bis du Code Général des Impôts (CGI)  
**Doctrine Administrative :** BOFiP BOI-TVA-DECLA-30-10-30 & Modèle BOI-LETTRE-000242  
**Droit de Contrôle :** Article L. 80 O du Livre des Procédures Fiscales (LPF)  
**Conservation des Données :** Article L. 102 B du Livre des Procédures Fiscales (Délai légal de 6 ans)  

---

### 1. IDENTIFICATION DE LA SOCIÉTÉ ÉDITRICE

* **Dénomination sociale :** TRADISTER
* **Forme juridique :** Société par Actions Simplifiée (SAS) au capital variable
* **Numéro SIREN :** 988 318 945
* **Numéro SIRET (Siège social) :** 988 318 945 00017
* **Code NAF / APE :** 62.02A (Conseil en systèmes et logiciels informatiques)
* **Siège social :** 11 Rue du Château d'Eau, 13ème Étage, Appt 132, 91130 Ris-Orangis, France
* **N° de TVA Intracommunautaire :** FR42 988 318 945
* **Représentant légal / Dirigeant :** Bisma KASHIF, Président de SAS
* **Plateforme exploitée :** Allonssy.com / Allonssy POS

---

### 2. IDENTIFICATION DE LA SOLUTION LOGICIELLE

* **Nom du logiciel :** Allonssy Restaurant POS
* **Version certifiée :** 1.0.0 (Web Cloud Architecture)
* **Type de solution :** Système d'encaissement et de gestion de commandes pour la restauration commerciale (B2C)
* **Date de mise sur le marché :** 22 Novembre 2026
* **Hébergement & Infrastructure :** Serveurs dédiés sécurisés en Union Européenne, base de données PostgreSQL managée avec chiffrement au repos et en transit (TLS 1.3 / SSL).

---

### 3. JUSTIFICATION TECHNIQUE DES 4 CONDITIONS LÉGALES (Art. 286 I-3° bis CGI)

#### Condition 1 : L'Inaltérabilité des Données
Le logiciel garantit que toute donnée d'encaissement enregistrée ne peut faire l'objet d'aucune modification ni suppression occulte :
1. **Verrouillage au niveau du moteur de base de données :**
   Un déclencheur PostgreSQL (`trg_guard_order_inalterability`) est exécuté au niveau serveur avant toute tentative de `DELETE` ou d'`UPDATE` sur la table `public.restaurant_orders`.
2. **Interdiction absolue de suppression :**
   Toute tentative de suppression d'un ticket ayant le statut `completed` déclenche une exception SQL bloquante :
   `RAISE EXCEPTION 'Loi anti-fraude (Art. 286 I-3° bis CGI): Suppression d''un ticket encaissé strictement interdite.'`
3. **Immutabilité des champs fiscaux :**
   Les champs `order_number`, `total_amount`, `total_ht`, `tva_10`, `tva_5_5`, `tva_20`, `payment_method`, `signature_hash`, `store_id` et `created_at` sont strictement verrouillés en mise à jour dès l'encaissement.
4. **Gestion légale des corrections :**
   Toute annulation d'erreur ou retour client fait impérativement l'objet d'un ticket d'avoir ou de remboursement (`is_refund = TRUE` avec référence `refund_of_order_id`), sans jamais altérer le ticket d'origine.

#### Condition 2 : La Sécurisation des Données
Le système assure l'intégrité et la traçabilité continue de chaque règlement au moyen d'un chaînage cryptographique :
1. **Algorithme de scellement SHA-256 :**
   À l'encaissement de chaque commande, le déclencheur `trg_seal_order_trigger` calcule une empreinte cryptographique SHA-256 irréversible intégrant :
   $$\text{Hash}_n = \text{SHA256}(\text{store\_id} + \text{order\_id} + \text{order\_number} + \text{created\_at} + \text{total\_amount} + \text{tva\_10} + \text{tva\_5\_5} + \text{previous\_hash})$$
2. **Chaînage séquentiel ininterrompu :**
   Chaque ticket intègre la signature du ticket immédiatement précédent (`previous_signature_hash`). Si un ticket est altéré ou supprimé de manière illicite, toute la chaîne séquentielle postérieure devient mathématiquement invalide.
3. **Intégrité de la note client :**
   L'empreinte cryptographique résumée (8 premiers caractères du hachage) est imprimée sur le ticket de caisse délivré au client (*Note de restaurant*).

#### Condition 3 : La Conservation des Données
1. **Clôture Journalière (Ticket Z) :**
   Une procédure de clôture journalière obligatoire (`close_daily_z_report`) est exécutée à chaque fin de service.
   Elle consolide le chiffre d'affaires du jour, ventile les encaissements par moyen de paiement (Espèces, Carte bancaire) et fige les tickets dans le statut `is_closed_in_z = TRUE`.
2. **Grand Total Perpétuel (GTP) :**
   Chaque clôture journalière calcule et incrémente de manière cumulative et non réinitialisable le *Grand Total Perpétuel* :
   $$\text{GTP}_n = \text{GTP}_{n-1} + \text{Total Journalier TTC}$$
   Ce compteur permanent permet aux inspecteurs de l'administration fiscale de vérifier la cohérence absolue entre les ventes enregistrées et les bilans comptables.
3. **Scellement du Z :**
   Chaque enregistrement dans `public.restaurant_pos_z_reports` est à son tour scellé par son propre hachage SHA-256 et verrouillé par le trigger `trg_guard_z_report_inalterability`.

#### Condition 4 : L'Archivage des Données
1. **Export d'audit fiscal DGFiP :**
   La fonction stockée `get_fiscal_audit_data(p_store_id)` génère à tout instant un journal d'audit complet au format JSON structuré, exportable en un clic par l'exploitant ou l'administration fiscale.
2. **Piste d'audit fiable :**
   L'archive contient l'historique complet des commandes, ventilations TVA, chaînage cryptographique, ainsi que la séquence chronologique intégrale des rapports de clôture Z.
3. **Délai légal de conservation :**
   Conformément à l'article L. 102 B du Livre des procédures fiscales, les données d'encaissement et leurs archives sont conservées sur supports sécurisés pendant une durée minimale de **six (6) années** à compter de la date de la transaction.

---

### 4. PROTOCOLE DE CONTRÔLE FISCAL INOPINÉ (Article L. 80 O du LPF)

En cas de visite d'un agent de la Direction Générale des Finances Publiques (DGFiP) dans l'établissement d'un client utilisateur :

1. **Présentation de l'Attestation :**
   L'exploitant présente immédiatement l'attestation individuelle de conformité établie selon le modèle **BOI-LETTRE-000242**, comprenant le **Volet 1 (Éditeur TRADISTER)** et le **Volet 2 (Entreprise utilisatrice)** signés.
2. **Consultation sur écran :**
   L'agent peut consulter directement l'historique des clôtures Z et des ventes en temps réel via l'espace sécurisé du POS (`/#pos` onglet Ventes).
3. **Fourniture des données :**
   L'exploitant clique sur le bouton **📥 Archive Audit (Contrôle Fiscal)** pour remettre à l'agent le fichier d'audit scellé contenant l'intégralité des écritures de caisse.
4. **Assistance technique de l'éditeur :**
   En cas de réquisition ou d'exercice du droit de communication par l'administration auprès de la société éditrice TRADISTER SAS, la direction technique s'engage à communiquer sous 48 heures le présent dossier technique ainsi que tout extrait de journal d'audit certifié.

---

### 5. ENGAGEMENT DU REPRÉSENTANT LÉGAL

La société éditrice **TRADISTER SAS**, représentée par son Président, certifie sur l'honneur que le logiciel **Allonssy Restaurant POS (v1.0.0)** ne comporte aucune commande cachée, fonction de dissimulation, bouton d'effacement discret ou mécanisme permettant de soustraire des règlements à la comptabilité générale.

Fait à Ris-Orangis, le 22 Novembre 2026.  
**Pour la société TRADISTER SAS**  
*La Présidence*
