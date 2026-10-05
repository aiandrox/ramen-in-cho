import 'package:flutter/material.dart';

/// 下から出る窓。下のタブの上に重ねず、画面の下端（タブも覆う）から出し、
/// 端末の帯（ステータスバーなど）にかからないようにする。
Future<T?> showWashiSheet<T>({
  required BuildContext context,
  required WidgetBuilder builder,
  bool isScrollControlled = false,
}) => showModalBottomSheet<T>(
  context: context,
  useRootNavigator: true,
  useSafeArea: true,
  isScrollControlled: isScrollControlled,
  showDragHandle: true,
  builder: builder,
);
