import 'package:get/get.dart';

import '../../domain/services_interfaces/i_role_service.dart';
import '../../domain/services_interfaces/i_messaging_service.dart';
import '../../domain/services_interfaces/i_session_service.dart';
import '../session/session_controller.dart';
import 'home_controller.dart';

class HomeBinding extends Bindings {
  @override
  void dependencies() {
    Get.lazyPut<HomeController>(
      () => HomeController(sessionService: Get.find<ISessionService>()),
    );
    if (!Get.isRegistered<SessionController>()) {
      Get.lazyPut<SessionController>(
        () => SessionController(
          roleService: Get.find<IRoleService>(),
          sessionService: Get.find<ISessionService>(),
          messagingService: Get.find<IMessagingService>(),
        ),
        fenix: true,
      );
    }
  }
}
