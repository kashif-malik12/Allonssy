const List<String> marketMainCategories = [
  'house_sale',
  'house_rent',
  'mobile_phone',
  'computers',
  'bikes',
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
    case 'house_sale':
      return 'House for Sale';
    case 'house_rent':
      return 'House for Rent';
    case 'mobile_phone':
      return 'Mobile Phone';
    case 'computers':
      return 'Computers';
    case 'bikes':
      return 'Bikes';
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
