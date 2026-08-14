import 'dart:async';

import 'package:flutter/material.dart';

import '../models/comm_tile.dart';
import '../models/pictogram.dart';
import '../services/arasaac_service.dart';
import '../theme/app_theme.dart';
import '../theme/tile_icons.dart';
import '../theme/tile_themes.dart';
import 'tile_glyph.dart';

/// The values collected by the editor. The page turns this into an add or an
/// update on [TileState].
class TileDraft {
  const TileDraft({
    required this.label,
    required this.ttsPhrase,
    required this.icon,
    required this.colorTheme,
    this.imageUrl,
  });

  final String label;
  final String ttsPhrase;
  final IconData icon;
  final String colorTheme;

  /// The chosen ARASAAC pictogram, or null to use [icon].
  final String? imageUrl;
}

/// How the tile's picture is chosen.
enum _GlyphMode { icon, symbol }

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
  final TextEditingController _searchController = TextEditingController();

  late IconData _icon;
  late String _colorTheme;
  String? _imageUrl;
  late _GlyphMode _mode;

  final ArasaacService _arasaac = ArasaacService();
  Timer? _debounce;
  List<Pictogram> _results = <Pictogram>[];
  bool _searching = false;
  bool _hasSearched = false;
  String? _searchError;

  bool get _isEditing => widget.existing != null;

  /// The picture that will actually be saved: a pictogram only while the
  /// symbol tab is active, otherwise the icon.
  String? get _effectiveImageUrl =>
      _mode == _GlyphMode.symbol ? _imageUrl : null;

  @override
  void initState() {
    super.initState();
    final CommTile? tile = widget.existing;
    _labelController = TextEditingController(text: tile?.label ?? '');
    _phraseController = TextEditingController(text: tile?.ttsPhrase ?? '');
    _icon = tile?.icon ?? kTileIconChoices.first;
    _colorTheme = tile?.colorTheme ?? kTileColorChoices.first;
    _imageUrl = tile?.imageUrl;
    _mode = tile?.imageUrl != null ? _GlyphMode.symbol : _GlyphMode.icon;
    _labelController.addListener(() => setState(() {}));
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _labelController.dispose();
    _phraseController.dispose();
    _searchController.dispose();
    _arasaac.dispose();
    super.dispose();
  }

  bool get _canSave => _labelController.text.trim().isNotEmpty;

  void _onSearchChanged(String value) {
    // Debounce so we search once the caregiver pauses, not on every keystroke.
    _debounce?.cancel();
    _debounce = Timer(
      const Duration(milliseconds: 450),
      () => _runSearch(value),
    );
  }

  Future<void> _runSearch(String query) async {
    final String trimmed = query.trim();
    if (trimmed.isEmpty) {
      setState(() {
        _results = <Pictogram>[];
        _hasSearched = false;
        _searchError = null;
        _searching = false;
      });
      return;
    }

    setState(() {
      _searching = true;
      _searchError = null;
    });

    try {
      final List<Pictogram> found = await _arasaac.searchPictograms(trimmed);
      if (!mounted) return;
      setState(() {
        _results = found;
        _hasSearched = true;
        _searching = false;
      });
    } on ArasaacException catch (e) {
      if (!mounted) return;
      setState(() {
        _searchError = e.message;
        _searching = false;
      });
    }
  }

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
        imageUrl: _effectiveImageUrl,
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
                      padding: EdgeInsets.all(
                        _effectiveImageUrl != null ? 7 : 0,
                      ),
                      decoration: BoxDecoration(
                        color: _effectiveImageUrl != null
                            ? Colors.white
                            : accent.withValues(alpha: 0.14),
                        borderRadius: BorderRadius.circular(16),
                      ),
                      child: TileGlyph(
                        imageUrl: _effectiveImageUrl,
                        icon: _icon,
                        iconSize: 28,
                        color: accent,
                      ),
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
                _FieldLabel('Picture', c),
                const SizedBox(height: 10),
                _ModeToggle(
                  mode: _mode,
                  colors: c,
                  onChanged: (_GlyphMode m) => setState(() => _mode = m),
                ),
                const SizedBox(height: 12),
                if (_mode == _GlyphMode.icon)
                  _IconPicker(
                    selected: _icon,
                    accent: accent,
                    colors: c,
                    onSelected: (IconData icon) => setState(() => _icon = icon),
                  )
                else
                  _SymbolSearch(
                    controller: _searchController,
                    colors: c,
                    accent: accent,
                    results: _results,
                    searching: _searching,
                    hasSearched: _hasSearched,
                    error: _searchError,
                    selectedUrl: _imageUrl,
                    onChanged: _onSearchChanged,
                    onPicked: (Pictogram p) =>
                        setState(() => _imageUrl = p.imageUrl),
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

class _ModeToggle extends StatelessWidget {
  const _ModeToggle({
    required this.mode,
    required this.colors,
    required this.onChanged,
  });

  final _GlyphMode mode;
  final EchoColors colors;
  final ValueChanged<_GlyphMode> onChanged;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: colors.surfaceHigh,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: colors.border),
      ),
      child: Row(
        children: <Widget>[
          _segment('Icon', Icons.category_rounded, _GlyphMode.icon),
          _segment(
            'Search symbol',
            Icons.image_search_rounded,
            _GlyphMode.symbol,
          ),
        ],
      ),
    );
  }

  Widget _segment(String label, IconData icon, _GlyphMode value) {
    final bool active = mode == value;
    return Expanded(
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: () => onChanged(value),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 9),
          decoration: BoxDecoration(
            color: active ? colors.accent : Colors.transparent,
            borderRadius: BorderRadius.circular(9),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: <Widget>[
              Icon(icon, size: 17, color: active ? Colors.white : colors.muted),
              const SizedBox(width: 7),
              Text(
                label,
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: active ? Colors.white : colors.muted,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _SymbolSearch extends StatelessWidget {
  const _SymbolSearch({
    required this.controller,
    required this.colors,
    required this.accent,
    required this.results,
    required this.searching,
    required this.hasSearched,
    required this.error,
    required this.selectedUrl,
    required this.onChanged,
    required this.onPicked,
  });

  final TextEditingController controller;
  final EchoColors colors;
  final Color accent;
  final List<Pictogram> results;
  final bool searching;
  final bool hasSearched;
  final String? error;
  final String? selectedUrl;
  final ValueChanged<String> onChanged;
  final ValueChanged<Pictogram> onPicked;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        TextField(
          controller: controller,
          onChanged: onChanged,
          textInputAction: TextInputAction.search,
          style: TextStyle(color: colors.text, fontSize: 15),
          cursorColor: colors.accent,
          decoration: InputDecoration(
            hintText: 'Search AAC symbols, e.g. water',
            hintStyle: TextStyle(color: colors.muted, fontSize: 14),
            prefixIcon: Icon(Icons.search_rounded, color: colors.muted),
            filled: true,
            fillColor: colors.surfaceHigh,
            contentPadding: const EdgeInsets.symmetric(vertical: 12),
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
        ),
        const SizedBox(height: 10),
        Container(
          height: 190,
          decoration: BoxDecoration(
            color: colors.surfaceHigh,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: colors.border),
          ),
          clipBehavior: Clip.antiAlias,
          child: _buildBody(),
        ),
        const SizedBox(height: 6),
        Text(
          'Symbols from ARASAAC (arasaac.org) · free AAC pictograms',
          style: TextStyle(fontSize: 11, color: colors.muted),
        ),
      ],
    );
  }

  Widget _buildBody() {
    if (searching) {
      return Center(
        child: SizedBox(
          width: 26,
          height: 26,
          child: CircularProgressIndicator(strokeWidth: 2.5, color: accent),
        ),
      );
    }
    if (error != null) {
      return _message(Icons.wifi_off_rounded, error!);
    }
    if (results.isEmpty) {
      return _message(
        hasSearched ? Icons.search_off_rounded : Icons.image_search_rounded,
        hasSearched
            ? 'No symbols found. Try another word.'
            : 'Type a word to find communication symbols.',
      );
    }

    return GridView.count(
      crossAxisCount: 4,
      padding: const EdgeInsets.all(8),
      mainAxisSpacing: 8,
      crossAxisSpacing: 8,
      children: results.map((Pictogram p) {
        final bool selected = p.imageUrl == selectedUrl;
        return GestureDetector(
          onTap: () => onPicked(p),
          child: Container(
            padding: const EdgeInsets.all(5),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(11),
              border: Border.all(
                color: selected ? accent : colors.border,
                width: selected ? 2.4 : 1,
              ),
            ),
            child: Image.network(
              p.imageUrl,
              fit: BoxFit.contain,
              gaplessPlayback: true,
              loadingBuilder:
                  (BuildContext context, Widget child, ImageChunkEvent? prog) {
                    if (prog == null) return child;
                    return Center(
                      child: SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: colors.muted,
                        ),
                      ),
                    );
                  },
              errorBuilder: (_, _, _) =>
                  Icon(Icons.broken_image_rounded, color: colors.muted),
            ),
          ),
        );
      }).toList(),
    );
  }

  Widget _message(IconData icon, String text) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            Icon(icon, color: colors.muted, size: 30),
            const SizedBox(height: 10),
            Text(
              text,
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 13, color: colors.muted, height: 1.4),
            ),
          ],
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
