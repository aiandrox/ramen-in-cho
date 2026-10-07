import 'package:flutter_riverpod/flutter_riverpod.dart';

/// 下のタブ。並びは画面の左から（真ん中の判子を除く）。
enum AppTab { records, wishes, shugyo, map }

final appTabProvider = NotifierProvider<AppTabNotifier, AppTab>(
  AppTabNotifier.new,
);

class AppTabNotifier extends Notifier<AppTab> {
  @override
  AppTab build() => AppTab.records;

  void select(AppTab tab) => state = tab;
}

/// 印帳をいちばん上（新しい1杯）まで戻してほしいときに数を進める。
final ledgerTopRequestProvider = NotifierProvider<LedgerTopRequest, int>(
  LedgerTopRequest.new,
);

class LedgerTopRequest extends Notifier<int> {
  @override
  int build() => 0;

  void request() => state++;
}
