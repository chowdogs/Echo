import 'package:flutter/material.dart';

import '../models/comm_tile.dart';
import '../theme/app_theme.dart';
import '../theme/tile_icons.dart';
import '../theme/tile_themes.dart';

/// The values collected by the editor. The page turns this into an add or an
/// update on [TileState].
class TileDraft {
  const TileDraft({
    required this.label,
    required this.ttsPhrase,
    required this.icon,
    required this.colorTheme,
  });

  final String label;
  final String ttsPhrase;
  final IconData icon;
  final String colorTheme;
}

/// Opens the add/edit sheet. Returns the draft on save, or null if dismissed.
///
/// One sheet serves both jobs: pass [existing] to edit it, omit it to create.
Future<TileDraft?> showTileEditor(BuildContext context, {CommTile? existing}) {
  return showModalBottomSheet<TileDraft>(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (BuildContext context) => _TileEditorSheet(existing: existing),
  );
}

class _TileEditorSheet extends StatefulWidget {
  const _TileEditorSheet({this.existing});

  final CommTile? existing;

  @override
  State<_TileEditorSheet> createState() => _TileEditorSheetState();
}

class _TileEditorSheetState extends State<_TileEditorSheet> {
  late final TextEditingController _labelController;
  late final TextEditingController _phraseController;
  late IconData _icon;
  late String _colorTheme;

  bool get _isEditing => widget.existing != null;

  @override
  void initState() {
    super.initState();
    final CommTile? tile = widget.existing;
    _labelController = TextEditingController(text: tile?.label ?? '');
    _phraseController = TextEditingController(text: tile?.ttsPhrase ?? '');
    _icon = tile?.icon ?? kTileIconChoices.first;
    _colorTheme = tile?.colorTheme ?? kTileColorChoices.first;
    _labelController.addListener(() => setState(() {}));
  }

  @override
  void dispose() {
    _labelController.dispose();
    _phraseController.dispose();
    super.dispose();
  }

  bool get _canSave => _labelController.text.trim().isNotEmpty;

  void _save() {
    final String label = _labelController.text.trim();
    final String phrase = _phraseController.text.trim();
    Navigator.of(context).pop(
      TileDraft(
        label: label,
        // Fall back to the label so a tile always says something.
        ttsPhrase: phrase.isEmpty ? label : phrase,
        icon: _icon,
        colorTheme: _colorTheme,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final EchoColors c = EchoColors.of(context);
    final Color accent = tileAccentFor(_colorTheme);

    return Padding(
      // Lift the sheet above the keyboard when a field is focused.
      padding: EdgeInsets.only(bottom: MediaQuery.viewInsetsOf(context).bottom),
      child: Container(
        decoration: BoxDecoration(
          color: c.surface,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
          border: Border.all(color: c.border),
        ),
        child: SafeArea(
          top: false,
          child: SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(20, 12, 20, 20),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Center(
                  child: Container(
                    width: 40,
                    height: 4,
                    decoration: BoxDecoration(
                      color: c.border,
                      borderRadius: BorderRadius.circular(999),
                    ),
                  ),
                ),
                const SizedBox(height: 18),
                // Live preview of the tile being built.
                Row(
                  children: <Widget>[
                    Container(
                      width: 56,
                      height: 56,
                      decoration: BoxDecoration(
                        color: accent.withValues(alpha: 0.14),
                        borderRadius: BorderRadius.circular(16),
                      ),
                      child: Icon(_icon, color: accent, size: 28),
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Text(
                        _isEditing ? 'Edit tile' : 'New tile',
                        style: const TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.w700,
                          letterSpacing: -0.4,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 22),
                _FieldLabel('Label', c),
                const SizedBox(height: 8),
                _EchoField(
                  controller: _labelController,
                  hint: 'e.g. Water',
                  colors: c,
                  textCapitalization: TextCapitalization.sentences,
                  maxLength: 24,
                ),
                const SizedBox(height: 16),
                _FieldLabel('Spoken phrase', c),
                const SizedBox(height: 8),
                _EchoField(
                  controller: _phraseController,
                  hint: 'What Echo says out loud (defaults to the label)',
                  colors: c,
                  textCapitalization: TextCapitalization.sentences,
                  maxLines: 2,
                ),
                const SizedBox(height: 20),
                _FieldLabel('Icon', c),
                const SizedBox(height: 10),
                _IconPicker(
                  selected: _icon,
                  accent: accent,
                  colors: c,
                  onSelected: (IconData icon) => setState(() => _icon = icon),
                ),
                const SizedBox(height: 20),
                _FieldLabel('Colour', c),
                const SizedBox(height: 10),
                _ColorPicker(
                  selected: _colorTheme,
                  colors: c,
                  onSelected: (String key) => setState(() => _colorTheme = key),
                ),
                const SizedBox(height: 26),
                Row(
                  children: <Widget>[
                    Expanded(
                      child: _SheetButton(
                        label: 'Cancel',
                        filled: false,
                        colors: c,
                        onTap: () => Navigator.of(context).pop(),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: _SheetButton(
                        key: const Key('tile-save'),
                        label: _isEditing ? 'Save' : 'Add tile',
                        filled: true,
                        colors: c,
                        onTap: _canSave ? _save : null,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _FieldLabel extends StatelessWidget {
  const _FieldLabel(this.text, this.colors);

  final String text;
  final EchoColors colors;

  @override
  Widget build(BuildContext context) {
    return Text(
      text.toUpperCase(),
      style: TextStyle(
        fontSize: 11.5,
        fontWeight: FontWeight.w700,
        letterSpacing: 1.2,
        color: colors.muted,
      ),
    );
  }
}

class _EchoField extends StatelessWidget {
  const _EchoField({
    required this.controller,
    required this.hint,
    required this.colors,
    this.maxLines = 1,
    this.maxLength,
    this.textCapitalization = TextCapitalization.none,
  });

  final TextEditingController controller;
  final String hint;
  final EchoColors colors;
  final int maxLines;
  final int? maxLength;
  final TextCapitalization textCapitalization;

  @override
  Widget build(BuildContext context) {
    return TextField(
      controller: controller,
      maxLines: maxLines,
      maxLength: maxLength,
      textCapitalization: textCapitalization,
      style: TextStyle(color: colors.text, fontSize: 15),
      cursorColor: colors.accent,
      decoration: InputDecoration(
        hintText: hint,
        hintStyle: TextStyle(color: colors.muted, fontSize: 14),
        filled: true,
        fillColor: colors.surfaceHigh,
        counterText: '',
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 14,
          vertical: 12,
        ),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide(color: colors.border),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide(color: colors.border),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide(color: colors.accent, width: 1.6),
        ),
      ),
    );
  }
}

class _IconPicker extends StatelessWidget {
  const _IconPicker({
    required this.selected,
    required this.accent,
    required this.colors,
    required this.onSelected,
  });

  final IconData selected;
  final Color accent;
  final EchoColors colors;
  final ValueChanged<IconData> onSelected;

  @override
  Widget build(BuildContext context) {
    // A bounded, scrollable pane so the long icon list never dominates the
    // sheet.
    return Container(
      height: 168,
      decoration: BoxDecoration(
        color: colors.surfaceHigh,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: colors.border),
      ),
      padding: const EdgeInsets.all(8),
      child: GridView.count(
        crossAxisCount: 6,
        mainAxisSpacing: 6,
        crossAxisSpacing: 6,
        children: kTileIconChoices.map((IconData icon) {
          final bool isSelected = icon == selected;
          return GestureDetector(
            onTap: () => onSelected(icon),
            child: Container(
              decoration: BoxDecoration(
                color: isSelected
                    ? accent.withValues(alpha: 0.16)
                    : colors.surface,
                borderRadius: BorderRadius.circular(11),
                border: Border.all(
                  color: isSelected ? accent : colors.border,
                  width: isSelected ? 1.6 : 1,
                ),
              ),
              child: Icon(
                icon,
                size: 22,
                color: isSelected ? accent : colors.muted,
              ),
            ),
          );
        }).toList(),
      ),
    );
  }
}

class _ColorPicker extends StatelessWidget {
  const _ColorPicker({
    required this.selected,
    required this.colors,
    required this.onSelected,
  });

  final String selected;
  final EchoColors colors;
  final ValueChanged<String> onSelected;

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: 12,
      runSpacing: 12,
      children: kTileColorChoices.map((String key) {
        final Color color = tileAccentFor(key);
        final bool isSelected = key == selected;
        return GestureDetector(
          onTap: () => onSelected(key),
          child: Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: color,
              shape: BoxShape.circle,
              border: Border.all(
                color: isSelected ? colors.text : Colors.transparent,
                width: 3,
              ),
            ),
            child: isSelected
                ? const Icon(Icons.check_rounded, size: 20, color: Colors.white)
                : null,
          ),
        );
      }).toList(),
    );
  }
}

class _SheetButton extends StatelessWidget {
  const _SheetButton({
    super.key,
    required this.label,
    required this.filled,
    required this.colors,
    required this.onTap,
  });

  final String label;
  final bool filled;
  final EchoColors colors;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final bool disabled = onTap == null;

    return GestureDetector(
      onTap: onTap,
      child: Container(
        height: 52,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: filled
              ? (disabled ? colors.surfaceHigh : colors.accent)
              : colors.surfaceHigh,
          borderRadius: BorderRadius.circular(15),
          border: filled ? null : Border.all(color: colors.border),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 15,
            fontWeight: FontWeight.w700,
            color: filled
                ? (disabled ? colors.muted : Colors.white)
                : colors.text,
          ),
        ),
      ),
    );
  }
}
