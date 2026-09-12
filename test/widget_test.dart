import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:local_social/core/business_categories.dart';
import 'package:local_social/core/localization/app_localizations.dart';
import 'package:local_social/models/post_model.dart';

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
    });
  });
}
