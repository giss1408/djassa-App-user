/// A shop photo or video, as `GET /api/venues/{id}` sends it. The server
/// already shrank it (hossouko-BE app/services/media_processing.py); the app
/// still chooses the cheapest size for each place it is shown.
class VenueMedia {
  const VenueMedia({
    required this.id,
    required this.isVideo,
    this.thumbUrl,
    this.mediumUrl,
    this.videoUrl,
    this.videoBytes,
    this.durationS,
  });

  final int id;
  final bool isVideo;

  /// 320 px: the only size loaded without a tap. A video's poster.
  final String? thumbUrl;

  /// 720 px: opened full screen.
  final String? mediumUrl;
  final String? videoUrl;
  final int? videoBytes;
  final int? durationS;

  factory VenueMedia.fromJson(Map<String, Object?> json) => VenueMedia(
        id: json['id']! as int,
        isVideo: json['kind'] == 'video',
        thumbUrl: json['thumb_url'] as String?,
        mediumUrl: json['medium_url'] as String?,
        videoUrl: json['video_url'] as String?,
        videoBytes: json['video_bytes'] as int?,
        durationS: json['duration_s'] as int?,
      );
}
