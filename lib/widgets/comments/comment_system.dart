import 'package:flutter/material.dart';

class Comment {
  final String id;
  final String author;
  final String authorInitials;
  final Color authorColor;
  final String text;
  final DateTime timestamp;
  final Offset? position;
  final String? slideId;
  final String? elementId;
  final String? parentCommentId;
  final List<Comment> replies;
  final bool isResolved;
  final DateTime? resolvedAt;
  final String? resolvedBy;

  Comment({
    required this.id,
    required this.author,
    required this.authorInitials,
    required this.authorColor,
    required this.text,
    required this.timestamp,
    this.position,
    this.slideId,
    this.elementId,
    this.parentCommentId,
    this.replies = const [],
    this.isResolved = false,
    this.resolvedAt,
    this.resolvedBy,
  });

  Comment copyWith({
    String? text,
    List<Comment>? replies,
    bool? isResolved,
    DateTime? resolvedAt,
    String? resolvedBy,
  }) => Comment(
    id: id,
    author: author,
    authorInitials: authorInitials,
    authorColor: authorColor,
    text: text ?? this.text,
    timestamp: timestamp,
    position: position,
    slideId: slideId,
    elementId: elementId,
    parentCommentId: parentCommentId,
    replies: replies ?? this.replies,
    isResolved: isResolved ?? this.isResolved,
    resolvedAt: resolvedAt ?? this.resolvedAt,
    resolvedBy: resolvedBy ?? this.resolvedBy,
  );
}

class CommentThread {
  final Comment rootComment;
  final List<Comment> replies;
  final Rect? anchorRect;

  CommentThread({
    required this.rootComment,
    this.replies = const [],
    this.anchorRect,
  });

  List<Comment> get allComments => [rootComment, ...replies];
  bool get isResolved => rootComment.isResolved;
  int get totalCount => 1 + replies.length;
}

class CommentManager extends ChangeNotifier {
  final List<CommentThread> _threads = [];
  String? _activeThreadId;
  bool _showComments = true;
  bool _showResolved = false;

  List<CommentThread> get threads => _threads;
  List<CommentThread> get unresolvedThreads =>
      _threads.where((t) => !t.isResolved).toList();
  List<CommentThread> get visibleThreads =>
      _showResolved ? _threads : unresolvedThreads;
  String? get activeThreadId => _activeThreadId;
  bool get showComments => _showComments;
  bool get showResolved => _showResolved;

  void addThread(Comment comment, {Rect? anchorRect}) {
    _threads.add(CommentThread(
      rootComment: comment,
      anchorRect: anchorRect,
    ));
    notifyListeners();
  }

  void addReply(String threadId, Comment reply) {
    final index = _threads.indexWhere((t) => t.rootComment.id == threadId);
    if (index >= 0) {
      final thread = _threads[index];
      _threads[index] = CommentThread(
        rootComment: thread.rootComment,
        replies: [...thread.replies, reply],
        anchorRect: thread.anchorRect,
      );
      notifyListeners();
    }
  }

  void resolveThread(String threadId, {required String resolvedBy}) {
    final index = _threads.indexWhere((t) => t.rootComment.id == threadId);
    if (index >= 0) {
      final thread = _threads[index];
      _threads[index] = CommentThread(
        rootComment: thread.rootComment.copyWith(
          isResolved: true,
          resolvedAt: DateTime.now(),
          resolvedBy: resolvedBy,
        ),
        replies: thread.replies,
        anchorRect: thread.anchorRect,
      );
      notifyListeners();
    }
  }

  void deleteThread(String threadId) {
    _threads.removeWhere((t) => t.rootComment.id == threadId);
    notifyListeners();
  }

  void setActiveThread(String? id) {
    _activeThreadId = id;
    notifyListeners();
  }

  void toggleComments() {
    _showComments = !_showComments;
    notifyListeners();
  }

  void toggleResolved() {
    _showResolved = !_showResolved;
    notifyListeners();
  }

  List<CommentThread> getThreadsForSlide(String slideId) {
    return _threads.where((t) => t.rootComment.slideId == slideId).toList();
  }

  List<CommentThread> getThreadsForElement(String elementId) {
    return _threads.where((t) => t.rootComment.elementId == elementId).toList();
  }
}

class CommentOverlay extends StatelessWidget {
  final CommentManager manager;
  final String currentSlideId;
  final Function(Offset) onAddComment;
  final Function(String, String) onReply;
  final Function(String) onResolve;
  final Function(String) onDelete;

  const CommentOverlay({
    super.key,
    required this.manager,
    required this.currentSlideId,
    required this.onAddComment,
    required this.onReply,
    required this.onResolve,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    if (!manager.showComments) return const SizedBox.shrink();

    final threads = manager.getThreadsForSlide(currentSlideId);

    return Stack(
      children: [
        // Comment indicators on canvas
        ...threads.where((t) => t.anchorRect != null).map((thread) {
          return Positioned.fromRect(
            rect: thread.anchorRect!,
            child: _CommentIndicator(
              thread: thread,
              isActive: manager.activeThreadId == thread.rootComment.id,
              onTap: () => manager.setActiveThread(thread.rootComment.id),
            ),
          );
        }),

        // Comment panel
        if (manager.activeThreadId != null)
          _CommentPanel(
            thread: threads.firstWhere(
              (t) => t.rootComment.id == manager.activeThreadId,
            ),
            onReply: (text) => onReply(manager.activeThreadId!, text),
            onResolve: () => onResolve(manager.activeThreadId!),
            onDelete: () => onDelete(manager.activeThreadId!),
            onClose: () => manager.setActiveThread(null),
          ),
      ],
    );
  }
}

class _CommentIndicator extends StatelessWidget {
  final CommentThread thread;
  final bool isActive;
  final VoidCallback onTap;

  const _CommentIndicator({
    required this.thread,
    required this.isActive,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 24,
        height: 24,
        decoration: BoxDecoration(
          color: thread.isResolved ? Colors.green : thread.rootComment.authorColor,
          shape: BoxShape.circle,
          border: Border.all(color: Colors.white, width: 2),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.2),
              blurRadius: 4,
            ),
          ],
        ),
        child: Center(
          child: Text(
            '${thread.totalCount}',
            style: const TextStyle(
              color: Colors.white,
              fontSize: 10,
              fontWeight: FontWeight.bold,
            ),
          ),
        ),
      ),
    );
  }
}

class _CommentPanel extends StatelessWidget {
  final CommentThread thread;
  final Function(String) onReply;
  final VoidCallback onResolve;
  final VoidCallback onDelete;
  final VoidCallback onClose;

  const _CommentPanel({
    required this.thread,
    required this.onReply,
    required this.onResolve,
    required this.onDelete,
    required this.onClose,
  });

  @override
  Widget build(BuildContext context) {
    return Positioned(
      right: 20,
      top: 80,
      width: 320,
      child: Material(
        elevation: 8,
        borderRadius: BorderRadius.circular(8),
        child: Container(
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(8),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: thread.isResolved ? Colors.green[50] : Colors.blue[50],
                  borderRadius: const BorderRadius.vertical(top: Radius.circular(8)),
                ),
                child: Row(
                  children: [
                    CircleAvatar(
                      backgroundColor: thread.rootComment.authorColor,
                      radius: 14,
                      child: Text(
                        thread.rootComment.authorInitials,
                        style: const TextStyle(color: Colors.white, fontSize: 10),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            thread.rootComment.author,
                            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                          ),
                          Text(
                            _formatTime(thread.rootComment.timestamp),
                            style: TextStyle(fontSize: 11, color: Colors.grey[600]),
                          ),
                        ],
                      ),
                    ),
                    if (thread.isResolved)
                      Chip(
                        label: const Text('Resolved', style: TextStyle(fontSize: 10)),
                        backgroundColor: Colors.green[100],
                        padding: EdgeInsets.zero,
                      ),
                    IconButton(
                      icon: const Icon(Icons.close, size: 18),
                      onPressed: onClose,
                      padding: EdgeInsets.zero,
                      constraints: const BoxConstraints(),
                    ),
                  ],
                ),
              ),

              // Comments
              Flexible(
                child: ListView.builder(
                  shrinkWrap: true,
                  padding: const EdgeInsets.all(12),
                  itemCount: thread.allComments.length,
                  itemBuilder: (context, index) {
                    final comment = thread.allComments[index];
                    return _CommentBubble(comment: comment);
                  },
                ),
              ),

              // Actions
              if (!thread.isResolved)
                Padding(
                  padding: const EdgeInsets.all(12),
                  child: Column(
                    children: [
                      TextField(
                        decoration: const InputDecoration(
                          hintText: 'Add a reply...',
                          border: OutlineInputBorder(),
                          contentPadding: EdgeInsets.all(8),
                        ),
                        maxLines: 2,
                        onSubmitted: onReply,
                      ),
                      const SizedBox(height: 8),
                      Row(
                        children: [
                          TextButton.icon(
                            onPressed: onResolve,
                            icon: const Icon(Icons.check_circle, size: 18),
                            label: const Text('Resolve'),
                          ),
                          const Spacer(),
                          TextButton.icon(
                            onPressed: onDelete,
                            icon: const Icon(Icons.delete, size: 18, color: Colors.red),
                            label: const Text('Delete', style: TextStyle(color: Colors.red)),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }

  String _formatTime(DateTime time) {
    final now = DateTime.now();
    final diff = now.difference(time);
    if (diff.inMinutes < 1) return 'Just now';
    if (diff.inHours < 1) return '${diff.inMinutes}m ago';
    if (diff.inDays < 1) return '${diff.inHours}h ago';
    return '${time.month}/${time.day}/${time.year}';
  }
}

class _CommentBubble extends StatelessWidget {
  final Comment comment;

  const _CommentBubble({required this.comment});

  @override
  Widget build(BuildContext context) {
    final isReply = comment.parentCommentId != null;

    return Padding(
      padding: EdgeInsets.only(left: isReply ? 24 : 0, bottom: 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (isReply)
            CircleAvatar(
              backgroundColor: comment.authorColor,
              radius: 12,
              child: Text(
                comment.authorInitials,
                style: const TextStyle(color: Colors.white, fontSize: 9),
              ),
            ),
          const SizedBox(width: 8),
          Expanded(
            child: Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: Colors.grey[100],
                borderRadius: BorderRadius.circular(8),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (isReply)
                    Text(
                      comment.author,
                      style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12),
                    ),
                  Text(comment.text),
                  const SizedBox(height: 4),
                  Text(
                    _formatTime(comment.timestamp),
                    style: TextStyle(fontSize: 10, color: Colors.grey[600]),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  String _formatTime(DateTime time) {
    final now = DateTime.now();
    final diff = now.difference(time);
    if (diff.inMinutes < 1) return 'Just now';
    if (diff.inHours < 1) return '${diff.inMinutes}m ago';
    if (diff.inDays < 1) return '${diff.inHours}h ago';
    return '${time.month}/${time.day}/${time.year}';
  }
}

// Comment sidebar for slide-level comments
class CommentSidebar extends StatelessWidget {
  final CommentManager manager;
  final String currentSlideId;
  final Function(String, String) onReply;
  final Function(String) onResolve;
  final Function(String) onDelete;

  const CommentSidebar({
    super.key,
    required this.manager,
    required this.currentSlideId,
    required this.onReply,
    required this.onResolve,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    final threads = manager.getThreadsForSlide(currentSlideId);

    return Container(
      width: 300,
      color: Colors.grey[50],
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              border: Border(bottom: BorderSide(color: Colors.grey[300]!)),
            ),
            child: Row(
              children: [
                Text(
                  'Comments (${threads.length})',
                  style: const TextStyle(fontWeight: FontWeight.bold),
                ),
                const Spacer(),
                TextButton(
                  onPressed: manager.toggleResolved,
                  child: Text(manager.showResolved ? 'Hide Resolved' : 'Show Resolved'),
                ),
              ],
            ),
          ),
          Expanded(
            child: ListView.builder(
              itemCount: threads.length,
              itemBuilder: (context, index) {
                final thread = threads[index];
                return _ThreadCard(
                  thread: thread,
                  onTap: () => manager.setActiveThread(thread.rootComment.id),
                  onReply: (text) => onReply(thread.rootComment.id, text),
                  onResolve: () => onResolve(thread.rootComment.id),
                  onDelete: () => onDelete(thread.rootComment.id),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

class _ThreadCard extends StatelessWidget {
  final CommentThread thread;
  final VoidCallback onTap;
  final Function(String) onReply;
  final VoidCallback onResolve;
  final VoidCallback onDelete;

  const _ThreadCard({
    required this.thread,
    required this.onTap,
    required this.onReply,
    required this.onResolve,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.all(8),
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  CircleAvatar(
                    backgroundColor: thread.rootComment.authorColor,
                    radius: 14,
                    child: Text(
                      thread.rootComment.authorInitials,
                      style: const TextStyle(color: Colors.white, fontSize: 10),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      thread.rootComment.author,
                      style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                    ),
                  ),
                  if (thread.isResolved)
                    Icon(Icons.check_circle, color: Colors.green[600], size: 18),
                ],
              ),
              const SizedBox(height: 8),
              Text(
                thread.rootComment.text,
                maxLines: 3,
                overflow: TextOverflow.ellipsis,
              ),
              if (thread.replies.isNotEmpty)
                Padding(
                  padding: const EdgeInsets.only(top: 8),
                  child: Text(
                    '${thread.replies.length} ${thread.replies.length == 1 ? 'reply' : 'replies'}',
                    style: TextStyle(fontSize: 12, color: Colors.grey[600]),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}
