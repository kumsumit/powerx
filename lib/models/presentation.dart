import 'dart:ui';
import 'package:equatable/equatable.dart';
import 'elements.dart';
import 'animation.dart';
import 'slide_master.dart';
import 'theme.dart';

class Presentation extends Equatable {
  final String id;
  final String title;
  final List<Slide> slides;
  final List<SlideMaster> masters;
  final List<SlideLayout> layouts;
  final PresentationTheme theme;
  final int activeSlideIndex;
  final PresentationSettings settings;
  final String? filePath;

  const Presentation({
    required this.id,
    required this.title,
    required this.slides,
    this.masters = const [],
    this.layouts = const [],
    required this.theme,
    this.activeSlideIndex = 0,
    this.settings = const PresentationSettings(),
    this.filePath,
  });

  Presentation copyWith({
    String? title,
    List<Slide>? slides,
    List<SlideMaster>? masters,
    List<SlideLayout>? layouts,
    PresentationTheme? theme,
    int? activeSlideIndex,
    PresentationSettings? settings,
    String? filePath,
  }) => Presentation(
    id: id,
    title: title ?? this.title,
    slides: slides ?? this.slides,
    masters: masters ?? this.masters,
    layouts: layouts ?? this.layouts,
    theme: theme ?? this.theme,
    activeSlideIndex: activeSlideIndex ?? this.activeSlideIndex,
    settings: settings ?? this.settings,
    filePath: filePath ?? this.filePath,
  );

  Slide get activeSlide => slides[activeSlideIndex];

  @override
  List<Object?> get props => [
    id,
    title,
    slides,
    masters,
    layouts,
    theme,
    activeSlideIndex,
    settings,
  ];
}

class Slide extends Equatable {
  final String id;
  final String? layoutId;
  final String? masterId;
  final Color? backgroundColorOverride;
  final BackgroundFill? backgroundFillOverride;
  final List<SlideElement> elements;
  final SlideTransition transition;
  final AnimationTimeline animations;
  final String? notes;
  final bool hidden;
  final int slideNumber;

  const Slide({
    required this.id,
    this.layoutId,
    this.masterId,
    this.backgroundColorOverride,
    this.backgroundFillOverride,
    this.elements = const [],
    this.transition = const SlideTransition(),
    this.animations = const AnimationTimeline(),
    this.notes,
    this.hidden = false,
    this.slideNumber = 0,
  });

  Slide copyWith({
    String? id,
    String? layoutId,
    String? masterId,
    Color? backgroundColorOverride,
    BackgroundFill? backgroundFillOverride,
    List<SlideElement>? elements,
    SlideTransition? transition,
    AnimationTimeline? animations,
    String? notes,
    bool? hidden,
    int? slideNumber,
  }) => Slide(
    id: id ?? this.id,
    layoutId: layoutId ?? this.layoutId,
    masterId: masterId ?? this.masterId,
    backgroundColorOverride:
        backgroundColorOverride ?? this.backgroundColorOverride,
    backgroundFillOverride:
        backgroundFillOverride ?? this.backgroundFillOverride,
    elements: elements ?? this.elements,
    transition: transition ?? this.transition,
    animations: animations ?? this.animations,
    notes: notes ?? this.notes,
    hidden: hidden ?? this.hidden,
    slideNumber: slideNumber ?? this.slideNumber,
  );

  @override
  List<Object?> get props => [
    id,
    layoutId,
    elements,
    transition,
    animations,
    hidden,
    slideNumber,
  ];
}

class PresentationSettings extends Equatable {
  final Size slideSize;
  final bool loopUntilEsc;
  final bool showPresenterView;
  final bool useTimings;
  final bool showMediaControls;
  const PresentationSettings({
    this.slideSize = const Size(960, 540),
    this.loopUntilEsc = false,
    this.showPresenterView = true,
    this.useTimings = false,
    this.showMediaControls = true,
  });

  PresentationSettings copyWith({
    Size? slideSize,
    bool? loopUntilEsc,
    bool? showPresenterView,
    bool? useTimings,
    bool? showMediaControls,
  }) => PresentationSettings(
    slideSize: slideSize ?? this.slideSize,
    loopUntilEsc: loopUntilEsc ?? this.loopUntilEsc,
    showPresenterView: showPresenterView ?? this.showPresenterView,
    useTimings: useTimings ?? this.useTimings,
    showMediaControls: showMediaControls ?? this.showMediaControls,
  );

  @override
  List<Object?> get props => [slideSize, loopUntilEsc, showPresenterView, useTimings, showMediaControls];
}
