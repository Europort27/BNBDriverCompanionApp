String _pad(int value) => value.toString().padLeft(2, '0');

/// Formats a duration as hh:mm:ss.
String formatClock(Duration duration) =>
    '${_pad(duration.inHours)}:${_pad(duration.inMinutes.remainder(60))}:'
    '${_pad(duration.inSeconds.remainder(60))}';

/// Formats seconds as mm:ss, or h:mm:ss past an hour.
String formatCompactDuration(int totalSeconds) {
  final duration = Duration(seconds: totalSeconds);
  final minutes = _pad(duration.inMinutes.remainder(60));
  final seconds = _pad(duration.inSeconds.remainder(60));
  return duration.inHours > 0
      ? '${duration.inHours}:$minutes:$seconds'
      : '$minutes:$seconds';
}

/// Converts meters to miles with two decimals.
String formatMiles(double meters) =>
    '${(meters / 1609.344).toStringAsFixed(2)} mi';
