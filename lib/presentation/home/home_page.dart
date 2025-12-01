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
        return StreamBuilder<List<SessionSummary>>(
          stream: controller.discoveredSessions$,
          builder: (context, snapshot) {
            final sessions = snapshot.data ?? const [];
            return SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _HeroActions(
                    onCreate: () => _handleCreateSession(context),
                    onResume: controller.lastSession.value == null
                        ? null
                        : controller.resumeLastSession,
                    onLogs: () => Get.toNamed(Routes.logs),
                    isBusy: controller.isLoading.value,
                  ),
                  const SizedBox(height: 16),
                  _StatsRow(
                    discovered: sessions.length,
                    lastSessionName: controller.lastSession.value?.summary.name,
                  ),
                  const SizedBox(height: 16),
                  _SessionList(
                    sessions: sessions,
                    onJoin: controller.joinSession,
                  ),
                ],
              ),
            );
          },
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

class _HeroActions extends StatelessWidget {
  const _HeroActions({
    required this.onCreate,
    required this.onLogs,
    required this.isBusy,
    this.onResume,
  });

  final VoidCallback onCreate;
  final VoidCallback onLogs;
  final bool isBusy;
  final VoidCallback? onResume;

  @override
  Widget build(BuildContext context) {
    return Card(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      elevation: 2,
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Run a LAN jam',
              style: Theme.of(context).textTheme.titleLarge,
            ),
            const SizedBox(height: 8),
            Text(
              'Create a new session or hop back into the last one you hosted.',
              style: Theme.of(context).textTheme.bodyMedium,
            ),
            const SizedBox(height: 16),
            Wrap(
              spacing: 12,
              runSpacing: 12,
              children: [
                FilledButton.icon(
                  onPressed: isBusy ? null : onCreate,
                  icon: const Icon(Icons.add_circle_outline),
                  label: const Text('Create Session'),
                ),
                if (onResume != null)
                  OutlinedButton.icon(
                    onPressed: isBusy ? null : onResume,
                    icon: const Icon(Icons.restart_alt),
                    label: const Text('Resume last session'),
                  ),
                IconButton.outlined(
                  onPressed: onLogs,
                  icon: const Icon(Icons.list_alt),
                  tooltip: 'View logs',
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _StatsRow extends StatelessWidget {
  const _StatsRow({required this.discovered, this.lastSessionName});

  final int discovered;
  final String? lastSessionName;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        _StatChip(
          label: 'Discovered',
          value: discovered.toString(),
          icon: Icons.wifi_tethering,
        ),
        const SizedBox(width: 12),
        Expanded(
          child: _StatChip(
            label: 'Last session',
            value: lastSessionName ?? 'None yet',
            icon: Icons.history,
          ),
        ),
      ],
    );
  }
}

class _StatChip extends StatelessWidget {
  const _StatChip({required this.label, required this.value, required this.icon});

  final String label;
  final String value;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(12),
        color: Theme.of(context).colorScheme.surfaceContainerHighest,
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 18),
          const SizedBox(width: 8),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(label, style: Theme.of(context).textTheme.labelMedium),
              Text(value, style: Theme.of(context).textTheme.titleMedium),
            ],
          ),
        ],
      ),
    );
  }
}

class _SessionList extends StatelessWidget {
  const _SessionList({required this.sessions, required this.onJoin});

  final List<SessionSummary> sessions;
  final void Function(SessionSummary) onJoin;

  @override
  Widget build(BuildContext context) {
    if (sessions.isEmpty) {
      return const _EmptyState();
    }
    return ListView.separated(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      itemCount: sessions.length,
      separatorBuilder: (_, __) => const SizedBox(height: 12),
      itemBuilder: (context, index) {
        final session = sessions[index];
        return _SessionCard(
          session: session,
          onJoin: () => onJoin(session),
        );
      },
    );
  }
}

class _SessionCard extends StatelessWidget {
  const _SessionCard({required this.session, required this.onJoin});

  final SessionSummary session;
  final VoidCallback onJoin;

  @override
  Widget build(BuildContext context) {
    return Card(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: ListTile(
        title: Text(session.name, style: Theme.of(context).textTheme.titleMedium),
        subtitle: Text('${session.hostName} • ${session.ip}:${session.port}'),
        trailing: FilledButton(
          onPressed: onJoin,
          child: const Text('Join'),
        ),
      ),
    );
  }
}

class _EmptyState extends StatelessWidget {
  const _EmptyState();

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 48),
      child: Column(
        children: [
          Icon(Icons.sensors_off, size: 48, color: Theme.of(context).colorScheme.outline),
          const SizedBox(height: 12),
          Text(
            'No sessions detected',
            style: Theme.of(context).textTheme.titleMedium,
          ),
          const SizedBox(height: 4),
          Text(
            'Make sure everyone is on the same LAN/hotspot and discovery is enabled.',
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.bodySmall,
          ),
        ],
      ),
    );
  }
}
