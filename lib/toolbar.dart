import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:file_chooser/file_chooser.dart';

import 'models/document.dart';
import 'models/editor_state.dart';
import 'io/doc_reader.dart';
import 'io/doc_writer.dart';
import 'io/ast_writer.dart';

class Toolbar extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Consumer2<Document, EditorState>(builder: (context, document, editorState, child) {
      return Container(
        decoration: BoxDecoration(
          color: Theme.of(context).canvasColor,
          border: Border(
            bottom: BorderSide(
              width: 1,
              color: Theme.of(context).dividerColor,
            ),
          ),
        ),
        child: Wrap(
          crossAxisAlignment: WrapCrossAlignment.center,
          children: [
            SizedBox(width: 20),
            _iconButton(
              icon: Icon(Icons.note_add),
              onPressed: null,
            ),
            _iconButton(
              icon: Icon(Icons.file_upload),
              onPressed: () => _openDocument(),
            ),
            _iconButton(
              icon: Icon(Icons.file_download),
              onPressed: () => _saveDocument(document),
            ),
            _iconButton(
              icon: Icon(Icons.arrow_forward),
              onPressed: () => _exportAst(document),
            ),
            _separator(),
            _iconButton(
              icon: Icon(Icons.zoom_out),
              onPressed: editorState.zoomOutAction,
            ),
            SizedBox(
              width: 30,
              child: Text(
                '${(editorState.zoomScale * 100).round()}%',
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: Colors.grey,
                  fontSize: 11,
                ),
              ),
            ),
            _iconButton(
              icon: Icon(Icons.zoom_in),
              onPressed: editorState.zoomInAction,
            ),
            _separator(),
            _iconButton(
              icon: Icon(Icons.filter_center_focus),
              onPressed: () => editorState.resetCanvasOffset(),
            ),
            _iconButton(
              icon: Icon(Icons.developer_board),
              onPressed: () => _jumpToRoot(document, editorState),
            ),
          ],
        ),
      );
    });
  }

  void _openDocument() {
    // TODO: Pick open path
    final path = 'todo.mand';
    final doc = DocReader(path).read();
    print('$doc read from disk');
    // TODO: load as current project/document
  }

  void _saveDocument(Document document) {
    // TODO: Pick save path
    final path = 'todo.mand';
    DocWriter(document, path).write();
  }

  void _exportAst(Document document) async {
    String path;
    if (kIsWeb) {
      // TODO: handle web export
      path = 'ast.bin';
    } else {
      final result = await showSavePanel(suggestedFileName: 'ast.bin');
      if (!result.canceled) {
        path = result.paths.first;
      }
    }

    if (path != null) {
      await AstWriter(document, path).write();
    }
  }

  void _jumpToRoot(Document document, EditorState editorState) {
    final root = document.root;
    editorState.resetCanvasOffset();
    final pos = root.position + Offset(-80, -200);
    editorState.moveCanvas(-pos);
  }

  Widget _iconButton({Widget icon, Function onPressed}) {
    return IconButton(
      icon: icon,
      onPressed: onPressed,
      hoverColor: Colors.transparent,
      highlightColor: Colors.transparent,
      splashColor: Colors.transparent,
    );
  }

  Widget _separator() {
    return SizedBox(
      width: 20,
      height: 40,
      child: VerticalDivider(
        indent: 8,
        endIndent: 8,
      ),
    );
  }
}
