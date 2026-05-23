import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:equatable/equatable.dart';
import '../models/presentation.dart';
import 'package:uuid/uuid.dart';

class EditorState extends Equatable {
  final Presentation presentation;
  final String? selectedElementId;
  final Tool activeTool;
  final double canvasZoom;
  final bool isPresentationMode;

  const EditorState({
    required this.presentation,
    this.selectedElementId,
    this.activeTool = Tool.select,
    this.canvasZoom = 1.0,
    this.isPresentationMode = false,
  });

  EditorState copyWith({
    Presentation? presentation,
    String? selectedElementId,
    Tool? activeTool,
    double? canvasZoom,
    bool? isPresentationMode,
  }) {
    return EditorState(
      presentation: presentation ?? this.presentation,
      selectedElementId: selectedElementId ?? this.selectedElementId,
      activeTool: activeTool ?? this.activeTool,
      canvasZoom: canvasZoom ?? this.canvasZoom,
      isPresentationMode: isPresentationMode ?? this.isPresentationMode,
    );
  }

  Slide get activeSlide => presentation.slides[presentation.activeSlideIndex];

  @override
  List<Object?> get props => [presentation, selectedElementId, activeTool, canvasZoom, isPresentationMode];
}

enum Tool { select, textBox, rectangle, circle, image }

class EditorCubit extends Cubit<EditorState> {
  final _uuid = const Uuid();

  EditorCubit()
      : super(EditorState(
          presentation: Presentation(
            id: 'pres_1',
            title: 'Untitled Presentation',
            slides: [Slide(id: 'slide_1')],
          ),
        ));

  void addSlide() {
    final slides = List<Slide>.from(state.presentation.slides)
      ..add(Slide(id: _uuid.v4()));
    emit(state.copyWith(
      presentation: state.presentation.copyWith(
        slides: slides,
        activeSlideIndex: slides.length - 1,
      ),
    ));
  }

  void selectSlide(int index) {
    if (index >= 0 && index < state.presentation.slides.length) {
      emit(state.copyWith(
        presentation: state.presentation.copyWith(activeSlideIndex: index),
        selectedElementId: null,
      ));
    }
  }

  void deleteSlide(int index) {
    if (state.presentation.slides.length <= 1) return;
    final slides = List<Slide>.from(state.presentation.slides)..removeAt(index);
    final newIndex = index >= slides.length ? slides.length - 1 : index;
    emit(state.copyWith(
      presentation: state.presentation.copyWith(
        slides: slides,
        activeSlideIndex: newIndex,
      ),
    ));
  }

  void setTool(Tool tool) => emit(state.copyWith(activeTool: tool, selectedElementId: null));

  void selectElement(String? id) => emit(state.copyWith(selectedElementId: id));

  void addElement(SlideElement element) {
    final slide = state.activeSlide;
    final elements = List<SlideElement>.from(slide.elements)..add(element);
    final updatedSlide = slide.copyWith(elements: elements);
    _updateSlide(updatedSlide);
    emit(state.copyWith(selectedElementId: element.id));
  }

  void updateElement(SlideElement element) {
    final slide = state.activeSlide;
    final elements = slide.elements.map((e) => e.id == element.id ? element : e).toList();
    _updateSlide(slide.copyWith(elements: elements));
  }

  void deleteSelected() {
    if (state.selectedElementId == null) return;
    final slide = state.activeSlide;
    final elements = slide.elements.where((e) => e.id != state.selectedElementId).toList();
    _updateSlide(slide.copyWith(elements: elements));
    emit(state.copyWith(selectedElementId: null));
  }

  void moveElement(String id, Offset delta) {
    final slide = state.activeSlide;
    final element = slide.elements.firstWhere((e) => e.id == id);
    final updated = element.copyWith(position: element.position + delta);
    updateElement(updated);
  }

  void resizeElement(String id, Size newSize) {
    final slide = state.activeSlide;
    final element = slide.elements.firstWhere((e) => e.id == id);
    final updated = element.copyWith(size: newSize);
    updateElement(updated);
  }

  void setZoom(double zoom) => emit(state.copyWith(canvasZoom: zoom.clamp(0.1, 5.0)));

  void startPresentation() => emit(state.copyWith(isPresentationMode: true));

  void exitPresentation() => emit(state.copyWith(isPresentationMode: false));

  void nextSlide() {
    if (state.presentation.activeSlideIndex < state.presentation.slides.length - 1) {
      selectSlide(state.presentation.activeSlideIndex + 1);
    }
  }

  void previousSlide() {
    if (state.presentation.activeSlideIndex > 0) {
      selectSlide(state.presentation.activeSlideIndex - 1);
    }
  }

  void _updateSlide(Slide slide) {
    final slides = List<Slide>.from(state.presentation.slides);
    slides[state.presentation.activeSlideIndex] = slide;
    emit(state.copyWith(presentation: state.presentation.copyWith(slides: slides)));
  }
}