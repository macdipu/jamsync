import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../domain/entities/session.dart';
import '../../domain/entities/track.dart';
import '../widgets/track_tile.dart';
import 'player_controller.dart';

class PlayerPage extends GetView<PlayerController> {
  const PlayerPage({super.key});

  @override
  Widget build(BuildContext context) {
    final session = Get.arguments as Session?;
    if (session != null) {
      controller.attachSession(session);
    }
    return Scaffold(
      appBar: AppBar(title: const Text('Player Controls')),
      body: Obx(() {
        final track = controller.selectedTrack.value;
        final queue = controller.queue;
        final scanning = controller.isScanning.value;
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (track != null) ...[
              ListTile(
                title: Text(track.title),
                subtitle: Text(track.artist),
              ),
              Obx(() {
                final position = controller.playbackPosition.value;
                final duration = track.duration ?? const Duration(minutes: 3);
                return Slider(
                  value: position.inSeconds.toDouble(),
                  max: duration.inSeconds.toDouble(),
                  onChanged: (value) => controller.seek(Duration(seconds: value.toInt())),
                );
              }),
              Row(
                children: [
                  IconButton(
                    icon: const Icon(Icons.skip_previous),
                    onPressed: queue.isEmpty ? null : () => _playPrevious(queue, track),
                  ),
                  Obx(() {
                    final isPlaying = controller.isPlaying.value;
                    return IconButton(
                      icon: Icon(isPlaying ? Icons.pause : Icons.play_arrow),
                      onPressed: isPlaying ? controller.pause : controller.play,
                    );
                  }),
                  IconButton(
                    icon: const Icon(Icons.skip_next),
                    onPressed: queue.isEmpty ? null : () => _playNext(queue, track),
                  ),
                ],
              ),
            ] else
              const Padding(
                padding: EdgeInsets.all(16),
                child: Text('Add a track to get started'),
              ),
            if (scanning)
              const LinearProgressIndicator(minHeight: 2),
            const Divider(),
            Expanded(
              child: Obx(() {
                final queue = controller.queue;
                if (queue.isEmpty) {
                  return const Center(child: Text('Queue is empty'));
                }
                return ReorderableListView.builder(
                  itemCount: queue.length,
                  onReorder: controller.reorderQueue,
                  itemBuilder: (context, index) {
                    final track = queue[index];
                    return TrackTile(
                      key: ValueKey(track.id),
                      track: track,
                      onTap: () => controller.loadTrack(track),
                      onRemove: () => controller.removeTrack(track),
                    );
                  },
                );
              }),
            ),
          ],
        );
      }),
      floatingActionButton: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          FloatingActionButton.extended(
            heroTag: 'scan',
            onPressed: controller.scanLocalLibrary,
            icon: Obx(() => controller.isScanning.value
                ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                : const Icon(Icons.library_music)),
            label: const Text('Scan Library'),
          ),
          const SizedBox(height: 12),
          FloatingActionButton(
            onPressed: () async {
              final track = await _showAddTrackDialog(context);
              if (track != null) {
                controller.addTrack(track);
              }
            },
            child: const Icon(Icons.add),
          ),
        ],
      ),
    );
  }

  void _playPrevious(List<Track> queue, Track current) {
    final index = queue.indexOf(current);
    if (index > 0) {
      controller.loadTrack(queue[index - 1]);
    }
  }

  void _playNext(List<Track> queue, Track current) {
    final index = queue.indexOf(current);
    if (index >= 0 && index < queue.length - 1) {
      controller.loadTrack(queue[index + 1]);
    }
  }

  Future<Track?> _showAddTrackDialog(BuildContext context) {
    final title = TextEditingController();
    final artist = TextEditingController();
    final url = TextEditingController();
    return showDialog<Track>(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('Add Track'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(controller: title, decoration: const InputDecoration(labelText: 'Title')),
              TextField(controller: artist, decoration: const InputDecoration(labelText: 'Artist')),
              TextField(controller: url, decoration: const InputDecoration(labelText: 'URL or file path')),
            ],
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
            ElevatedButton(
              onPressed: () {
                final track = Track(
                  id: DateTime.now().microsecondsSinceEpoch.toString(),
                  title: title.text.trim(),
                  artist: artist.text.trim().isEmpty ? 'Unknown' : artist.text.trim(),
                  source: Uri.parse(url.text.trim()),
                );
                Navigator.pop(context, track);
              },
              child: const Text('Add'),
            ),
          ],
        );
      },
    );
  }
}
