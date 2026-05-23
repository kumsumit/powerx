import 'dart:math';
import 'package:flutter/material.dart' hide SlideTransition;
import 'package:flutter/widgets.dart' as flutter;
import '../../models/animation.dart';
import '../../models/elements.dart';

class AnimationEngine {
  static Widget buildAnimatedElement({
    required SlideElement element,
    required List<SlideAnimation> animations,
    required AnimationController controller,
    required bool isPlaying,
    required int triggerIndex,
    required Widget child,
  }) {
    if (animations.isEmpty || !isPlaying) return child;

    Widget result = child;

    for (int i = 0; i <= triggerIndex && i < animations.length; i++) {
      final anim = animations[i];
      final animController = _createSubController(controller, anim, i);

      switch (anim.type) {
        case AnimationType.fade:
        case AnimationType.fadeOut:
          result = FadeTransition(
            opacity: Tween<double>(
              begin: anim.category == AnimationCategory.exit ? 1.0 : 0.0,
              end: anim.category == AnimationCategory.exit ? 0.0 : 1.0,
            ).animate(animController),
            child: result,
          );
          break;
        case AnimationType.fly:
        case AnimationType.flyOut:
          result = _buildFlyAnimation(result, anim, animController);
          break;
        case AnimationType.growShrink:
          result = ScaleTransition(
            scale: Tween<double>(begin: 0.0, end: 1.0).animate(
              CurvedAnimation(
                parent: animController,
                curve: Curves.easeOutBack,
              ),
            ),
            child: result,
          );
          break;
        case AnimationType.spin:
          result = RotationTransition(
            turns: Tween<double>(begin: 0, end: 1).animate(animController),
            child: result,
          );
          break;
        case AnimationType.wipe:
          result = ClipRect(
            child: AnimatedBuilder(
              animation: animController,
              builder: (context, child) {
                return Align(
                  alignment: _getWipeAlignment(anim.direction),
                  widthFactor: animController.value,
                  heightFactor: animController.value,
                  child: child,
                );
              },
              child: result,
            ),
          );
          break;
        default:
          result = FadeTransition(
            opacity: Tween<double>(
              begin: 0.0,
              end: 1.0,
            ).animate(animController),
            child: result,
          );
      }
    }

    return result;
  }

  static Animation<double> _createSubController(
    AnimationController parent,
    SlideAnimation anim,
    int index,
  ) {
    final start = anim.delay.inMilliseconds / parent.duration!.inMilliseconds;
    final end =
        start + anim.duration.inMilliseconds / parent.duration!.inMilliseconds;

    return CurvedAnimation(
      parent: parent,
      curve: Interval(
        start.clamp(0.0, 1.0),
        end.clamp(0.0, 1.0),
        curve: Curves.easeInOut,
      ),
    );
  }

  static Widget _buildFlyAnimation(
    Widget child,
    SlideAnimation anim,
    Animation<double> controller,
  ) {
    Offset beginOffset = Offset.zero;
    switch (anim.direction) {
      case AnimationDirection.fromBottom:
        beginOffset = const Offset(0, 1);
        break;
      case AnimationDirection.fromTop:
        beginOffset = const Offset(0, -1);
        break;
      case AnimationDirection.fromLeft:
        beginOffset = const Offset(-1, 0);
        break;
      case AnimationDirection.fromRight:
        beginOffset = const Offset(1, 0);
        break;
      default:
        beginOffset = const Offset(0, 1);
    }

    return AnimatedBuilder(
      animation: controller,
      builder: (context, child) {
        return Transform.translate(
          offset: beginOffset * (1 - controller.value) * 200,
          child: Opacity(opacity: controller.value, child: child),
        );
      },
      child: child,
    );
  }

  static Alignment _getWipeAlignment(AnimationDirection direction) {
    switch (direction) {
      case AnimationDirection.fromBottom:
        return Alignment.bottomCenter;
      case AnimationDirection.fromTop:
        return Alignment.topCenter;
      case AnimationDirection.fromLeft:
        return Alignment.centerLeft;
      case AnimationDirection.fromRight:
        return Alignment.centerRight;
      default:
        return Alignment.center;
    }
  }
}

class SlideTransitionWidget extends StatelessWidget {
  final SlideTransition transition;
  final Animation<double> animation;
  final Widget child;

  const SlideTransitionWidget({
    super.key,
    required this.transition,
    required this.animation,
    required this.child,
  });

  @override
  Widget build(BuildContext context) {
    switch (transition.type) {
      case TransitionType.fade:
        return FadeTransition(opacity: animation, child: child);
      case TransitionType.push:
        return flutter.SlideTransition(
          position: Tween<Offset>(
            begin: const Offset(1, 0),
            end: Offset.zero,
          ).animate(animation),
          child: child,
        );
      case TransitionType.wipe:
        return ClipRect(
          child: Align(
            alignment: Alignment.centerLeft,
            widthFactor: animation.value,
            child: child,
          ),
        );
      case TransitionType.split:
        return AnimatedBuilder(
          animation: animation,
          builder: (context, child) {
            return ClipRect(
              child: Align(
                alignment: Alignment.center,
                widthFactor: animation.value,
                heightFactor: 1.0,
                child: child,
              ),
            );
          },
          child: child,
        );
      case TransitionType.reveal:
        return AnimatedBuilder(
          animation: animation,
          builder: (context, child) {
            return Transform.scale(
              scale: 0.8 + (0.2 * animation.value),
              child: Opacity(opacity: animation.value, child: child),
            );
          },
          child: child,
        );
      case TransitionType.cube:
        return AnimatedBuilder(
          animation: animation,
          builder: (context, child) {
            final angle = animation.value * pi / 2;
            return Transform(
              transform: Matrix4.identity()
                ..setEntry(3, 2, 0.001)
                ..rotateY(angle),
              alignment: Alignment.centerLeft,
              child: child,
            );
          },
          child: child,
        );
      case TransitionType.flip:
        return AnimatedBuilder(
          animation: animation,
          builder: (context, child) {
            final angle = animation.value * pi;
            return Transform(
              transform: Matrix4.identity()
                ..setEntry(3, 2, 0.001)
                ..rotateY(angle),
              alignment: Alignment.center,
              child: child,
            );
          },
          child: child,
        );
      default:
        return child;
    }
  }
}
