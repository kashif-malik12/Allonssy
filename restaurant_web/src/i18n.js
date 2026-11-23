// Allonssy Restaurant & POS Internationalization (FR / EN)

const STORAGE_KEY = 'allonssy_lang';

export function getLang() {
  try {
    const saved = localStorage.getItem(STORAGE_KEY);
    if (saved === 'en' || saved === 'fr') return saved;
  } catch (e) {}
  return 'fr';
}

export function setLang(lang) {
  try {
    localStorage.setItem(STORAGE_KEY, lang === 'en' ? 'en' : 'fr');
  } catch (e) {}
}

export const translations = {
  fr: {
    // Top Bar & General
    app_subtitle: 'Caisse & Analytics Temps Réel',
    live_badge: 'En direct',
    tab_orders: '🔔 Commandes',
    tab_counter: '🧾 Caisse',
    tab_analytics: '📊 Statistiques & Ventes',
    tab_menu: '🍽️ Carte & Équipe',
    tab_orders_short: 'Commandes',
    tab_counter_short: 'Caisse',
    tab_analytics_short: 'Ventes',
    tab_menu_short: 'Carte',
    role_owner: 'Patron',
    role_cashier: 'Caissier',
    role_staff: 'Employé',
    sound_test_title: 'Tester la sonnerie',
    lock_title: 'Verrouiller',
    fullscreen_title: 'Plein écran',
    switch_staff: 'Changer de serveur',

    // PIN Lock Screen
    pin_lock_subtitle: 'Connexion Caisse & Analyse des Ventes',
    pin_select_user: "Sélectionner l'utilisateur :",
    pin_unlock: 'Déverrouiller',
    pin_back_to_menu: '← Retour au Menu Public',
    pin_error: 'Code PIN incorrect. Veuillez réessayer.',

    // Live Orders
    stat_received: 'Reçues / Attente',
    stat_preparing: 'Au Four / En Cours',
    stat_ready: 'Prêtes au Retrait',
    stat_total_today: 'Total Jour',
    no_orders_title: 'Aucune commande en attente',
    no_orders_desc: 'Les nouvelles commandes en ligne ou au comptoir apparaîtront ici automatiquement avec une alerte sonore.',
    last_completed_orders: 'Dernières commandes terminées',
    counter_customer: 'Client comptoir',
    btn_receipt: '🧾 Note',
    status_paid: 'Payée',
    status_received: 'Reçue',
    status_preparing: 'Au Four',
    status_ready: 'Prête',
    status_completed: 'Terminée',
    status_cancelled: 'Annulée',
    desired_time: 'Heure souhaitée :',
    asap: 'Dès que possible',
    size: 'Taille :',
    sauce: 'Sauce :',
    extras: 'Extras :',
    btn_prepare: 'En préparation (Four)',
    btn_mark_ready: 'Commande Prête !',
    btn_pay_complete: 'Encaisser & Terminer',
    client_default: 'Client',

    // Payment Validation Modal
    pay_modal_title: 'Encaisser la Commande #{0}',
    cashed_by: 'Encaissé par :',
    pay_cash: 'Espèces',
    pay_card: 'Carte (TPE)',
    cancel: 'Annuler',
    close: 'Fermer',

    // Counter POS
    counter_ticket_title: 'Ticket Comptoir',
    taken_by: 'Saisie par :',
    clear_ticket: 'Vider',
    clear_ticket_confirm: 'Voulez-vous vider le ticket en cours ?',
    empty_ticket_hint: 'Tapez sur les articles pour les ajouter au ticket',
    total_to_pay: 'Total à régler :',
    total_ht: 'Sous-total HT :',
    tva_10: 'TVA 10.0% :',
    tva_55: 'TVA 5.5% :',
    total_ttc: 'Total TTC :',
    active_ticket: 'Ticket en cours',
    details: 'Détails',
    pay: 'Payer',
    add_to_ticket: 'Ajouter au ticket',
    choose_size: 'Choisir la taille :',
    choose_base: 'Base / Sauce :',
    optional_extras: 'Suppléments (Optionnels) :',
    kitchen_note: 'Note cuisine (sans oignon, bien cuit...)',
    select_size_req: 'Veuillez sélectionner une taille',

    // Change Calculator
    change_calc_title: 'Rendu de Monnaie',
    amount_received: 'Montant Reçu :',
    change_to_give: 'Monnaie à Rendre :',
    exact_amount: 'Montant Exact',
    validate_payment: 'Valider le Règlement',

    // Analytics & Reports
    analytics_title: 'Rapports & Analyse des Ventes',
    analytics_subtitle: "Chiffre d'affaires, répartition par caissier et suivi des performances.",
    period_today: "Aujourd'hui",
    period_week: '7 Derniers Jours',
    period_month: 'Ce Mois',
    period_all: 'Historique Global',
    total_revenue: 'Chiffre Total',
    orders_count: '{0} commandes',
    avg_basket: 'Panier Moyen',
    per_ticket: 'Par ticket / client',
    card_tpe: 'Carte (TPE)',
    cash: 'Espèces',
    pct_revenue: '{0}% du chiffre',
    sales_by_person: 'Ventes par Personne',
    cashiers_count: '{0} caissiers',
    no_sales_period: 'Aucune vente enregistrée sur cette période.',
    weekly_evolution: 'Évolution 7 Derniers Jours',
    weekly_total: 'Total : {0} €',
    daily_sales_legend: "Chiffre d'affaires journalier (7 derniers jours)",
    z_closing_section_title: 'Clôture Journalière (Rapport Z) & Fiscalité',
    z_closing_section_desc: 'Scellez les ventes en cours, incrémentez le Grand Total Perpétuel et téléchargez l\'archive fiscale officielle en cas de contrôle DGFiP.',
    btn_close_z: '🔒 Clôturer la Caisse (Z)',
    btn_fiscal_archive: '📥 Archive Audit',
    z_closing_confirm: "Voulez-vous clôturer la caisse pour aujourd'hui et émettre le Rapport Z officiel ? Les ventes actuelles seront scellées.",
    z_closing_error: 'Erreur lors de la clôture Z : ',
    fiscal_export_error: "Erreur lors de l'export fiscal : ",

    // Menu & Staff Manager
    menu_mgmt_title: 'Carte & Gestion des Employés',
    menu_mgmt_desc: 'Gérez les plats du restaurant et les comptes de vos caissiers.',
    btn_team: '👥 Équipe ({0})',
    btn_add_category: '+ Catégorie',
    btn_add_item: '+ Article',
    admin_control_title: 'Contrôle Admin & Conformité Fiscale',
    admin_control_desc: 'Auto-sync externe : Désactivé. POS certifié conforme CGI Art. 286 I-3° bis (Inaltérabilité, Sécurisation SHA-256, Conservation & Archivage).',
    btn_tax_cert: '📜 Attestation Fiscale',
    btn_tech_dossier: '📄 Dossier Technique',
    btn_force_sync: '🔄 Forcer sync Allonssy',
    all_items: 'Tous les articles ({0})',
    no_items_category: 'Aucun article dans cette catégorie',
    no_items_category_hint: 'Cliquez sur "+ Ajouter un Article" pour créer votre premier plat.',
    from_price: 'Dès {0} €',
    in_stock: '● En stock',
    out_of_stock: '○ Rupture',
    edit: 'Modifier',
    delete: 'Supprimer',
    delete_item_confirm: 'Voulez-vous vraiment supprimer cet article ?',
    delete_cat_confirm: 'Voulez-vous vraiment supprimer cette catégorie ?',

    // Team Modal
    team_modal_title: 'Gestion de l\'Équipe & Rôles',
    team_modal_desc: 'Chaque employé dispose de son code PIN à 4 chiffres pour se connecter à la caisse.',
    btn_add_staff: '+ Ajouter un employé',
    col_name: 'Nom',
    col_role: 'Rôle',
    col_pin: 'Code PIN',
    col_status: 'Statut',
    col_action: 'Action',
    active: 'Actif',
    btn_remove: 'Retirer',
    new_staff_title: 'Nouvel Employé',
    field_name: 'Nom complet :',
    field_role: 'Rôle :',
    field_pin: 'Code PIN (4 chiffres) :',
    save: 'Enregistrer',

    // Add Category Modal
    new_category_title: 'Nouvelle Catégorie',
    field_cat_name: 'Nom de la catégorie (ex: Pizzas, Desserts...) :',
    field_cat_icon: 'Icône (ex: pizza, burger, drink, cake) :',

    // Add / Edit Item Modal
    new_item_title: 'Nouveau Produit',
    edit_item_title: 'Modifier le Produit',
    field_item_cat: 'Catégorie :',
    field_item_name: 'Nom du plat :',
    field_item_desc: 'Description / Ingrédients :',
    field_item_price: 'Prix de base (€) :',
    field_item_sizes: 'Formats & Tailles (optionnel, JSON) :',
    field_item_sauces: 'Sauces de base (optionnel, séparées par virgule) :',
    field_item_extras: 'Suppléments (optionnel, JSON) :',

    // Receipt Modal
    receipt_title: 'Note de Restaurant / Ticket de Caisse',
    receipt_btn_print: '🖨️ Imprimer la Note',
    ticket_num: 'TICKET N° {0}',
    receipt_date: 'Date :',
    receipt_time: 'Heure :',
    receipt_server: 'Serveur :',
    receipt_method: 'Règlement :',
    receipt_seal: 'Empreinte fiscale :',
    receipt_legal: 'Conforme Art. 286, I-3° bis du CGI<br>Système certifié Allonssy POS',

    // Z-Report Modal
    z_modal_title: 'Rapport Z Journalier Officiel',
    z_report_num: 'RAPPORT DE CLÔTURE Z N° {0}',
    z_period_start: 'Début période :',
    z_period_end: 'Fin période :',
    z_order_count: 'Nombre de tickets :',
    z_total_ttc: 'TOTAL VENTES TTC :',
    z_total_ht: 'TOTAL VENTES HT :',
    z_total_tva: 'TVA COLLECTÉE (10%) :',
    z_cash_total: 'Total Espèces :',
    z_card_total: 'Total Cartes Bancaires :',
    z_perpetual_grand_total: 'GRAND TOTAL PERPÉTUEL (GTP) :',
    z_sha256_seal: 'Empreinte Cryptographique SHA-256 :',
    z_closed_by: 'Clôturé par :',
    z_legal_notice: 'Document d\'homologation fiscale inaltérable – Article 286 I-3° bis du CGI',
    btn_print_z: '🖨️ Imprimer Rapport Z',

    // Public Menu (if viewed)
    menu_open: 'Ouvert',
    menu_pos_space: 'Espace Caisse / POS',
    menu_formats: '{0} formats',
    menu_single_format: 'Format unique',
    menu_cart: 'Panier',
    menu_add: 'Ajouter',
    menu_total: 'Total',
    menu_order: 'Commander'
  },

  en: {
    // Top Bar & General
    app_subtitle: 'Cashier & Real-Time Analytics',
    live_badge: 'Live',
    tab_orders: '🔔 Orders',
    tab_counter: '🧾 POS Register',
    tab_analytics: '📊 Sales & Analytics',
    tab_menu: '🍽️ Menu & Staff',
    tab_orders_short: 'Orders',
    tab_counter_short: 'Register',
    tab_analytics_short: 'Sales',
    tab_menu_short: 'Menu',
    role_owner: 'Owner',
    role_cashier: 'Cashier',
    role_staff: 'Staff',
    sound_test_title: 'Test alert chime',
    lock_title: 'Lock register',
    fullscreen_title: 'Fullscreen',
    switch_staff: 'Switch user',

    // PIN Lock Screen
    pin_lock_subtitle: 'POS Register Login & Sales Analytics',
    pin_select_user: 'Select user:',
    pin_unlock: 'Unlock',
    pin_back_to_menu: '← Back to Public Menu',
    pin_error: 'Incorrect PIN code. Please try again.',

    // Live Orders
    stat_received: 'Received / Pending',
    stat_preparing: 'In Kitchen / Oven',
    stat_ready: 'Ready for Pickup',
    stat_total_today: 'Total Today',
    no_orders_title: 'No pending orders',
    no_orders_desc: 'New online or counter orders will appear here automatically with a sound chime.',
    last_completed_orders: 'Recent completed orders',
    counter_customer: 'Counter Customer',
    btn_receipt: '🧾 Receipt',
    status_paid: 'Paid',
    status_received: 'Received',
    status_preparing: 'In Oven',
    status_ready: 'Ready',
    status_completed: 'Completed',
    status_cancelled: 'Cancelled',
    desired_time: 'Pickup time:',
    asap: 'As soon as possible',
    size: 'Size:',
    sauce: 'Sauce:',
    extras: 'Extras:',
    btn_prepare: 'Preparing (Kitchen/Oven)',
    btn_mark_ready: 'Order Ready!',
    btn_pay_complete: 'Pay & Complete',
    client_default: 'Customer',

    // Payment Validation Modal
    pay_modal_title: 'Charge Order #{0}',
    cashed_by: 'Handled by:',
    pay_cash: 'Cash',
    pay_card: 'Card (POS Terminal)',
    cancel: 'Cancel',
    close: 'Close',

    // Counter POS
    counter_ticket_title: 'Counter Ticket',
    taken_by: 'Served by:',
    clear_ticket: 'Clear',
    clear_ticket_confirm: 'Do you want to clear the current ticket?',
    empty_ticket_hint: 'Tap items on the menu to add them to this ticket',
    total_to_pay: 'Total Due:',
    total_ht: 'Subtotal excl. tax:',
    tva_10: 'VAT 10.0%:',
    tva_55: 'VAT 5.5%:',
    total_ttc: 'Total incl. tax:',
    active_ticket: 'Current Ticket',
    details: 'Details',
    pay: 'Pay',
    add_to_ticket: 'Add to ticket',
    choose_size: 'Select size:',
    choose_base: 'Base / Sauce:',
    optional_extras: 'Extras (Optional):',
    kitchen_note: 'Kitchen note (no onions, well done...)',
    select_size_req: 'Please select a size',

    // Change Calculator
    change_calc_title: 'Cash Change Calculator',
    amount_received: 'Amount Received:',
    change_to_give: 'Change Due:',
    exact_amount: 'Exact Amount',
    validate_payment: 'Confirm Payment',

    // Analytics & Reports
    analytics_title: 'Sales Reports & Analytics',
    analytics_subtitle: 'Revenue metrics, cashier breakdowns, and performance tracking.',
    period_today: 'Today',
    period_week: 'Last 7 Days',
    period_month: 'This Month',
    period_all: 'All Time',
    total_revenue: 'Total Revenue',
    orders_count: '{0} orders',
    avg_basket: 'Average Order',
    per_ticket: 'Per ticket / customer',
    card_tpe: 'Card (Terminal)',
    cash: 'Cash',
    pct_revenue: '{0}% of sales',
    sales_by_person: 'Sales by Staff',
    cashiers_count: '{0} cashiers',
    no_sales_period: 'No sales recorded in this period.',
    weekly_evolution: 'Last 7 Days Trend',
    weekly_total: 'Total: {0} €',
    daily_sales_legend: 'Daily gross revenue (last 7 days)',
    z_closing_section_title: 'Daily Z-Report Closing & Fiscal Compliance',
    z_closing_section_desc: 'Seal current transactions, increment the Perpetual Grand Total, and export the official DGFiP audit ledger.',
    btn_close_z: '🔒 Close Register (Z)',
    btn_fiscal_archive: '📥 Audit Archive',
    z_closing_confirm: 'Do you want to close the register for today and generate the official Z-Report? Current sales will be sealed.',
    z_closing_error: 'Error during Z closing: ',
    fiscal_export_error: 'Error during fiscal export: ',

    // Menu & Staff Manager
    menu_mgmt_title: 'Menu & Team Management',
    menu_mgmt_desc: 'Manage your restaurant items, prices, and cashier sub-accounts.',
    btn_team: '👥 Team ({0})',
    btn_add_category: '+ Category',
    btn_add_item: '+ Item',
    admin_control_title: 'Admin Controls & Fiscal Compliance',
    admin_control_desc: 'External Auto-sync: Disabled. POS certified compliant with CGI Art. 286 I-3° bis (Unalterability, SHA-256 Sealing, Conservation & Archiving).',
    btn_tax_cert: '📜 Fiscal Certificate',
    btn_tech_dossier: '📄 Technical Dossier',
    btn_force_sync: '🔄 Force Allonssy Sync',
    all_items: 'All items ({0})',
    no_items_category: 'No items in this category',
    no_items_category_hint: 'Click "+ Add Item" to create your first dish.',
    from_price: 'From {0} €',
    in_stock: '● In stock',
    out_of_stock: '○ Out of stock',
    edit: 'Edit',
    delete: 'Delete',
    delete_item_confirm: 'Are you sure you want to delete this item?',
    delete_cat_confirm: 'Are you sure you want to delete this category?',

    // Team Modal
    team_modal_title: 'Team & Roles Management',
    team_modal_desc: 'Each staff member has their own 4-digit PIN to sign into the register.',
    btn_add_staff: '+ Add staff member',
    col_name: 'Name',
    col_role: 'Role',
    col_pin: 'PIN Code',
    col_status: 'Status',
    col_action: 'Action',
    active: 'Active',
    btn_remove: 'Remove',
    new_staff_title: 'New Staff Member',
    field_name: 'Full name:',
    field_role: 'Role:',
    field_pin: 'PIN Code (4 digits):',
    save: 'Save',

    // Add Category Modal
    new_category_title: 'New Category',
    field_cat_name: 'Category name (e.g. Pizzas, Desserts...):',
    field_cat_icon: 'Icon (e.g. pizza, burger, drink, cake):',

    // Add / Edit Item Modal
    new_item_title: 'New Product',
    edit_item_title: 'Edit Product',
    field_item_cat: 'Category:',
    field_item_name: 'Dish name:',
    field_item_desc: 'Description / Ingredients:',
    field_item_price: 'Base price (€):',
    field_item_sizes: 'Formats & Sizes (optional, JSON):',
    field_item_sauces: 'Base sauces (optional, comma-separated):',
    field_item_extras: 'Extras (optional, JSON):',

    // Receipt Modal
    receipt_title: 'Restaurant Receipt / Customer Bill',
    receipt_btn_print: '🖨️ Print Receipt',
    ticket_num: 'RECEIPT N° {0}',
    receipt_date: 'Date:',
    receipt_time: 'Time:',
    receipt_server: 'Server:',
    receipt_method: 'Payment:',
    receipt_seal: 'Fiscal seal:',
    receipt_legal: 'Compliant with Art. 286, I-3° bis du CGI<br>Certified Allonssy POS System',

    // Z-Report Modal
    z_modal_title: 'Official Daily Z-Report Closing',
    z_report_num: 'DAILY Z-REPORT CLOSING N° {0}',
    z_period_start: 'Period start:',
    z_period_end: 'Period end:',
    z_order_count: 'Number of receipts:',
    z_total_ttc: 'TOTAL GROSS SALES (incl. tax):',
    z_total_ht: 'TOTAL NET SALES (excl. tax):',
    z_total_tva: 'VAT COLLECTED (10%):',
    z_cash_total: 'Total Cash:',
    z_card_total: 'Total Card / Terminal:',
    z_perpetual_grand_total: 'PERPETUAL GRAND TOTAL (GTP):',
    z_sha256_seal: 'SHA-256 Cryptographic Seal:',
    z_closed_by: 'Closed by:',
    z_legal_notice: 'Tamper-evident legal fiscal record – Article 286 I-3° bis du CGI',
    btn_print_z: '🖨️ Print Z-Report',

    // Public Menu (if viewed)
    menu_open: 'Open',
    menu_pos_space: 'Cashier / POS Area',
    menu_formats: '{0} formats',
    menu_single_format: 'Single format',
    menu_cart: 'Cart',
    menu_add: 'Add',
    menu_total: 'Total',
    menu_order: 'Order'
  }
};

export function t(key, lang = 'fr', ...args) {
  const currentLocale = lang === 'en' ? 'en' : 'fr';
  let str = translations[currentLocale]?.[key] || translations['fr']?.[key] || key;
  if (args.length > 0) {
    args.forEach((val, idx) => {
      str = str.replace(new RegExp(`\\{${idx}\\}`, 'g'), val);
    });
  }
  return str;
}

export function renderLangSwitch(currentLang, extraClasses = '') {
  const isEn = currentLang === 'en';
  return `
    <div class="inline-flex items-center bg-slate-800 p-0.5 rounded-xl border border-slate-700 shadow-inner text-xs ${extraClasses}">
      <button type="button" data-set-lang="fr" class="lang-switch-btn px-2 py-1 rounded-lg font-bold transition-all flex items-center space-x-1 ${!isEn ? 'bg-orange-600 text-white shadow-sm' : 'text-slate-400 hover:text-white'}">
        <span>🇫🇷</span>
        <span>FR</span>
      </button>
      <button type="button" data-set-lang="en" class="lang-switch-btn px-2 py-1 rounded-lg font-bold transition-all flex items-center space-x-1 ${isEn ? 'bg-orange-600 text-white shadow-sm' : 'text-slate-400 hover:text-white'}">
        <span>🇬🇧</span>
        <span>EN</span>
      </button>
    </div>
  `;
}
