import '../entities/control_message.dart';
import '../entities/sync_packet.dart';
import '../services_interfaces/i_playback_service.dart';

abstract class ISyncEngine {
  void bindPlayback(IPlaybackService playback);
  void onPing(ControlMessage message);
  void onPong(ControlMessage message);
  void onSyncTick(SyncPacket packet);
  void setUserOffset(Duration offset);
}

