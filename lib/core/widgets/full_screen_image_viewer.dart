import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'app_product_image.dart';

/// Opens [urls] in a full-screen viewer starting at [initialIndex].
///
/// Swipe (or use the arrows / left-right keys) to move between images, pinch
/// or scroll to zoom, tap the close button or press Esc to leave.
Future<void> showFullScreenImages(
  BuildContext context, {
  required List<String> urls,
  int initialIndex = 0,
}) {
  final images = urls.where((u) => u.trim().isNotEmpty).toList();
  if (images.isEmpty) return Future<void>.value();
  return showDialog<void>(
    context: context,
    useSafeArea: false,
    barrierColor: Colors.black,
    builder: (_) => FullScreenImageViewer(
      urls: images,
      initialIndex: initialIndex.clamp(0, images.length - 1),
    ),
  );
}

class FullScreenImageViewer extends StatefulWidget {
  final List<String> urls;
  final int initialIndex;

  const FullScreenImageViewer({
    super.key,
    required this.urls,
    this.initialIndex = 0,
  });

  @override
  State<FullScreenImageViewer> createState() => _FullScreenImageViewerState();
}

class _FullScreenImageViewerState extends State<FullScreenImageViewer> {
  late final PageController _controller;
  late int _index;

  @override
  void initState() {
    super.initState();
    _index = widget.initialIndex;
    _controller = PageController(initialPage: _index);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  bool get _hasPrevious => _index > 0;
  bool get _hasNext => _index < widget.urls.length - 1;

  void _go(int delta) {
    final target = _index + delta;
    if (target < 0 || target >= widget.urls.length) return;
    _controller.animateToPage(
      target,
      duration: const Duration(milliseconds: 220),
      curve: Curves.easeOut,
    );
  }

  @override
  Widget build(BuildContext context) {
    return CallbackShortcuts(
      bindings: {
        const SingleActivator(LogicalKeyboardKey.arrowLeft): () => _go(-1),
        const SingleActivator(LogicalKeyboardKey.arrowRight): () => _go(1),
      },
      child: Focus(
        autofocus: true,
        child: Dialog.fullscreen(
          key: const Key('fullscreen-image-viewer'),
          backgroundColor: Colors.black,
          child: Stack(
            children: [
              PageView.builder(
                controller: _controller,
                itemCount: widget.urls.length,
                onPageChanged: (i) => setState(() => _index = i),
                itemBuilder: (context, i) => InteractiveViewer(
                  minScale: 1,
                  maxScale: 5,
                  child: Center(
                    child: AppProductImage(
                      key: ValueKey('fullscreen-image-$i'),
                      url: widget.urls[i],
                      fit: BoxFit.contain,
                      fallback: const Icon(
                        Icons.broken_image_outlined,
                        color: Colors.white54,
                        size: 64,
                      ),
                    ),
                  ),
                ),
              ),
              SafeArea(
                child: Align(
                  alignment: Alignment.topCenter,
                  child: Padding(
                    padding: const EdgeInsets.all(8),
                    child: Row(
                      children: [
                        IconButton(
                          key: const Key('fullscreen-image-close'),
                          icon: const Icon(Icons.close, color: Colors.white),
                          onPressed: () => Navigator.of(context).pop(),
                        ),
                        const Spacer(),
                        if (widget.urls.length > 1)
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 12,
                              vertical: 4,
                            ),
                            decoration: BoxDecoration(
                              color: Colors.white12,
                              borderRadius: BorderRadius.circular(16),
                            ),
                            child: Text(
                              '${_index + 1} / ${widget.urls.length}',
                              key: const Key('fullscreen-image-counter'),
                              style: const TextStyle(color: Colors.white),
                            ),
                          ),
                        const SizedBox(width: 8),
                      ],
                    ),
                  ),
                ),
              ),
              if (widget.urls.length > 1) ...[
                if (_hasPrevious)
                  Align(
                    alignment: Alignment.centerLeft,
                    child: IconButton.filledTonal(
                      key: const Key('fullscreen-image-previous'),
                      icon: const Icon(Icons.chevron_left),
                      onPressed: () => _go(-1),
                    ),
                  ),
                if (_hasNext)
                  Align(
                    alignment: Alignment.centerRight,
                    child: IconButton.filledTonal(
                      key: const Key('fullscreen-image-next'),
                      icon: const Icon(Icons.chevron_right),
                      onPressed: () => _go(1),
                    ),
                  ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
