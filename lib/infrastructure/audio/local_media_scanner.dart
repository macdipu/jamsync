import 'dart:io';

import 'package:on_audio_query_pluse/on_audio_query.dart';
import 'package:path_provider/path_provider.dart';

import '../../domain/services_interfaces/i_media_scanner_service.dart';

class LocalMediaScanner implements IMediaScannerService {
  LocalMediaScanner(this._audioQuery);

  final OnAudioQuery _audioQuery;

  @override
  Future<List<LocalAudioTrack>> scanLibrary() async {
    final hasPermission = await _audioQuery.permissionsStatus();
    if (!hasPermission) {
      final granted = await _audioQuery.permissionsRequest();
      if (!granted) {
        return const [];
      }
    }
    final songs = await _audioQuery.querySongs(
      uriType: UriType.EXTERNAL,
      sortType: SongSortType.TITLE,
    );
    if (songs.isNotEmpty) {
      return songs
          .map(
            (song) => LocalAudioTrack(
              id: song.id.toString(),
              title: song.title,
              artist: song.artist ?? 'Unknown',
              uri: Uri.parse(song.uri ?? ''),
              duration: Duration(milliseconds: song.duration ?? 0),
            ),
          )
          .where((track) => track.uri.toString().isNotEmpty)
          .toList();
    }
    final directory = await getApplicationDocumentsDirectory();
    final files = directory
        .listSync(recursive: true)
        .whereType<File>()
        .where((file) => file.path.toLowerCase().endsWith('.mp3'));
    return files
        .map(
          (file) => LocalAudioTrack(
            id: file.path,
            title: file.uri.pathSegments.last,
            artist: 'Local',
            uri: file.uri,
            duration: null,
          ),
        )
        .toList();
  }
}

