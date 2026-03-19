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

String marketCategoryLabel(String value, {bool isFrench = false}) {
  return localizedMarketCategoryLabel(value, isFrench: isFrench);
}

String localizedMarketCategoryLabel(String value, {bool isFrench = false}) {
  switch (value) {
    case 'house_sale':
      return isFrench ? 'Maison à vendre' : 'House for Sale';
    case 'house_rent':
      return isFrench ? 'Maison à louer' : 'House for Rent';
    case 'mobile_phone':
      return isFrench ? 'Téléphone mobile' : 'Mobile Phone';
    case 'computers':
      return isFrench ? 'Informatique' : 'Computers';
    case 'bikes':
      return isFrench ? 'Vélos' : 'Bikes';
    case 'electronics':
      return isFrench ? 'Électronique' : 'Electronics';
    case 'fashion':
      return isFrench ? 'Mode' : 'Fashion';
    case 'home_garden':
      return isFrench ? 'Maison et jardin' : 'Home & Garden';
    case 'vehicles':
      return isFrench ? 'Véhicules' : 'Vehicles';
    case 'sports':
      return isFrench ? 'Sports' : 'Sports';
    case 'books':
      return isFrench ? 'Livres' : 'Books';
    case 'toys':
      return isFrench ? 'Jouets' : 'Toys';
    case 'other':
      return isFrench ? 'Autre' : 'Other';
    default:
      return value;
  }
}
