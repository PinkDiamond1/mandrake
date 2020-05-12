import 'dart:collection';
import 'dart:ui' show Offset, Size, Rect;
import 'package:uuid/uuid.dart';

/// Base class for [Node], which describes an object representing part of
/// an AST tree, and its geometry information on a canvas.
abstract class NodeBase {
  NodeBase(this.name, this.position) : assert(position != null);

  final String id = Uuid().v4();
  String name;
  Offset position;

  Size get size {
    final height = titleHeight + subtitleHeight + slots.length * slotRowHeight + bottomPadding;
    return Size(
      120,
      canAddChild ? height + actionRowHeight : height,
    );
  }

  final List<Node> _children = [];
  UnmodifiableListView<Node> get children => UnmodifiableListView(_children);

  final List<ChildSlot> _slots = [];
  UnmodifiableListView<ChildSlot> get slots => UnmodifiableListView(_slots);

  bool get canAddChild => false;

  double get titleHeight => 30;
  double get subtitleHeight => 16;
  double get actionRowHeight => 24;
  double get slotRowHeight => 24;
  double get bottomPadding => 5;

  @override
  bool operator ==(dynamic other) => other is NodeBase && other.id == id;

  @override
  int get hashCode => id.hashCode;
}

class Node extends NodeBase {
  Node([name = 'Node', position = Offset.zero]) : super(name, position);

  /// Full list as this node plus its children.
  UnmodifiableListView<Node> get nodes {
    final descendants =
        children.map((e) => e.nodes).fold(<Node>[], (value, element) => value + element);
    return UnmodifiableListView([this] + descendants);
  }

  /// Assign a virtual slot to the add child button so that one can drag
  /// from the add child button to another node to connect.
  static final ChildSlot addChildSlot = ChildSlot();

  @override
  bool get canAddChild => true;

  ChildSlot addSlot(String name) {
    final slot = ChildSlot(name: name);
    _slots.add(slot);
    return slot;
  }

  /// Remove both the slot and the child if there's one connected.
  void removeSlot(String slot_id) {
    final slot = slots.firstWhere((s) => s.id == slot_id, orElse: () => null);
    if (slot != null) {
      removeChild(slot.child_id);
      _slots.remove(slot);
    }
  }

  void _fillSlot(Node child, String slot_id) {
    final slot = slots.firstWhere((s) => s.id == slot_id && !s.isConnected, orElse: () => null);
    assert(slot != null);
    slot.child_id = child.id;
  }

  /// Add a child. If slot_id is provided fill the child to that slot.
  void addChild(Node child, [String slot_id]) {
    assert(canAddChild);
    if (_children.contains(child)) {
      return;
    }

    _children.add(child);
    if (slot_id == addChildSlot.id) {
      _fillSlot(child, addSlot('new child').id);
    } else if (slot_id != null) {
      _fillSlot(child, slot_id);
    }
  }

  /// Remove a child from this node. Not this merely deletes the connection
  /// between this node and its child. It would keep the slot.
  void removeChild(String child_id) {
    if (child_id == null) {
      return;
    }

    final slot = slots.firstWhere((s) => s.child_id == child_id, orElse: () => null);
    if (slot != null) {
      slot.child_id = null;
    }

    _children.removeWhere((c) => c.id == child_id);
  }

  Offset childConnectorPosition(Node child) {
    final callSlot = slots.firstWhere((s) => s.child_id == child.id, orElse: () => null);
    if (callSlot != null) {
      return slotConnectorPosition(callSlot);
    }

    return position + Offset(size.width, 55); // Should not happen.
  }

  Offset slotConnectorPosition(ChildSlot slot) {
    final verticalOffset = titleHeight + subtitleHeight;

    if (slot == addChildSlot) {
      return position +
          Offset(
            size.width - 12,
            verticalOffset + slotRowHeight * slots.length + slotRowHeight / 2,
          );
    }

    final index = slots.indexOf(slot);
    if (index != -1) {
      return position +
          Offset(
            size.width - 12,
            verticalOffset + slotRowHeight * slots.indexOf(slot) + slotRowHeight / 2,
          );
    }

    return null;
  }

  /// Return a child slot if pointer is inside its add button area.
  /// Param point is local position of node within Offset(0, 0) and Size(size).
  ChildSlot hitTest(Offset point) {
    final verticalOffset = titleHeight + subtitleHeight;
    final hitWidth = 25.0;

    for (var i = 0; i < slots.length; i++) {
      if (slots[i].isConnected) {
        // Already connected(filled), cannot link to another child.
        continue;
      }

      final rect = Rect.fromLTWH(
        size.width - hitWidth,
        verticalOffset + slotRowHeight * i,
        hitWidth,
        slotRowHeight,
      );
      if (rect.contains(point)) {
        return slots[i];
      }
    }
    final addCallButtonRect = Rect.fromLTWH(
      size.width - hitWidth,
      verticalOffset + slotRowHeight * slots.length,
      hitWidth,
      slotRowHeight,
    );
    if (addCallButtonRect.contains(point)) {
      return addChildSlot;
    }

    return null;
  }
}

/// A slot of a [Node] can either hold a reference to a child, or empty
/// before connecting to child.
class ChildSlot {
  ChildSlot({this.name = '', this.child_id});

  final String id = Uuid().v4();
  String name;
  String child_id;

  bool get isConnected => child_id != null;

  @override
  bool operator ==(dynamic other) => other is ChildSlot && other.id == id;

  @override
  int get hashCode => id.hashCode;
}
