import 'dart:math';
import 'package:flutter/material.dart';

import 'models/editor_bag.dart';
import 'models/node.dart';
import 'models/selection.dart';
import 'object_panel.dart';
import 'node_view.dart';

class Editor extends StatefulWidget {
  @override
  State<StatefulWidget> createState() => _EditorState();
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
  final List<Node> nodes = [];
  final Selection selection = Selection();

  final double _canvasMargin = 20;
  Offset canvasOffset = Offset.zero;
  double zoomScale = 1;

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        Container(
          color: Colors.grey[400],
        ),
        Positioned(
          left: _canvasMargin,
          top: _canvasMargin,
          right: _canvasMargin,
          bottom: _canvasMargin,
          child: Transform(
            transform: Matrix4.translationValues(
              canvasOffset.dx,
              canvasOffset.dy,
              0,
            )..scale(zoomScale, zoomScale, 1),
            child: Stack(
              children: [
                _canvasLayer(context),
                _edgesLayer(context),
                _graphsLayer(context, selection),
                _dragTargetLayer(context),
              ],
            ),
          ),
        ),
        Positioned(
          bottom: _canvasMargin,
          right: _canvasMargin,
          height: 40,
          child: Row(
            children: [
              Text('${(zoomScale * 100).toInt()}%'),
              IconButton(
                icon: Icon(Icons.zoom_out),
                onPressed: zoomScale > 0.2
                    ? () => {
                          setState(() {
                            zoomScale = max(0.2, zoomScale - 0.2);
                          })
                        }
                    : null,
              ),
              IconButton(
                icon: Icon(Icons.zoom_in),
                onPressed: zoomScale < 2
                    ? () => {
                          setState(() {
                            zoomScale = min(2, zoomScale + 0.2);
                          })
                        }
                    : null,
              ),
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
      child: CustomPaint(
        painter: _CanvasGridPainter(),
        child: Container(),
      ),
    );
  }

  Widget _edgesLayer(BuildContext context) {
    return CustomPaint(
      painter: _EdgesPainter(nodes),
      child: Container(),
    );
  }

  bool _isDragging = false;
  bool _isDraggingCanvas = false;

  Widget _graphsLayer(BuildContext context, Selection selection) {
    final nodeViews = nodes.map((e) {
      return NodeView(e, selection);
    }).toList();

    final hitTest = (Offset point) {
      for (final nodeView in nodeViews.reversed) {
        final rect = Rect.fromLTWH(
          nodeView.node.position.dx,
          nodeView.node.position.dy,
          nodeView.size.width,
          nodeView.size.height,
        );
        if (rect.contains(point)) {
          return nodeView.node;
        }
      }
      return null;
    };

    return Listener(
      behavior: HitTestBehavior.opaque,
      child: Stack(
        children: nodeViews,
      ),
      onPointerMove: (event) {
        // HisTest and move objects. Note: inner listener cannot stop  outer
        // listener; nested listeners won't work.
        // On the other side, GestureDetector has a delay which makes dragging
        // feel unnatural.
        if (!_isDragging) {
          _isDragging = true;
          final node = hitTest(event.localPosition);
          if (node != null) {
            setState(() {
              selection.select(node);
              _isDraggingCanvas = false;
            });
          } else {
            setState(() {
              selection.select(null);
              _isDraggingCanvas = true;
            });
          }
        }

        if (_isDraggingCanvas) {
          setState(() {
            canvasOffset += event.delta;
          });
        } else {
          setState(() {
            selection.selectedNode(nodes).position += event.delta / zoomScale;
          });
        }
      },
      onPointerDown: (event) {
        final node = hitTest(event.localPosition);
        setState(() {
          selection.select(node);
        });
      },
      onPointerUp: (event) {
        _isDragging = false;
        _isDraggingCanvas = false;
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
            final pos = (dropPos -
                    Offset(_canvasMargin, _canvasMargin) -
                    canvasOffset) /
                zoomScale;
            final node = Node(pos);
            nodes.add(node);
            selection.select(node);
          });
        });
      },
      builder: (context, candidateData, rejectedData) => Container(),
    );
  }
}

class _CanvasGridPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    var paint = Paint()
      ..isAntiAlias = true
      ..strokeWidth = 1
      ..color = Colors.black12;

    for (var i = 20; i < size.width; i += 20) {
      canvas.drawLine(
        Offset(i.toDouble(), 0),
        Offset(i.toDouble(), size.height),
        paint,
      );
    }

    for (var i = 20; i < size.height; i += 20) {
      canvas.drawLine(
        Offset(0, i.toDouble()),
        Offset(size.width, i.toDouble()),
        paint,
      );
    }
  }

  @override
  bool shouldRepaint(_CanvasGridPainter oldPainter) => false;
}

class _EdgesPainter extends CustomPainter {
  List<Node> nodes;
  _EdgesPainter(this.nodes);

  @override
  void paint(Canvas canvas, Size size) {
    var paint = Paint()
      ..isAntiAlias = true
      ..strokeWidth = 1
      ..color = Colors.purple;

    // Draw a test edge between the first two nodes.
    if (nodes.length > 1) {
      canvas.drawLine(
        nodes[0].position + Offset(30, 180),
        nodes[1].position + Offset(0, 20),
        paint,
      );
    }
  }

  @override
  bool shouldRepaint(_EdgesPainter oldPainter) => false;
}
