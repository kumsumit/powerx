import 'dart:math';
import 'dart:async';
import 'package:flutter/material.dart';

// CRDT: Conflict-free Replicated Data Type for collaborative editing
abstract class Crdt {
  String get id;
  int get lamportTimestamp;
  String get replicaId;

  Map<String, dynamic> toJson();
  void merge(Crdt other);
}

class LamportClock {
  int _time = 0;
  final String replicaId;

  LamportClock(this.replicaId);

  int tick() => ++_time;

  void update(int otherTime) {
    _time = max(_time, otherTime) + 1;
  }

  int get time => _time;
}

class CrdtSlide extends Crdt {
  @override
  final String id;
  @override
  int lamportTimestamp;
  @override
  final String replicaId;

  final CrdtMap<String, dynamic> properties;
  final CrdtList<CrdtElement> elements;
  final CrdtMap<String, dynamic> background;

  CrdtSlide({
    required this.id,
    required this.replicaId,
    required this.lamportTimestamp,
    required this.properties,
    required this.elements,
    required this.background,
  });

  factory CrdtSlide.fromJson(Map<String, dynamic> json) => CrdtSlide(
    id: json['id'] as String,
    replicaId: json['replicaId'] as String,
    lamportTimestamp: json['lamportTimestamp'] as int,
    properties: CrdtMap<String, dynamic>.fromJson(
      json['properties'] as Map<String, dynamic>,
    ),
    elements: CrdtList<CrdtElement>.fromJson(
      json['elements'] as Map<String, dynamic>,
      CrdtElement.fromJson,
    ),
    background: CrdtMap<String, dynamic>.fromJson(
      json['background'] as Map<String, dynamic>,
    ),
  );

  @override
  Map<String, dynamic> toJson() => {
    'id': id,
    'lamportTimestamp': lamportTimestamp,
    'replicaId': replicaId,
    'properties': properties.toJson(),
    'elements': elements.toJson(),
    'background': background.toJson(),
  };

  @override
  void merge(Crdt other) {
    if (other is! CrdtSlide || other.id != id) return;
    properties.merge(other.properties);
    elements.merge(other.elements);
    background.merge(other.background);
    lamportTimestamp = max(lamportTimestamp, other.lamportTimestamp);
  }
}

class CrdtElement extends Crdt {
  @override
  final String id;
  @override
  int lamportTimestamp;
  @override
  final String replicaId;

  final CrdtMap<String, dynamic> properties;
  final CrdtMap<String, dynamic> style;

  CrdtElement({
    required this.id,
    required this.replicaId,
    required this.lamportTimestamp,
    required this.properties,
    required this.style,
  });

  factory CrdtElement.fromJson(Map<String, dynamic> json) => CrdtElement(
    id: json['id'] as String,
    replicaId: json['replicaId'] as String,
    lamportTimestamp: json['lamportTimestamp'] as int,
    properties: CrdtMap<String, dynamic>.fromJson(
      json['properties'] as Map<String, dynamic>,
    ),
    style: CrdtMap<String, dynamic>.fromJson(
      json['style'] as Map<String, dynamic>,
    ),
  );

  @override
  Map<String, dynamic> toJson() => {
    'id': id,
    'lamportTimestamp': lamportTimestamp,
    'replicaId': replicaId,
    'properties': properties.toJson(),
    'style': style.toJson(),
  };

  @override
  void merge(Crdt other) {
    if (other is! CrdtElement || other.id != id) return;
    properties.merge(other.properties);
    style.merge(other.style);
    lamportTimestamp = max(lamportTimestamp, other.lamportTimestamp);
  }
}

class CrdtMap<K, V> extends Crdt {
  @override
  final String id;
  @override
  int lamportTimestamp;
  @override
  final String replicaId;

  final Map<K, CrdtRegister<V>> _data = {};

  CrdtMap({
    required this.id,
    required this.replicaId,
    required this.lamportTimestamp,
  });

  factory CrdtMap.fromJson(Map<String, dynamic> json) {
    final map = CrdtMap<K, V>(
      id: json['id'] as String,
      replicaId: json['replicaId'] as String,
      lamportTimestamp: json['lamportTimestamp'] as int,
    );
    final values = (json['data'] as Map<String, dynamic>? ?? {});
    for (final entry in values.entries) {
      map._data[entry.key as K] = CrdtRegister<V>.fromJson(
        entry.value as Map<String, dynamic>,
      );
    }
    return map;
  }

  void set(K key, V value, LamportClock clock) {
    final timestamp = clock.tick();
    _data[key] = CrdtRegister<V>(
      id: '${id}_$key',
      replicaId: replicaId,
      lamportTimestamp: timestamp,
      value: value,
    );
    lamportTimestamp = timestamp;
  }

  V? get(K key) => _data[key]?.value;

  void remove(K key, LamportClock clock) {
    _data.remove(key);
    lamportTimestamp = clock.tick();
  }

  @override
  Map<String, dynamic> toJson() => {
    'id': id,
    'lamportTimestamp': lamportTimestamp,
    'replicaId': replicaId,
    'data': _data.map((k, v) => MapEntry(k.toString(), v.toJson())),
  };

  @override
  void merge(Crdt other) {
    if (other is! CrdtMap<K, V> || other.id != id) return;
    for (final entry in other._data.entries) {
      if (!_data.containsKey(entry.key)) {
        _data[entry.key] = entry.value;
      } else {
        final existing = _data[entry.key]!;
        if (entry.value.lamportTimestamp > existing.lamportTimestamp ||
            (entry.value.lamportTimestamp == existing.lamportTimestamp &&
                entry.value.replicaId.compareTo(existing.replicaId) > 0)) {
          _data[entry.key] = entry.value;
        }
      }
    }
    lamportTimestamp = max(lamportTimestamp, other.lamportTimestamp);
  }
}

class CrdtList<T extends Crdt> extends Crdt {
  @override
  final String id;
  @override
  int lamportTimestamp;
  @override
  final String replicaId;

  final List<T> _items = [];
  final Map<String, T> _tombstones = {};

  CrdtList({
    required this.id,
    required this.replicaId,
    required this.lamportTimestamp,
  });

  factory CrdtList.fromJson(
    Map<String, dynamic> json,
    T Function(Map<String, dynamic>) itemFromJson,
  ) {
    final list = CrdtList<T>(
      id: json['id'] as String,
      replicaId: json['replicaId'] as String,
      lamportTimestamp: json['lamportTimestamp'] as int,
    );
    for (final item in (json['items'] as List? ?? const [])) {
      list._items.add(itemFromJson(item as Map<String, dynamic>));
    }
    for (final item in (json['tombstones'] as List? ?? const [])) {
      final tombstone = itemFromJson(item as Map<String, dynamic>);
      list._tombstones[tombstone.id] = tombstone;
    }
    return list;
  }

  void add(T item, LamportClock clock) {
    _items.add(item);
    lamportTimestamp = clock.tick();
  }

  void insert(int index, T item, LamportClock clock) {
    _items.insert(index, item);
    lamportTimestamp = clock.tick();
  }

  void removeAt(int index, LamportClock clock) {
    if (index >= 0 && index < _items.length) {
      final item = _items.removeAt(index);
      _tombstones[item.id] = item;
      lamportTimestamp = clock.tick();
    }
  }

  T? get(int index) =>
      index >= 0 && index < _items.length ? _items[index] : null;

  List<T> get items => List.unmodifiable(_items);

  @override
  Map<String, dynamic> toJson() => {
    'id': id,
    'lamportTimestamp': lamportTimestamp,
    'replicaId': replicaId,
    'items': _items.map((i) => i.toJson()).toList(),
    'tombstones': _tombstones.values.map((t) => t.toJson()).toList(),
  };

  @override
  void merge(Crdt other) {
    if (other is! CrdtList<T> || other.id != id) return;

    // Merge tombstones
    for (final entry in other._tombstones.entries) {
      _tombstones.putIfAbsent(entry.key, () => entry.value);
    }

    // Merge items using LWW for same IDs
    final mergedItems = <T>[];
    final allIds = <String>{};

    for (final item in [..._items, ...other._items]) {
      if (_tombstones.containsKey(item.id)) continue;
      if (allIds.contains(item.id)) {
        // Conflict resolution: keep newer
        final existingIndex = mergedItems.indexWhere((i) => i.id == item.id);
        if (existingIndex >= 0) {
          final existing = mergedItems[existingIndex];
          if (item.lamportTimestamp > existing.lamportTimestamp ||
              (item.lamportTimestamp == existing.lamportTimestamp &&
                  item.replicaId.compareTo(existing.replicaId) > 0)) {
            mergedItems[existingIndex] = item;
          }
        }
      } else {
        mergedItems.add(item);
        allIds.add(item.id);
      }
    }

    _items.clear();
    _items.addAll(mergedItems);
    lamportTimestamp = max(lamportTimestamp, other.lamportTimestamp);
  }
}

class CrdtRegister<T> extends Crdt {
  @override
  final String id;
  @override
  int lamportTimestamp;
  @override
  final String replicaId;
  T value;

  CrdtRegister({
    required this.id,
    required this.replicaId,
    required this.lamportTimestamp,
    required this.value,
  });

  factory CrdtRegister.fromJson(Map<String, dynamic> json) => CrdtRegister<T>(
    id: json['id'] as String,
    replicaId: json['replicaId'] as String,
    lamportTimestamp: json['lamportTimestamp'] as int,
    value: json['value'] as T,
  );

  @override
  Map<String, dynamic> toJson() => {
    'id': id,
    'lamportTimestamp': lamportTimestamp,
    'replicaId': replicaId,
    'value': value,
  };

  @override
  void merge(Crdt other) {
    if (other is! CrdtRegister<T> || other.id != id) return;
    if (other.lamportTimestamp > lamportTimestamp ||
        (other.lamportTimestamp == lamportTimestamp &&
            other.replicaId.compareTo(replicaId) > 0)) {
      value = other.value;
      lamportTimestamp = other.lamportTimestamp;
    }
  }
}

abstract class CollaborationTransport {
  Stream<Map<String, dynamic>> get messages;
  Future<void> connect(String roomId, {String? serverUrl});
  void send(Map<String, dynamic> message);
  Future<void> disconnect();
}

class LocalCollaborationTransport implements CollaborationTransport {
  static final Map<String, StreamController<Map<String, dynamic>>> _rooms = {};

  StreamController<Map<String, dynamic>>? _room;
  StreamController<Map<String, dynamic>>? _messages;

  @override
  Stream<Map<String, dynamic>> get messages {
    _messages ??= StreamController<Map<String, dynamic>>.broadcast();
    return _messages!.stream;
  }

  @override
  Future<void> connect(String roomId, {String? serverUrl}) async {
    _messages ??= StreamController<Map<String, dynamic>>.broadcast();
    _room = _rooms.putIfAbsent(
      roomId,
      () => StreamController<Map<String, dynamic>>.broadcast(),
    );
    _room!.stream.listen((message) {
      if (!(_messages?.isClosed ?? true)) {
        _messages!.add(Map<String, dynamic>.from(message));
      }
    });
  }

  @override
  void send(Map<String, dynamic> message) {
    _room?.add(Map<String, dynamic>.from(message));
  }

  @override
  Future<void> disconnect() async {
    _room = null;
    await _messages?.close();
    _messages = null;
  }
}

// WebSocket-based collaboration service
class CollaborationService extends ChangeNotifier {
  final String replicaId;
  final LamportClock _clock;
  final CollaborationTransport _transport;
  final Map<String, CrdtSlide> _slides = {};

  // Connection state
  bool _isConnected = false;
  bool _isConnecting = false;
  final List<Collaborator> _collaborators = [];
  final List<Operation> _pendingOperations = [];
  StreamSubscription<Map<String, dynamic>>? _transportSubscription;

  // Callbacks
  Function(Map<String, dynamic>)? _onRemoteChange;
  Function(String, dynamic)? _onCursorMove;
  Function(String)? _onUserJoin;
  Function(String)? _onUserLeave;

  CollaborationService({String? replicaId, CollaborationTransport? transport})
    : this._(
        replicaId ?? _generateReplicaId(),
        transport ?? LocalCollaborationTransport(),
      );

  CollaborationService._(
    String resolvedReplicaId,
    CollaborationTransport transport,
  ) : replicaId = resolvedReplicaId,
      _clock = LamportClock(resolvedReplicaId),
      _transport = transport;

  static String _generateReplicaId() {
    return '${DateTime.now().millisecondsSinceEpoch}_${Random().nextInt(10000)}';
  }

  bool get isConnected => _isConnected;
  bool get isConnecting => _isConnecting;
  List<Collaborator> get collaborators => List.unmodifiable(_collaborators);

  Future<void> connect(String roomId, {String? serverUrl}) async {
    _isConnecting = true;
    notifyListeners();

    try {
      await _transport.connect(roomId, serverUrl: serverUrl);
      _transportSubscription = _transport.messages.listen(handleRemoteMessage);

      _isConnected = true;
      _isConnecting = false;
      notifyListeners();

      // Send join message
      _broadcast({
        'type': 'join',
        'replicaId': replicaId,
        'timestamp': _clock.tick(),
      });
    } catch (e) {
      _isConnecting = false;
      notifyListeners();
      rethrow;
    }
  }

  void disconnect() {
    _broadcast({
      'type': 'leave',
      'replicaId': replicaId,
      'timestamp': _clock.tick(),
    });
    _transportSubscription?.cancel();
    _transportSubscription = null;
    _transport.disconnect();
    _isConnected = false;
    _collaborators.clear();
    notifyListeners();
  }

  void applyLocalOperation(Operation operation) {
    operation.timestamp = _clock.tick();
    operation.replicaId = replicaId;

    _pendingOperations.add(operation);

    // Apply to local state
    _applyOperation(operation);

    // Broadcast to peers
    _broadcast({'type': 'operation', 'operation': operation.toJson()});

    notifyListeners();
  }

  void _applyOperation(Operation operation) {
    switch (operation.type) {
      case OperationType.insertSlide:
        final slide = operation.data['slide'] as CrdtSlide;
        _slides[slide.id] = slide;
        break;
      case OperationType.deleteSlide:
        _slides.remove(operation.targetId);
        break;
      case OperationType.updateSlide:
        final slide = _slides[operation.targetId];
        if (slide != null) {
          slide.merge(operation.data['slide'] as CrdtSlide);
        }
        break;
      case OperationType.insertElement:
        final slide = _slides[operation.targetId];
        final element = operation.data['element'] as CrdtElement;
        if (slide != null) {
          slide.elements.add(element, _clock);
        }
        break;
      case OperationType.deleteElement:
        final slide = _slides[operation.targetId];
        if (slide != null) {
          final index = slide.elements.items.indexWhere(
            (e) => e.id == operation.elementId,
          );
          if (index >= 0) {
            slide.elements.removeAt(index, _clock);
          }
        }
        break;
      case OperationType.updateElement:
        final slide = _slides[operation.targetId];
        if (slide != null) {
          final element = slide.elements.items.firstWhere(
            (e) => e.id == operation.elementId,
            orElse: () => throw Exception('Element not found'),
          );
          element.merge(operation.data['element'] as CrdtElement);
        }
        break;
      case OperationType.moveElement:
        // Element move is handled as update
        break;
      case OperationType.updateCursor:
        _onCursorMove?.call(operation.replicaId!, operation.data);
        break;
    }
  }

  void handleRemoteMessage(Map<String, dynamic> message) {
    final type = message['type'] as String;

    switch (type) {
      case 'join':
        if (message['replicaId'] == replicaId) break;
        final collaborator = Collaborator(
          id: message['replicaId'] as String,
          name: message['name'] as String? ?? 'Anonymous',
          color: _generateUserColor(message['replicaId'] as String),
          cursorPosition: null,
        );
        _collaborators.add(collaborator);
        _onUserJoin?.call(collaborator.id);
        notifyListeners();
        break;

      case 'leave':
        final id = message['replicaId'] as String;
        if (id == replicaId) break;
        _collaborators.removeWhere((c) => c.id == id);
        _onUserLeave?.call(id);
        notifyListeners();
        break;

      case 'operation':
        final operation = _operationFromJson(
          message['operation'] as Map<String, dynamic>,
        );
        if (operation.replicaId == replicaId) break;
        _clock.update(operation.timestamp);
        _applyOperation(operation);
        _onRemoteChange?.call(message);
        notifyListeners();
        break;

      case 'cursor':
        final replicaId = message['replicaId'] as String;
        if (replicaId == this.replicaId) break;
        final position = message['position'] as Map<String, dynamic>;
        _onCursorMove?.call(replicaId, position);
        break;

      case 'sync':
        // Full state sync for new joiners
        final slides = (message['slides'] as List).cast<Map<String, dynamic>>();
        for (final slideData in slides) {
          final remoteSlide = CrdtSlide.fromJson(slideData);
          final localSlide = _slides[remoteSlide.id];
          if (localSlide == null) {
            _slides[remoteSlide.id] = remoteSlide;
          } else {
            localSlide.merge(remoteSlide);
          }
        }
        notifyListeners();
        break;
    }
  }

  Operation _operationFromJson(Map<String, dynamic> json) {
    final operation = Operation.fromJson(json);
    final data = Map<String, dynamic>.from(operation.data);
    final slide = data['slide'];
    if (slide is Map<String, dynamic>) {
      data['slide'] = CrdtSlide.fromJson(slide);
    }
    final element = data['element'];
    if (element is Map<String, dynamic>) {
      data['element'] = CrdtElement.fromJson(element);
    }
    operation.data = data;
    return operation;
  }

  void _broadcast(Map<String, dynamic> message) {
    if (!_isConnected) return;
    _transport.send(message);
  }

  void updateCursor(Offset position, String slideId) {
    _broadcast({
      'type': 'cursor',
      'replicaId': replicaId,
      'position': {'x': position.dx, 'y': position.dy},
      'slideId': slideId,
      'timestamp': _clock.tick(),
    });
  }

  Color _generateUserColor(String id) {
    final hash = id.hashCode;
    return Color.fromARGB(
      255,
      (hash & 0xFF0000) >> 16,
      (hash & 0x00FF00) >> 8,
      hash & 0x0000FF,
    );
  }

  void setOnRemoteChange(Function(Map<String, dynamic>) callback) {
    _onRemoteChange = callback;
  }

  void setOnCursorMove(Function(String, dynamic) callback) {
    _onCursorMove = callback;
  }

  void setOnUserJoin(Function(String) callback) {
    _onUserJoin = callback;
  }

  void setOnUserLeave(Function(String) callback) {
    _onUserLeave = callback;
  }

  @override
  void dispose() {
    _transportSubscription?.cancel();
    _transport.disconnect();
    super.dispose();
  }
}

class Collaborator {
  final String id;
  final String name;
  final Color color;
  Offset? cursorPosition;
  String? currentSlideId;
  bool isActive;
  DateTime lastSeen;

  Collaborator({
    required this.id,
    required this.name,
    required this.color,
    this.cursorPosition,
    this.currentSlideId,
    this.isActive = true,
    DateTime? lastSeen,
  }) : lastSeen = lastSeen ?? DateTime.now();
}

class Operation {
  OperationType type;
  String targetId;
  String? elementId;
  Map<String, dynamic> data;
  int timestamp;
  String? replicaId;

  Operation({
    required this.type,
    required this.targetId,
    this.elementId,
    required this.data,
    this.timestamp = 0,
    this.replicaId,
  });

  Map<String, dynamic> toJson() => {
    'type': type.index,
    'targetId': targetId,
    'elementId': elementId,
    'data': data,
    'timestamp': timestamp,
    'replicaId': replicaId,
  };

  factory Operation.fromJson(Map<String, dynamic> json) => Operation(
    type: OperationType.values[json['type'] as int],
    targetId: json['targetId'] as String,
    elementId: json['elementId'] as String?,
    data: json['data'] as Map<String, dynamic>,
    timestamp: json['timestamp'] as int,
    replicaId: json['replicaId'] as String?,
  );
}

enum OperationType {
  insertSlide,
  deleteSlide,
  updateSlide,
  insertElement,
  deleteElement,
  updateElement,
  moveElement,
  updateCursor,
}

// Presence indicators widget
class PresenceIndicators extends StatelessWidget {
  final List<Collaborator> collaborators;
  final String currentSlideId;

  const PresenceIndicators({
    super.key,
    required this.collaborators,
    required this.currentSlideId,
  });

  @override
  Widget build(BuildContext context) {
    final activeOnSlide = collaborators
        .where((c) => c.currentSlideId == currentSlideId && c.isActive)
        .toList();

    if (activeOnSlide.isEmpty) return const SizedBox.shrink();

    return Positioned(
      top: 16,
      right: 16,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(20),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.1),
              blurRadius: 8,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            ...activeOnSlide.map((c) => _buildAvatar(c)),
            if (activeOnSlide.length > 3)
              Container(
                width: 32,
                height: 32,
                decoration: BoxDecoration(
                  color: Colors.grey[300],
                  shape: BoxShape.circle,
                ),
                child: Center(
                  child: Text(
                    '+${activeOnSlide.length - 3}',
                    style: const TextStyle(fontSize: 12),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildAvatar(Collaborator collaborator) {
    return Tooltip(
      message: collaborator.name,
      child: Container(
        width: 32,
        height: 32,
        margin: const EdgeInsets.only(right: -8),
        decoration: BoxDecoration(
          color: collaborator.color,
          shape: BoxShape.circle,
          border: Border.all(color: Colors.white, width: 2),
        ),
        child: Center(
          child: Text(
            collaborator.name.isNotEmpty
                ? collaborator.name[0].toUpperCase()
                : '?',
            style: const TextStyle(
              color: Colors.white,
              fontSize: 14,
              fontWeight: FontWeight.bold,
            ),
          ),
        ),
      ),
    );
  }
}

// Cursor overlay for remote users
class RemoteCursorOverlay extends StatelessWidget {
  final List<Collaborator> collaborators;

  const RemoteCursorOverlay({super.key, required this.collaborators});

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: collaborators.where((c) => c.cursorPosition != null).map((c) {
        return Positioned(
          left: c.cursorPosition!.dx,
          top: c.cursorPosition!.dy,
          child: _RemoteCursor(collaborator: c),
        );
      }).toList(),
    );
  }
}

class _RemoteCursor extends StatelessWidget {
  final Collaborator collaborator;

  const _RemoteCursor({required this.collaborator});

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(Icons.mouse, color: collaborator.color, size: 20),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
          decoration: BoxDecoration(
            color: collaborator.color,
            borderRadius: BorderRadius.circular(4),
          ),
          child: Text(
            collaborator.name,
            style: const TextStyle(color: Colors.white, fontSize: 10),
          ),
        ),
      ],
    );
  }
}
