import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../theme/app_colors.dart';

class AnimatedLibrisLogo extends StatefulWidget {
  const AnimatedLibrisLogo({
    super.key,
    this.onCompleted,
  });

  final VoidCallback? onCompleted;

  @override
  State<AnimatedLibrisLogo> createState() => _AnimatedLibrisLogoState();
}

class _AnimatedLibrisLogoState extends State<AnimatedLibrisLogo>
    with SingleTickerProviderStateMixin {
  static const String _assetPath = 'assets/images/libris_logo.png';

  late final AnimationController _controller;

  late final Animation<double> _logoOpacity;
  late final Animation<double> _logoScale;

  late final Animation<double> _plantProgress;

  late final Animation<double> _lowerStarProgress;
  late final Animation<double> _middleStarProgress;
  late final Animation<double> _upperStarProgress;

  late final Animation<double> _titleProgress;
  late final Animation<double> _greenLineProgress;
  late final Animation<double> _mottoProgress;

  ui.Image? _logoImage;

  bool _loadingFailed = false;

  @override
  void initState() {
    super.initState();

    _controller = AnimationController(
      vsync: this,
      duration: const Duration(
        milliseconds: 5200,
      ),
    );

    /*
     * A teljes logó finom megjelenése.
     */
    _logoOpacity = CurvedAnimation(
      parent: _controller,
      curve: const Interval(
        0.00,
        0.12,
        curve: Curves.easeOut,
      ),
    );

    _logoScale = Tween<double>(
      begin: 0.96,
      end: 1.0,
    ).animate(
      CurvedAnimation(
        parent: _controller,
        curve: const Interval(
          0.00,
          0.16,
          curve: Curves.easeOutCubic,
        ),
      ),
    );

    /*
     * A növény alulról felfelé válik láthatóvá.
     */
    _plantProgress = CurvedAnimation(
      parent: _controller,
      curve: const Interval(
        0.14,
        0.58,
        curve: Curves.easeInOutCubic,
      ),
    );

    /*
     * A három csillag alulról felfelé,
     * egymást követve jelenik meg.
     */
    _lowerStarProgress = CurvedAnimation(
      parent: _controller,
      curve: const Interval(
        0.60,
        0.68,
        curve: Curves.easeOutBack,
      ),
    );

    _middleStarProgress = CurvedAnimation(
      parent: _controller,
      curve: const Interval(
        0.67,
        0.75,
        curve: Curves.easeOutBack,
      ),
    );

    _upperStarProgress = CurvedAnimation(
      parent: _controller,
      curve: const Interval(
        0.74,
        0.82,
        curve: Curves.easeOutBack,
      ),
    );

    /*
     * A márkanév csak a három csillag után jelenik meg.
     */
    _titleProgress = CurvedAnimation(
      parent: _controller,
      curve: const Interval(
        0.83,
        0.89,
        curve: Curves.easeIn,
      ),
    );

    /*
     * A zöld vonal a márkanév után jelenik meg.
     */
    _greenLineProgress = CurvedAnimation(
      parent: _controller,
      curve: const Interval(
        0.88,
        0.93,
        curve: Curves.easeInOut,
      ),
    );

    /*
     * A mottó balról jobbra válik láthatóvá.
     */
    _mottoProgress = CurvedAnimation(
      parent: _controller,
      curve: const Interval(
        0.92,
        0.98,
        curve: Curves.easeInOutCubic,
      ),
    );

    _controller.addStatusListener(
      (AnimationStatus status) {
        if (status == AnimationStatus.completed) {
          widget.onCompleted?.call();
        }
      },
    );

    _loadLogo();
  }

  Future<void> _loadLogo() async {
    try {
      final ByteData byteData = await rootBundle.load(_assetPath);

      final ui.Codec codec = await ui.instantiateImageCodec(
        byteData.buffer.asUint8List(),
      );

      final ui.FrameInfo frameInfo = await codec.getNextFrame();

      codec.dispose();

      if (!mounted) {
        frameInfo.image.dispose();
        return;
      }

      setState(() {
        _logoImage = frameInfo.image;
      });

      _controller.forward();
    } catch (_) {
      if (!mounted) {
        return;
      }

      setState(() {
        _loadingFailed = true;
      });
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    _logoImage?.dispose();

    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (_loadingFailed) {
      return const Center(
        child: Icon(
          Icons.broken_image_outlined,
          color: AppColors.secondary,
          size: 48,
        ),
      );
    }

    final ui.Image? logoImage = _logoImage;

    if (logoImage == null) {
      return const Center(
        child: CircularProgressIndicator(),
      );
    }

    return AspectRatio(
      aspectRatio: 1,
      child: FadeTransition(
        opacity: _logoOpacity,
        child: ScaleTransition(
          scale: _logoScale,
          child: AnimatedBuilder(
            animation: _controller,
            builder: (
              BuildContext context,
              Widget? child,
            ) {
              return CustomPaint(
                painter: _AnimatedLogoPainter(
                  image: logoImage,
                  plantProgress: _plantProgress.value,
                  lowerStarProgress: _lowerStarProgress.value,
                  middleStarProgress: _middleStarProgress.value,
                  upperStarProgress: _upperStarProgress.value,
                  titleProgress: _titleProgress.value,
                  greenLineProgress: _greenLineProgress.value,
                  mottoProgress: _mottoProgress.value,
                ),
                child: const SizedBox.expand(),
              );
            },
          ),
        ),
      ),
    );
  }
}

class _AnimatedLogoPainter extends CustomPainter {
  const _AnimatedLogoPainter({
    required this.image,
    required this.plantProgress,
    required this.lowerStarProgress,
    required this.middleStarProgress,
    required this.upperStarProgress,
    required this.titleProgress,
    required this.greenLineProgress,
    required this.mottoProgress,
  });

  final ui.Image image;

  final double plantProgress;

  final double lowerStarProgress;
  final double middleStarProgress;
  final double upperStarProgress;

  final double titleProgress;
  final double greenLineProgress;
  final double mottoProgress;

  /*
   * Növény.
   */
  static const List<Offset> _plantPolygon = <Offset>[
    Offset(0.5000, 0.4406),
    Offset(0.4845, 0.4085),
    Offset(0.4834, 0.3654),
    Offset(0.4115, 0.3289),
    Offset(0.3673, 0.2515),
    Offset(0.4115, 0.2316),
    Offset(0.4536, 0.2714),
    Offset(0.4812, 0.2238),
    Offset(0.5310, 0.1663),
    Offset(0.6183, 0.1331),
    Offset(0.5785, 0.2857),
    Offset(0.5641, 0.3587),
  ];

  /*
   * Alsó, bal oldali csillag.
   */
  static const List<Offset> _lowerStarPolygon = <Offset>[
    Offset(0.4690, 0.3963),
    Offset(0.4491, 0.3753),
    Offset(0.4690, 0.3499),
    Offset(0.4867, 0.3742),
  ];

  /*
   * Középső, jobb oldali csillag.
   */
  static const List<Offset> _middleStarPolygon = <Offset>[
    Offset(0.6084, 0.3211),
    Offset(0.5708, 0.2813),
    Offset(0.6051, 0.2470),
    Offset(0.6482, 0.2791),
  ];

  /*
   * Felső, bal oldali csillag.
   */
  static const List<Offset> _upperStarPolygon = <Offset>[
    Offset(0.4469, 0.2680),
    Offset(0.4060, 0.2349),
    Offset(0.4458, 0.1917),
    Offset(0.4812, 0.2271),
  ];

  /*
   * LibriS felirat.
   */
  static const List<Offset> _titlePolygon = <Offset>[
    Offset(0.1915, 0.7679),
    Offset(0.1826, 0.5711),
    Offset(0.8207, 0.5722),
    Offset(0.8262, 0.7646),
  ];

  /*
   * A LibriS felirat alatti zöld vonal.
   */
  static const List<Offset> _greenLinePolygon = <Offset>[
    Offset(0.3983, 0.8110),
    Offset(0.3960, 0.7756),
    Offset(0.6205, 0.7712),
    Offset(0.6128, 0.8066),
  ];

  /*
   * Alsó mottó.
   */
  static const List<Offset> _mottoPolygon = <Offset>[
    Offset(0.2291, 0.8685),
    Offset(0.2335, 0.8177),
    Offset(0.7743, 0.8143),
    Offset(0.7853, 0.8685),
  ];

  @override
  void paint(
    Canvas canvas,
    Size size,
  ) {
    final Rect destination = _calculateContainRect(
      inputSize: Size(
        image.width.toDouble(),
        image.height.toDouble(),
      ),
      outputSize: size,
    );

    /*
     * A saveLayer lehetővé teszi,
     * hogy a BlendMode.dstOut átlátszó
     * területeket készítsen.
     */
    canvas.saveLayer(
      Offset.zero & size,
      Paint(),
    );

    /*
     * Először kirajzoljuk a teljes eredeti logót.
     */
    canvas.drawImageRect(
      image,
      Rect.fromLTWH(
        0,
        0,
        image.width.toDouble(),
        image.height.toDouble(),
      ),
      destination,
      Paint()
        ..isAntiAlias = true
        ..filterQuality = FilterQuality.high,
    );

    /*
     * Növény felfedése alulról felfelé.
     */
    _hideUnrevealedPlant(
      canvas,
      destination,
    );

    /*
     * Csillagok egymást követő megjelenése.
     */
    _hidePolygon(
      canvas: canvas,
      destination: destination,
      normalizedPoints: _lowerStarPolygon,
      hiddenOpacity: 1 - lowerStarProgress,
      paddingFactor: 0.010,
    );

    _hidePolygon(
      canvas: canvas,
      destination: destination,
      normalizedPoints: _middleStarPolygon,
      hiddenOpacity: 1 - middleStarProgress,
      paddingFactor: 0.010,
    );

    _hidePolygon(
      canvas: canvas,
      destination: destination,
      normalizedPoints: _upperStarPolygon,
      hiddenOpacity: 1 - upperStarProgress,
      paddingFactor: 0.010,
    );

    /*
     * LibriS felirat áttűnése.
     */
    _hidePolygon(
      canvas: canvas,
      destination: destination,
      normalizedPoints: _titlePolygon,
      hiddenOpacity: 1 - titleProgress,
      paddingFactor: 0.008,
    );

    /*
     * Zöld vonal áttűnése.
     */
    _hidePolygon(
      canvas: canvas,
      destination: destination,
      normalizedPoints: _greenLinePolygon,
      hiddenOpacity: 1 - greenLineProgress,
      paddingFactor: 0.006,
    );

    /*
     * Mottó balról jobbra történő megjelenése.
     */
    _hidePolygonFromRight(
      canvas: canvas,
      destination: destination,
      normalizedPoints: _mottoPolygon,
      progress: mottoProgress,
      paddingFactor: 0.008,
    );

    canvas.restore();
  }

  void _hideUnrevealedPlant(
    Canvas canvas,
    Rect destination,
  ) {
    final Path plantPath = _buildPolygonPath(
      normalizedPoints: _plantPolygon,
      destination: destination,
    );

    final Rect plantBounds = plantPath.getBounds();

    /*
     * progress = 0:
     * a revealBoundary a növény alján van,
     * ezért a teljes növény rejtve marad.
     *
     * progress = 1:
     * a revealBoundary a növény tetejére ér,
     * ezért a teljes növény látható.
     */
    final double revealBoundaryY = ui.lerpDouble(
      plantBounds.bottom,
      plantBounds.top,
      plantProgress.clamp(0.0, 1.0),
    )!;

    final Rect hiddenArea = Rect.fromLTRB(
      plantBounds.left - destination.width * 0.01,
      plantBounds.top - destination.height * 0.01,
      plantBounds.right + destination.width * 0.01,
      revealBoundaryY,
    );

    canvas.save();

    canvas.clipPath(plantPath);
    canvas.clipRect(hiddenArea);

    canvas.drawRect(
      hiddenArea,
      Paint()
        ..color = Colors.white
        ..blendMode = BlendMode.dstOut,
    );

    canvas.restore();
  }

  void _hidePolygon({
    required Canvas canvas,
    required Rect destination,
    required List<Offset> normalizedPoints,
    required double hiddenOpacity,
    required double paddingFactor,
  }) {
    if (hiddenOpacity <= 0) {
      return;
    }

    final Path originalPath = _buildPolygonPath(
      normalizedPoints: normalizedPoints,
      destination: destination,
    );

    final Rect bounds = originalPath.getBounds();

    if (bounds.width <= 0 || bounds.height <= 0) {
      return;
    }

    final Offset center = bounds.center;

    final double scaleX =
        (bounds.width + destination.width * paddingFactor * 2) / bounds.width;

    final double scaleY =
        (bounds.height + destination.height * paddingFactor * 2) /
            bounds.height;

    final Matrix4 transform = Matrix4.identity()
      ..translateByDouble(
        center.dx,
        center.dy,
        0,
        1,
      )
      ..scaleByDouble(
        scaleX,
        scaleY,
        1,
        1,
      )
      ..translateByDouble(
        -center.dx,
        -center.dy,
        0,
        1,
      );

    final Path paddedPath = originalPath.transform(
      transform.storage,
    );

    canvas.drawPath(
      paddedPath,
      Paint()
        ..color = Colors.white.withValues(
          alpha: hiddenOpacity.clamp(0.0, 1.0),
        )
        ..style = PaintingStyle.fill
        ..blendMode = BlendMode.dstOut,
    );
  }

  void _hidePolygonFromRight({
    required Canvas canvas,
    required Rect destination,
    required List<Offset> normalizedPoints,
    required double progress,
    required double paddingFactor,
  }) {
    if (progress >= 1) {
      return;
    }

    final Path originalPath = _buildPolygonPath(
      normalizedPoints: normalizedPoints,
      destination: destination,
    );

    final Rect originalBounds = originalPath.getBounds();

    final double horizontalPadding = destination.width * paddingFactor;

    final double verticalPadding = destination.height * paddingFactor;

    final Rect paddedBounds = Rect.fromLTRB(
      originalBounds.left - horizontalPadding,
      originalBounds.top - verticalPadding,
      originalBounds.right + horizontalPadding,
      originalBounds.bottom + verticalPadding,
    );

    /*
     * A felfedési határ balról jobbra halad.
     */
    final double revealX = ui.lerpDouble(
      paddedBounds.left,
      paddedBounds.right,
      progress.clamp(0.0, 1.0),
    )!;

    /*
     * A revealX-től jobbra eső mottórész
     * még rejtve marad.
     */
    final Rect hiddenArea = Rect.fromLTRB(
      revealX,
      paddedBounds.top,
      paddedBounds.right,
      paddedBounds.bottom,
    );

    canvas.save();

    canvas.clipPath(originalPath);
    canvas.clipRect(hiddenArea);

    canvas.drawRect(
      hiddenArea,
      Paint()
        ..color = Colors.white
        ..blendMode = BlendMode.dstOut,
    );

    canvas.restore();
  }

  Path _buildPolygonPath({
    required List<Offset> normalizedPoints,
    required Rect destination,
  }) {
    final Offset firstPoint = Offset(
      destination.left + normalizedPoints.first.dx * destination.width,
      destination.top + normalizedPoints.first.dy * destination.height,
    );

    final Path path = Path()
      ..moveTo(
        firstPoint.dx,
        firstPoint.dy,
      );

    for (int index = 1; index < normalizedPoints.length; index++) {
      final Offset point = Offset(
        destination.left + normalizedPoints[index].dx * destination.width,
        destination.top + normalizedPoints[index].dy * destination.height,
      );

      path.lineTo(
        point.dx,
        point.dy,
      );
    }

    path.close();

    return path;
  }

  Rect _calculateContainRect({
    required Size inputSize,
    required Size outputSize,
  }) {
    final double inputRatio = inputSize.width / inputSize.height;

    final double outputRatio = outputSize.width / outputSize.height;

    if (outputRatio > inputRatio) {
      final double height = outputSize.height;

      final double width = height * inputRatio;

      return Rect.fromLTWH(
        (outputSize.width - width) / 2,
        0,
        width,
        height,
      );
    }

    final double width = outputSize.width;

    final double height = width / inputRatio;

    return Rect.fromLTWH(
      0,
      (outputSize.height - height) / 2,
      width,
      height,
    );
  }

  @override
  bool shouldRepaint(
    covariant _AnimatedLogoPainter oldDelegate,
  ) {
    return oldDelegate.image != image ||
        oldDelegate.plantProgress != plantProgress ||
        oldDelegate.lowerStarProgress != lowerStarProgress ||
        oldDelegate.middleStarProgress != middleStarProgress ||
        oldDelegate.upperStarProgress != upperStarProgress ||
        oldDelegate.titleProgress != titleProgress ||
        oldDelegate.greenLineProgress != greenLineProgress ||
        oldDelegate.mottoProgress != mottoProgress;
  }
}
