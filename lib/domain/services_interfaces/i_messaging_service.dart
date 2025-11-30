import '../entities/control_message.dart';

abstract class IMessagingService {
  Future<void> startHub({required int port});
  Future<void> stopHub();
  Future<void> connect({required String host, required int port});
  Future<void> disconnect();
  Stream<ControlMessage> get messages$;
  Future<void> send(ControlMessage message);
}

