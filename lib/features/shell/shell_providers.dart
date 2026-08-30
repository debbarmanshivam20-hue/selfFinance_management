import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Which root tab the shell is showing.
///
/// Exposed as state (rather than kept inside the shell widget) so any screen
/// can navigate the user to another tab - for example the dashboard's
/// "View all" jumping to the History tab.
class ShellTabController extends Notifier<int> {
  static const int dashboard = 0;
  static const int history = 1;
  static const int analytics = 2;
  static const int settings = 3;

  @override
  int build() => dashboard;

  void select(int index) => state = index.clamp(0, 3);
}

final shellTabProvider =
    NotifierProvider<ShellTabController, int>(ShellTabController.new);
