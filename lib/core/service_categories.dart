const List<String> serviceMainCategories = [
  'marketing',
  'finance',
  'business_services',
  'home_services',
  'tech',
  'design',
  'education',
  'beauty_wellness',
  'events',
  'transport',
  'other',
];

String serviceCategoryLabel(String value, {bool isFrench = false}) {
  return localizedServiceCategoryLabel(value, isFrench: isFrench);
}

String localizedServiceCategoryLabel(String value, {bool isFrench = false}) {
  switch (value) {
    case 'marketing':
      return isFrench ? 'Marketing' : 'Marketing';
    case 'finance':
      return isFrench ? 'Finance' : 'Finance';
    case 'business_services':
      return isFrench ? 'Services aux entreprises' : 'Business Services';
    case 'home_services':
      return isFrench ? 'Services à domicile' : 'Home Services';
    case 'tech':
      return isFrench ? 'Technologie' : 'Tech';
    case 'design':
      return isFrench ? 'Design' : 'Design';
    case 'education':
      return isFrench ? 'Éducation' : 'Education';
    case 'beauty_wellness':
      return isFrench ? 'Beauté et bien-être' : 'Beauty & Wellness';
    case 'events':
      return isFrench ? 'Événements' : 'Events';
    case 'transport':
      return isFrench ? 'Transport' : 'Transport';
    case 'other':
      return isFrench ? 'Autre' : 'Other';
    default:
      return value;
  }
}
