import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../app/routes.dart';
import '../../domain/entities/session_summary.dart';
import 'home_controller.dart';

class HomePage extends GetView<HomeController> {
  const HomePage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('jamSync')),
      body: Obx(() {
        if (controller.isLoading.value) {
          return const Center(child: CircularProgressIndicator());
        }
        return Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  ElevatedButton(
                    onPressed: controller.isLoading.value
                        ? null
                        : () async {
                            await _handleCreateSession(context);
                          },
                    child: const Text('Create Session'),
                  ),
                  const SizedBox(width: 8),
                  Obx(() {
                    final resume = controller.lastSession.value;
                    if (resume == null) {
                      return const SizedBox.shrink();
                    }
                    return OutlinedButton(
                      onPressed: controller.isLoading.value ? null : controller.resumeLastSession,
                      child: const Text('Resume last session'),
                    );
                  }),
                  const Spacer(),
                  IconButton(
                    icon: const Icon(Icons.list_alt),
                    onPressed: () => Get.toNamed(Routes.logs),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              Expanded(
                child: StreamBuilder<List<SessionSummary>>(
                  stream: controller.discoveredSessions$,
                  builder: (context, snapshot) {
                    final sessions = snapshot.data ?? const [];
                    if (sessions.isEmpty) {
                      return const Center(child: Text('No sessions yet.'));
                    }
                    return ListView.builder(
                      itemCount: sessions.length,
                      itemBuilder: (context, index) {
                        final session = sessions[index];
                        return ListTile(
                          title: Text(session.name),
                          subtitle: Text('${session.hostName} • ${session.ip}:${session.port}'),
                          trailing: TextButton(
                            onPressed: () => controller.joinSession(session),
                            child: const Text('Join'),
                          ),
                        );
                      },
                    );
                  },
                ),
              ),
            ],
          ),
        );
      }),
    );
  }

  Future<void> _handleCreateSession(BuildContext context) async {
    final name = await _askSessionName(context);
    if (name == null) {
      return;
    }
    await controller.createSessionFromInput(name);
  }

  Future<String?> _askSessionName(BuildContext context) {
    final controller = TextEditingController();
    return showDialog<String>(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('Session Name'),
          content: TextField(
            controller: controller,
            decoration: const InputDecoration(hintText: 'My Jam'),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: () {
                final text = controller.text.trim();
                Navigator.of(context).pop(text.isEmpty ? null : text);
              },
              child: const Text('Create'),
            ),
          ],
        );
      },
    );
  }
}
