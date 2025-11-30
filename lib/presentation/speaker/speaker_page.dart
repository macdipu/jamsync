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
            Expanded(
              child: Center(
                child: Obx(() => Text('Playback state: ${controller.playbackState.value}')),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
