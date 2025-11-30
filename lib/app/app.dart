import 'package:flutter/material.dart';
import 'package:get/get.dart';

import 'di.dart';
import 'routes.dart';

class JamSyncApp extends StatefulWidget {
  const JamSyncApp({super.key});

  @override
  State<JamSyncApp> createState() => _JamSyncAppState();
}

class _JamSyncAppState extends State<JamSyncApp> {
  @override
  void initState() {
    super.initState();
    configureDependencies();
  }

  @override
  Widget build(BuildContext context) {
    return GetMaterialApp(
      title: 'jamSync',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.deepPurple),
        useMaterial3: true,
      ),
      getPages: appRoutes,
      initialRoute: Routes.home,
    );
  }
}

