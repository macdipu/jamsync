import 'package:flutter/material.dart';
import 'package:just_audio_background/just_audio_background.dart';

import 'app/app.dart';
import 'app/di.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await JustAudioBackground.init(
    androidNotificationChannelId: 'jamsync.playback',
    androidNotificationChannelName: 'jamSync Playback',
    androidNotificationOngoing: true,
  );
  await configureDependencies();
  runApp(const JamSyncApp());
}
