import 'dart:async';

/// The Debouncer class is designed to limit the rate at which a function
/// is called. It ensures that the function is only executed if a certain
/// amount of time has passed since the last invocation of the execute method.
class Debouncer {
  /// The duration of the delay after which the action function will be called.
  final Duration delay;

  /// A Timer instance used to manage the delay for debouncing.
  Timer? _timer;

  /// The action function that will be executed after the delay.
  final void Function() action;

  /// Constructs a Debouncer instance with the specified delay and action.
  ///
  /// [delay] is the amount of time to wait before executing the action.
  /// [action] is the function that will be executed after the delay.
  Debouncer({
    required this.delay,
    required this.action,
  });

  /// Call this method to trigger the debounced execution of the action.
  ///
  /// If another execution is already scheduled, this call is ignored.
  void execute() {
    // If the timer is active, ignore this invocation
    if (_timer?.isActive ?? false) {
      return;
    }

    // Wait for the specified delay before executing the action
    _timer = Timer(delay, action);
  }

  /// Cancel the timer when the instance is disposed of.
  /// This is important to prevent any scheduled execution after the instance
  /// is considered no longer needed.
  void dispose() {
    // Cancel any existing timer to clear the scheduled action
    _timer?.cancel();
  }
}
