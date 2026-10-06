import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../l10n/app_localizations.dart';
import '../records/record_repository.dart';
import 'credits.dart';
import '../../theme/washi_buttons.dart';

class CreditsScreen extends ConsumerWidget {
  const CreditsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final textTheme = Theme.of(context).textTheme;
    final credits = sourceCredits(
      (ref.watch(visitsProvider).value ?? const []).map((e) => e.shop),
    );

    Widget heading(String text) => Padding(
      padding: const EdgeInsets.only(top: 24, bottom: 8),
      child: Text(text, style: textTheme.titleMedium),
    );

    return Scaffold(
      appBar: AppBar(title: Text(l10n.creditsTitle)),
      body: ListView(
        padding: EdgeInsets.fromLTRB(
          16,
          0,
          16,
          32 + MediaQuery.viewPaddingOf(context).bottom,
        ),
        children: [
          heading(l10n.creditsServicesHeading),
          Text(l10n.creditsOsm),
          const SizedBox(height: 8),
          Text(l10n.creditsOpenPoi),
          const SizedBox(height: 4),
          Text(l10n.creditsGsi),
          const SizedBox(height: 4),
          Text(l10n.creditsPrefectures),
          const SizedBox(height: 8),
          Text(l10n.creditsYahoo),
          if (!credits.isEmpty) ...[
            heading(l10n.creditsSavedShopsHeading),
            Text(l10n.creditsSavedShopsNote, style: textTheme.bodySmall),
            const SizedBox(height: 8),
            for (final attribution in credits.attributions)
              Padding(
                padding: const EdgeInsets.only(bottom: 4),
                child: Text('・$attribution'),
              ),
            if (credits.licenses.isNotEmpty)
              Padding(
                padding: const EdgeInsets.only(top: 4),
                child: Text(
                  l10n.creditsLicenses(credits.licenses.join('、')),
                  style: textTheme.bodySmall,
                ),
              ),
          ],
          heading(l10n.creditsAppHeading),
          Align(
            alignment: Alignment.centerLeft,
            child: SumiFuda(
              onPressed: () => showLicensePage(
                context: context,
                applicationName: l10n.appName,
              ),
              child: Text(l10n.creditsAppLicenses),
            ),
          ),
        ],
      ),
    );
  }
}
