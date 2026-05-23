import 'package:flutter/material.dart';
import '../models/presentation.dart';
import '../models/elements.dart';

abstract class EditorCommand {
  void execute();
  void undo();
  String get description;
}

class CommandHistory {
  final List<EditorCommand> _history = [];
  int _index = -1;
  final int maxSize;

  CommandHistory({this.maxSize = 100});

  void execute(EditorCommand command) {
    command.execute();
    if (_index < _history.length - 1) {
      _history.removeRange(_index + 1, _history.length);
    }
    _history.add(command);
    if (_history.length > maxSize) {
      _history.removeAt(0);
    } else {
      _index++;
    }
  }

  bool get canUndo => _index >= 0;
  bool get canRedo => _index < _history.length - 1;

  void undo() {
    if (canUndo) {
      _history[_index].undo();
      _index--;
    }
  }

  void redo() {
    if (canRedo) {
      _index++;
      _history[_index].execute();
    }
  }

  void clear() {
    _history.clear();
    _index = -1;
  }

  List<String> get historyDescriptions =>
      _history.map((c) => c.description).toList();
}

class AddElementCommand extends EditorCommand {
  final Presentation presentation;
  final int slideIndex;
  final SlideElement element;
  final Function(Presentation) onUpdate;

  AddElementCommand({
    required this.presentation,
    required this.slideIndex,
    required this.element,
    required this.onUpdate,
  });

  @override
  void execute() {
    final slides = List<Slide>.from(presentation.slides);
    final slide = slides[slideIndex];
    final elements = List<SlideElement>.from(slide.elements)..add(element);
    slides[slideIndex] = slide.copyWith(elements: elements);
    onUpdate(presentation.copyWith(slides: slides));
  }

  @override
  void undo() {
    final slides = List<Slide>.from(presentation.slides);
    final slide = slides[slideIndex];
    final elements = slide.elements.where((e) => e.id != element.id).toList();
    slides[slideIndex] = slide.copyWith(elements: elements);
    onUpdate(presentation.copyWith(slides: slides));
  }

  @override
  String get description => 'Add \${element.runtimeType}';
}

class RemoveElementCommand extends EditorCommand {
  final Presentation presentation;
  final int slideIndex;
  final String elementId;
  final Function(Presentation) onUpdate;
  SlideElement? _removedElement;

  RemoveElementCommand({
    required this.presentation,
    required this.slideIndex,
    required this.elementId,
    required this.onUpdate,
  });

  @override
  void execute() {
    final slides = List<Slide>.from(presentation.slides);
    final slide = slides[slideIndex];
    _removedElement = slide.elements.firstWhere((e) => e.id == elementId);
    final elements = slide.elements.where((e) => e.id != elementId).toList();
    slides[slideIndex] = slide.copyWith(elements: elements);
    onUpdate(presentation.copyWith(slides: slides));
  }

  @override
  void undo() {
    if (_removedElement == null) return;
    final slides = List<Slide>.from(presentation.slides);
    final slide = slides[slideIndex];
    final elements = List<SlideElement>.from(slide.elements)..add(_removedElement!);
    slides[slideIndex] = slide.copyWith(elements: elements);
    onUpdate(presentation.copyWith(slides: slides));
  }

  @override
  String get description => 'Remove element';
}

class MoveElementCommand extends EditorCommand {
  final Presentation presentation;
  final int slideIndex;
  final String elementId;
  final Offset oldPosition;
  final Offset newPosition;
  final Function(Presentation) onUpdate;

  MoveElementCommand({
    required this.presentation,
    required this.slideIndex,
    required this.elementId,
    required this.oldPosition,
    required this.newPosition,
    required this.onUpdate,
  });

  @override
  void execute() {
    _updatePosition(newPosition);
  }

  @override
  void undo() {
    _updatePosition(oldPosition);
  }

  void _updatePosition(Offset pos) {
    final slides = List<Slide>.from(presentation.slides);
    final slide = slides[slideIndex];
    final elements = slide.elements.map((e) {
      if (e.id == elementId) return e.copyWith(position: pos);
      return e;
    }).toList();
    slides[slideIndex] = slide.copyWith(elements: elements);
    onUpdate(presentation.copyWith(slides: slides));
  }

  @override
  String get description => 'Move element';
}

class UpdateElementCommand extends EditorCommand {
  final Presentation presentation;
  final int slideIndex;
  final SlideElement oldElement;
  final SlideElement newElement;
  final Function(Presentation) onUpdate;

  UpdateElementCommand({
    required this.presentation,
    required this.slideIndex,
    required this.oldElement,
    required this.newElement,
    required this.onUpdate,
  });

  @override
  void execute() {
    _apply(newElement);
  }

  @override
  void undo() {
    _apply(oldElement);
  }

  void _apply(SlideElement element) {
    final slides = List<Slide>.from(presentation.slides);
    final slide = slides[slideIndex];
    final elements = slide.elements.map((e) => e.id == element.id ? element : e).toList();
    slides[slideIndex] = slide.copyWith(elements: elements);
    onUpdate(presentation.copyWith(slides: slides));
  }

  @override
  String get description => 'Update \${newElement.runtimeType}';
}

class AddSlideCommand extends EditorCommand {
  final Presentation presentation;
  final Slide slide;
  final int index;
  final Function(Presentation) onUpdate;

  AddSlideCommand({
    required this.presentation,
    required this.slide,
    required this.index,
    required this.onUpdate,
  });

  @override
  void execute() {
    final slides = List<Slide>.from(presentation.slides);
    slides.insert(index, slide);
    onUpdate(presentation.copyWith(slides: slides, activeSlideIndex: index));
  }

  @override
  void undo() {
    final slides = List<Slide>.from(presentation.slides);
    slides.removeAt(index);
    final newIndex = (presentation.activeSlideIndex >= slides.length)
        ? slides.length - 1
        : presentation.activeSlideIndex;
    onUpdate(presentation.copyWith(slides: slides, activeSlideIndex: newIndex));
  }

  @override
  String get description => 'Add slide';
}

class DeleteSlideCommand extends EditorCommand {
  final Presentation presentation;
  final int index;
  final Function(Presentation) onUpdate;
  Slide? _removedSlide;

  DeleteSlideCommand({
    required this.presentation,
    required this.index,
    required this.onUpdate,
  });

  @override
  void execute() {
    final slides = List<Slide>.from(presentation.slides);
    _removedSlide = slides[index];
    slides.removeAt(index);
    final newIndex = (presentation.activeSlideIndex >= slides.length)
        ? slides.length - 1
        : presentation.activeSlideIndex;
    onUpdate(presentation.copyWith(slides: slides, activeSlideIndex: newIndex));
  }

  @override
  void undo() {
    if (_removedSlide == null) return;
    final slides = List<Slide>.from(presentation.slides);
    slides.insert(index, _removedSlide!);
    onUpdate(presentation.copyWith(slides: slides, activeSlideIndex: index));
  }

  @override
  String get description => 'Delete slide';
}
