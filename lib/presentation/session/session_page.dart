import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../domain/entities/session.dart';
import '../../domain/services_interfaces/i_messaging_service.dart';
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
            _SessionHero(session: current),
            Obx(() {
              final state = controller.connectionState.value;
              if (state == MessagingConnectionState.connected) {
                return const SizedBox.shrink();
              }
              return Container(
                width: double.infinity,
                color: Colors.amber.shade100,
                padding: const EdgeInsets.all(12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        const Icon(Icons.wifi_off, size: 18),
                        const SizedBox(width: 8),
                        Text('Connection: ${state.name}'),
                        const Spacer(),
                        Obx(() {
                          return ElevatedButton.icon(
                            onPressed: controller.reconnecting.value
                                ? null
                                : () => controller.attemptReconnect(showToast: true),
                            icon: controller.reconnecting.value
                                ? const SizedBox(
                                    width: 14,
                                    height: 14,
                                    child: CircularProgressIndicator(strokeWidth: 2),
                                  )
                                : const Icon(Icons.refresh, size: 16),
                            label: Text(controller.reconnecting.value ? 'Retrying...' : 'Retry'),
                          );
                        }),
                      ],
                    ),
                    Obx(() {
                      final error = controller.lastError.value;
                      return error == null
                          ? const SizedBox.shrink()
                          : Padding(
                              padding: const EdgeInsets.only(top: 8),
                              child: Text(error, style: const TextStyle(color: Colors.red)),
                            );
                    }),
                  ],
                ),
              );
            }),
            ListTile(
              title: Text(current.name),
              subtitle: Text('Admin: ${current.admin.name}'),
              trailing: FilledButton.icon(
                onPressed: controller.scanLocalLibrary,
                icon: const Icon(Icons.library_music),
                label: const Text('Scan MP3s'),
              ),
            ),
            const Padding(
              padding: EdgeInsets.symmetric(horizontal: 16),
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
                          } else if (value == 'view_player') {
                            controller.openPlayer(member);
                          } else if (value == 'view_speaker') {
                            controller.openSpeaker(member);
                          }
                        },
                        itemBuilder: (_) => const [
                          PopupMenuItem(value: 'player', child: Text('Make Player')),
                          PopupMenuItem(value: 'speaker', child: Text('Make Speaker')),
                          PopupMenuItem(value: 'view_player', child: Text('Open Player UI')),
                          PopupMenuItem(value: 'view_speaker', child: Text('Open Speaker UI')),
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

class _SessionHero extends StatelessWidget {
  const _SessionHero({required this.session});

  final Session session;

  @override
  Widget build(BuildContext context) {
    final controller = Get.find<SessionController>();
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Card(
        elevation: 3,
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(session.name, style: Theme.of(context).textTheme.titleLarge),
              const SizedBox(height: 4),
              Text('Admin: ${session.admin.name}', style: Theme.of(context).textTheme.bodySmall),
              const Divider(height: 24),
              Row(
                children: [
                  const Icon(Icons.music_note, size: 18),
                  const SizedBox(width: 8),
                  Obx(() => Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(controller.nowPlayingTitle.value, style: Theme.of(context).textTheme.titleMedium),
                            if (controller.nowPlayingArtist.value.isNotEmpty)
                              Text(controller.nowPlayingArtist.value, style: Theme.of(context).textTheme.bodySmall),
                          ],
                        ),
                      )),
                  IconButton(
                    icon: const Icon(Icons.queue_music),
                    onPressed: session.queue.isEmpty
                        ? null
                        : () => controller.openPlayer(session.player ?? session.admin),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
