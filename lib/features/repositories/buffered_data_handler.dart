import 'dart:async';

class BufferedDataHandler {
  final void Function(String) _addDataFunction;

  /// Interval to wait before sending data in seconds.
  final int _interval;

  /// Buffer to hold incoming data.
  String _dataBuffer = '';

  /// Last time data was sent.
  int _lastSentTime = 0;

  Timer? _timer;

  void dispose() {
    _timer?.cancel();
    _dataBuffer = '';
    _lastSentTime = 0;
    _timer = null;
  }

  /// Creates a [BufferedDataHandler] that handles the data buffering and delayed processing.
  ///
  /// @param addDataFunction Function to handle data adding.
  /// @param interval Time interval in milliseconds for transmitting buffered data.
  BufferedDataHandler(
    this._addDataFunction, {
    int interval = 1000,
  }) : _interval = interval;

  /// Adds data to the buffer and processes it with controlled timing.
  void addData(String base64String) {
    final currentTime = DateTime.now().millisecondsSinceEpoch;

    // Append incoming data to the buffer
    _dataBuffer += base64String;

    final elapsedTime = currentTime - _lastSentTime;

    // If it's been at least _interval milliseconds or no new data is received within the interval
    if (elapsedTime >= _interval) {
      _sendDataToPlayer();
    } else {
      _timer?.cancel();

      // Set a timer to send data if no further data arrives within the remaining interval
      _timer = Timer(
          Duration(milliseconds: _interval - elapsedTime), _sendDataToPlayer);
    }
  }

  /// Sends the accumulated data to the player and resets the timer and buffer.
  void _sendDataToPlayer() {
    if (_dataBuffer.isEmpty) {
      return;
    }
    _addDataFunction(_dataBuffer);
    _dataBuffer = '';
    _lastSentTime = DateTime.now().millisecondsSinceEpoch;
  }
}
