import 'dart:io';

import 'package:on_audio_query_pluse/on_audio_query.dart';
import 'package:path_provider/path_provider.dart';

import '../../domain/services_interfaces/i_media_scanner_service.dart';
import '../../core/logging/app_logger.dart';

class LocalMediaScanner implements IMediaScannerService {
  LocalMediaScanner(this._audioQuery, {AppLogger? logger}) : _logger = logger;

  final OnAudioQuery _audioQuery;
  final AppLogger? _logger;

  @override
  Future<List<LocalAudioTrack>> scanLibrary() async {
    _logger?.info('Scanning local media library…');
    if (!await _ensurePermission()) {
      _logger?.warn('Media permission denied; returning empty library');
      return const [];
    }
    final songs = await _querySongsAcrossVolumes();
    if (songs.isNotEmpty) {
      _logger?.info('Found ${songs.length} tracks via MediaStore');
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
    _logger?.warn('MediaStore returned 0 tracks; falling back to documents directory');
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

  Future<bool> _ensurePermission() async {
    var hasPermission = await _audioQuery.permissionsStatus();
    if (!hasPermission) {
      hasPermission = await _audioQuery.permissionsRequest();
    }
    return hasPermission;
  }

  Future<List<SongModel>> _querySongsAcrossVolumes() async {
    final results = <SongModel>[];
    for (final uriType in const [UriType.EXTERNAL, UriType.INTERNAL]) {
      try {
        final chunk = await _audioQuery.querySongs(
          uriType: uriType,
          sortType: SongSortType.TITLE,
        );
        results.addAll(chunk);
      } catch (error, stackTrace) {
        _logger?.error('querySongs failed for $uriType: $error', error, stackTrace);
      }
    }
    final deduped = <int, SongModel>{};
    for (final song in results) {
      deduped[song.id] = song;
    }
    return deduped.values.toList();
  }
}
