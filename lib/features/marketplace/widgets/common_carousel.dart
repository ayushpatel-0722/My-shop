import 'dart:async';
import 'package:flutter/material.dart';

/// Versatile, reusable carousel supporting banner carousels (16:9),
/// product image galleries (3:2), auto-scroll, dot indicators, and
/// screen height constraints (up to 60% of screen height).
class CommonCarousel extends StatefulWidget {
  final int itemCount;
  final Widget Function(BuildContext context, int index) itemBuilder;
  final double aspectRatio; // e.g. 16/9 for banners, 3/2 for product images
  final double? maxHeightFactor; // e.g. 0.60 for max 60% of screen height
  final double? height; // explicit height override
  final bool autoScroll;
  final Duration autoScrollInterval;
  final ValueChanged<int>? onPageChanged;
  final int initialPage;
  final bool showIndicators;
  final EdgeInsetsGeometry padding;
  final BorderRadius? borderRadius;
  final PageController? controller;
  final Color activeIndicatorColor;
  final Color inactiveIndicatorColor;

  const CommonCarousel({
    super.key,
    required this.itemCount,
    required this.itemBuilder,
    this.aspectRatio = 16 / 9,
    this.maxHeightFactor = 0.60,
    this.height,
    this.autoScroll = true,
    this.autoScrollInterval = const Duration(seconds: 4),
    this.onPageChanged,
    this.initialPage = 0,
    this.showIndicators = true,
    this.padding = EdgeInsets.zero,
    this.borderRadius,
    this.controller,
    this.activeIndicatorColor = const Color(0xFFB3261E),
    this.inactiveIndicatorColor = const Color(0xFFD1D5DB),
  });

  /// 16:9 Banner Carousel preset (capped at 60% screen height)
  factory CommonCarousel.banner({
    Key? key,
    required int itemCount,
    required Widget Function(BuildContext context, int index) itemBuilder,
    ValueChanged<int>? onPageChanged,
    int initialPage = 0,
    bool autoScroll = true,
    double maxHeightFactor = 0.60,
    BorderRadius? borderRadius,
    PageController? controller,
    EdgeInsetsGeometry padding = EdgeInsets.zero,
  }) => CommonCarousel(
    key: key,
    itemCount: itemCount,
    itemBuilder: itemBuilder,
    aspectRatio: 16 / 9,
    maxHeightFactor: maxHeightFactor,
    autoScroll: autoScroll,
    onPageChanged: onPageChanged,
    initialPage: initialPage,
    padding: padding,
    borderRadius: borderRadius ?? BorderRadius.circular(16),
    controller: controller,
  );

  /// 3:2 Product Images Carousel preset (capped at 60% screen height)
  factory CommonCarousel.productImages({
    Key? key,
    required int itemCount,
    required Widget Function(BuildContext context, int index) itemBuilder,
    ValueChanged<int>? onPageChanged,
    int initialPage = 0,
    bool autoScroll = false,
    double maxHeightFactor = 0.60,
    BorderRadius? borderRadius,
    PageController? controller,
    EdgeInsetsGeometry padding = EdgeInsets.zero,
  }) => CommonCarousel(
    key: key,
    itemCount: itemCount,
    itemBuilder: itemBuilder,
    aspectRatio: 3 / 2,
    maxHeightFactor: maxHeightFactor,
    autoScroll: autoScroll,
    onPageChanged: onPageChanged,
    initialPage: initialPage,
    padding: padding,
    borderRadius: borderRadius,
    controller: controller,
  );

  @override
  State<CommonCarousel> createState() => _CommonCarouselState();
}

class _CommonCarouselState extends State<CommonCarousel> {
  late PageController _pageController;
  late int _currentPage;
  Timer? _timer;
  bool _userDragging = false;

  @override
  void initState() {
    super.initState();
    _currentPage = widget.initialPage;
    _pageController =
        widget.controller ?? PageController(initialPage: _currentPage);
    if (widget.autoScroll && widget.itemCount > 1) {
      _startAutoScroll();
    }
  }

  @override
  void didUpdateWidget(covariant CommonCarousel oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.itemCount != widget.itemCount ||
        oldWidget.autoScroll != widget.autoScroll) {
      _timer?.cancel();
      if (widget.autoScroll && widget.itemCount > 1) {
        _startAutoScroll();
      }
    }
  }

  @override
  void dispose() {
    _timer?.cancel();
    if (widget.controller == null) {
      _pageController.dispose();
    }
    super.dispose();
  }

  void _startAutoScroll() {
    _timer?.cancel();
    if (widget.itemCount <= 1) return;
    _timer = Timer.periodic(widget.autoScrollInterval, (_) {
      if (!_pageController.hasClients || !mounted || _userDragging) return;
      final next = (_currentPage + 1) % widget.itemCount;
      _pageController.animateToPage(
        next,
        duration: const Duration(milliseconds: 350),
        curve: Curves.easeOutCubic,
      );
    });
  }

  @override
  Widget build(BuildContext context) {
    if (widget.itemCount <= 0) return const SizedBox.shrink();

    final screenHeight = MediaQuery.sizeOf(context).height;
    final maxAllowedHeight = widget.maxHeightFactor != null
        ? screenHeight * widget.maxHeightFactor!
        : double.infinity;

    final Widget carouselBody = NotificationListener<ScrollNotification>(
      onNotification: (notification) {
        if (notification is ScrollStartNotification &&
            notification.dragDetails != null) {
          _userDragging = true;
          _timer?.cancel();
        } else if (notification is ScrollEndNotification) {
          _userDragging = false;
          if (widget.autoScroll && widget.itemCount > 1) {
            _startAutoScroll();
          }
        }
        return false;
      },
      child: PageView.builder(
        controller: _pageController,
        itemCount: widget.itemCount,
        onPageChanged: (i) {
          setState(() => _currentPage = i);
          widget.onPageChanged?.call(i);
        },
        itemBuilder: (context, i) {
          final child = widget.itemBuilder(context, i);
          if (widget.borderRadius != null) {
            return ClipRRect(borderRadius: widget.borderRadius!, child: child);
          }
          return child;
        },
      ),
    );

    // Apply aspect ratio & height constraints
    Widget framedCarousel;
    if (widget.height != null) {
      framedCarousel = SizedBox(
        height: widget.height!.clamp(0.0, maxAllowedHeight),
        width: double.infinity,
        child: carouselBody,
      );
    } else {
      framedCarousel = ConstrainedBox(
        constraints: BoxConstraints(maxHeight: maxAllowedHeight),
        child: AspectRatio(
          aspectRatio: widget.aspectRatio,
          child: carouselBody,
        ),
      );
    }

    return Padding(
      padding: widget.padding,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          framedCarousel,
          if (widget.showIndicators && widget.itemCount > 1) ...[
            const SizedBox(height: 8),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: List.generate(widget.itemCount, (i) {
                final isActive = i == _currentPage;
                return AnimatedContainer(
                  duration: const Duration(milliseconds: 250),
                  margin: const EdgeInsets.symmetric(horizontal: 3),
                  width: isActive ? 18 : 6,
                  height: 6,
                  decoration: BoxDecoration(
                    color: isActive
                        ? widget.activeIndicatorColor
                        : widget.inactiveIndicatorColor,
                    borderRadius: BorderRadius.circular(3),
                  ),
                );
              }),
            ),
          ],
        ],
      ),
    );
  }
}
