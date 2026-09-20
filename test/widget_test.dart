import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:local_social/core/business_categories.dart';
import 'package:local_social/core/item_condition.dart';
import 'package:local_social/core/localization/app_localizations.dart';
import 'package:local_social/models/post_model.dart';
import 'package:local_social/widgets/share_button.dart';

void main() {
  group('AppLocalizations terminology test', () {
    test('English translations for business and professionals', () {
      final l10n = AppLocalizations(const Locale('en'));
      expect(l10n.tr('business'), 'Business or Service Provider');
      expect(l10n.tr('professionals'), 'Professionals');
      expect(
        l10n.tr('professionals_and_service_providers'),
        'Professionals and Service Providers',
      );
      expect(
        l10n.tr('explore_nearby_local_professionals'),
        'Explore nearby local professionals.',
      );
      expect(l10n.tr('shareable'), 'Shareable');
      expect(l10n.tr('share_followers'), 'Share: Followers');
      expect(l10n.tr('share_connections'), 'Share: Connections');
    });

    test('French translations for business and professionals', () {
      final l10n = AppLocalizations(const Locale('fr'));
      expect(l10n.tr('business'), 'Entreprise ou prestataire de services');
      expect(l10n.tr('professionals'), 'Professionnels');
      expect(
        l10n.tr('professionals_and_service_providers'),
        'Professionnels et prestataires de services',
      );
      expect(
        l10n.tr('explore_nearby_local_professionals'),
        'Explorez les professionnels locaux a proximite.',
      );
      expect(l10n.tr('business_main_category'), 'Categorie principale');
      expect(l10n.tr('business_subcategory'), 'Sous-categorie');
      expect(l10n.tr('all_subcategories'), 'Toutes les sous-categories');
      expect(l10n.tr('shareable'), 'Partageable');
      expect(l10n.tr('share_followers'), 'Partage : Abonnes');
      expect(l10n.tr('share_connections'), 'Partage : Relations');
    });

    test('2-tier business categories structure and labels', () {
      expect(businessMainCategories.length, 7);
      expect(businessMainCategories, contains('health_medical'));
      expect(businessMainCategories, contains('professional_legal'));
      expect(businessMainCategories, contains('home_trades'));
      expect(businessMainCategories, contains('auto_mobility'));
      expect(businessMainCategories, contains('beauty_personal_care'));
      expect(businessMainCategories, contains('education_fitness'));
      expect(businessMainCategories, contains('b2b_industry'));

      // Health & Medical
      expect(businessSubcategories('health_medical'), ['doctors', 'clinics', 'pharmacies', 'therapists']);
      expect(businessMainCategoryLabel('health_medical'), 'Health & Medical');
      expect(businessSubcategoryLabel('doctors'), 'Doctors');
      expect(businessCategoryLabel('health_medical', subcategory: 'doctors'), 'Health & Medical • Doctors');

      // French labels
      expect(businessMainCategoryLabel('health_medical', isFrench: true), 'Sante et medical');
      expect(businessSubcategoryLabel('doctors', isFrench: true), 'Medecins');
      expect(businessCategoryLabel('health_medical', subcategory: 'doctors', isFrench: true), 'Sante et medical • Medecins');

      // Professional & Legal
      expect(businessSubcategories('professional_legal'), ['lawyers', 'notaries', 'accountants', 'consultants']);

      // Home & Trades
      expect(businessSubcategories('home_trades'), ['electricians', 'plumbers', 'construction', 'maintenance']);

      // Auto & Mobility
      expect(businessSubcategories('auto_mobility'), ['garages', 'dealers', 'mechanics']);

      // Beauty & Personal Care
      expect(businessSubcategories('beauty_personal_care'), ['salons', 'barbers', 'spas']);

      // Education & Fitness
      expect(businessSubcategories('education_fitness'), ['tutors', 'driving_schools', 'gyms', 'trainers']);

      // B2B & Industry
      expect(businessSubcategories('b2b_industry'), ['manufacturing', 'it_services', 'wholesale']);

      // Edge cases & fallbacks
      expect(businessSubcategories('non_existent'), isEmpty);
      expect(businessSubcategories(''), isEmpty);
      expect(businessMainCategoryLabel('unknown_cat'), 'unknown_cat');
      expect(businessSubcategoryLabel('unknown_sub'), 'unknown_sub');
      expect(businessCategoryLabel('home_trades'), 'Home & Trades');
      expect(businessCategoryLabel('home_trades', subcategory: 'plumbers'), 'Home & Trades • Plumbers');
      expect(businessCategoryLabel('home_trades', isFrench: true), 'Maison et artisanat');
      expect(businessCategoryLabel('home_trades', subcategory: 'plumbers', isFrench: true), 'Maison et artisanat • Plombiers');
    });

    test('Post model shareScope and author business parsing', () {
      final nowStr = DateTime.now().toIso8601String();
      final postMap = {
        'id': 'post-1',
        'user_id': 'user-1',
        'content': 'Test post content',
        'visibility': 'public',
        'share_scope': 'public',
        'latitude': 48.8566,
        'longitude': 2.3522,
        'created_at': nowStr,
        'profiles': {
          'full_name': 'Dr. Alice',
          'business_type': 'health_medical',
          'business_name': 'City Clinic',
          'job_title': 'Lead Doctor',
        },
      };

      // Import Post model
      final post = Post.fromMap(postMap);
      expect(post.id, 'post-1');
      expect(post.shareScope, 'public');
      expect(post.authorBusinessType, 'health_medical');
      expect(post.authorBusinessName, 'City Clinic');
      expect(post.authorJobTitle, 'Lead Doctor');

      // Default shareScope when null
      final defaultPostMap = {
        'id': 'post-2',
        'user_id': 'user-2',
        'content': 'Another post',
        'created_at': nowStr,
      };
      final defaultPost = Post.fromMap(defaultPostMap);
      expect(defaultPost.shareScope, 'none');
      expect(defaultPost.visibility, 'public');
      expect(defaultPost.itemStatus, 'available');

      // Explicit item_status parsing
      final reservedPost = Post.fromMap({
        'id': 'post-3',
        'user_id': 'user-3',
        'content': 'Reserved item',
        'created_at': nowStr,
        'item_status': 'reserved',
      });
      expect(reservedPost.itemStatus, 'reserved');

      final soldPost = Post.fromMap({
        'id': 'post-4',
        'user_id': 'user-4',
        'content': 'Sold item',
        'created_at': nowStr,
        'item_status': 'sold',
      });
      expect(soldPost.itemStatus, 'sold');
    });

    test('Marketplace item status localization in English and French', () {
      final en = AppLocalizations(const Locale('en'));
      expect(en.tr('available'), 'Available');
      expect(en.tr('reserved'), 'Reserved');
      expect(en.tr('sold'), 'Sold');
      expect(en.tr('item_status'), 'Status');
      expect(en.tr('item_sold'), 'Item sold');
      expect(en.tr('hide_sold_items'), 'Hide sold items');

      final fr = AppLocalizations(const Locale('fr'));
      expect(fr.tr('available'), 'Disponible');
      expect(fr.tr('reserved'), 'Reserve');
      expect(fr.tr('sold'), 'Vendu');
      expect(fr.tr('item_status'), 'Statut');
      expect(fr.tr('item_sold'), 'Article vendu');
      expect(fr.tr('hide_sold_items'), 'Masquer les articles vendus');
    });

    test('Saved listings / bookmarks localization in English and French', () {
      final en = AppLocalizations(const Locale('en'));
      expect(en.tr('saved_listings'), 'Saved listings');
      expect(en.tr('save_listing'), 'Save listing');
      expect(en.tr('remove_saved'), 'Remove from saved');
      expect(en.tr('listing_saved'), 'Listing saved');
      expect(en.tr('listing_unsaved'), 'Listing removed from saved');
      expect(en.tr('no_saved_listings'), 'No saved listings yet');
      expect(en.tr('saved'), 'Saved');

      final fr = AppLocalizations(const Locale('fr'));
      expect(fr.tr('saved_listings'), 'Annonces enregistrees');
      expect(fr.tr('save_listing'), "Enregistrer l'annonce");
      expect(fr.tr('remove_saved'), 'Retirer des favoris');
      expect(fr.tr('listing_saved'), 'Annonce enregistree');
      expect(fr.tr('listing_unsaved'), 'Annonce retiree des favoris');
      expect(fr.tr('no_saved_listings'), 'Aucune annonce enregistree');
      expect(fr.tr('saved'), 'Enregistre');
    });

    test('Network source filter and trust badges localization in English and French', () {
      final en = AppLocalizations(const Locale('en'));
      expect(en.tr('source_label'), 'Source:');
      expect(en.tr('all_listings'), 'All listings');
      expect(en.tr('from_network'), 'Following & Connections');
      expect(en.tr('from_connections_only'), 'Connections only');
      expect(en.tr('connected_badge'), 'Connected');
      expect(en.tr('following_badge'), 'Following');
      expect(en.tr('no_network_listings'), 'No listings from your network yet');
      expect(en.tr('view_all_listings'), 'View all listings');

      final fr = AppLocalizations(const Locale('fr'));
      expect(fr.tr('source_label'), 'Source :');
      expect(fr.tr('all_listings'), 'Toutes les annonces');
      expect(fr.tr('from_network'), 'Abonnements & Relations');
      expect(fr.tr('from_connections_only'), 'Relations uniquement');
      expect(fr.tr('connected_badge'), 'Connecte');
      expect(fr.tr('following_badge'), 'Suivi');
      expect(fr.tr('no_network_listings'), 'Aucune annonce de votre reseau pour le moment');
      expect(fr.tr('view_all_listings'), 'Voir toutes les annonces');
    });

    test('Post model parses original_price and computes discount correctly', () {
      final discountedPost = Post.fromMap({
        'id': 'p1',
        'user_id': 'u1',
        'content': 'Great chair',
        'created_at': DateTime.now().toIso8601String(),
        'post_type': 'market',
        'market_price': 80.0,
        'original_price': 100.0,
      });
      expect(discountedPost.originalPrice, 100.0);
      expect(discountedPost.marketPrice, 80.0);
      expect(discountedPost.hasDiscount, true);
      expect(discountedPost.discountPercentage, 20);

      final regularPost = Post.fromMap({
        'id': 'p2',
        'user_id': 'u1',
        'content': 'Normal table',
        'created_at': DateTime.now().toIso8601String(),
        'post_type': 'market',
        'market_price': 50.0,
      });
      expect(regularPost.originalPrice, isNull);
      expect(regularPost.hasDiscount, false);
      expect(regularPost.discountPercentage, 0);

      final equalPricePost = Post.fromMap({
        'id': 'p3',
        'user_id': 'u1',
        'content': 'Equal price',
        'created_at': DateTime.now().toIso8601String(),
        'post_type': 'market',
        'market_price': 100.0,
        'original_price': 100.0,
      });
      expect(equalPricePost.hasDiscount, false);
      expect(equalPricePost.discountPercentage, 0);
    });

    test('Price drop and discount indicator localization in English and French', () {
      final en = AppLocalizations(const Locale('en'));
      expect(en.tr('original_price'), 'Original price');
      expect(en.tr('original_price_optional'), 'Original price (optional)');
      expect(en.tr('price_drop'), 'Price drop');
      expect(en.tr('price_drop_only'), 'Price drop only');
      expect(en.tr('percent_off', args: {'percent': '25'}), '-25%');

      final fr = AppLocalizations(const Locale('fr'));
      expect(fr.tr('original_price'), "Prix d'origine");
      expect(fr.tr('original_price_optional'), "Prix d'origine (facultatif)");
      expect(fr.tr('price_drop'), 'Baisse de prix');
      expect(fr.tr('price_drop_only'), 'Prix en baisse uniquement');
      expect(fr.tr('percent_off', args: {'percent': '25'}), '-25%');
    });

    test('Saved gigs & services localization in English and French', () {
      final en = AppLocalizations(const Locale('en'));
      expect(en.tr('saved_gigs'), 'Saved gigs');
      expect(en.tr('save_gig'), 'Save gig');
      expect(en.tr('remove_saved_gig'), 'Remove from saved gigs');
      expect(en.tr('gig_saved'), 'Gig saved');
      expect(en.tr('gig_unsaved'), 'Gig removed from saved');
      expect(en.tr('no_saved_gigs'), 'No saved gigs yet');

      final fr = AppLocalizations(const Locale('fr'));
      expect(fr.tr('saved_gigs'), 'Services enregistres');
      expect(fr.tr('save_gig'), 'Enregistrer le service');
      expect(fr.tr('remove_saved_gig'), 'Retirer des services enregistres');
      expect(fr.tr('gig_saved'), 'Service enregistre');
      expect(fr.tr('gig_unsaved'), 'Service retire des favoris');
      expect(fr.tr('no_saved_gigs'), 'Aucun service enregistre');
    });

    test('Favorite local businesses & restaurants localization in English and French', () {
      final en = AppLocalizations(const Locale('en'));
      expect(en.tr('favorite_businesses'), 'Favorite places');
      expect(en.tr('add_favorite'), 'Add to favorites');
      expect(en.tr('remove_favorite'), 'Remove from favorites');
      expect(en.tr('business_favorited'), 'Added to favorites');
      expect(en.tr('business_unfavorited'), 'Removed from favorites');
      expect(en.tr('favorites_only'), 'Favorites only');
      expect(en.tr('no_favorites'), 'No favorites yet');

      final fr = AppLocalizations(const Locale('fr'));
      expect(fr.tr('favorite_businesses'), 'Lieux favoris');
      expect(fr.tr('add_favorite'), 'Ajouter aux favoris');
      expect(fr.tr('remove_favorite'), 'Retirer des favoris');
      expect(fr.tr('business_favorited'), 'Ajoute aux favoris');
      expect(fr.tr('business_unfavorited'), 'Retire des favoris');
      expect(fr.tr('favorites_only'), 'Favoris uniquement');
      expect(fr.tr('no_favorites'), 'Aucun favori pour le moment');
    });

    test('Marketplace item condition parsing, labels and translations', () {
      final en = AppLocalizations(const Locale('en'));
      final fr = AppLocalizations(const Locale('fr'));

      expect(itemConditionValues, ['new', 'like_new', 'good', 'fair', 'parts']);
      expect(itemConditionLabel('new', en), 'New with tags');
      expect(itemConditionLabel('like_new', en), 'Like new');
      expect(itemConditionLabel('good', en), 'Good condition');
      expect(itemConditionLabel('fair', en), 'Fair condition');
      expect(itemConditionLabel('parts', en), 'For parts / not working');

      expect(itemConditionLabel('new', fr), 'Neuf avec etiquette');
      expect(itemConditionLabel('like_new', fr), 'Tres bon etat');
      expect(itemConditionLabel('good', fr), 'Bon etat');
      expect(itemConditionLabel('fair', fr), 'Etat satisfaisant');
      expect(itemConditionLabel('parts', fr), 'Pour pieces');

      expect(en.tr('item_condition'), 'Condition');
      expect(en.tr('all_conditions'), 'All conditions');
      expect(fr.tr('item_condition'), 'Etat de l article');
      expect(fr.tr('all_conditions'), 'Tous les etats');

      // Post model item_condition parsing
      final postWithCondition = Post.fromMap({
        'id': 'post-cond-1',
        'user_id': 'user-1',
        'content': 'iPhone 13',
        'created_at': DateTime.now().toIso8601String(),
        'post_type': 'market',
        'item_condition': 'like_new',
      });
      expect(postWithCondition.itemCondition, 'like_new');

      final postWithoutCondition = Post.fromMap({
        'id': 'post-cond-2',
        'user_id': 'user-1',
        'content': 'Old couch',
        'created_at': DateTime.now().toIso8601String(),
        'post_type': 'market',
      });
      expect(postWithoutCondition.itemCondition, isNull);
    });

    test('Chat quick presets localization in English and French', () {
      final en = AppLocalizations(const Locale('en'));
      expect(en.tr('quick_replies'), 'Quick questions');
      expect(en.tr('preset_available'), 'Is this still available?');
      expect(en.tr('preset_best_price'), "What's your best price?");
      expect(en.tr('preset_more_photos'), 'Can I see more photos?');
      expect(en.tr('preset_meetup'), 'When and where can we meet?');
      expect(en.tr('preset_available_week'), 'Are you available this week?');
      expect(en.tr('preset_quote'), 'Can you provide a quote?');

      final fr = AppLocalizations(const Locale('fr'));
      expect(fr.tr('quick_replies'), 'Questions rapides');
      expect(fr.tr('preset_available'), 'Est-ce toujours disponible ?');
      expect(fr.tr('preset_best_price'), 'Quel est votre dernier prix ?');
      expect(fr.tr('preset_more_photos'), 'Puis-je avoir plus de photos ?');
      expect(fr.tr('preset_meetup'), 'Quand et ou peut-on se rencontrer ?');
      expect(fr.tr('preset_available_week'), 'Etes-vous disponible cette semaine ?');
      expect(fr.tr('preset_quote'), 'Pouvez-vous me faire un devis ?');
    });

    test('App sharing URLs and localization in English and French', () {
      final en = AppLocalizations(const Locale('en'));
      final fr = AppLocalizations(const Locale('fr'));

      // Check URL helpers
      expect(appShareUrl(), 'https://app.allonssy.com');
      expect(marketplaceShareUrl('item-123'), 'https://app.allonssy.com/marketplace/product/item-123');
      expect(gigShareUrl('gig-456'), 'https://app.allonssy.com/gigs/service/gig-456');
      expect(foodShareUrl('food-789'), 'https://app.allonssy.com/foods/food-789');
      expect(profileShareUrl('user-101'), 'https://app.allonssy.com/p/user-101');

      // English share strings
      expect(en.tr('share_app'), 'Share Allonssy');
      expect(en.tr('share_app_title'), 'Join me on Allonssy');
      expect(en.tr('share_app_subtitle'), 'Tell friends & invite them to Allonssy');
      expect(
        en.tr('share_app_message', args: {'url': 'https://app.allonssy.com'}),
        contains("https://app.allonssy.com"),
      );
      expect(en.tr('link_copied'), 'Link copied to clipboard');

      // French share strings
      expect(fr.tr('share_app'), 'Partager Allonssy');
      expect(fr.tr('share_app_title'), 'Rejoignez-moi sur Allonssy');
      expect(fr.tr('share_app_subtitle'), 'Inviter des amis et partager Allonssy');
      expect(
        fr.tr('share_app_message', args: {'url': 'https://app.allonssy.com'}),
        contains("https://app.allonssy.com"),
      );
      expect(fr.tr('link_copied'), 'Lien copié dans le presse-papiers');
    });

    test('Feedback flow localization in English and French', () {
      final en = AppLocalizations(const Locale('en'));
      final fr = AppLocalizations(const Locale('fr'));

      expect(en.tr('give_feedback'), 'Give Feedback');
      expect(en.tr('feedback'), 'Feedback');
      expect(en.tr('feedback_general'), 'General feedback');
      expect(en.tr('feedback_bug'), 'Bug report');
      expect(en.tr('feedback_feature'), 'Feature idea');
      expect(en.tr('feedback_rating'), 'Your experience rating');
      expect(en.tr('feedback_message_empty'), 'Please enter your feedback message');
      expect(en.tr('feedback_submitted_success'), 'Thank you! Your feedback has been sent.');
      expect(en.tr('community_and_feedback'), 'Community & Feedback');

      expect(fr.tr('give_feedback'), 'Donner votre avis');
      expect(fr.tr('feedback'), 'Commentaires & Avis');
      expect(fr.tr('feedback_general'), 'Avis général');
      expect(fr.tr('feedback_bug'), 'Signaler un bug');
      expect(fr.tr('feedback_feature'), 'Idée de fonctionnalité');
      expect(fr.tr('feedback_rating'), 'Votre appréciation');
      expect(fr.tr('feedback_message_empty'), 'Veuillez entrer votre message de commentaire');
      expect(fr.tr('feedback_submitted_success'), 'Merci ! Votre retour a bien été envoyé.');
      expect(fr.tr('community_and_feedback'), 'Communauté & Retours');
    });

    test('Profile tabs & Unified Categorized Search localization', () {
      final en = AppLocalizations(const Locale('en'));
      final fr = AppLocalizations(const Locale('fr'));

      // English
      expect(en.tr('tab_posts'), 'Posts');
      expect(en.tr('tab_marketplace'), 'Marketplace');
      expect(en.tr('tab_services'), 'Gigs & Services');
      expect(en.tr('no_user_listings'), 'No marketplace listings yet');
      expect(en.tr('no_user_services'), 'No services offered yet');
      expect(en.tr('manage'), 'Manage');
      expect(en.tr('directory'), 'Directory');
      expect(en.tr('no_products_found'), 'No products found');

      // French
      expect(fr.tr('tab_posts'), 'Publications');
      expect(fr.tr('tab_marketplace'), 'Marketplace');
      expect(fr.tr('tab_services'), 'Missions & Services');
      expect(fr.tr('no_user_listings'), 'Aucune annonce marketplace pour le moment');
      expect(fr.tr('no_user_services'), 'Aucun service proposé pour le moment');
      expect(fr.tr('manage'), 'Gérer');
      expect(fr.tr('directory'), 'Annuaire');
      expect(fr.tr('no_products_found'), 'Aucun produit trouvé');
    });
  });
}

