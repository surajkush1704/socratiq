import 'package:flutter/cupertino.dart';

/// Standard page route across Socratiq.
/// Provides iOS-style slide-from-right transition and interactive swipe-to-go-back gesture.
class AppPageRoute<T> extends CupertinoPageRoute<T> {
  AppPageRoute({
    required super.builder,
    super.settings,
    super.maintainState = true,
    super.fullscreenDialog = false,
    super.allowSnapshotting = true,
    super.barrierDismissible = false,
  });
}
