import 'package:flutter/material.dart';
import 'package:confetti/confetti.dart';
import '../../../../core/00_base/module_base.dart';
import '../../../../core/managers/module_manager.dart';
import '../../../../core/managers/services_manager.dart';
import '../../../../core/services/shared_preferences.dart';
import '../../../../tools/logging/logger.dart';

class AnimationsModule extends ModuleBase {
  static final Logger _log = Logger(); // ✅ Use a static logger for static methods
  final List<AnimationController> _controllers = [];
  final Map<String, ConfettiController> _confettiControllers = {}; // ✅ Store confetti controllers

  /// ✅ Constructor with module key
  AnimationsModule() : super("animations_module") {
    _log.info('✅ AnimationsModule initialized.');
  }

  @override
  void initialize(BuildContext context) {
    _log.info('✅ AnimationsModule initialized with context.');
  }

  /// ✅ Cleanup logic for AnimationsModule
  @override
  void dispose() {
    _log.info('Cleaning up AnimationsModule resources.');

    for (final controller in _controllers) {
      if (controller.isAnimating) {
        controller.stop();
      }
      controller.dispose();
    }
    _controllers.clear();

    for (final confettiController in _confettiControllers.values) {
      confettiController.dispose();
    }
    _confettiControllers.clear();

    _log.info('AnimationsModule fully disposed.');
    super.dispose();
  }

  /// ✅ Registers an AnimationController for later cleanup
  void registerController(AnimationController controller) {
    _controllers.add(controller);
    _log.info('Registered AnimationController: $controller');
  }

  /// ✅ Method to trigger confetti animation
  void playConfetti({required String key}) {
    if (!_confettiControllers.containsKey(key)) {
      _confettiControllers[key] = ConfettiController(duration: const Duration(seconds: 2));
    }

    _confettiControllers[key]!.play();
    _log.info('🎉 Confetti started: $key');
  }

  /// ✅ Applies fade animation
  Widget applyFadeAnimation({
    required Widget child,
    required AnimationController controller,
  }) {
    registerController(controller);
    _log.info('Applying fade animation.');
    return AnimatedBuilder(
      animation: controller,
      builder: (context, _) {
        return Opacity(
          opacity: controller.value,
          child: child,
        );
      },
    );
  }

  /// ✅ Applies scale animation
  Widget applyScaleAnimation({
    required Widget child,
    required AnimationController controller,
    double begin = 0.8,
    double end = 1.2,
  }) {
    registerController(controller);
    _log.info('Applying scale animation.');
    final scaleAnimation = Tween<double>(begin: begin, end: end).animate(
      CurvedAnimation(parent: controller, curve: Curves.easeInOut),
    );
    return AnimatedBuilder(
      animation: scaleAnimation,
      builder: (context, _) {
        return Transform.scale(
          scale: scaleAnimation.value,
          child: child,
        );
      },
    );
  }

  /// ✅ Applies slide animation
  Widget applySlideAnimation({
    required Widget child,
    required AnimationController controller,
    Offset begin = const Offset(0, -1),
    Offset end = const Offset(0, 0),
  }) {
    registerController(controller);
    _log.info('Applying slide animation.');
    final slideAnimation = Tween<Offset>(begin: begin, end: end).animate(
      CurvedAnimation(parent: controller, curve: Curves.easeInOut),
    );
    return AnimatedBuilder(
      animation: slideAnimation,
      builder: (context, _) {
        return SlideTransition(
          position: slideAnimation,
          child: child,
        );
      },
    );
  }

  /// ✅ Applies bounce animation
  Widget applyBounceAnimation({
    required Widget child,
    required AnimationController controller,
  }) {
    registerController(controller);
    _log.info('Applying bounce animation.');
    final bounceAnimation = Tween<double>(begin: 0.0, end: 20.0).animate(
      CurvedAnimation(parent: controller, curve: Curves.bounceOut),
    );
    return AnimatedBuilder(
      animation: bounceAnimation,
      builder: (context, _) {
        return Transform.translate(
          offset: Offset(0, -bounceAnimation.value),
          child: child,
        );
      },
    );
  }

  /// ✅ New Shake & Drop Animation (4 left-right movements in 2 sec, then drop)
  Widget applyShakeAndDropAnimation({
    required Widget child,
    required AnimationController controller,
  }) {
    registerController(controller);
    _log.info('Applying shake and drop animation.');

    // Durations
    const double totalDuration = 5.0; // Total duration in seconds
    const double shakeDuration = 4.0; // Shake for 2s
    const double dropStartTime = 3.0; // Drop starts at 2s
    const double dropDuration = 2.0; // Drop lasts 2s

    // Get screen size **once** (prevents unnecessary recalculations)
    final screenWidth = MediaQueryData.fromView(WidgetsBinding.instance.window).size.width;
    final screenHeight = MediaQueryData.fromView(WidgetsBinding.instance.window).size.height;

    // Shake animation: Moves left & right 4 times in 2 seconds
    final shakeAnimation = TweenSequence<Offset>([
      TweenSequenceItem(
          tween: Tween(begin: const Offset(0, 0), end: const Offset(0.05, 0))
              .chain(CurveTween(curve: Curves.easeInOut)),
          weight: 1),
      TweenSequenceItem(
          tween: Tween(begin: const Offset(0.05, 0), end: const Offset(-0.05, 0))
              .chain(CurveTween(curve: Curves.easeInOut)),
          weight: 1),
      TweenSequenceItem(
          tween: Tween(begin: const Offset(-0.05, 0), end: const Offset(0.05, 0))
              .chain(CurveTween(curve: Curves.easeInOut)),
          weight: 1),
      TweenSequenceItem(
          tween: Tween(begin: const Offset(0.05, 0), end: const Offset(0, 0))
              .chain(CurveTween(curve: Curves.easeInOut)),
          weight: 1),
    ]).animate(
      CurvedAnimation(
        parent: controller,
        curve: Interval(0.0, shakeDuration / totalDuration, curve: Curves.easeInOut), // Shake for 2s
      ),
    );

    // Drop animation: Moves down 100% height in 2 seconds (starts at 2s)
    final dropAnimation = Tween<Offset>(
      begin: const Offset(0, 0),
      end: const Offset(0, 1), // Moves to bottom of the screen
    ).animate(
      CurvedAnimation(
        parent: controller,
        curve: Interval(dropStartTime / totalDuration, 1.0, curve: Curves.easeInOut), // Drop lasts 2s
      ),
    );

    return AnimatedBuilder(
      animation: controller,
      builder: (context, _) {
        return Transform.translate(
          offset: Offset(
            screenWidth * shakeAnimation.value.dx, // ✅ Shake Movement
            screenHeight * dropAnimation.value.dy, // ✅ Drop Movement
          ),
          child: child,
        );
      },
    );
  }

  /// ✅ Applies a repeating side-to-side animation
  Widget applySideToSideAnimation({
    required Widget child,
    required AnimationController controller,
    double distance = 20.0, // Default movement distance
  }) {
    registerController(controller);
    _log.info('Applying repeating side-to-side animation.');

    final sideToSideAnimation = Tween<Offset>(
      begin: Offset(-distance, 0),
      end: Offset(distance, 0),
    ).animate(
      CurvedAnimation(
        parent: controller,
        curve: Curves.easeInOut,
      ),
    );

    return AnimatedBuilder(
      animation: sideToSideAnimation,
      builder: (context, _) {
        return Transform.translate(
          offset: Offset(sideToSideAnimation.value.dx, 0),
          child: child,
        );
      },
    );
  }



}
