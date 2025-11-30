import '../entities/device.dart';
import '../entities/session_summary.dart';

class SessionResumeData {
  const SessionResumeData({required this.summary, required this.device});

  final SessionSummary summary;
  final Device device;

  Map<String, dynamic> toJson() => {
        'summary': summary.toJson(),
        'device': device.toJson(),
      };

  factory SessionResumeData.fromJson(Map<String, dynamic> json) {
    return SessionResumeData(
      summary: SessionSummary.fromJson(json['summary'] as Map<String, dynamic>),
      device: Device.fromJson(json['device'] as Map<String, dynamic>),
    );
  }
}
