import 'dart:convert';
import 'dart:math';
import 'package:flutter/material.dart';

class VersionControlSystem {
  final Map<String, Commit> _commits = {};
  final Map<String, Branch> _branches = {};
  String _headBranch = 'main';
  String? _headCommit;

  String get currentBranch => _headBranch;
  Commit? get headCommit => _headCommit != null ? _commits[_headCommit] : null;

  List<Branch> get branches => _branches.values.toList();

  VersionControlSystem() {
    // Create initial commit
    final initialCommit = Commit(
      id: _generateCommitId(),
      message: 'Initial commit',
      author: 'System',
      timestamp: DateTime.now(),
      parentIds: [],
      tree: PresentationTree.empty(),
    );
    _commits[initialCommit.id] = initialCommit;
    _headCommit = initialCommit.id;

    _branches['main'] = Branch(name: 'main', commitId: initialCommit.id);
  }

  VersionControlSystem._({
    required Map<String, Commit> commits,
    required Map<String, Branch> branches,
    required this._headBranch,
    required this._headCommit,
  }) {
    _commits.addAll(commits);
    _branches.addAll(branches);
  }

  Commit commit(
    String message, {
    String? author,
    required PresentationTree tree,
  }) {
    final commit = Commit(
      id: _generateCommitId(),
      message: message,
      author: author ?? 'Anonymous',
      timestamp: DateTime.now(),
      parentIds: _headCommit != null ? [_headCommit!] : [],
      tree: tree,
    );

    _commits[commit.id] = commit;
    _headCommit = commit.id;
    _branches[_headBranch]!.commitId = commit.id;

    return commit;
  }

  Commit? checkout(String commitId) {
    if (!_commits.containsKey(commitId)) return null;
    _headCommit = commitId;
    return _commits[commitId];
  }

  Branch createBranch(String name, {String? fromCommitId}) {
    final baseCommitId = fromCommitId ?? _headCommit;
    final branch = Branch(name: name, commitId: baseCommitId!);
    _branches[name] = branch;
    return branch;
  }

  bool switchBranch(String name) {
    if (!_branches.containsKey(name)) return false;
    _headBranch = name;
    _headCommit = _branches[name]!.commitId;
    return true;
  }

  Commit? merge(String branchName, {String? message}) {
    final targetBranch = _branches[branchName];
    if (targetBranch == null) return null;

    final currentCommit = _commits[_headCommit];
    final targetCommit = _commits[targetBranch.commitId];

    if (currentCommit == null || targetCommit == null) return null;

    // Find merge base
    final mergeBase = _findMergeBase(currentCommit.id, targetCommit.id);

    // Fast-forward if possible
    if (mergeBase?.id == currentCommit.id) {
      _headCommit = targetCommit.id;
      _branches[_headBranch]!.commitId = targetCommit.id;
      return targetCommit;
    }

    // Create merge commit
    final mergeCommit = Commit(
      id: _generateCommitId(),
      message: message ?? 'Merge branch $branchName',
      author: 'System',
      timestamp: DateTime.now(),
      parentIds: [currentCommit.id, targetCommit.id],
      tree: _mergeTrees(currentCommit.tree, targetCommit.tree, mergeBase?.tree),
    );

    _commits[mergeCommit.id] = mergeCommit;
    _headCommit = mergeCommit.id;
    _branches[_headBranch]!.commitId = mergeCommit.id;

    return mergeCommit;
  }

  Commit? revert(String commitId) {
    final targetCommit = _commits[commitId];
    if (targetCommit == null) return null;
    final currentCommit = _headCommit == null ? null : _commits[_headCommit];
    final parentCommit = targetCommit.parentIds.isEmpty
        ? null
        : _commits[targetCommit.parentIds.first];
    if (currentCommit == null) return null;

    final revertCommit = Commit(
      id: _generateCommitId(),
      message: 'Revert "${targetCommit.message}"',
      author: 'System',
      timestamp: DateTime.now(),
      parentIds: _headCommit != null ? [_headCommit!] : [],
      tree: _revertTree(
        currentCommit.tree,
        targetCommit.tree,
        parentCommit?.tree,
      ),
    );

    _commits[revertCommit.id] = revertCommit;
    _headCommit = revertCommit.id;
    _branches[_headBranch]!.commitId = revertCommit.id;

    return revertCommit;
  }

  Commit? cherryPick(String commitId) {
    final targetCommit = _commits[commitId];
    if (targetCommit == null) return null;

    final cherryPickCommit = Commit(
      id: _generateCommitId(),
      message: targetCommit.message,
      author: targetCommit.author,
      timestamp: DateTime.now(),
      parentIds: _headCommit != null ? [_headCommit!] : [],
      tree: targetCommit.tree,
    );

    _commits[cherryPickCommit.id] = cherryPickCommit;
    _headCommit = cherryPickCommit.id;
    _branches[_headBranch]!.commitId = cherryPickCommit.id;

    return cherryPickCommit;
  }

  List<Commit> getHistory({String? branchName, int? limit}) {
    final branch = branchName != null
        ? _branches[branchName]
        : _branches[_headBranch];
    if (branch == null) return [];

    final history = <Commit>[];
    String? currentId = branch.commitId;

    while (currentId != null && _commits.containsKey(currentId)) {
      final commit = _commits[currentId]!;
      history.add(commit);
      if (limit != null && history.length >= limit) break;
      currentId = commit.parentIds.isNotEmpty ? commit.parentIds.first : null;
    }

    return history;
  }

  List<Commit> getBranchHistory(String branchName) {
    return getHistory(branchName: branchName);
  }

  Commit? _findMergeBase(String commitId1, String commitId2) {
    final ancestors1 = <String>{};
    String? current = commitId1;

    while (current != null && _commits.containsKey(current)) {
      ancestors1.add(current);
      final commit = _commits[current]!;
      current = commit.parentIds.isNotEmpty ? commit.parentIds.first : null;
    }

    current = commitId2;
    while (current != null && _commits.containsKey(current)) {
      if (ancestors1.contains(current)) {
        return _commits[current];
      }
      final commit = _commits[current]!;
      current = commit.parentIds.isNotEmpty ? commit.parentIds.first : null;
    }

    return null;
  }

  PresentationTree _mergeTrees(
    PresentationTree current,
    PresentationTree target,
    PresentationTree? base,
  ) {
    // Three-way merge
    if (base == null) return target;

    final mergedSlides = <String, SlideSnapshot>{};
    final allSlideIds = {...current.slides.keys, ...target.slides.keys};

    for (final slideId in allSlideIds) {
      final currentSlide = current.slides[slideId];
      final targetSlide = target.slides[slideId];
      final baseSlide = base.slides[slideId];

      if (currentSlide == null) {
        // Added in target
        mergedSlides[slideId] = targetSlide!;
      } else if (targetSlide == null) {
        // Deleted in target
        if (baseSlide != null) {
          // Deleted in target, check if modified in current
          if (_slidesEqual(currentSlide, baseSlide)) {
            // Safe to delete
            continue;
          }
        }
        mergedSlides[slideId] = currentSlide;
      } else {
        // Modified in both
        mergedSlides[slideId] = _mergeSlides(
          currentSlide,
          targetSlide,
          baseSlide,
        );
      }
    }

    return PresentationTree(
      slides: mergedSlides,
      metadata: {...current.metadata, ...target.metadata},
    );
  }

  SlideSnapshot _mergeSlides(
    SlideSnapshot current,
    SlideSnapshot target,
    SlideSnapshot? base,
  ) {
    // Simple LWW merge for now
    if (base == null) return target;

    final mergedElements = <String, ElementSnapshot>{};
    final allElementIds = {...current.elements.keys, ...target.elements.keys};

    for (final elementId in allElementIds) {
      final currentElement = current.elements[elementId];
      final targetElement = target.elements[elementId];

      if (currentElement == null) {
        mergedElements[elementId] = targetElement!;
      } else if (targetElement == null) {
        mergedElements[elementId] = currentElement;
      } else {
        // LWW based on timestamp
        mergedElements[elementId] =
            targetElement.timestamp.isAfter(currentElement.timestamp)
            ? targetElement
            : currentElement;
      }
    }

    return SlideSnapshot(
      id: current.id,
      elements: mergedElements,
      background: target.timestamp.isAfter(current.timestamp)
          ? target.background
          : current.background,
      timestamp: DateTime.now(),
    );
  }

  PresentationTree _revertTree(
    PresentationTree current,
    PresentationTree target,
    PresentationTree? parent,
  ) {
    if (parent == null) {
      final slides = Map<String, SlideSnapshot>.from(current.slides);
      for (final entry in target.slides.entries) {
        final currentSlide = slides[entry.key];
        if (currentSlide != null && _slidesEqual(currentSlide, entry.value)) {
          slides.remove(entry.key);
        }
      }
      return PresentationTree(
        slides: slides,
        metadata: Map<String, dynamic>.from(current.metadata),
      );
    }

    final revertedSlides = Map<String, SlideSnapshot>.from(current.slides);
    final allSlideIds = {...parent.slides.keys, ...target.slides.keys};

    for (final slideId in allSlideIds) {
      final before = parent.slides[slideId];
      final after = target.slides[slideId];
      final currentSlide = current.slides[slideId];

      if (before == null && after != null) {
        if (currentSlide == null || _slidesEqual(currentSlide, after)) {
          revertedSlides.remove(slideId);
        }
      } else if (before != null && after == null) {
        revertedSlides[slideId] = before;
      } else if (before != null && after != null) {
        if (currentSlide == null || _slidesEqual(currentSlide, after)) {
          revertedSlides[slideId] = before;
        } else {
          revertedSlides[slideId] = _revertSlide(currentSlide, after, before);
        }
      }
    }

    return PresentationTree(
      slides: revertedSlides,
      metadata: _revertMap(current.metadata, target.metadata, parent.metadata),
    );
  }

  SlideSnapshot _revertSlide(
    SlideSnapshot current,
    SlideSnapshot target,
    SlideSnapshot parent,
  ) {
    final elements = Map<String, ElementSnapshot>.from(current.elements);
    final allElementIds = {...parent.elements.keys, ...target.elements.keys};

    for (final elementId in allElementIds) {
      final before = parent.elements[elementId];
      final after = target.elements[elementId];
      final currentElement = current.elements[elementId];

      if (before == null && after != null) {
        if (currentElement == null || _elementsEqual(currentElement, after)) {
          elements.remove(elementId);
        }
      } else if (before != null && after == null) {
        elements[elementId] = before;
      } else if (before != null &&
          after != null &&
          (currentElement == null || _elementsEqual(currentElement, after))) {
        elements[elementId] = before;
      }
    }

    return SlideSnapshot(
      id: current.id,
      elements: elements,
      background: _mapsEqual(current.background, target.background)
          ? parent.background
          : current.background,
      timestamp: DateTime.now(),
    );
  }

  Map<String, dynamic> _revertMap(
    Map<String, dynamic> current,
    Map<String, dynamic> target,
    Map<String, dynamic> parent,
  ) {
    final result = Map<String, dynamic>.from(current);
    for (final key in {...parent.keys, ...target.keys}) {
      final before = parent[key];
      final after = target[key];
      final currentValue = current[key];
      if (before == null && after != null) {
        if (currentValue == after) result.remove(key);
      } else if (before != null && after == null) {
        result[key] = before;
      } else if (currentValue == after) {
        result[key] = before;
      }
    }
    return result;
  }

  bool _slidesEqual(SlideSnapshot a, SlideSnapshot b) {
    return a.id == b.id &&
        _mapsEqual(a.background, b.background) &&
        a.elements.length == b.elements.length &&
        a.elements.entries.every((entry) {
          final other = b.elements[entry.key];
          return other != null && _elementsEqual(entry.value, other);
        });
  }

  bool _elementsEqual(ElementSnapshot a, ElementSnapshot b) {
    return a.id == b.id &&
        a.type == b.type &&
        _mapsEqual(a.properties, b.properties) &&
        _mapsEqual(a.style, b.style);
  }

  bool _mapsEqual(Map<String, dynamic> a, Map<String, dynamic> b) {
    return jsonEncode(a) == jsonEncode(b);
  }

  String _generateCommitId() {
    final bytes = utf8.encode(
      '${DateTime.now().millisecondsSinceEpoch}_${Random().nextInt(1000000)}',
    );
    return base64Encode(bytes).substring(0, 40);
  }

  Map<String, dynamic> toJson() => {
    'commits': _commits.map((k, v) => MapEntry(k, v.toJson())),
    'branches': _branches.map((k, v) => MapEntry(k, v.toJson())),
    'headBranch': _headBranch,
    'headCommit': _headCommit,
  };

  factory VersionControlSystem.fromJson(Map<String, dynamic> json) {
    return VersionControlSystem._(
      commits: (json['commits'] as Map<String, dynamic>).map(
        (key, value) =>
            MapEntry(key, Commit.fromJson(value as Map<String, dynamic>)),
      ),
      branches: (json['branches'] as Map<String, dynamic>).map(
        (key, value) =>
            MapEntry(key, Branch.fromJson(value as Map<String, dynamic>)),
      ),
      headBranch: json['headBranch'] as String,
      headCommit: json['headCommit'] as String?,
    );
  }
}

class Commit {
  final String id;
  final String message;
  final String author;
  final DateTime timestamp;
  final List<String> parentIds;
  final PresentationTree tree;

  Commit({
    required this.id,
    required this.message,
    required this.author,
    required this.timestamp,
    required this.parentIds,
    required this.tree,
  });

  Map<String, dynamic> toJson() => {
    'id': id,
    'message': message,
    'author': author,
    'timestamp': timestamp.toIso8601String(),
    'parentIds': parentIds,
    'tree': tree.toJson(),
  };

  factory Commit.fromJson(Map<String, dynamic> json) => Commit(
    id: json['id'] as String,
    message: json['message'] as String,
    author: json['author'] as String,
    timestamp: DateTime.parse(json['timestamp'] as String),
    parentIds: (json['parentIds'] as List).cast<String>(),
    tree: PresentationTree.fromJson(json['tree'] as Map<String, dynamic>),
  );
}

class Branch {
  String name;
  String commitId;

  Branch({required this.name, required this.commitId});

  Map<String, dynamic> toJson() => {'name': name, 'commitId': commitId};

  factory Branch.fromJson(Map<String, dynamic> json) => Branch(
    name: json['name'] as String,
    commitId: json['commitId'] as String,
  );
}

class PresentationTree {
  final Map<String, SlideSnapshot> slides;
  final Map<String, dynamic> metadata;

  PresentationTree({required this.slides, required this.metadata});

  PresentationTree.empty() : slides = {}, metadata = {};

  Map<String, dynamic> toJson() => {
    'slides': slides.map((k, v) => MapEntry(k, v.toJson())),
    'metadata': metadata,
  };

  factory PresentationTree.fromJson(Map<String, dynamic> json) =>
      PresentationTree(
        slides: (json['slides'] as Map<String, dynamic>).map(
          (k, v) =>
              MapEntry(k, SlideSnapshot.fromJson(v as Map<String, dynamic>)),
        ),
        metadata: json['metadata'] as Map<String, dynamic>,
      );
}

class SlideSnapshot {
  final String id;
  final Map<String, ElementSnapshot> elements;
  final Map<String, dynamic> background;
  final DateTime timestamp;

  SlideSnapshot({
    required this.id,
    required this.elements,
    required this.background,
    required this.timestamp,
  });

  Map<String, dynamic> toJson() => {
    'id': id,
    'elements': elements.map((k, v) => MapEntry(k, v.toJson())),
    'background': background,
    'timestamp': timestamp.toIso8601String(),
  };

  factory SlideSnapshot.fromJson(Map<String, dynamic> json) => SlideSnapshot(
    id: json['id'] as String,
    elements: (json['elements'] as Map<String, dynamic>).map(
      (k, v) =>
          MapEntry(k, ElementSnapshot.fromJson(v as Map<String, dynamic>)),
    ),
    background: json['background'] as Map<String, dynamic>,
    timestamp: DateTime.parse(json['timestamp'] as String),
  );
}

class ElementSnapshot {
  final String id;
  final String type;
  final Map<String, dynamic> properties;
  final Map<String, dynamic> style;
  final DateTime timestamp;

  ElementSnapshot({
    required this.id,
    required this.type,
    required this.properties,
    required this.style,
    required this.timestamp,
  });

  Map<String, dynamic> toJson() => {
    'id': id,
    'type': type,
    'properties': properties,
    'style': style,
    'timestamp': timestamp.toIso8601String(),
  };

  factory ElementSnapshot.fromJson(Map<String, dynamic> json) =>
      ElementSnapshot(
        id: json['id'] as String,
        type: json['type'] as String,
        properties: json['properties'] as Map<String, dynamic>,
        style: json['style'] as Map<String, dynamic>,
        timestamp: DateTime.parse(json['timestamp'] as String),
      );
}

// Version history UI
class VersionHistoryPanel extends StatelessWidget {
  final VersionControlSystem vcs;
  final Function(String) onCheckout;
  final Function(String) onRevert;
  final Function(String, String) onCompare;

  const VersionHistoryPanel({
    super.key,
    required this.vcs,
    required this.onCheckout,
    required this.onRevert,
    required this.onCompare,
  });

  @override
  Widget build(BuildContext context) {
    final history = vcs.getHistory();

    return Container(
      width: 350,
      color: Colors.grey[50],
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              border: Border(bottom: BorderSide(color: Colors.grey[300]!)),
            ),
            child: Row(
              children: [
                const Text(
                  'Version History',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                ),
                const Spacer(),
                DropdownButton<String>(
                  value: vcs.currentBranch,
                  items: vcs.branches
                      .map(
                        (b) => DropdownMenuItem(
                          value: b.name,
                          child: Text(b.name),
                        ),
                      )
                      .toList(),
                  onChanged: (branch) {
                    if (branch != null) vcs.switchBranch(branch);
                  },
                ),
              ],
            ),
          ),
          Expanded(
            child: ListView.builder(
              itemCount: history.length,
              itemBuilder: (context, index) {
                final commit = history[index];
                final isHead = index == 0;

                return ListTile(
                  leading: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Container(
                        width: 12,
                        height: 12,
                        decoration: BoxDecoration(
                          color: isHead ? Colors.green : Colors.grey,
                          shape: BoxShape.circle,
                        ),
                      ),
                      if (index < history.length - 1)
                        Container(
                          width: 2,
                          height: 30,
                          color: Colors.grey[300],
                        ),
                    ],
                  ),
                  title: Text(
                    commit.message,
                    style: TextStyle(
                      fontWeight: isHead ? FontWeight.bold : FontWeight.normal,
                    ),
                  ),
                  subtitle: Text(
                    '${commit.author} \u2022 ${_formatDate(commit.timestamp)}',
                    style: TextStyle(fontSize: 12, color: Colors.grey[600]),
                  ),
                  trailing: PopupMenuButton<String>(
                    onSelected: (value) {
                      switch (value) {
                        case 'checkout':
                          onCheckout(commit.id);
                          break;
                        case 'revert':
                          onRevert(commit.id);
                          break;
                        case 'compare':
                          if (index < history.length - 1) {
                            onCompare(commit.id, history[index + 1].id);
                          }
                          break;
                      }
                    },
                    itemBuilder: (_) => [
                      const PopupMenuItem(
                        value: 'checkout',
                        child: Text('Checkout'),
                      ),
                      const PopupMenuItem(
                        value: 'revert',
                        child: Text('Revert'),
                      ),
                      const PopupMenuItem(
                        value: 'compare',
                        child: Text('Compare with previous'),
                      ),
                    ],
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  String _formatDate(DateTime date) {
    final now = DateTime.now();
    final diff = now.difference(date);

    if (diff.inMinutes < 1) return 'Just now';
    if (diff.inHours < 1) return '${diff.inMinutes}m ago';
    if (diff.inDays < 1) return '${diff.inHours}h ago';
    if (diff.inDays < 7) return '${diff.inDays}d ago';
    return '${date.month}/${date.day}/${date.year}';
  }
}
