const List<String> marketMainCategories = [
  'electronics',
  'fashion',
  'home_garden',
  'vehicles',
  'sports',
  'books',
  'toys',
  'other',
];

String marketCategoryLabel(String value) {
  switch (value) {
    case 'electronics':
      return 'Electronics';
    case 'fashion':
      return 'Fashion';
    case 'home_garden':
      return 'Home & Garden';
    case 'vehicles':
      return 'Vehicles';
    case 'sports':
      return 'Sports';
    case 'books':
      return 'Books';
    case 'toys':
      return 'Toys';
    case 'other':
      return 'Other';
    default:
      return value;
  }
}
