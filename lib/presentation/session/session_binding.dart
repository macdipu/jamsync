import 'package:get/get.dart';

import '../../domain/services_interfaces/i_role_service.dart';
import 'session_controller.dart';

class SessionBinding extends Bindings {
  @override
  void dependencies() {
    Get.lazyPut<SessionController>(
      () => SessionController(
        roleService: Get.find<IRoleService>(),
      ),
    );
  }
}
