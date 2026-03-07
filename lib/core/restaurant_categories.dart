const List<String> restaurantMainCategories = [
  'italian',
  'indian',
  'chinese',
  'japanese',
  'middle_eastern',
  'fast_food',
  'cafe_bakery',
  'takeaway',
  'fine_dining',
  'other',
];

String restaurantCategoryLabel(String value) {
  switch (value) {
    case 'italian':
      return 'Italian';
    case 'indian':
      return 'Indian';
    case 'chinese':
      return 'Chinese';
    case 'japanese':
      return 'Japanese';
    case 'middle_eastern':
      return 'Middle Eastern';
    case 'fast_food':
      return 'Fast Food';
    case 'cafe_bakery':
      return 'Cafe & Bakery';
    case 'takeaway':
      return 'Takeaway';
    case 'fine_dining':
      return 'Fine Dining';
    case 'other':
      return 'Other';
    default:
      return value;
  }
}