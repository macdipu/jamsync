import '../../core/logging/app_logger.dart';
import '../../domain/entities/control_message.dart';
import '../../domain/entities/device.dart';
import '../../domain/entities/session.dart';
import '../../domain/services_interfaces/i_messaging_service.dart';
import '../../domain/services_interfaces/i_role_service.dart';

class RoleServiceImpl implements IRoleService {
  RoleServiceImpl({
    required IMessagingService messagingService,
    required AppLogger logger,
  })  : _messagingService = messagingService,
        _logger = logger;

  final IMessagingService _messagingService;
  final AppLogger _logger;

  @override
  Future<Session> assignPlayer(Session session, Device newPlayer) async {
    final updated = session.copyWith(player: newPlayer);
    _logger.info('Assigning player ${newPlayer.id}');
    await _messagingService.send(
      ControlMessage(
        type: MessageType.roleChange,
        payload: {
          'sessionId': session.id,
          'newPlayerId': newPlayer.id,
        },
      ),
    );
    return updated;
  }

  @override
  Future<Session> assignSpeaker(Session session, Device speaker) async {
    final updatedMembers = [...session.members];
    final index = updatedMembers.indexWhere((device) => device.id == speaker.id);
    if (index >= 0) {
      updatedMembers[index] = speaker.copyWith(role: DeviceRole.speaker);
    } else {
      updatedMembers.add(speaker.copyWith(role: DeviceRole.speaker));
    }
    final updated = session.copyWith(members: updatedMembers);
    await _messagingService.send(
      ControlMessage(
        type: MessageType.roleChange,
        payload: {
          'sessionId': session.id,
          'speakerId': speaker.id,
        },
      ),
    );
    return updated;
  }
}
