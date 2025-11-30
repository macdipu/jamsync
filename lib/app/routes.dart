import 'package:get/get.dart';

import '../presentation/home/home_binding.dart';
import '../presentation/home/home_page.dart';
import '../presentation/player/player_binding.dart';
import '../presentation/player/player_page.dart';
import '../presentation/session/session_binding.dart';
import '../presentation/session/session_page.dart';
import '../presentation/speaker/speaker_binding.dart';
import '../presentation/speaker/speaker_page.dart';

class Routes {
  static const home = '/';
  static const session = '/session';
  static const player = '/player';
  static const speaker = '/speaker';
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
  GetPage(
    name: Routes.player,
    page: PlayerPage.new,
    binding: PlayerBinding(),
  ),
  GetPage(
    name: Routes.speaker,
    page: SpeakerPage.new,
    binding: SpeakerBinding(),
  ),
];
