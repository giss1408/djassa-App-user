import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:video_player/video_player.dart';

import '../core/model/venue_media.dart';
import '../core/providers.dart';
import '../l10n/strings.dart';
import '../ui/theme.dart';

/// The shop's photos and videos, cheapest first.
///
/// Only 320 px thumbnails (~15 KB each) load with the page. A photo's 720 px
/// version loads when tapped; a video never downloads until the customer has
/// seen its length and weight and said yes, and then plays here in the app,
/// streaming (the server writes it `faststart`), so it starts at once.
class VenueMediaStrip extends StatelessWidget {
  const VenueMediaStrip({super.key, required this.media});

  final List<VenueMedia> media;

  @override
  Widget build(BuildContext context) {
    if (media.isEmpty) return const SizedBox.shrink();
    return SizedBox(
      height: 96,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        itemCount: media.length,
        separatorBuilder: (_, __) => const SizedBox(width: 8),
        itemBuilder: (context, i) => _Thumb(media: media[i], onTap: () => _open(context, i)),
      ),
    );
  }

  Future<void> _open(BuildContext context, int index) async {
    final m = media[index];
    if (m.isVideo) {
      await _confirmVideo(context, m);
      return;
    }
    final photos = media.where((x) => !x.isVideo).toList();
    ProviderScope.containerOf(context, listen: false).read(usageTrackerProvider).track('media_viewed', {'kind': 'photo'});
    await Navigator.of(context).push(MaterialPageRoute(
      settings: const RouteSettings(name: 'photo_viewer'),
      builder: (_) => _PhotoViewer(photos: photos, initial: photos.indexOf(m)),
    ));
  }

  Future<void> _confirmVideo(BuildContext context, VenueMedia m) async {
    final url = m.videoUrl;
    if (url == null) return;
    final mb = ((m.videoBytes ?? 0) / (1024 * 1024)).toStringAsFixed(1);
    final watch = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text(Strings.videoTitle),
        content: Text('${m.durationS ?? '?'} s · $mb Mo. ${Strings.videoCost}'),
        actions: [
          TextButton(onPressed: () => Navigator.of(context).pop(false), child: const Text(Strings.cancel)),
          FilledButton(onPressed: () => Navigator.of(context).pop(true), child: const Text(Strings.videoWatch)),
        ],
      ),
    );
    if (watch == true && context.mounted) {
      // Counted only once the customer agreed to spend the data.
      ProviderScope.containerOf(context, listen: false).read(usageTrackerProvider).track('media_viewed', {'kind': 'video'});
      await Navigator.of(context).push(MaterialPageRoute(settings: const RouteSettings(name: 'video'), builder: (_) => _VideoScreen(url: url, poster: m.thumbUrl)));
    }
  }
}

class _Thumb extends StatelessWidget {
  const _Thumb({required this.media, required this.onTap});

  final VenueMedia media;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(DjassaRadius.md),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(DjassaRadius.md),
        child: SizedBox(
          width: 128,
          child: Stack(fit: StackFit.expand, children: [
            ColoredBox(
              color: DjassaColors.paper,
              child: media.thumbUrl == null
                  ? const SizedBox.shrink()
                  : Image.network(
                      media.thumbUrl!,
                      fit: BoxFit.cover,
                      cacheWidth: 256,
                      errorBuilder: (_, __, ___) => const Icon(Icons.image_not_supported_outlined, color: DjassaColors.muted),
                    ),
            ),
            if (media.isVideo) ...[
              const Center(child: Icon(Icons.play_circle_fill_rounded, color: Colors.white, size: 38)),
              Positioned(
                right: 6,
                bottom: 6,
                child: DecoratedBox(
                  decoration: BoxDecoration(color: Colors.black54, borderRadius: BorderRadius.circular(6)),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 2),
                    child: Text('${media.durationS ?? ''} s', style: const TextStyle(color: Colors.white, fontSize: 11)),
                  ),
                ),
              ),
            ],
          ]),
        ),
      ),
    );
  }
}

class _PhotoViewer extends StatelessWidget {
  const _PhotoViewer({required this.photos, required this.initial});

  final List<VenueMedia> photos;
  final int initial;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(backgroundColor: Colors.black, foregroundColor: Colors.white),
      body: PageView.builder(
        controller: PageController(initialPage: initial < 0 ? 0 : initial),
        itemCount: photos.length,
        itemBuilder: (context, i) => InteractiveViewer(
          child: Center(
            child: Image.network(
              photos[i].mediumUrl ?? photos[i].thumbUrl ?? '',
              fit: BoxFit.contain,
              // The thumbnail shows instantly from cache while the 720 px loads.
              loadingBuilder: (context, child, progress) => progress == null
                  ? child
                  : Stack(alignment: Alignment.center, children: [
                      if (photos[i].thumbUrl != null) Image.network(photos[i].thumbUrl!, fit: BoxFit.contain),
                      const CircularProgressIndicator(color: Colors.white),
                    ]),
              errorBuilder: (_, __, ___) => const Icon(Icons.image_not_supported_outlined, color: Colors.white54),
            ),
          ),
        ),
      ),
    );
  }
}

/// Plays one shop video, full screen on black. Tap to pause or resume; drag
/// the bar to seek. The controller (and its download) ends with the screen.
class _VideoScreen extends StatefulWidget {
  const _VideoScreen({required this.url, this.poster});

  final String url;
  final String? poster;

  @override
  State<_VideoScreen> createState() => _VideoScreenState();
}

class _VideoScreenState extends State<_VideoScreen> {
  late VideoPlayerController _controller;
  bool _failed = false;

  @override
  void initState() {
    super.initState();
    _open();
  }

  void _open() {
    _failed = false;
    _controller = VideoPlayerController.networkUrl(Uri.parse(widget.url))
      ..addListener(_onChange)
      ..initialize().then((_) {
        if (mounted) _controller.play();
      }).catchError((Object _) {
        if (mounted) setState(() => _failed = true);
      });
  }

  void _onChange() {
    if (!mounted) return;
    if (_controller.value.hasError && !_failed) {
      setState(() => _failed = true);
    } else {
      setState(() {});
    }
  }

  Future<void> _retry() async {
    _controller.removeListener(_onChange);
    await _controller.dispose();
    setState(_open);
  }

  @override
  void dispose() {
    _controller.removeListener(_onChange);
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final value = _controller.value;
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(backgroundColor: Colors.black, foregroundColor: Colors.white),
      body: SafeArea(
        child: Center(
          child: _failed
              ? Column(mainAxisSize: MainAxisSize.min, children: [
                  const Icon(Icons.wifi_off_rounded, color: Colors.white54, size: 40),
                  const SizedBox(height: 12),
                  const Text(Strings.videoFailed, style: TextStyle(color: Colors.white70), textAlign: TextAlign.center),
                  const SizedBox(height: 12),
                  FilledButton(onPressed: _retry, child: const Text(Strings.retry)),
                ])
              : !value.isInitialized
                  ? Stack(alignment: Alignment.center, children: [
                      if (widget.poster != null) Image.network(widget.poster!, fit: BoxFit.contain),
                      const CircularProgressIndicator(color: Colors.white),
                    ])
                  : GestureDetector(
                      onTap: () => value.isPlaying ? _controller.pause() : _controller.play(),
                      child: Column(mainAxisSize: MainAxisSize.min, children: [
                        Flexible(
                          child: AspectRatio(
                            aspectRatio: value.aspectRatio,
                            child: Stack(alignment: Alignment.center, children: [
                              VideoPlayer(_controller),
                              if (value.isBuffering) const CircularProgressIndicator(color: Colors.white),
                              if (!value.isPlaying && !value.isBuffering)
                                const Icon(Icons.play_circle_fill_rounded, color: Colors.white, size: 64),
                            ]),
                          ),
                        ),
                        Padding(
                          padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
                          child: VideoProgressIndicator(
                            _controller,
                            allowScrubbing: true,
                            colors: const VideoProgressColors(playedColor: DjassaColors.orange, bufferedColor: Colors.white38),
                          ),
                        ),
                      ]),
                    ),
        ),
      ),
    );
  }
}
