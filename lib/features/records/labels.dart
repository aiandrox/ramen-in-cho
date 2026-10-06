import '../../l10n/app_localizations.dart';
import 'models.dart';

String styleLabel(AppLocalizations l10n, RamenStyle style) => switch (style) {
  RamenStyle.shoyu => l10n.styleShoyu,
  RamenStyle.miso => l10n.styleMiso,
  RamenStyle.shio => l10n.styleShio,
  RamenStyle.tonkotsu => l10n.styleTonkotsu,
  RamenStyle.iekei => l10n.styleIekei,
  RamenStyle.jiro => l10n.styleJiro,
  RamenStyle.tsukemen => l10n.styleTsukemen,
  RamenStyle.shirunashi => l10n.styleShirunashi,
  RamenStyle.other => l10n.styleOther,
};
