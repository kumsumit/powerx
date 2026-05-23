import 'package:flutter/material.dart';
import '../../models/text_styles.dart';

class RichTextEditor extends StatefulWidget {
  final List<RichParagraph> paragraphs;
  final Function(List<RichParagraph>) onChanged;
  final VoidCallback onDone;

  const RichTextEditor({
    super.key,
    required this.paragraphs,
    required this.onChanged,
    required this.onDone,
  });

  @override
  State<RichTextEditor> createState() => _RichTextEditorState();
}

class _RichTextEditorState extends State<RichTextEditor> {
  late List<RichParagraph> _paragraphs;
  int _currentParagraphIndex = 0;
  int _currentRunIndex = 0;
  final TextEditingController _controller = TextEditingController();
  final FocusNode _focusNode = FocusNode();

  @override
  void initState() {
    super.initState();
    _paragraphs = widget.paragraphs.map((p) => p.copyWith()).toList();
    if (_paragraphs.isEmpty) {
      _paragraphs = [const RichParagraph(runs: [TextRun(text: '')])];
    }
    _updateController();
    _focusNode.requestFocus();
  }

  void _updateController() {
    final text = _paragraphs.map((p) => p.plainText).join('\n');
    _controller.text = text;
    _controller.selection = TextSelection.collapsed(offset: text.length);
  }

  void _notifyChange() {
    widget.onChanged(_paragraphs);
  }

  @override
  Widget build(BuildContext context) {
    final currentRun = _paragraphs.isNotEmpty && _paragraphs.first.runs.isNotEmpty
        ? _paragraphs.first.runs.first
        : const TextRun();
    final firstPara = _paragraphs.isNotEmpty ? _paragraphs.first : const RichParagraph();

    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Mini formatting toolbar
        Container(
          height: 36,
          color: Colors.grey[200],
          child: SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: [
                _FormatButton(
                  icon: Icons.format_bold,
                  isActive: currentRun.bold,
                  onTap: () => _toggleFormat(bold: true),
                ),
                _FormatButton(
                  icon: Icons.format_italic,
                  isActive: currentRun.italic,
                  onTap: () => _toggleFormat(italic: true),
                ),
                _FormatButton(
                  icon: Icons.format_underline,
                  isActive: currentRun.underline,
                  onTap: () => _toggleFormat(underline: true),
                ),
                _FormatButton(
                  icon: Icons.format_strikethrough,
                  isActive: currentRun.strikethrough,
                  onTap: () => _toggleFormat(strikethrough: true),
                ),
                const VerticalDivider(width: 1),
                _FormatButton(
                  icon: Icons.format_align_left,
                  isActive: firstPara.style.alignment == TextAlign.left,
                  onTap: () => _setAlignment(TextAlign.left),
                ),
                _FormatButton(
                  icon: Icons.format_align_center,
                  isActive: firstPara.style.alignment == TextAlign.center,
                  onTap: () => _setAlignment(TextAlign.center),
                ),
                _FormatButton(
                  icon: Icons.format_align_right,
                  isActive: firstPara.style.alignment == TextAlign.right,
                  onTap: () => _setAlignment(TextAlign.right),
                ),
                const VerticalDivider(width: 1),
                _FormatButton(
                  icon: Icons.format_list_bulleted,
                  isActive: firstPara.style.bulletType == BulletType.bullet,
                  onTap: () => _setBullet(BulletType.bullet),
                ),
                _FormatButton(
                  icon: Icons.format_list_numbered,
                  isActive: firstPara.style.bulletType == BulletType.number,
                  onTap: () => _setBullet(BulletType.number),
                ),
                const VerticalDivider(width: 1),
                _FontSizeDropdown(
                  value: currentRun.fontSize,
                  onChanged: _setFontSize,
                ),
              ],
            ),
          ),
        ),
        // Text field
        Expanded(
          child: TextField(
            controller: _controller,
            focusNode: _focusNode,
            maxLines: null,
            expands: true,
            decoration: const InputDecoration(
              border: InputBorder.none,
              contentPadding: EdgeInsets.zero,
            ),
            style: TextStyle(
              fontFamily: currentRun.fontFamily,
              fontSize: currentRun.fontSize,
              color: currentRun.color,
              fontWeight: currentRun.bold ? FontWeight.bold : FontWeight.normal,
              fontStyle: currentRun.italic ? FontStyle.italic : FontStyle.normal,
              decoration: currentRun.underline
                  ? TextDecoration.underline
                  : currentRun.strikethrough
                      ? TextDecoration.lineThrough
                      : TextDecoration.none,
            ),
            onChanged: _onTextChanged,
            onEditingComplete: widget.onDone,
          ),
        ),
      ],
    );
  }

  void _toggleFormat({bool? bold, bool? italic, bool? underline, bool? strikethrough}) {
    if (_paragraphs.isEmpty || _paragraphs.first.runs.isEmpty) return;

    final run = _paragraphs.first.runs.first;
    final newRun = run.copyWith(
      bold: bold != null ? !run.bold : null,
      italic: italic != null ? !run.italic : null,
      underline: underline != null ? !run.underline : null,
      strikethrough: strikethrough != null ? !run.strikethrough : null,
    );

    _paragraphs = _paragraphs.map((para) {
      final newRuns = para.runs.map((r) => r.copyWith(
        bold: newRun.bold,
        italic: newRun.italic,
        underline: newRun.underline,
        strikethrough: newRun.strikethrough,
      )).toList();
      return para.copyWith(runs: newRuns);
    }).toList();

    setState(() {});
    _notifyChange();
  }

  void _setAlignment(TextAlign align) {
    _paragraphs = _paragraphs.map((para) {
      return para.copyWith(
        style: para.style.copyWith(alignment: align),
      );
    }).toList();
    setState(() {});
    _notifyChange();
  }

  void _setBullet(BulletType type) {
    _paragraphs = _paragraphs.map((para) {
      return para.copyWith(
        style: para.style.copyWith(
          bulletType: para.style.bulletType == type ? BulletType.none : type,
        ),
      );
    }).toList();
    setState(() {});
    _notifyChange();
  }

  void _setFontSize(double? size) {
    if (size == null) return;
    _paragraphs = _paragraphs.map((para) {
      final newRuns = para.runs.map((r) => r.copyWith(fontSize: size)).toList();
      return para.copyWith(runs: newRuns);
    }).toList();
    setState(() {});
    _notifyChange();
  }

  void _onTextChanged(String text) {
    final lines = text.split('\n');
    final baseRun = _paragraphs.isNotEmpty && _paragraphs.first.runs.isNotEmpty
        ? _paragraphs.first.runs.first
        : const TextRun();
    final baseStyle = _paragraphs.isNotEmpty ? _paragraphs.first.style : const ParagraphStyle();

    _paragraphs = lines.map((line) {
      return RichParagraph(
        runs: [baseRun.copyWith(text: line)],
        style: baseStyle,
      );
    }).toList();
    _notifyChange();
  }

  @override
  void dispose() {
    _controller.dispose();
    _focusNode.dispose();
    super.dispose();
  }
}

class _FormatButton extends StatelessWidget {
  final IconData icon;
  final bool isActive;
  final VoidCallback onTap;

  const _FormatButton({required this.icon, required this.isActive, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      child: Container(
        width: 32,
        height: 32,
        decoration: BoxDecoration(
          color: isActive ? const Color(0xFFB7472A) : Colors.transparent,
          borderRadius: BorderRadius.circular(4),
        ),
        child: Icon(icon, size: 18, color: isActive ? Colors.white : Colors.black87),
      ),
    );
  }
}

class _FontSizeDropdown extends StatelessWidget {
  final double value;
  final Function(double?) onChanged;

  const _FontSizeDropdown({required this.value, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 60,
      child: DropdownButtonHideUnderline(
        child: DropdownButton<double>(
          value: value,
          isDense: true,
          items: [8, 9, 10, 11, 12, 14, 16, 18, 20, 22, 24, 28, 32, 36, 40, 44, 48, 54, 60, 66, 72, 80, 96]
              .map((s) => DropdownMenuItem(value: s.toDouble(), child: Text('$s')))
              .toList(),
          onChanged: onChanged,
        ),
      ),
    );
  }
}
