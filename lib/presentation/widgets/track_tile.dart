import 'package:flutter/material.dart';

import '../../domain/entities/track.dart';

class TrackTile extends StatelessWidget {
  const TrackTile({
    super.key,
    required this.track,
    required this.onTap,
    required this.onRemove,
  });

  final Track track;
  final VoidCallback onTap;
  final VoidCallback onRemove;

  @override
  Widget build(BuildContext context) {
    return ListTile(
      title: Text(track.title),
      subtitle: Text(track.artist),
      onTap: onTap,
      trailing: IconButton(
        icon: const Icon(Icons.delete),
        onPressed: onRemove,
      ),
    );
  }
}

