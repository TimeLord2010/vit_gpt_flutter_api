import 'dart:collection';

/// A class that smooths volume values over time using a configurable smoothing factor.
///
/// This class maintains a history of volume values and applies exponential moving average
/// smoothing to reduce noise and sudden changes in volume readings.
class VolumeSmoother {
  /// The smoothing factor (0.0 to 1.0).
  /// - 0.0: No smoothing (raw values pass through)
  /// - 1.0: Maximum smoothing (very slow response to changes)
  /// - Typical values: 0.1 to 0.8
  final double smoothingFactor;

  /// Maximum number of volume values to keep in history
  final int _maxHistorySize;

  /// History of volume values for smoothing calculations
  final Queue<double> _volumeHistory = Queue<double>();

  /// Current smoothed volume value
  double _currentSmoothedVolume = 0.0;

  /// Whether this is the first volume value received
  bool _isFirstValue = true;

  /// Creates a VolumeSmoother with the specified smoothing factor.
  ///
  /// [smoothingFactor] controls how much smoothing is applied (0.0 to 1.0).
  ///
  /// [maxHistorySize] limits the number of volume values kept in history (default: 100).
  VolumeSmoother({
    double smoothingFactor = 0.3,
    int maxHistorySize = 100,
  })  : smoothingFactor = smoothingFactor.clamp(0.0, 1.0),
        _maxHistorySize = maxHistorySize;

  /// Gets the current smoothed volume value.
  double get currentVolume => _currentSmoothedVolume;

  /// Gets the number of volume values in history.
  int get historySize => _volumeHistory.length;

  /// Gets a copy of the volume history as a list.
  List<double> get volumeHistory => List<double>.from(_volumeHistory);

  /// Processes a raw volume value and returns the smoothed result.
  ///
  /// [rawVolume] should be a value between 0.0 and 1.0.
  /// Returns the smoothed volume value.
  double smooth(double rawVolume) {
    // Clamp input to valid range
    rawVolume = rawVolume.clamp(0.0, 1.0);

    // Add to history
    _volumeHistory.addLast(rawVolume);

    // Maintain history size limit
    while (_volumeHistory.length > _maxHistorySize) {
      _volumeHistory.removeFirst();
    }

    // For the first value, initialize without smoothing
    if (_isFirstValue) {
      _currentSmoothedVolume = rawVolume;
      _isFirstValue = false;
      return _currentSmoothedVolume;
    }

    // Apply exponential moving average smoothing
    // Formula: smoothed = (1 - factor) * new_value + factor * previous_smoothed
    _currentSmoothedVolume = (1.0 - smoothingFactor) * rawVolume +
        smoothingFactor * _currentSmoothedVolume;

    return _currentSmoothedVolume;
  }

  /// Resets the smoother to its initial state.
  ///
  /// Clears the volume history and resets the current smoothed volume to 0.0.
  void reset() {
    _volumeHistory.clear();
    _currentSmoothedVolume = 0.0;
    _isFirstValue = true;
  }

  /// Gets the average volume from the current history.
  double get averageVolume {
    if (_volumeHistory.isEmpty) return 0.0;

    double sum = _volumeHistory.fold(0.0, (sum, volume) => sum + volume);
    return sum / _volumeHistory.length;
  }

  /// Gets the peak (maximum) volume from the current history.
  double get peakVolume {
    if (_volumeHistory.isEmpty) return 0.0;

    return _volumeHistory.reduce((a, b) => a > b ? a : b);
  }

  /// Gets the minimum volume from the current history.
  double get minimumVolume {
    if (_volumeHistory.isEmpty) return 0.0;

    return _volumeHistory.reduce((a, b) => a < b ? a : b);
  }

  /// Gets statistics about the volume history.
  VolumeStatistics get statistics {
    return VolumeStatistics(
      current: _currentSmoothedVolume,
      average: averageVolume,
      peak: peakVolume,
      minimum: minimumVolume,
      historySize: _volumeHistory.length,
      smoothingFactor: smoothingFactor,
    );
  }
}

/// Statistics about volume smoothing.
class VolumeStatistics {
  /// Current smoothed volume value
  final double current;

  /// Average volume from history
  final double average;

  /// Peak volume from history
  final double peak;

  /// Minimum volume from history
  final double minimum;

  /// Number of values in history
  final int historySize;

  /// Current smoothing factor
  final double smoothingFactor;

  const VolumeStatistics({
    required this.current,
    required this.average,
    required this.peak,
    required this.minimum,
    required this.historySize,
    required this.smoothingFactor,
  });

  @override
  String toString() {
    return 'VolumeStatistics(current: ${current.toStringAsFixed(3)}, '
        'average: ${average.toStringAsFixed(3)}, '
        'peak: ${peak.toStringAsFixed(3)}, '
        'minimum: ${minimum.toStringAsFixed(3)}, '
        'historySize: $historySize, '
        'smoothingFactor: ${smoothingFactor.toStringAsFixed(2)})';
  }
}
