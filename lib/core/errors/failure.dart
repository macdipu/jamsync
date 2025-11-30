sealed class Failure {
  const Failure(this.message);
  final String message;
}

final class NetworkFailure extends Failure {
  const NetworkFailure(super.message);
}

final class PlaybackFailure extends Failure {
  const PlaybackFailure(super.message);
}

final class SyncFailure extends Failure {
  const SyncFailure(super.message);
}

