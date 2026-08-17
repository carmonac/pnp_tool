import 'dart:io';
import 'dart:isolate';

import 'package:flutter/foundation.dart';
import 'package:image/image.dart' as img;
import 'package:path/path.dart' as p;
import 'package:pnp_core/pnp_core.dart';

/// Wraps the immutable [PnpProject] with mutation methods, dirty tracking,
/// undo/redo (JSON snapshots) and save/load/export.
class ProjectController extends ChangeNotifier {
  PnpProject _project;
  String? _filePath;
  bool _dirty = false;

  final List<String> _undoStack = [];
  final List<String> _redoStack = [];
  List<PagePlan>? _cachedPlans;

  int _selectedPlanIndex = 0;
  String? _selectedItemId;

  ProjectController(this._project);

  factory ProjectController.load(String filePath) {
    final serializer = ProjectSerializer(baseDir: p.dirname(filePath));
    final project = serializer.decode(File(filePath).readAsStringSync());
    return ProjectController(project).._filePath = filePath;
  }

  PnpProject get project => _project;
  String? get filePath => _filePath;
  bool get dirty => _dirty;
  bool get canUndo => _undoStack.isNotEmpty;
  bool get canRedo => _redoStack.isNotEmpty;

  List<PagePlan> get plans => _cachedPlans ??= planProject(_project);

  int get selectedPlanIndex =>
      _selectedPlanIndex.clamp(0, plans.isEmpty ? 0 : plans.length - 1);

  PagePlan? get selectedPlan =>
      plans.isEmpty ? null : plans[selectedPlanIndex];

  String? get selectedItemId => _selectedItemId;

  /// Sheet index (0-based) of the selected plan; used by the freeform editor.
  int get selectedSheetIndex =>
      selectedPlan == null ? 0 : selectedPlan!.sheetNumber - 1;

  bool get selectedPlanIsBack => selectedPlan?.isBackPage ?? false;

  void selectPlan(int index) {
    _selectedPlanIndex = index;
    _selectedItemId = null;
    notifyListeners();
  }

  void selectItem(String? id) {
    _selectedItemId = id;
    notifyListeners();
  }

  // --- Card selection (grid mode, UI state only — not undoable) ----------

  final Set<String> _selectedCardIds = {};
  String? _lastSelectedCardId;

  Set<String> get selectedCardIds => Set.unmodifiable(_selectedCardIds);

  /// Click selection with desktop semantics: plain click selects only the
  /// card, [toggle] (cmd-click) toggles it, [range] (shift-click) extends
  /// from the last clicked card.
  void selectCard(String cardId, {bool toggle = false, bool range = false}) {
    if (range && _lastSelectedCardId != null) {
      final ids = _project.cards.map((c) => c.id).toList();
      final from = ids.indexOf(_lastSelectedCardId!);
      final to = ids.indexOf(cardId);
      if (from != -1 && to != -1) {
        final low = from < to ? from : to;
        final high = from < to ? to : from;
        _selectedCardIds.addAll(ids.sublist(low, high + 1));
        notifyListeners();
        return;
      }
    }
    if (toggle) {
      if (!_selectedCardIds.remove(cardId)) _selectedCardIds.add(cardId);
    } else {
      _selectedCardIds
        ..clear()
        ..add(cardId);
    }
    _lastSelectedCardId = cardId;
    notifyListeners();
  }

  void clearCardSelection() {
    if (_selectedCardIds.isEmpty) return;
    _selectedCardIds.clear();
    _lastSelectedCardId = null;
    notifyListeners();
  }

  void selectAllCards() {
    _selectedCardIds
      ..clear()
      ..addAll(_project.cards.map((c) => c.id));
    notifyListeners();
  }

  /// Points every card in [cardIds] at a global back (null = default/first),
  /// clearing their per-card backs, in a single undo step.
  void setCardsGlobalBack(Set<String> cardIds, String? globalBackId) {
    if (cardIds.isEmpty) return;
    _mutate((project) => project.copyWith(cards: [
          for (final card in project.cards)
            cardIds.contains(card.id)
                ? card.copyWith(backRef: null, globalBackId: globalBackId)
                : card,
        ]));
  }

  /// Removes every card in [cardIds] in a single undo step.
  void removeCards(Set<String> cardIds) {
    if (cardIds.isEmpty) return;
    _mutate((project) => project.copyWith(
        cards:
            project.cards.where((c) => !cardIds.contains(c.id)).toList()));
    _selectedCardIds.removeAll(cardIds);
  }

  // --- Mutations ---------------------------------------------------------

  static const _serializer = ProjectSerializer();

  void _mutate(PnpProject Function(PnpProject) transform) {
    _undoStack.add(_serializer.encode(_project));
    if (_undoStack.length > 100) _undoStack.removeAt(0);
    _redoStack.clear();
    _project = transform(_project);
    _afterChange();
  }

  void _afterChange() {
    _cachedPlans = null;
    _dirty = true;
    notifyListeners();
  }

  void undo() {
    if (_undoStack.isEmpty) return;
    _redoStack.add(_serializer.encode(_project));
    _project = _serializer.decode(_undoStack.removeLast());
    _afterChange();
  }

  void redo() {
    if (_redoStack.isEmpty) return;
    _undoStack.add(_serializer.encode(_project));
    _project = _serializer.decode(_redoStack.removeLast());
    _afterChange();
  }

  void updateSettings({
    double? bleedMm,
    double? spacingMm,
    bool? drawCutLines,
    bool? drawCalibration,
    Object? jpegQuality = _unset,
    FitMode? fitMode,
  }) {
    _mutate((project) => project.copyWith(
          bleedMm: bleedMm,
          spacingMm: spacingMm,
          drawCutLines: drawCutLines,
          drawCalibration: drawCalibration,
          jpegQuality: jpegQuality == _unset ? project.jpegQuality : jpegQuality,
          fitMode: fitMode,
        ));
  }

  static const _unset = Object();

  // Grid mode -------------------------------------------------------------

  void addCards(List<String> paths) {
    if (paths.isEmpty) return;
    _mutate((project) => project.copyWith(cards: [
          ...project.cards,
          for (final path in paths)
            CardItem(
              id: _newId(p.basenameWithoutExtension(path)),
              frontRef: path,
            ),
        ]));
  }

  /// Imports a folder laid out with the `_front`/`_back`/`global_back`
  /// naming convention. Cards are appended; a discovered global back is
  /// added to the project's global back list unless already present.
  Future<void> importFolder(String dir) async {
    final result = await discoverCards(dir, requireBacks: false);
    if (result.cards.isEmpty && result.globalBackRef == null) return;
    _mutate((project) {
      final discoveredBack = result.globalBackRef;
      final alreadyListed = discoveredBack == null ||
          project.globalBacks.any((b) => b.ref == discoveredBack);
      return project.copyWith(
        cards: [
          ...project.cards,
          for (final card in result.cards)
            CardItem(
              id: _newId(card.id),
              frontRef: card.frontRef,
              backRef: card.backRef,
            ),
        ],
        globalBacks: alreadyListed
            ? null
            : [
                ...project.globalBacks,
                GlobalBack(id: _newId('global'), ref: discoveredBack),
              ],
      );
    });
  }

  void setCardBack(String cardId, String? backPath) {
    _mutate((project) => project.copyWith(cards: [
          for (final card in project.cards)
            card.id == cardId ? card.copyWith(backRef: backPath) : card,
        ]));
  }

  void setCardCount(String cardId, int count) {
    if (count < 1) return;
    _mutate((project) => project.copyWith(cards: [
          for (final card in project.cards)
            card.id == cardId ? card.copyWith(count: count) : card,
        ]));
  }

  void removeCard(String cardId) {
    _mutate((project) => project.copyWith(
        cards: project.cards.where((c) => c.id != cardId).toList()));
    _selectedCardIds.remove(cardId);
  }

  /// [newIndex] must already account for the removal at [oldIndex]
  /// (ReorderableListView.onReorderItem semantics).
  void reorderCards(int oldIndex, int newIndex) {
    _mutate((project) {
      final cards = [...project.cards];
      final card = cards.removeAt(oldIndex);
      cards.insert(newIndex, card);
      return project.copyWith(cards: cards);
    });
  }

  /// Adds a global back and returns its id.
  String addGlobalBack(String path) {
    final id = _newId('global');
    _mutate((project) => project.copyWith(globalBacks: [
          ...project.globalBacks,
          GlobalBack(id: id, ref: path),
        ]));
    return id;
  }

  /// Removes a global back; cards that pointed to it fall back to the
  /// default (first) global back.
  void removeGlobalBack(String globalBackId) {
    _mutate((project) => project.copyWith(
          globalBacks: project.globalBacks
              .where((b) => b.id != globalBackId)
              .toList(),
          cards: [
            for (final card in project.cards)
              card.globalBackId == globalBackId
                  ? card.copyWith(globalBackId: null)
                  : card,
          ],
        ));
  }

  /// Points a card at a specific global back (null = default/first).
  /// Clears any per-card back so the choice takes effect.
  void setCardGlobalBack(String cardId, String? globalBackId) {
    _mutate((project) => project.copyWith(cards: [
          for (final card in project.cards)
            card.id == cardId
                ? card.copyWith(backRef: null, globalBackId: globalBackId)
                : card,
        ]));
  }

  // Freeform mode ---------------------------------------------------------

  /// Adds an image to the given sheet, sized from its pixel dimensions at
  /// 300 DPI and clamped to fit the page.
  Future<void> addFreeItem(int sheetIndex, String path) async {
    final size = await _initialSizeFor(path);
    _mutate((project) {
      final pages = [...project.pages];
      while (pages.length <= sheetIndex) {
        pages.add(const FreePage());
      }
      final page = pages[sheetIndex];
      pages[sheetIndex] = page.copyWith(items: [
        ...page.items,
        FreeItem(
          id: _newId(p.basenameWithoutExtension(path)),
          frontRef: path,
          position: PointMm(
            (project.pageSize.width - size.width) / 2,
            (project.pageSize.height - size.height) / 2,
          ),
          size: size,
        ),
      ]);
      return project.copyWith(pages: pages);
    });
  }

  Future<SizeMm> _initialSizeFor(String path) async {
    const dpi = 300.0;
    final maxSize = SizeMm(
        _project.pageSize.width - 20, _project.pageSize.height - 20);
    try {
      final bytes = await File(path).readAsBytes();
      final decoded = img.decodeImage(bytes);
      if (decoded != null) {
        var width = decoded.width / dpi * mmPerInch;
        var height = decoded.height / dpi * mmPerInch;
        final scale = [
          1.0,
          maxSize.width / width,
          maxSize.height / height,
        ].reduce((a, b) => a < b ? a : b);
        return SizeMm(width * scale, height * scale);
      }
    } catch (_) {}
    return const SizeMm(63.5, 88.9);
  }

  /// Pushes one undo snapshot for a whole continuous gesture (drag/resize);
  /// pair with the transient move/resize methods below.
  void beginGesture() {
    _undoStack.add(_serializer.encode(_project));
    if (_undoStack.length > 100) _undoStack.removeAt(0);
    _redoStack.clear();
  }

  /// Transient: mutates without an undo snapshot. Call [beginGesture] first.
  void moveItem(String itemId, PointMm position) =>
      _updateItemTransient(
          itemId,
          (item) =>
              item.copyWith(position: _clampToPage(position, item.size)));

  /// Transient: mutates without an undo snapshot. Call [beginGesture] first.
  void resizeItem(String itemId, PointMm position, SizeMm size) {
    final page = _project.pageSize;
    final clampedSize = SizeMm(
      size.width.clamp(1.0, page.width),
      size.height.clamp(1.0, page.height),
    );
    _updateItemTransient(
        itemId,
        (item) => item.copyWith(
            position: _clampToPage(position, clampedSize),
            size: clampedSize));
  }

  /// Keeps an item of [size] fully inside the page.
  PointMm _clampToPage(PointMm position, SizeMm size) {
    final page = _project.pageSize;
    return PointMm(
      position.x.clamp(0.0, (page.width - size.width).clamp(0.0, page.width)),
      position.y
          .clamp(0.0, (page.height - size.height).clamp(0.0, page.height)),
    );
  }

  void _updateItemTransient(
      String itemId, FreeItem Function(FreeItem) transform) {
    _project = _project.copyWith(pages: [
      for (final page in _project.pages)
        page.copyWith(items: [
          for (final item in page.items)
            item.id == itemId ? transform(item) : item,
        ]),
    ]);
    _afterChange();
  }

  void setItemBack(String itemId, String? backPath) =>
      _updateItem(itemId, (item) => item.copyWith(backRef: backPath));

  void _updateItem(String itemId, FreeItem Function(FreeItem) transform) {
    _mutate((project) => project.copyWith(pages: [
          for (final page in project.pages)
            page.copyWith(items: [
              for (final item in page.items)
                item.id == itemId ? transform(item) : item,
            ]),
        ]));
  }

  void removeItem(String itemId) {
    _mutate((project) => project.copyWith(pages: [
          for (final page in project.pages)
            page.copyWith(
                items: page.items.where((i) => i.id != itemId).toList()),
        ]));
    if (_selectedItemId == itemId) _selectedItemId = null;
  }

  void addPage() {
    _mutate((project) =>
        project.copyWith(pages: [...project.pages, const FreePage()]));
    _selectedPlanIndex = plans.length - 2; // the new front page
  }

  void removePage(int sheetIndex) {
    if (_project.pages.length <= 1) return;
    _mutate((project) {
      final pages = [...project.pages]..removeAt(sheetIndex);
      return project.copyWith(pages: pages);
    });
  }

  FreeItem? findItem(String itemId) {
    for (final page in _project.pages) {
      for (final item in page.items) {
        if (item.id == itemId) return item;
      }
    }
    return null;
  }

  // --- Persistence -------------------------------------------------------

  Future<void> save() async {
    final path = _filePath;
    if (path == null) {
      throw StateError('No file path; use saveAs');
    }
    final serializer = ProjectSerializer(baseDir: p.dirname(path));
    await File(path).writeAsString(serializer.encode(_project));
    _dirty = false;
    notifyListeners();
  }

  Future<void> saveAs(String path) async {
    _filePath = path;
    await save();
  }

  /// Generates the PDF in a background isolate so the UI stays responsive.
  /// Progress events arrive as (page, totalPages).
  Future<Uint8List> exportPdf({
    void Function(int page, int totalPages)? onProgress,
  }) async {
    final json = _serializer.encode(_project);
    final progressPort = ReceivePort();
    final subscription = progressPort.listen((message) {
      if (message is List && message.length == 2 && onProgress != null) {
        onProgress(message[0] as int, message[1] as int);
      }
    });
    final sendPort = progressPort.sendPort;
    try {
      return await Isolate.run(() async {
        final project = _serializer.decode(json);
        return PdfGenerator(
          project: project,
          resolver: const FileImageResolver(),
        ).generate(onProgress: (page, total) => sendPort.send([page, total]));
      });
    } finally {
      await subscription.cancel();
      progressPort.close();
    }
  }

  int _idCounter = 0;

  String _newId(String base) =>
      '${base}_${DateTime.now().millisecondsSinceEpoch}_${_idCounter++}';
}
