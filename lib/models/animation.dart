import 'package:equatable/equatable.dart';

class AnimationTimeline extends Equatable {
  final List<SlideAnimation> animations;
  final Duration totalDuration;
  const AnimationTimeline({
    this.animations = const [],
    this.totalDuration = Duration.zero,
  });
  AnimationTimeline copyWith({
    List<SlideAnimation>? animations,
    Duration? totalDuration,
  }) => AnimationTimeline(
    animations: animations ?? this.animations,
    totalDuration: totalDuration ?? this.totalDuration,
  );
  @override
  List<Object?> get props => [animations, totalDuration];
}

class SlideAnimation extends Equatable {
  final String id;
  final String targetElementId;
  final AnimationType type;
  final AnimationCategory category;
  final AnimationTrigger trigger;
  final Duration delay;
  final Duration duration;
  final AnimationDirection direction;
  final double intensity;
  final bool autoReverse;
  final int repeatCount;

  const SlideAnimation({
    required this.id,
    required this.targetElementId,
    this.type = AnimationType.fade,
    this.category = AnimationCategory.entrance,
    this.trigger = AnimationTrigger.onClick,
    this.delay = Duration.zero,
    this.duration = const Duration(milliseconds: 500),
    this.direction = AnimationDirection.fromBottom,
    this.intensity = 1.0,
    this.autoReverse = false,
    this.repeatCount = 0,
  });

  SlideAnimation copyWith({
    String? id,
    String? targetElementId,
    AnimationType? type,
    AnimationCategory? category,
    AnimationTrigger? trigger,
    Duration? delay,
    Duration? duration,
    AnimationDirection? direction,
    double? intensity,
    bool? autoReverse,
    int? repeatCount,
  }) => SlideAnimation(
    id: id ?? this.id,
    targetElementId: targetElementId ?? this.targetElementId,
    type: type ?? this.type,
    category: category ?? this.category,
    trigger: trigger ?? this.trigger,
    delay: delay ?? this.delay,
    duration: duration ?? this.duration,
    direction: direction ?? this.direction,
    intensity: intensity ?? this.intensity,
    autoReverse: autoReverse ?? this.autoReverse,
    repeatCount: repeatCount ?? this.repeatCount,
  );

  @override
  List<Object?> get props => [
    id,
    targetElementId,
    type,
    trigger,
    delay,
    duration,
  ];
}

enum AnimationType {
  appear,
  fade,
  fly,
  float,
  split,
  wipe,
  shape,
  wheel,
  randomBars,
  growShrink,
  pulse,
  colorPulse,
  teeter,
  spin,
  boldFlash,
  wave,
  disappear,
  fadeOut,
  flyOut,
  floatOut,
  shrink,
  collapse,
}

enum AnimationCategory { entrance, emphasis, exit, motionPath }

enum AnimationTrigger { onClick, withPrevious, afterPrevious }

enum AnimationDirection {
  fromBottom,
  fromTop,
  fromLeft,
  fromRight,
  fromCenter,
  fromBottomLeft,
  fromBottomRight,
  fromTopLeft,
  fromTopRight,
}

class SlideTransition extends Equatable {
  final TransitionType type;
  final Duration duration;
  final bool advanceOnClick;
  final Duration advanceAfter;
  const SlideTransition({
    this.type = TransitionType.none,
    this.duration = const Duration(milliseconds: 2000),
    this.advanceOnClick = true,
    this.advanceAfter = Duration.zero,
  });

  SlideTransition copyWith({
    TransitionType? type,
    Duration? duration,
    bool? advanceOnClick,
    Duration? advanceAfter,
  }) => SlideTransition(
    type: type ?? this.type,
    duration: duration ?? this.duration,
    advanceOnClick: advanceOnClick ?? this.advanceOnClick,
    advanceAfter: advanceAfter ?? this.advanceAfter,
  );

  @override
  List<Object?> get props => [type, duration, advanceOnClick];
}

enum TransitionType {
  none,
  fade,
  push,
  wipe,
  split,
  reveal,
  randomBars,
  cover,
  uncover,
  clock,
  cube,
  flip,
  ripple,
}
