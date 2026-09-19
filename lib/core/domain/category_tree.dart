import '../models/category.dart';

/// A [Category] placed inside the tree, with its resolved depth and children.
class CategoryNode {
  final Category category;
  final int depth;
  final List<CategoryNode> children;

  const CategoryNode({
    required this.category,
    this.depth = 0,
    this.children = const <CategoryNode>[],
  });

  String get id => category.id;
  String get name => category.name;
  bool get isLeaf => children.isEmpty;

  /// Products assigned directly to this category.
  int get directProductCount => category.productList.length;

  /// Products in this category **and** every descendant.
  int get totalProductCount =>
      directProductCount +
      children.fold<int>(0, (sum, child) => sum + child.totalProductCount);

  /// Number of categories below this one (any depth).
  int get descendantCount =>
      children.fold<int>(0, (sum, child) => sum + 1 + child.descendantCount);

  @override
  String toString() => 'CategoryNode($id, depth: $depth, kids: ${children.length})';
}

/// Builds and queries a category hierarchy from the flat Firestore list.
///
/// The tree is defensive on purpose: categories with a missing parent are
/// promoted to roots and cycles are broken instead of hanging the UI.
class CategoryTree {
  /// Safety valve so a corrupt hierarchy can never recurse forever.
  static const int maxDepth = 12;

  /// Top level nodes (depth 0), sorted by name.
  final List<CategoryNode> roots;

  /// Categories whose parent chain looped and had to be re-rooted.
  final List<Category> repairedCycles;

  const CategoryTree({this.roots = const <CategoryNode>[], this.repairedCycles = const <Category>[]});

  factory CategoryTree.build(List<Category> categories) {
    final byId = <String, Category>{};
    for (final c in categories) {
      byId[c.id] = c;
    }

    final childrenOf = <String, List<Category>>{};
    final repaired = <Category>[];

    for (final c in categories) {
      final parentId = c.parentId;
      if (parentId == null || parentId.isEmpty) continue;

      if (parentId == c.id || _reaches(c.id, parentId, byId)) {
        // Assigning this parent would create a loop -> keep it at the root.
        repaired.add(c);
        continue;
      }
      childrenOf.putIfAbsent(parentId, () => <Category>[]).add(c);
    }

    final knownIds = byId.keys.toSet();
    final repairedIds = <String>{};

    List<CategoryNode> buildLevel(String? parentId, int depth) {
      if (depth > maxDepth) return const <CategoryNode>[];

      final own = parentId == null
          ? categories.where((c) {
              final parent = c.parentId;
              return parent == null ||
                  parent.isEmpty ||
                  !knownIds.contains(parent) ||
                  repairedIds.contains(c.id);
            }).toList()
          : (childrenOf[parentId] ?? const <Category>[]);

      final nodes = own
          .map(
            (c) => CategoryNode(
              category: c,
              depth: depth,
              children: buildLevel(c.id, depth + 1),
            ),
          )
          .toList();
      return _sorted(nodes);
    }

    for (final c in repaired) {
      repairedIds.add(c.id);
    }

    return CategoryTree(
      roots: buildLevel(null, 0),
      repairedCycles: repaired,
    );
  }

  /// Depth-first list of every node.
  List<CategoryNode> flatten() {
    final out = <CategoryNode>[];
    void walk(List<CategoryNode> nodes) {
      for (final node in nodes) {
        out.add(node);
        walk(node.children);
      }
    }

    walk(roots);
    return out;
  }

  /// Nodes that should be painted given the current expanded set.
  ///
  /// Parents are always visible; children only when their id is in
  /// [expandedIds]. Cycle-repaired nodes are shown at the root.
  List<CategoryNode> visibleRows(Set<String> expandedIds) {
    final out = <CategoryNode>[];
    void walk(List<CategoryNode> nodes) {
      for (final node in nodes) {
        out.add(node);
        if (node.children.isNotEmpty && expandedIds.contains(node.id)) {
          walk(node.children);
        }
      }
    }

    walk(roots);
    return out;
  }

  /// Every id that should start expanded: all parents with children.
  Set<String> get defaultExpandedIds => flatten()
      .where((n) => n.children.isNotEmpty)
      .map((n) => n.id)
      .toSet();

  static List<CategoryNode> _sorted(List<CategoryNode> nodes) {
    nodes.sort(
      (a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()),
    );
    return nodes;
  }

  /// Walks up from [startId] to see whether [targetId] is an ancestor.
  static bool _reaches(
    String startId,
    String targetId,
    Map<String, Category> byId,
  ) {
    var current = byId[startId]?.parentId;
    final seen = <String>{startId};
    while (current != null && current.isNotEmpty) {
      if (current == targetId) return true;
      if (!seen.add(current)) return true; // loop in the stored data
      current = byId[current]?.parentId;
    }
    return false;
  }
}

/// Helpers that operate on the flat list (used by the editors before saving).
class CategoryHierarchy {
  const CategoryHierarchy._();

  /// All descendant ids of [categoryId] at any depth.
  static Set<String> descendantIds(String categoryId, List<Category> all) {
    final result = <String>{};
    final queue = <String>[categoryId];
    final seen = <String>{categoryId};

    while (queue.isNotEmpty) {
      final current = queue.removeAt(0);
      for (final c in all) {
        if (c.parentId == current && seen.add(c.id)) {
          result.add(c.id);
          queue.add(c.id);
        }
      }
    }
    return result;
  }

  /// True when moving [categoryId] under [newParentId] would create a loop.
  static bool wouldCreateCycle({
    required String categoryId,
    required String? newParentId,
    required List<Category> all,
  }) {
    if (newParentId == null || newParentId.isEmpty) return false;
    if (newParentId == categoryId) return true;
    return descendantIds(categoryId, all).contains(newParentId);
  }

  /// Breadcrumb from the root down to [categoryId] (inclusive).
  static List<Category> pathTo(String categoryId, List<Category> all) {
    final byId = <String, Category>{for (final c in all) c.id: c};
    final path = <Category>[];
    var current = byId[categoryId];
    final seen = <String>{};

    while (current != null && seen.add(current.id)) {
      path.insert(0, current);
      final parentId = current.parentId;
      if (parentId == null || parentId.isEmpty) break;
      current = byId[parentId];
    }
    return path;
  }

  /// Full display path such as `Apparel / Men / Shirts`.
  static String pathLabel(String categoryId, List<Category> all) =>
      pathTo(categoryId, all).map((c) => c.name).join(' / ');
}
