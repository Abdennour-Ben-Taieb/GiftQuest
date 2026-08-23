import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';

/// Animated gift-opening reveal shown on the very first Flutter frame,
/// picking up right where the native static splash (flutter_native_splash)
/// leaves off: closed gift box holds briefly, the lid pops up and tilts
/// open, then the whole overlay cross-fades away to reveal [child].
///
/// Built with nothing but AnimationController + Transform + flutter_svg —
/// no video, no Lottie, no third-party animation package — so it stays
/// cheap on the GPU. Total runtime is ~1.15s, comfortably under the 1.5s
/// budget so it never becomes an obstacle for repeat users.
class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key, required this.child});

  /// The app's real start screen, revealed once the animation finishes.
  final Widget child;

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen>
    with TickerProviderStateMixin {
  static const _holdBeforePop = Duration(milliseconds: 200);
  static const _popDuration = Duration(milliseconds: 600);
  static const _holdAfterPop = Duration(milliseconds: 150);
  static const _fadeDuration = Duration(milliseconds: 200);
  static const _giftSize = 160.0;
  static const _liftPixels = 50.0;
  static const _rotationDegrees = 10.0;

  late final AnimationController _popController;
  late final Animation<double> _lidLift;
  late final Animation<double> _lidRotation;

  late final AnimationController _fadeController;
  late final Animation<double> _overlayOpacity;

  bool _showOverlay = true;

  @override
  void initState() {
    super.initState();

    final popTotal = _holdBeforePop + _popDuration;
    _popController = AnimationController(vsync: this, duration: popTotal);

    // Interval holds the lid at rest for the first slice of the run, then
    // eases it open with a slight overshoot for the rest — a single
    // controller driving both the hold and the pop.
    final popCurve = CurvedAnimation(
      parent: _popController,
      curve: Interval(
        _holdBeforePop.inMilliseconds / popTotal.inMilliseconds,
        1.0,
        curve: Curves.easeOutBack,
      ),
    );
    _lidLift = Tween<double>(begin: 0, end: -_liftPixels).animate(popCurve);
    _lidRotation = Tween<double>(
      begin: 0,
      end: -_rotationDegrees * (3.141592653589793 / 180),
    ).animate(popCurve);

    _fadeController = AnimationController(
      vsync: this,
      duration: _fadeDuration,
    );
    _overlayOpacity = Tween<double>(begin: 1, end: 0).animate(
      CurvedAnimation(parent: _fadeController, curve: Curves.easeIn),
    );

    _popController.addStatusListener((status) {
      if (status == AnimationStatus.completed) {
        Future.delayed(_holdAfterPop, () {
          if (mounted) _fadeController.forward();
        });
      }
    });
    _fadeController.addStatusListener((status) {
      if (status == AnimationStatus.completed && mounted) {
        setState(() => _showOverlay = false);
      }
    });

    _popController.forward();
  }

  @override
  void dispose() {
    _popController.dispose();
    _fadeController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        widget.child,
        if (_showOverlay)
          FadeTransition(
            opacity: _overlayOpacity,
            child: Container(
              color: const Color(0xFF4F378B),
              alignment: Alignment.center,
              child: AnimatedBuilder(
                animation: _popController,
                builder: (context, _) {
                  return SizedBox(
                    width: _giftSize,
                    height: _giftSize,
                    child: Stack(
                      alignment: Alignment.center,
                      children: [
                        SvgPicture.asset(
                          'assets/icon/gift_body_white.svg',
                          width: _giftSize,
                          height: _giftSize,
                        ),
                        Transform.translate(
                          offset: Offset(0, _lidLift.value),
                          child: Transform.rotate(
                            angle: _lidRotation.value,
                            child: SvgPicture.asset(
                              'assets/icon/gift_lid_white.svg',
                              width: _giftSize,
                              height: _giftSize,
                            ),
                          ),
                        ),
                      ],
                    ),
                  );
                },
              ),
            ),
          ),
      ],
    );
  }
}
