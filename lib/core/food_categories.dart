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

String foodCategoryLabel(String value, {bool isFrench = false}) {
  return localizedFoodCategoryLabel(value, isFrench: isFrench);
}

String localizedFoodCategoryLabel(String value, {bool isFrench = false}) {
  switch (value) {
    case 'indian':
      return isFrench ? 'Indien' : 'Indian';
    case 'high_protein':
      return isFrench ? 'Riche en protéines' : 'High Protein';
    case 'starters':
      return isFrench ? 'Entrées' : 'Starters';
    case 'pizza':
      return isFrench ? 'Pizza' : 'Pizza';
    case 'burger':
      return isFrench ? 'Burger' : 'Burger';
    case 'pasta':
      return isFrench ? 'Pâtes' : 'Pasta';
    case 'rice_bowl':
      return isFrench ? 'Bol de riz' : 'Rice Bowl';
    case 'sandwich_wrap':
      return isFrench ? 'Sandwich et wrap' : 'Sandwich & Wrap';
    case 'dessert':
      return isFrench ? 'Dessert' : 'Dessert';
    case 'drinks':
      return isFrench ? 'Boissons' : 'Drinks';
    case 'vegan':
      return isFrench ? 'Végan' : 'Vegan';
    case 'other':
      return isFrench ? 'Autre' : 'Other';
    default:
      return value;
  }
}
