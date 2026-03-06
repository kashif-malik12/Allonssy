const List<String> serviceMainCategories = [
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