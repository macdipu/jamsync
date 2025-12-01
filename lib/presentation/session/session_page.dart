import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../domain/entities/device.dart';
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
              subtitle: Text('Admin: ${current.admin.name} • ${current.admin.ip}:${current.admin.port}'),
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
                    final isLocal = member.isLocal;
                    final roleLabel = member.role.name.toUpperCase();
                    final subtitle = '${member.ip}:${member.port} • $roleLabel';
                    return ListTile(
                      leading: CircleAvatar(
                        backgroundColor: _roleColor(member.role, context),
                        child: Icon(_roleIcon(member.role), color: Colors.white),
                      ),
                      title: Row(
                        children: [
                          Expanded(child: Text(member.name)),
                          if (isLocal)
                            Padding(
                              padding: const EdgeInsets.only(left: 6),
                              child: Chip(
                                label: const Text('You'),
                                backgroundColor: Theme.of(context).colorScheme.primaryContainer,
                                materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                              ),
                            ),
                        ],
                      ),
                      subtitle: Text(subtitle),
                      trailing: PopupMenuButton<String>(
                        onSelected: (value) {
                          switch (value) {
                            case 'make_player':
                              controller.assignPlayer(member);
                              break;
                            case 'make_speaker':
                              controller.assignSpeaker(member);
                              break;
                            case 'open_player':
                              controller.openPlayer(member);
                              break;
                            case 'open_speaker':
                              controller.openSpeaker(member);
                              break;
                          }
                        },
                        itemBuilder: (_) => [
                          PopupMenuItem(
                            value: 'make_player',
                            enabled: member.role != DeviceRole.player && member.role != DeviceRole.admin,
                            child: const Text('Make Player (time source)'),
                          ),
                          PopupMenuItem(
                            value: 'make_speaker',
                            enabled: member.role != DeviceRole.speaker,
                            child: const Text('Make Speaker (listener)'),
                          ),
                          const PopupMenuDivider(),
                          PopupMenuItem(
                            value: 'open_player',
                            child: Text('Open Player UI${member.isLocal ? ' (you)' : ''}'),
                          ),
                          PopupMenuItem(
                            value: 'open_speaker',
                            child: Text('Open Speaker UI${member.isLocal ? ' (you)' : ''}'),
                          ),
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
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  RoleBadge(
                    label: 'Host / Admin',
                    value: session.admin.name,
                    icon: Icons.verified_user,
                    color: Colors.deepPurple,
                  ),
                  RoleBadge(
                    label: 'Player',
                    value: session.player?.name ?? 'Not assigned',
                    icon: Icons.play_circle_fill,
                    color: Colors.teal,
                  ),
                  RoleBadge(
                    label: 'Speakers',
                    value: session.members.where((m) => m.role == DeviceRole.speaker).length.toString(),
                    icon: Icons.speaker_group,
                    color: Colors.orange,
                  ),
                ],
              ),
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

Color _roleColor(DeviceRole role, BuildContext context) {
  switch (role) {
    case DeviceRole.admin:
      return Colors.deepPurple;
    case DeviceRole.player:
      return Colors.teal;
    case DeviceRole.speaker:
      return Colors.orange;
  }
}

IconData _roleIcon(DeviceRole role) {
  switch (role) {
    case DeviceRole.admin:
      return Icons.verified_user;
    case DeviceRole.player:
      return Icons.play_arrow;
    case DeviceRole.speaker:
      return Icons.speaker_phone;
  }
}

class RoleBadge extends StatelessWidget {
  const RoleBadge({
    required this.label,
    required this.value,
    required this.icon,
    required this.color,
    super.key,
  });

  final String label;
  final String value;
  final IconData icon;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withValues(alpha: 0.5)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, color: color, size: 18),
          const SizedBox(width: 6),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(label, style: Theme.of(context).textTheme.labelSmall),
              Text(value, style: Theme.of(context).textTheme.titleSmall?.copyWith(color: color)),
            ],
          ),
        ],
      ),
    );
  }
}
