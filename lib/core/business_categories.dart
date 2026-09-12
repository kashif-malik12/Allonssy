const List<String> businessMainCategories = [
  'health_medical',
  'professional_legal',
  'home_trades',
  'auto_mobility',
  'beauty_personal_care',
  'education_fitness',
  'b2b_industry',
];

const Map<String, List<String>> businessSubcategoriesMap = {
  'health_medical': [
    'doctors',
    'clinics',
    'pharmacies',
    'therapists',
  ],
  'professional_legal': [
    'lawyers',
    'notaries',
    'accountants',
    'consultants',
  ],
  'home_trades': [
    'electricians',
    'plumbers',
    'construction',
    'maintenance',
  ],
  'auto_mobility': [
    'garages',
    'dealers',
    'mechanics',
  ],
  'beauty_personal_care': [
    'salons',
    'barbers',
    'spas',
  ],
  'education_fitness': [
    'tutors',
    'driving_schools',
    'gyms',
    'trainers',
  ],
  'b2b_industry': [
    'manufacturing',
    'it_services',
    'wholesale',
  ],
};

List<String> businessSubcategories(String mainCategory) {
  return businessSubcategoriesMap[mainCategory] ?? const [];
}

String businessMainCategoryLabel(String key, {bool isFrench = false}) {
  switch (key) {
    case 'health_medical':
      return isFrench ? 'Sante et medical' : 'Health & Medical';
    case 'professional_legal':
      return isFrench ? 'Professionnel et juridique' : 'Professional & Legal';
    case 'home_trades':
      return isFrench ? 'Maison et artisanat' : 'Home & Trades';
    case 'auto_mobility':
      return isFrench ? 'Auto et mobilite' : 'Auto & Mobility';
    case 'beauty_personal_care':
      return isFrench ? 'Beaute et soins personnels' : 'Beauty & Personal Care';
    case 'education_fitness':
      return isFrench ? 'Education et fitness' : 'Education & Fitness';
    case 'b2b_industry':
      return isFrench ? 'B2B et industrie' : 'B2B & Industry';
    default:
      return key;
  }
}

String businessSubcategoryLabel(String key, {bool isFrench = false}) {
  switch (key) {
    // Health & Medical
    case 'doctors':
      return isFrench ? 'Medecins' : 'Doctors';
    case 'clinics':
      return isFrench ? 'Cliniques' : 'Clinics';
    case 'pharmacies':
      return isFrench ? 'Pharmacies' : 'Pharmacies';
    case 'therapists':
      return isFrench ? 'Therapeutes' : 'Therapists';

    // Professional & Legal
    case 'lawyers':
      return isFrench ? 'Avocats' : 'Lawyers';
    case 'notaries':
      return isFrench ? 'Notaires' : 'Notaries';
    case 'accountants':
      return isFrench ? 'Comptables' : 'Accountants';
    case 'consultants':
      return isFrench ? 'Consultants' : 'Consultants';

    // Home & Trades
    case 'electricians':
      return isFrench ? 'Electriciens' : 'Electricians';
    case 'plumbers':
      return isFrench ? 'Plombiers' : 'Plumbers';
    case 'construction':
      return isFrench ? 'Construction' : 'Construction';
    case 'maintenance':
      return isFrench ? 'Maintenance' : 'Maintenance';

    // Auto & Mobility
    case 'garages':
      return isFrench ? 'Garages' : 'Garages';
    case 'dealers':
      return isFrench ? 'Concessionnaires' : 'Dealers';
    case 'mechanics':
      return isFrench ? 'Mecaniciens' : 'Mechanics';

    // Beauty & Personal Care
    case 'salons':
      return isFrench ? 'Salons' : 'Salons';
    case 'barbers':
      return isFrench ? 'Barbiers' : 'Barbers';
    case 'spas':
      return isFrench ? 'Spas' : 'Spas';

    // Education & Fitness
    case 'tutors':
      return isFrench ? 'Professeurs particuliers' : 'Tutors';
    case 'driving_schools':
      return isFrench ? 'Auto-ecoles' : 'Driving Schools';
    case 'gyms':
      return isFrench ? 'Salles de sport' : 'Gyms';
    case 'trainers':
      return isFrench ? 'Coachs sportifs' : 'Trainers';

    // B2B & Industry
    case 'manufacturing':
      return isFrench ? 'Fabrication & Industrie' : 'Manufacturing';
    case 'it_services':
      return isFrench ? 'Services informatiques' : 'IT Services';
    case 'wholesale':
      return isFrench ? 'Commerce de gros' : 'Wholesale';

    default:
      return key;
  }
}

String businessCategoryLabel(
  String value, {
  String? subcategory,
  bool isFrench = false,
}) {
  if (subcategory != null && subcategory.trim().isNotEmpty) {
    final subLabel = businessSubcategoryLabel(subcategory.trim(), isFrench: isFrench);
    final mainLabel = businessMainCategoryLabel(value.trim(), isFrench: isFrench);
    if (mainLabel.isNotEmpty && mainLabel != value.trim()) {
      return '$mainLabel • $subLabel';
    }
    return subLabel;
  }

  // Check if value is a subcategory
  final asSub = businessSubcategoryLabel(value, isFrench: isFrench);
  if (asSub != value) return asSub;

  // Check if value is a main category
  final asMain = businessMainCategoryLabel(value, isFrench: isFrench);
  if (asMain != value) return asMain;

  return localizedBusinessCategoryLabel(value, isFrench: isFrench);
}

String localizedBusinessCategoryLabel(String value, {bool isFrench = false}) {
  // Check main categories
  final asMain = businessMainCategoryLabel(value, isFrench: isFrench);
  if (asMain != value) return asMain;

  // Check subcategories
  final asSub = businessSubcategoryLabel(value, isFrench: isFrench);
  if (asSub != value) return asSub;

  // Legacy fallbacks for historical data
  switch (value) {
    case 'it_software':
      return isFrench ? 'Informatique et logiciels' : 'IT & Software';
    case 'legal_services':
      return isFrench ? 'Services juridiques' : 'Legal Services';
    case 'banking_finance':
      return isFrench ? 'Banque et finance' : 'Banking & Finance';
    case 'accounting':
      return isFrench ? 'Comptabilite' : 'Accountant';
    case 'consulting':
      return isFrench ? 'Conseil' : 'Consulting';
    case 'brokerage':
      return isFrench ? 'Courtage' : 'Broker';
    case 'dealership':
      return isFrench ? 'Concessionnaire' : 'Dealer';
    case 'trader':
      return isFrench ? 'Commerce' : 'Trader';
    case 'manufacturer':
      return isFrench ? 'Fabrication' : 'Manufacturer';
    case 'auto_garage':
      return isFrench ? 'Garage auto' : 'Auto Garage';
    case 'notary':
      return isFrench ? 'Notaire' : 'Notary';
    case 'real_estate':
      return isFrench ? 'Immobilier' : 'Real Estate';
    case 'health_wellness':
      return isFrench ? 'Sante et bien-etre' : 'Health & Wellness';
    case 'education_training':
      return isFrench ? 'Education et formation' : 'Education & Training';
    case 'marketing_media':
      return isFrench ? 'Marketing et medias' : 'Marketing & Media';
    case 'construction_trades':
      return isFrench ? 'Construction et metiers' : 'Construction & Trades';
    case 'home_services':
      return isFrench ? 'Services a domicile' : 'Home Services';
    case 'logistics_transport':
      return isFrench ? 'Logistique et transport' : 'Logistics & Transport';
    case 'beauty_personal_care':
      return isFrench ? 'Beaute et soins personnels' : 'Beauty & Personal Care';
    case 'other':
      return isFrench ? 'Autre' : 'Other';
    default:
      return value;
  }
}
