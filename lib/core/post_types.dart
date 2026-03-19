enum PostType {
  post,
  market,
  serviceOffer,
  serviceRequest,
  lostFound,
  foodAd,
}

extension PostTypeX on PostType {
  String get dbValue {
    switch (this) {
      case PostType.post:
        return 'post';
      case PostType.market:
        return 'market';
      case PostType.serviceOffer:
        return 'service_offer';
      case PostType.serviceRequest:
        return 'service_request';
      case PostType.lostFound:
        return 'lost_found';
      case PostType.foodAd:
        return 'food_ad';
    }
  }

  String get label => localizedLabel(isFrench: false);

  String localizedLabel({bool isFrench = false}) {
    switch (this) {
      case PostType.post:
        return isFrench ? 'Publication' : 'Posts';
      case PostType.market:
        return isFrench ? 'Achat & Vente' : 'Buy & Sell';
      case PostType.serviceOffer:
        return isFrench ? 'Offre de service' : 'Offer Service';
      case PostType.serviceRequest:
        return isFrench ? 'Demande de service' : 'Request Service';
      case PostType.lostFound:
        return isFrench ? 'Objets perdus & trouvés' : 'Lost & Found';
      case PostType.foodAd:
        return isFrench ? 'Annonce alimentaire' : 'Food Ad';
    }
  }
}
