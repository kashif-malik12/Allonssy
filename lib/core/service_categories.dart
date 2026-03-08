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

String serviceCategoryLabel(String value) {
  switch (value) {
    case 'marketing':
      return 'Marketing';
    case 'finance':
      return 'Finance';
    case 'business_services':
      return 'Business Services';
    case 'home_services':
      return 'Home Services';
    case 'tech':
      return 'Tech';
    case 'design':
      return 'Design';
    case 'education':
      return 'Education';
    case 'beauty_wellness':
      return 'Beauty & Wellness';
    case 'events':
      return 'Events';
    case 'transport':
      return 'Transport';
    case 'other':
      return 'Other';
    default:
      return value;
  }
}
