import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../domain/entities/session.dart';
import 'speaker_controller.dart';

class SpeakerPage extends GetView<SpeakerController> {
  const SpeakerPage({super.key});

  @override
  Widget build(BuildContext context) {
    final Session? session = Get.arguments as Session?;
    if (session != null) {
      controller.attachSession(session);
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('Speaker Mode'),
        backgroundColor: Theme.of(context).colorScheme.primaryContainer,
      ),
      body: Column(
        children: [
          // Session info banner
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(16),
            color: Theme.of(context).colorScheme.surfaceContainerHighest,
            child: Obx(() {
              final session = controller.currentSession.value;
              if (session == null) {
                return const Text('Waiting for session info...');
              }
              return Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(Icons.speaker_group,
                        color: Theme.of(context).colorScheme.primary),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          session.name,
                          style: Theme.of(context).textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Obx(() => Text(
                    'Playing in sync • ${controller.playbackState.value}',
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: Theme.of(context).colorScheme.onSurfaceVariant,
                    ),
                  )),
                ],
              );
            }),
          ),

          // Now playing section
          Expanded(
            child: Obx(() {
              final track = controller.currentTrack.value;
              if (track == null) {
                return const Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.music_note, size: 80, color: Colors.grey),
                      SizedBox(height: 16),
                      Text('No track playing', style: TextStyle(fontSize: 18, color: Colors.grey)),
                    ],
                  ),
                );
              }

              return SingleChildScrollView(
                padding: const EdgeInsets.all(24),
                child: Column(
                  children: [
                    const SizedBox(height: 32),
                    // Album art placeholder
                    Container(
                      width: 280,
                      height: 280,
                      decoration: BoxDecoration(
                        color: Theme.of(context).colorScheme.primaryContainer,
                        borderRadius: BorderRadius.circular(16),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withValues(alpha: 0.2),
                            blurRadius: 20,
                            offset: const Offset(0, 10),
                          ),
                        ],
                      ),
                      child: Icon(
                        Icons.music_note,
                        size: 120,
                        color: Theme.of(context).colorScheme.onPrimaryContainer,
                      ),
                    ),
                    const SizedBox(height: 48),

                    // Track title
                    Text(
                      track.title,
                      style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 8),

                    // Artist name
                    Text(
                      track.artist,
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        color: Colors.grey[600],
                      ),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 48),

                    // Sync status indicator
                    Obx(() {
                      final drift = controller.driftMs.value;
                      final isInSync = drift.abs() < 50;
                      return Container(
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                        decoration: BoxDecoration(
                          color: isInSync
                            ? Colors.green.withValues(alpha: 0.1)
                            : Colors.orange.withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(
                            color: isInSync ? Colors.green : Colors.orange,
                          ),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              isInSync ? Icons.check_circle : Icons.sync,
                              color: isInSync ? Colors.green : Colors.orange,
                              size: 20,
                            ),
                            const SizedBox(width: 8),
                            Text(
                              isInSync ? 'In Sync' : 'Syncing...',
                              style: TextStyle(
                                color: isInSync ? Colors.green : Colors.orange,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ],
                        ),
                      );
                    }),
                  ],
                ),
              );
            }),
          ),

          // Queue section
          Obx(() {
            final queue = controller.queue;
            if (queue.isEmpty) {
              return const SizedBox.shrink();
            }

            return Container(
              height: 200,
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.surface,
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.1),
                    blurRadius: 10,
                    offset: const Offset(0, -5),
                  ),
                ],
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Padding(
                    padding: const EdgeInsets.all(16),
                    child: Row(
                      children: [
                        Icon(Icons.queue_music,
                          color: Theme.of(context).colorScheme.primary),
                        const SizedBox(width: 8),
                        Text(
                          'Up Next',
                          style: Theme.of(context).textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                  ),
                  Expanded(
                    child: ListView.builder(
                      itemCount: queue.length,
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      itemBuilder: (context, index) {
                        final track = queue[index];
                        final isCurrent = controller.currentTrack.value?.id == track.id;
                        return ListTile(
                          dense: true,
                          contentPadding: const EdgeInsets.symmetric(horizontal: 8),
                          leading: Icon(
                            isCurrent ? Icons.equalizer : Icons.music_note,
                            color: isCurrent
                              ? Theme.of(context).colorScheme.primary
                              : Colors.grey,
                            size: 20,
                          ),
                          title: Text(
                            track.title,
                            style: TextStyle(
                              fontWeight: isCurrent ? FontWeight.bold : FontWeight.normal,
                              color: isCurrent
                                ? Theme.of(context).colorScheme.primary
                                : null,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                          subtitle: Text(
                            track.artist,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        );
                      },
                    ),
                  ),
                ],
              ),
            );
          }),
        ],
      ),
    );
  }
}
