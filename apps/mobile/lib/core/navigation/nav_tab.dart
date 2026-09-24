import 'package:flutter_riverpod/flutter_riverpod.dart';

class NavTabNotifier extends Notifier<int> {
  @override
  int build() => 0;

  void select(int index) => state = index;
}

final navTabProvider = NotifierProvider<NavTabNotifier, int>(NavTabNotifier.new);

abstract final class NavTabs {
  static const home = 0;
  static const history = 1;
  static const nearby = 2;
  static const profile = 3;
}
