import 'dart:math';

class TimeUtils {
  static int nowMs() => DateTime.now().millisecondsSinceEpoch;

  static double clampDouble(double value, double minValue, double maxValue) {
    return max(minValue, min(value, maxValue));
  }
}

