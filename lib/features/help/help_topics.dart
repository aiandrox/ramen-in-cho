import '../../l10n/app_localizations.dart';

/// 使い方の絵。絵は `test/tool/help_shots_test.dart` で架空のデータから描いて作る。
enum HelpShot {
  recordStart,
  recordPhoto,
  recordShop,
  recordResult,
  queueStart,
  queueWaiting,
  retreat,
  rating,
  wishList,
  wishCandidate,
  mapSearch,
  journey,
  homeBase,
  shugyoRank,
  shugyoQuests,
  shugyoroku,
  share,
  backup;

  String get asset => 'assets/help/$name.webp';
}

/// 1枚の絵と、それに添える1〜2文。
class HelpPage {
  const HelpPage(this.shot, this.caption);

  final HelpShot shot;
  final String Function(AppLocalizations l10n) caption;
}

class HelpTopic {
  const HelpTopic({required this.title, required this.pages});

  final String Function(AppLocalizations l10n) title;
  final List<HelpPage> pages;
}

/// 使い方の項目。点の決まり方・印の意味・まだ会得していない秘伝の中身は書かない。
final helpTopics = <HelpTopic>[
  HelpTopic(
    title: (l) => l.helpRecordTitle,
    pages: [
      HelpPage(HelpShot.recordStart, (l) => l.helpRecordStart),
      HelpPage(HelpShot.recordPhoto, (l) => l.helpRecordPhoto),
      HelpPage(HelpShot.recordShop, (l) => l.helpRecordShop),
      HelpPage(HelpShot.recordResult, (l) => l.helpRecordResult),
    ],
  ),
  HelpTopic(
    title: (l) => l.helpQueueTitle,
    pages: [
      HelpPage(HelpShot.queueStart, (l) => l.helpQueueStart),
      HelpPage(HelpShot.queueWaiting, (l) => l.helpQueueWaiting),
    ],
  ),
  HelpTopic(
    title: (l) => l.helpRetreatTitle,
    pages: [HelpPage(HelpShot.retreat, (l) => l.helpRetreat)],
  ),
  HelpTopic(
    title: (l) => l.helpRatingTitle,
    pages: [HelpPage(HelpShot.rating, (l) => l.helpRating)],
  ),
  HelpTopic(
    title: (l) => l.helpWishTitle,
    pages: [
      HelpPage(HelpShot.wishList, (l) => l.helpWishList),
      HelpPage(HelpShot.wishCandidate, (l) => l.helpWishCandidate),
    ],
  ),
  HelpTopic(
    title: (l) => l.helpMapTitle,
    pages: [HelpPage(HelpShot.mapSearch, (l) => l.helpMapSearch)],
  ),
  HelpTopic(
    title: (l) => l.helpJourneyTitle,
    pages: [HelpPage(HelpShot.journey, (l) => l.helpJourney)],
  ),
  HelpTopic(
    title: (l) => l.helpHomeBaseTitle,
    pages: [HelpPage(HelpShot.homeBase, (l) => l.helpHomeBase)],
  ),
  HelpTopic(
    title: (l) => l.helpShugyoTitle,
    pages: [
      HelpPage(HelpShot.shugyoRank, (l) => l.helpShugyoRank),
      HelpPage(HelpShot.shugyoQuests, (l) => l.helpShugyoQuests),
      HelpPage(HelpShot.shugyoroku, (l) => l.helpShugyoroku),
    ],
  ),
  HelpTopic(
    title: (l) => l.helpShareTitle,
    pages: [HelpPage(HelpShot.share, (l) => l.helpShare)],
  ),
  HelpTopic(
    title: (l) => l.helpBackupTitle,
    pages: [HelpPage(HelpShot.backup, (l) => l.helpBackup)],
  ),
];
