import 'package:flutter/foundation.dart';

/// Fires whenever the pending/approved queue changes from outside the page
/// that's currently showing it (e.g. clipboard-triggered processLink running
/// in the background), mirroring the desktop app's broadcastQueueUpdate.
/// Pages that show queue contents should listen and refresh on change.
class QueueEvents {
  static final ValueNotifier<int> updates = ValueNotifier<int>(0);

  static void notify() => updates.value++;
}
