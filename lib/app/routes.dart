import 'package:get/get.dart';

import '../presentation/home/home_binding.dart';
import '../presentation/home/home_page.dart';
import '../presentation/session/session_binding.dart';
import '../presentation/session/session_page.dart';

class Routes {
  static const home = '/';
  static const session = '/session';
}

final appRoutes = <GetPage<dynamic>>[
  GetPage(
    name: Routes.home,
    page: HomePage.new,
    binding: HomeBinding(),
  ),
  GetPage(
    name: Routes.session,
    page: SessionPage.new,
    binding: SessionBinding(),
  ),
];
