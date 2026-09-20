import 'localization/app_localizations.dart';

const itemConditionValues = [
  'new',
  'like_new',
  'good',
  'fair',
  'parts',
];

String itemConditionLabel(String? condition, AppLocalizations l10n) {
  switch (condition?.trim().toLowerCase()) {
    case 'new':
      return l10n.tr('condition_new');
    case 'like_new':
      return l10n.tr('condition_like_new');
    case 'good':
      return l10n.tr('condition_good');
    case 'fair':
      return l10n.tr('condition_fair');
    case 'parts':
      return l10n.tr('condition_parts');
    default:
      return condition ?? '';
  }
}
