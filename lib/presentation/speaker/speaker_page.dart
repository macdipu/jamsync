import 'package:flutter/material.dart';
import 'package:get/get.dart';

import 'speaker_controller.dart';

class SpeakerPage extends GetView<SpeakerController> {
  const SpeakerPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Speaker')),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Obx(() {
              final session = controller.currentSession.value;
              if (session == null) {
                return const Text('Waiting for session info...');
              }
              return Text('Session: ${session.name}');
            }),
            const SizedBox(height: 8),
            Obx(() {
              final track = controller.currentTrack.value;
              if (track == null) {
                return const Text('Now Playing: --');
              }
              return Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Now Playing: ${track.title}', style: Theme.of(context).textTheme.titleMedium),
                  Text(track.artist, style: Theme.of(context).textTheme.bodySmall),
                ],
              );
            }),
            const SizedBox(height: 16),
            Obx(() => Text('Drift: ${controller.driftMs.value.toStringAsFixed(2)} ms')),
            Obx(() => Text('Latency: ${controller.latencyMs.value} ms')),
            const SizedBox(height: 16),
            const Text('Drift trend (ms)'),
            Obx(() {
              final history = controller.driftHistory;
              if (history.isEmpty) {
                return const Text('No data yet');
              }
              return SizedBox(
                height: 80,
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: history
                      .map((value) => Expanded(
                            child: Container(
                              margin: const EdgeInsets.symmetric(horizontal: 1),
                              height: value.abs().clamp(4.0, 80.0),
                              color: value.abs() > 150 ? Colors.red : Colors.green,
                            ),
                          ))
                      .toList(),
                ),
              );
            }),
            const SizedBox(height: 16),
            const Text('Manual Offset (ms)'),
            Obx(() {
              return Slider(
                value: controller.userOffset.value,
                min: -200,
                max: 200,
                onChanged: controller.setUserOffset,
              );
            }),
            const SizedBox(height: 16),
            Obx(() {
              final queue = controller.queue;
              if (queue.isEmpty) {
                return const Padding(
                  padding: EdgeInsets.symmetric(vertical: 16),
                  child: Text('Queue is empty'),
                );
              }
              return Expanded(
                child: ListView.builder(
                  itemCount: queue.length,
                  itemBuilder: (context, index) {
                    final track = queue[index];
                    final isCurrent = controller.currentTrack.value?.id == track.id;
                    return ListTile(
                      leading: Icon(isCurrent ? Icons.equalizer : Icons.music_note,
                          color: isCurrent ? Theme.of(context).colorScheme.primary : null),
                      title: Text(track.title),
                      subtitle: Text(track.artist),
                      trailing: isCurrent ? const Text('Playing') : null,
                    );
                  },
                ),
              );
            }),
            const SizedBox(height: 16),
            Obx(() => Text('Playback state: ${controller.playbackState.value}')),
          ],
        ),
      ),
    );
  }
}
