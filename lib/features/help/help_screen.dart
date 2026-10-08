import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../l10n/app_localizations.dart';
import '../../theme/safe_bottom.dart';
import '../../theme/washi.dart';
import '../../theme/washi_buttons.dart';
import '../onboarding/onboarding_screen.dart';
import 'help_topics.dart';

/// 使い方。設定から開き、項目を選ぶと画面の絵を1枚ずつめくって見せる。
class HelpScreen extends ConsumerWidget {
  const HelpScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final textTheme = Theme.of(context).textTheme;
    return Scaffold(
      appBar: AppBar(title: Text(l10n.helpTitle)),
      body: ListView(
        padding: EdgeInsets.fromLTRB(
          16,
          8,
          16,
          16 + MediaQuery.viewPaddingOf(context).bottom,
        ),
        children: [
          Text(l10n.helpIntro, style: textTheme.bodyMedium),
          const SizedBox(height: 8),
          for (final topic in helpTopics)
            ListTile(
              contentPadding: EdgeInsets.zero,
              title: Text(topic.title(l10n)),
              trailing: const Icon(Icons.chevron_right),
              onTap: () => Navigator.of(context).push(
                MaterialPageRoute<void>(
                  builder: (_) => HelpTopicScreen(topic: topic),
                ),
              ),
            ),
          const SizedBox(height: 16),
          Text(
            l10n.helpOnboardingNote,
            style: textTheme.bodySmall?.copyWith(color: Washi.inkSoft),
          ),
          Align(
            alignment: Alignment.centerLeft,
            child: FudeLink(
              onPressed: () => showOnboarding(context, ref),
              child: Text(l10n.onboardingReplay),
            ),
          ),
        ],
      ),
    );
  }
}

/// 1つの項目の絵を、横にめくって1枚ずつ見せる。
class HelpTopicScreen extends StatefulWidget {
  const HelpTopicScreen({super.key, required this.topic});

  final HelpTopic topic;

  @override
  State<HelpTopicScreen> createState() => _HelpTopicScreenState();
}

class _HelpTopicScreenState extends State<HelpTopicScreen> {
  final _controller = PageController();
  var _page = 0;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _go(int page) => _controller.animateToPage(
    page,
    duration: const Duration(milliseconds: 300),
    curve: Curves.easeOutCubic,
  );

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final pages = widget.topic.pages;
    final last = _page == pages.length - 1;
    return Scaffold(
      appBar: AppBar(title: Text(widget.topic.title(l10n))),
      body: PageView(
        controller: _controller,
        onPageChanged: (page) => setState(() => _page = page),
        children: [for (final page in pages) _HelpPageView(page: page)],
      ),
      bottomNavigationBar: SafeBottomBar(
        child: Row(
          children: [
            Expanded(
              child: _page == 0
                  ? const SizedBox.shrink()
                  : Align(
                      alignment: Alignment.centerLeft,
                      child: FudeLink(
                        onPressed: () => _go(_page - 1),
                        child: Text(l10n.helpPrev),
                      ),
                    ),
            ),
            if (pages.length > 1)
              Text(
                l10n.helpPageCount(_page + 1, pages.length),
                style: Theme.of(context).textTheme.bodyMedium,
              ),
            Expanded(
              child: Align(
                alignment: Alignment.centerRight,
                child: last
                    ? SumiFuda(
                        onPressed: () => Navigator.of(context).pop(),
                        child: Text(l10n.helpDone),
                      )
                    : AiFuda(
                        onPressed: () => _go(_page + 1),
                        child: Text(l10n.helpNext),
                      ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _HelpPageView extends StatelessWidget {
  const _HelpPageView({required this.page});

  final HelpPage page;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return Padding(
      padding: const EdgeInsets.fromLTRB(24, 16, 24, 8),
      child: Column(
        children: [
          Expanded(
            child: Center(
              child: Container(
                padding: const EdgeInsets.all(3),
                decoration: BoxDecoration(
                  color: Washi.ink,
                  borderRadius: BorderRadius.circular(16),
                  boxShadow: const [
                    BoxShadow(
                      color: Color(0x33000000),
                      blurRadius: 8,
                      offset: Offset(0, 3),
                    ),
                  ],
                ),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(13),
                  child: Image.asset(
                    page.shot.asset,
                    fit: BoxFit.contain,
                    semanticLabel: page.caption(l10n),
                    errorBuilder: (_, _, _) => const AspectRatio(
                      aspectRatio: 393 / 852,
                      child: ColoredBox(color: Washi.page),
                    ),
                  ),
                ),
              ),
            ),
          ),
          const SizedBox(height: 16),
          Text(
            page.caption(l10n),
            style: Theme.of(context).textTheme.bodyLarge,
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }
}
