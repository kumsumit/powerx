import 'dart:ui';
import 'package:flutter/material.dart' hide SlideTransition;
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:equatable/equatable.dart';
import 'package:uuid/uuid.dart';
import '../models/presentation.dart';
import '../models/elements.dart';
import '../models/text_styles.dart';
import '../models/animation.dart';
import '../models/theme.dart';
import '../engine/command_pattern.dart';
import '../engine/pptx_importer.dart';
import '../engine/pptx_exporter.dart';

class EditorState extends Equatable {
  final Presentation presentation;
  final String? selectedElementId;
  final Set<String> multiSelectedIds;
  final Tool activeTool;
  final double canvasZoom;
  final bool isPresentationMode;
  final bool isPresenterView;
  final bool isDirty;
  final String? errorMessage;
  final bool canUndo;
  final bool canRedo;
  final bool isLoading;

  const EditorState({
    required this.presentation,
    this.selectedElementId,
    this.multiSelectedIds = const {},
    this.activeTool = Tool.select,
    this.canvasZoom = 1.0,
    this.isPresentationMode = false,
    this.isPresenterView = false,
    this.isDirty = false,
    this.errorMessage,
    this.canUndo = false,
    this.canRedo = false,
    this.isLoading = false,
  });

  EditorState copyWith({
    Presentation? presentation,
    String? selectedElementId,
    Set<String>? multiSelectedIds,
    Tool? activeTool,
    double? canvasZoom,
    bool? isPresentationMode,
    bool? isPresenterView,
    bool? isDirty,
    String? errorMessage,
    bool? canUndo,
    bool? canRedo,
    bool? isLoading,
    bool clearSelection = false,
    bool clearError = false,
  }) => EditorState(
    presentation: presentation ?? this.presentation,
    selectedElementId: clearSelection
        ? null
        : (selectedElementId ?? this.selectedElementId),
    multiSelectedIds: clearSelection
        ? const {}
        : (multiSelectedIds ?? this.multiSelectedIds),
    activeTool: activeTool ?? this.activeTool,
    canvasZoom: canvasZoom ?? this.canvasZoom,
    isPresentationMode: isPresentationMode ?? this.isPresentationMode,
    isPresenterView: isPresenterView ?? this.isPresenterView,
    isDirty: isDirty ?? this.isDirty,
    errorMessage: clearError ? null : (errorMessage ?? this.errorMessage),
    canUndo: canUndo ?? this.canUndo,
    canRedo: canRedo ?? this.canRedo,
    isLoading: isLoading ?? this.isLoading,
  );

  Slide get activeSlide => presentation.slides[presentation.activeSlideIndex];
  SlideElement? get selectedElement {
    if (selectedElementId == null) return null;
    try {
      return activeSlide.elements.firstWhere((e) => e.id == selectedElementId);
    } catch (_) {
      return null;
    }
  }

  @override
  List<Object?> get props => [
    presentation,
    selectedElementId,
    multiSelectedIds,
    activeTool,
    canvasZoom,
    isPresentationMode,
    isDirty,
    errorMessage,
    canUndo,
    canRedo,
    isLoading,
  ];
}

enum Tool {
  select,
  textBox,
  rectangle,
  roundedRectangle,
  circle,
  triangle,
  diamond,
  arrow,
  star,
  image,
  video,
  table,
  chart,
  line,
  pen,
}

class EditorCubit extends Cubit<EditorState> {
  final _uuid = const Uuid();
  final CommandHistory _history = CommandHistory(maxSize: 200);

  EditorCubit()
    : super(
        EditorState(
          presentation: Presentation(
            id: 'pres_1',
            title: 'Untitled Presentation',
            slides: [Slide(id: 'slide_1')],
            theme: const PresentationTheme(),
          ),
        ),
      );

  void _updatePresentation(Presentation pres) {
    emit(
      state.copyWith(
        presentation: pres,
        isDirty: true,
        canUndo: _history.canUndo,
        canRedo: _history.canRedo,
      ),
    );
  }

  void _executeCommand(EditorCommand cmd) {
    _history.execute(cmd);
    emit(
      state.copyWith(
        canUndo: _history.canUndo,
        canRedo: _history.canRedo,
        isDirty: true,
      ),
    );
  }

  void undo() {
    _history.undo();
    emit(
      state.copyWith(
        canUndo: _history.canUndo,
        canRedo: _history.canRedo,
        isDirty: true,
        clearSelection: true,
      ),
    );
  }

  void redo() {
    _history.redo();
    emit(
      state.copyWith(
        canUndo: _history.canUndo,
        canRedo: _history.canRedo,
        isDirty: true,
        clearSelection: true,
      ),
    );
  }

  void newPresentation() {
    _history.clear();
    emit(
      EditorState(
        presentation: Presentation(
          id: _uuid.v4(),
          title: 'Untitled Presentation',
          slides: [Slide(id: _uuid.v4())],
          theme: const PresentationTheme(),
        ),
        canUndo: false,
        canRedo: false,
      ),
    );
  }

  Future<void> openPresentation(String filePath) async {
    emit(state.copyWith(isLoading: true));
    try {
      final importer = PptxImporter();
      final pres = await importer.import(filePath);
      _history.clear();
      emit(
        EditorState(
          presentation: pres,
          canUndo: false,
          canRedo: false,
          isDirty: false,
        ),
      );
    } catch (e) {
      emit(
        state.copyWith(errorMessage: 'Failed to open: \$e', isLoading: false),
      );
    }
  }

  Future<void> savePresentation(String filePath) async {
    try {
      final exporter = PptxExporter();
      await exporter.export(state.presentation, filePath);
      emit(
        state.copyWith(
          presentation: state.presentation.copyWith(filePath: filePath),
          isDirty: false,
        ),
      );
    } catch (e) {
      emit(state.copyWith(errorMessage: 'Failed to save: \$e'));
    }
  }

  void addSlide() {
    final slide = Slide(
      id: _uuid.v4(),
      slideNumber: state.presentation.slides.length + 1,
    );
    _executeCommand(
      AddSlideCommand(
        presentation: state.presentation,
        slide: slide,
        index: state.presentation.slides.length,
        onUpdate: _updatePresentation,
      ),
    );
  }

  void duplicateSlide(int index) {
    if (index < 0 || index >= state.presentation.slides.length) return;
    final original = state.presentation.slides[index];
    final copy = original.copyWith(id: _uuid.v4());
    _executeCommand(
      AddSlideCommand(
        presentation: state.presentation,
        slide: copy,
        index: index + 1,
        onUpdate: _updatePresentation,
      ),
    );
  }

  void selectSlide(int index) {
    if (index >= 0 && index < state.presentation.slides.length) {
      emit(
        state.copyWith(
          presentation: state.presentation.copyWith(activeSlideIndex: index),
          clearSelection: true,
        ),
      );
    }
  }

  void deleteSlide(int index) {
    if (state.presentation.slides.length <= 1) return;
    _executeCommand(
      DeleteSlideCommand(
        presentation: state.presentation,
        index: index,
        onUpdate: _updatePresentation,
      ),
    );
  }

  void setTool(Tool tool) =>
      emit(state.copyWith(activeTool: tool, clearSelection: true));

  void selectElement(String? id, {bool multiSelect = false}) {
    if (id == null) {
      emit(state.copyWith(clearSelection: true));
      return;
    }
    if (multiSelect) {
      final current = Set<String>.from(state.multiSelectedIds);
      if (current.contains(id)) {
        current.remove(id);
      } else {
        current.add(id);
      }
      emit(state.copyWith(multiSelectedIds: current, selectedElementId: id));
    } else {
      emit(state.copyWith(selectedElementId: id, multiSelectedIds: const {}));
    }
  }

  void addElement(SlideElement element) {
    _executeCommand(
      AddElementCommand(
        presentation: state.presentation,
        slideIndex: state.presentation.activeSlideIndex,
        element: element,
        onUpdate: _updatePresentation,
      ),
    );
    emit(state.copyWith(selectedElementId: element.id));
  }

  void updateElement(SlideElement element) {
    final oldElement = state.activeSlide.elements.firstWhere(
      (e) => e.id == element.id,
    );
    _executeCommand(
      UpdateElementCommand(
        presentation: state.presentation,
        slideIndex: state.presentation.activeSlideIndex,
        oldElement: oldElement,
        newElement: element,
        onUpdate: _updatePresentation,
      ),
    );
  }

  void deleteSelected() {
    final id = state.selectedElementId;
    if (id == null) return;
    _executeCommand(
      RemoveElementCommand(
        presentation: state.presentation,
        slideIndex: state.presentation.activeSlideIndex,
        elementId: id,
        onUpdate: _updatePresentation,
      ),
    );
    emit(state.copyWith(clearSelection: true));
  }

  void moveElement(String id, Offset delta) {
    final slide = state.activeSlide;
    final element = slide.elements.firstWhere((e) => e.id == id);
    final newPos = element.position + delta;
    _executeCommand(
      MoveElementCommand(
        presentation: state.presentation,
        slideIndex: state.presentation.activeSlideIndex,
        elementId: id,
        oldPosition: element.position,
        newPosition: newPos,
        onUpdate: _updatePresentation,
      ),
    );
  }

  void resizeElement(String id, Size newSize, {Offset? newPosition}) {
    final slide = state.activeSlide;
    final element = slide.elements.firstWhere((e) => e.id == id);
    final updated = element.copyWith(
      size: newSize,
      position: newPosition ?? element.position,
    );
    updateElement(updated);
  }

  void bringToFront(String id) {
    final slide = state.activeSlide;
    final maxZ = slide.elements.fold(0, (m, e) => e.zIndex > m ? e.zIndex : m);
    final element = slide.elements.firstWhere((e) => e.id == id);
    updateElement(element.copyWith(zIndex: maxZ + 1));
  }

  void sendToBack(String id) {
    final slide = state.activeSlide;
    final minZ = slide.elements.fold(0, (m, e) => e.zIndex < m ? e.zIndex : m);
    final element = slide.elements.firstWhere((e) => e.id == id);
    updateElement(element.copyWith(zIndex: minZ - 1));
  }

  void setZoom(double zoom) =>
      emit(state.copyWith(canvasZoom: zoom.clamp(0.1, 5.0)));

  void startPresentation({bool presenterView = false}) {
    emit(
      state.copyWith(isPresentationMode: true, isPresenterView: presenterView),
    );
  }

  void exitPresentation() =>
      emit(state.copyWith(isPresentationMode: false, isPresenterView: false));

  void nextSlide() {
    if (state.presentation.activeSlideIndex <
        state.presentation.slides.length - 1) {
      selectSlide(state.presentation.activeSlideIndex + 1);
    }
  }

  void previousSlide() {
    if (state.presentation.activeSlideIndex > 0) {
      selectSlide(state.presentation.activeSlideIndex - 1);
    }
  }

  void updateTextElement(String id, List<RichParagraph> paragraphs) {
    final slide = state.activeSlide;
    final element = slide.elements.firstWhere((e) => e.id == id) as TextElement;
    updateElement(element.copyWith(paragraphs: paragraphs));
  }

  void updateSlideBackground(Color color) {
    final slide = state.activeSlide;
    _updateSlide(slide.copyWith(backgroundColorOverride: color));
  }

  void setSlideTransition(SlideTransition transition) {
    final slide = state.activeSlide;
    _updateSlide(slide.copyWith(transition: transition));
  }

  void _updateSlide(Slide slide) {
    final slides = List<Slide>.from(state.presentation.slides);
    slides[state.presentation.activeSlideIndex] = slide;
    _updatePresentation(state.presentation.copyWith(slides: slides));
  }

  void clearError() => emit(state.copyWith(clearError: true));
}
