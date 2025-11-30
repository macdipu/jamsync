import 'package:get/get.dart';

import '../../domain/services_interfaces/i_session_service.dart';
import 'home_controller.dart';

class HomeBinding extends Bindings {
  @override
  void dependencies() {
    Get.lazyPut<HomeController>(
      () => HomeController(sessionService: Get.find<ISessionService>()),
    );
  }
}

