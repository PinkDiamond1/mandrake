import 'package:flutter/material.dart';

import 'models/editor_bag.dart';
import 'models/node.dart';
import 'models/selection.dart';
import 'object_panel.dart';
import 'node_view.dart';

class Editor extends StatefulWidget {
  @override
  State<StatefulWidget> createState() =>_EditorState();
}

class _EditorState extends State<Editor> {
  final double objectPanelWidth = 240;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(builder: (buildContext, constraints) {
      return Stack(
        children: [
          Positioned(
            top: 0,
            left: objectPanelWidth,
            right: 0,
            bottom: 0,
            child: DesignEditor(),
          ),
          Positioned(
            top: 0,
            left: 0,
            right: constraints.maxWidth - objectPanelWidth,
            bottom: 0,
            child: ObjectPanel(),
          ),
        ],
      );
    });
  }
}

class DesignEditor extends StatefulWidget {
  @override
  State<StatefulWidget> createState() {
    return _DesignEditorState();
  }
}

class _DesignEditorState extends State<DesignEditor> {
  final double _canvasMargin = 20;
  Offset canvasOffset = Offset.zero;
  final List<Node> nodes = [];
  final Selection selection = Selection();

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        Container(
          color: Colors.grey[400],
        ),
        Positioned(
          left: _canvasMargin + canvasOffset.dx,
          top: _canvasMargin + canvasOffset.dy,
          right: _canvasMargin - canvasOffset.dx,
          bottom: _canvasMargin - canvasOffset.dy,
          child: Stack(
            children: [
              _canvasLayer(context),
              _edgesLayer(context),
              _graphsLayer(context, selection),
              _dragTargetLayer(context),
            ],
          ),
        ),
      ],
    );
  }

  Widget _canvasLayer(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        boxShadow: [
          BoxShadow(
            color: Colors.grey,
            offset: Offset(0, 2),
            blurRadius: 5,
          ),
        ],
      ),
    );
  }

  Widget _edgesLayer(BuildContext context) {
    return CustomPaint(
      painter: _EdgesPainter(),
      child: Container(),
    );
  }

  Widget _graphsLayer(BuildContext context, Selection selection) {
    final graphObjects = nodes.map((e) {
      return NodeView(e, selection);
    }).toList();

    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      child: Stack(
        children: graphObjects,
      ),
      onPanUpdate: (drag) {
        // final selectedNode = selection.selectedNode(nodes);
        setState(() {
          canvasOffset += drag.delta;
        });
      },
      onPanEnd: (drag) {
        // TODO: clean up
      },
      onTap: () {
        setState(() {
          selection.select(null);
        });
      },
    );
  }

  Widget _dragTargetLayer(BuildContext context) {
    return DragTarget<String>(
      onWillAccept: (data) {
        print('data = $data onWillAccept');
        return data != null;
      },
      onAccept: (data) {
        // Draggable.onDragEnd gets called after DragTarget.onDragAccept. That
        // doesn't leave us the proper drop position.
        // Note flutter already has a PR to include the offset for onDragAccept.
        Future.delayed(Duration(milliseconds: 20), () {
          final renderBox = context.findRenderObject() as RenderBox;
          final dropPos = renderBox.globalToLocal(editorBag.lastDropOffset);
          setState(() {
            final node = Node(dropPos - canvasOffset - Offset(20, 20));
            nodes.add(node);
            selection.select(node);
          });
        });
      },
      builder: (context, candidateData, rejectedData) => Container(),
    );
  }
}

class _EdgesPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    var paint = Paint()
      ..isAntiAlias = true
      ..strokeWidth = 1
      ..color = Colors.black12;

    for (var i = 20; i < size.width; i += 20) {
      canvas.drawLine(
          Offset(i.toDouble(), 0), Offset(i.toDouble(), size.height), paint);
    }

    for (var i = 20; i < size.height; i += 20) {
      canvas.drawLine(
          Offset(0, i.toDouble()), Offset(size.width, i.toDouble()), paint);
    }
  }

  @override
  bool shouldRepaint(_EdgesPainter oldPainter) => false;
}
