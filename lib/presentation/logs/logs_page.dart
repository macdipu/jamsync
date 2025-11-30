import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../core/logging/app_logger.dart';

class LogsPage extends StatelessWidget {
  const LogsPage({super.key});

  @override
  Widget build(BuildContext context) {
    final logger = Get.find<AppLogger>();
    return Scaffold(
      appBar: AppBar(title: const Text('Session Logs')),
      body: FutureBuilder<List<String>>(
        future: logger.loadEntries(),
        builder: (context, snapshot) {
          if (!snapshot.hasData) {
            return const Center(child: CircularProgressIndicator());
          }
          final entries = snapshot.data!;
          if (entries.isEmpty) {
            return const Center(child: Text('No logs yet.'));
          }
          return ListView.builder(
            itemCount: entries.length,
            itemBuilder: (context, index) => ListTile(
              dense: true,
              title: Text(entries[index]),
            ),
          );
        },
      ),
    );
  }
}

