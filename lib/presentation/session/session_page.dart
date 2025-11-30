import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../domain/entities/session.dart';
import 'session_controller.dart';

class SessionPage extends GetView<SessionController> {
  const SessionPage({super.key});

  @override
  Widget build(BuildContext context) {
    final Session? session = Get.arguments as Session?;
    if (session != null) {
      controller.attachSession(session);
    }
    return Scaffold(
      appBar: AppBar(title: const Text('Session')),
      body: Obx(() {
        final current = controller.currentSession.value;
        if (current == null) {
          return const Center(child: Text('No session selected.'));
        }
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            ListTile(
              title: Text(current.name),
              subtitle: Text('Admin: ${current.admin.name}'),
            ),
            const Padding(
              padding: EdgeInsets.all(16),
              child: Text('Members', style: TextStyle(fontWeight: FontWeight.bold)),
            ),
            Expanded(
              child: Obx(() {
                final members = controller.members;
                return ListView.builder(
                  itemCount: members.length,
                  itemBuilder: (context, index) {
                    final member = members[index];
                    return ListTile(
                      title: Text(member.name),
                      subtitle: Text(member.role.name),
                      trailing: PopupMenuButton<String>(
                        onSelected: (value) {
                          if (value == 'player') {
                            controller.assignPlayer(member);
                          } else if (value == 'speaker') {
                            controller.assignSpeaker(member);
                          }
                        },
                        itemBuilder: (_) => const [
                          PopupMenuItem(value: 'player', child: Text('Make Player')),
                          PopupMenuItem(value: 'speaker', child: Text('Make Speaker')),
                        ],
                      ),
                    );
                  },
                );
              }),
            ),
          ],
        );
      }),
    );
  }
}
