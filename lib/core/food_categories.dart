const List<String> foodMainCategories = [
  'indian',
  'high_protein',
  'starters',
  'pizza',
  'burger',
  'pasta',
  'rice_bowl',
  'sandwich_wrap',
  'dessert',
  'drinks',
  'vegan',
  'other',
];

String foodCategoryLabel(String value) {
  switch (value) {
    case 'indian':
      return 'Indian';
    case 'high_protein':
      return 'High Protein';
    case 'starters':
      return 'Starters';
    case 'pizza':
      return 'Pizza';
    case 'burger':
      return 'Burger';
    case 'pasta':
      return 'Pasta';
    case 'rice_bowl':
      return 'Rice Bowl';
    case 'sandwich_wrap':
      return 'Sandwich & Wrap';
    case 'dessert':
      return 'Dessert';
    case 'drinks':
      return 'Drinks';
    case 'vegan':
      return 'Vegan';
    case 'other':
      return 'Other';
    default:
      return value;
  }
}
