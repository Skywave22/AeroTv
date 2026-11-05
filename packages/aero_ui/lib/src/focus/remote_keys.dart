import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';

/// Intents emitted by an Android TV remote. Registered once at the app root so
/// every screen can bind handlers via [Actions].
class PlayPauseIntent extends Intent {
  const PlayPauseIntent();
}

class SeekForwardIntent extends Intent {
  const SeekForwardIntent();
}

class SeekBackwardIntent extends Intent {
  const SeekBackwardIntent();
}

class ShowMenuIntent extends Intent {
  const ShowMenuIntent();
}

class ToggleControlsIntent extends Intent {
  const ToggleControlsIntent();
}

class StopIntent extends Intent {
  const StopIntent();
}

/// Maps the media keys found on TV remotes and Bluetooth controllers.
///
/// Covers both the Android TV remote codes and generic HID media keys so
/// Fire TV / Mi Box / Shield remotes all behave.
class RemoteKeys {
  const RemoteKeys._();

  static final Map<ShortcutActivator, Intent> shortcuts =
      <ShortcutActivator, Intent>{
    // Play / pause
    const SingleActivator(LogicalKeyboardKey.mediaPlayPause): PlayPauseIntent(),
    const SingleActivator(LogicalKeyboardKey.mediaPlay): PlayPauseIntent(),
    const SingleActivator(LogicalKeyboardKey.mediaPause): PlayPauseIntent(),
    const SingleActivator(LogicalKeyboardKey.space): PlayPauseIntent(),
    const SingleActivator(LogicalKeyboardKey.select): PlayPauseIntent(),
    const SingleActivator(LogicalKeyboardKey.enter): PlayPauseIntent(),
    const SingleActivator(LogicalKeyboardKey.gameButtonA): PlayPauseIntent(),

    // Seek — D-pad left/right and dedicated skip keys
    const SingleActivator(LogicalKeyboardKey.arrowRight): SeekForwardIntent(),
    const SingleActivator(LogicalKeyboardKey.mediaStepForward): SeekForwardIntent(),
    const SingleActivator(LogicalKeyboardKey.mediaFastForward): SeekForwardIntent(),
    const SingleActivator(LogicalKeyboardKey.arrowLeft): SeekBackwardIntent(),
    const SingleActivator(LogicalKeyboardKey.mediaStepBackward): SeekBackwardIntent(),
    const SingleActivator(LogicalKeyboardKey.mediaRewind): SeekBackwardIntent(),

    // Menu / info
    const SingleActivator(LogicalKeyboardKey.contextMenu): ShowMenuIntent(),
    const SingleActivator(LogicalKeyboardKey.info): ShowMenuIntent(),
    const SingleActivator(LogicalKeyboardKey.gameButtonMode): ShowMenuIntent(),
    const SingleActivator(LogicalKeyboardKey.arrowDown): ToggleControlsIntent(),
    const SingleActivator(LogicalKeyboardKey.arrowUp): ToggleControlsIntent(),

    // Stop
    const SingleActivator(LogicalKeyboardKey.mediaStop): StopIntent(),
    const SingleActivator(LogicalKeyboardKey.escape): StopIntent(),
  };
}
