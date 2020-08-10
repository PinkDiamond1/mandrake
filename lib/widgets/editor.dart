import 'dart:async';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../models/document.dart';
import '../models/document_template.dart';
import '../models/selection.dart';
import '../models/editor_state.dart';
import '../models/recent_files.dart';

import '../io/file_chooser.dart';
import '../io/doc_reader.dart';
import '../io/doc_writer.dart';
import '../io/ast_writer.dart';

import 'toolbar.dart';
import 'object_library.dart';
import 'property_inspector.dart';
import 'ruler.dart';

import '../views/editor/editor_dimensions.dart';
import '../views/editor/canvas_layer.dart';
import '../views/editor/edges_layer.dart';
import '../views/editor/nodes_layer.dart';
import '../views/editor/pointer_layer.dart';

class Editor extends StatefulWidget {
  @override
  _EditorState createState() => _EditorState();
}

class _EditorState extends State<Editor> {
  Document _doc;
  FileHandle _docHandle;
  Selection _selection;
  EditorState _editorState;
  RecentFiles _recentFiles;

  void _newDocument() {
    _promptToSaveIfNecessary(() {
      setState(() {
        _doc = DocumentTemplate(DocumentTemplateType.blank).create();
        _docHandle = null;
        _selection = Selection();
        _editorState = EditorState();
      });
    });
  }

  void _newDocumentFromTemplate() {
    _promptToSaveIfNecessary(() {
      _showTemplateDialog();
    });
  }

  Future<void> _showTemplateDialog({Function dangerAction, bool cancellable = true}) async {
    final result = await showDialog(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext context) {
        var selectedTemplate = DocumentTemplate.templates.first;
        return AlertDialog(
          title: Text('Choose a template'),
          content: StatefulBuilder(builder: (BuildContext context, StateSetter setState) {
            return Container(
              width: 800,
              height: 400,
              child: Column(
                children: DocumentTemplate.templates.map((template) {
                  return RadioListTile<DocumentTemplate>(
                    title: Text(template.name),
                    subtitle: Text(template.description),
                    value: template,
                    groupValue: selectedTemplate,
                    onChanged: (DocumentTemplate value) {
                      setState(() {
                        selectedTemplate = value;
                      });
                    },
                  );
                }).toList(),
              ),
            );
          }),
          actions: <Widget>[
            FlatButton(
              child: Text('Cancel'),
              onPressed: cancellable
                  ? () {
                      Navigator.pop(context, null);
                    }
                  : null,
            ),
            FlatButton(
              child: Text('Create'),
              onPressed: () {
                Navigator.pop(context, selectedTemplate);
              },
            ),
          ],
        );
      },
    );

    if (result != null) {
      setState(() {
        _doc = result.create();
        _docHandle = null;
        _selection = Selection();
        _editorState = EditorState();
      });
    }
  }

  void _openDocument() {
    _promptToSaveIfNecessary(() async {
      final handle = await showOpenPanel(
        allowedFileTypes: [
          FileFilterGroup(extensions: ['json'], label: 'JSON')
        ],
      );

      if (handle == null) {
        return;
      }

      final doc = await DocReader(handle).read();
      if (doc != null) {
        setState(() {
          _doc = doc;
          _doc.rebuild();
          _doc.markNotDirty();
          _docHandle = handle;
          _trackRecentFile(handle);
          _selection = Selection();
          _editorState = EditorState();
        });
      }
    });
  }

  void _openDocumentHandle(FileHandle handle) {
    _promptToSaveIfNecessary(() async {
      final doc = await DocReader(handle).read();
      if (doc != null) {
        setState(() {
          _doc = doc;
          _doc.rebuild();
          _doc.markNotDirty();
          _docHandle = handle;
          _trackRecentFile(handle);
          _selection = Selection();
          _editorState = EditorState();
        });
      }
    });
  }

  Future<bool> _saveDocument() async {
    if (_docHandle == null) {
      final handle = await showSavePanel(
        suggestedFileName: _doc.fileName,
        allowedFileTypes: [
          FileFilterGroup(extensions: ['json'], label: 'JSON')
        ],
      );
      if (handle != null) {
        _docHandle = handle;
        _trackRecentFile(handle);
      }
    }

    if (_docHandle != null) {
      await DocWriter(_doc, _docHandle).write();
      _doc.markNotDirty();
      return true;
    }
    return false;
  }

  Future<bool> _saveDocumentAs() async {
    final handle = await showSavePanel(
      suggestedFileName: _doc.fileName,
      allowedFileTypes: [
        FileFilterGroup(extensions: ['json'], label: 'JSON')
      ],
    );
    if (handle != null) {
      _docHandle = handle;
      _trackRecentFile(handle);
    }

    if (_docHandle != null) {
      await DocWriter(_doc, _docHandle).write();
      _doc.markNotDirty();
      return true;
    }
    return false;
  }

  void _exportAst() async {
    final handle = await showSavePanel(
      suggestedFileName: 'ast.bin',
    );

    if (handle != null) {
      await AstWriter(_doc, handle).write();
    }
  }

  void _trackRecentFile(FileHandle fileHandle) async {
    await _recentFiles.push(fileHandle);
  }

  Future<void> _promptToSaveIfNecessary(Function dangerAction) async {
    if (!_doc.isDirty) {
      return dangerAction();
    }

    final result = await showDialog(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext context) {
        return AlertDialog(
          title: Text('Unsaved document'),
          content: SingleChildScrollView(
            child: ListBody(
              children: <Widget>[
                Text("There're unsaved changes. Do you want to save the current document first?"),
              ],
            ),
          ),
          actions: <Widget>[
            FlatButton(
              child: Text('Yes, save the document.'),
              onPressed: () {
                Navigator.pop(context, true);
              },
            ),
            FlatButton(
              child: Text('No, discard the changes.'),
              onPressed: () {
                Navigator.pop(context, false);
              },
            ),
          ],
        );
      },
    );

    if (result) {
      if (await _saveDocument()) {
        dangerAction();
      }
    } else {
      dangerAction();
    }
  }

  @override
  void initState() {
    _doc = Document();
    _docHandle = null;
    _selection = Selection();
    _editorState = EditorState();
    _recentFiles = RecentFiles();
    _recentFiles.init();

    super.initState();

    Timer.run(() => _showTemplateDialog(cancellable: false));
  }

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider<Document>.value(value: _doc),
        ChangeNotifierProvider<Selection>.value(value: _selection),
        ChangeNotifierProvider<EditorState>.value(value: _editorState),
        ChangeNotifierProvider<RecentFiles>.value(value: _recentFiles),
      ],
      child: Stack(
        children: [
          Positioned(
            top: EditorDimensions.toolbarHeight + EditorDimensions.rulerWidth,
            left: EditorDimensions.objectLibraryPanelWidth + EditorDimensions.rulerWidth,
            right: EditorDimensions.propertyInspectorPanelWidth,
            bottom: 0,
            child: DesignEditor(),
          ),
          Positioned(
            top: EditorDimensions.toolbarHeight + EditorDimensions.rulerWidth,
            left: EditorDimensions.objectLibraryPanelWidth,
            bottom: 0,
            width: EditorDimensions.rulerWidth,
            child: Ruler(RulerDirection.vertical),
          ),
          Positioned(
            top: EditorDimensions.toolbarHeight,
            left: EditorDimensions.objectLibraryPanelWidth + EditorDimensions.rulerWidth,
            right: EditorDimensions.propertyInspectorPanelWidth,
            height: EditorDimensions.rulerWidth,
            child: Ruler(RulerDirection.horizontal),
          ),
          Positioned(
            top: EditorDimensions.toolbarHeight,
            left: EditorDimensions.objectLibraryPanelWidth,
            width: EditorDimensions.rulerWidth,
            height: EditorDimensions.rulerWidth,
            child: RulerControl(),
          ),
          Positioned(
            top: EditorDimensions.toolbarHeight,
            left: 0,
            bottom: 0,
            width: EditorDimensions.objectLibraryPanelWidth,
            child: ObjectLibrary(),
          ),
          Positioned(
            top: EditorDimensions.toolbarHeight,
            bottom: 0,
            right: 0,
            width: EditorDimensions.propertyInspectorPanelWidth,
            child: PropertyInspector(),
          ),
          Positioned(
            top: 0,
            left: 0,
            right: 0,
            // Toolbar actual size to occupy full screen for main menu
            height: MediaQuery.of(context).size.height,
            child: Toolbar(
              onNewDocument: _newDocument,
              onNewDocumentFromTemplate: _newDocumentFromTemplate,
              onOpenDocument: _openDocument,
              onOpenDocumentHandle: _openDocumentHandle,
              onSaveDocument: _saveDocument,
              onSaveDocumentAs: _saveDocumentAs,
              onExportAst: _exportAst,
            ),
          ),
        ],
      ),
    );
  }
}

/// Graph design core editor.
class DesignEditor extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final editorState = Provider.of<EditorState>(context);

    return Stack(
      children: [
        CanvasLayer(), // endless scrolling
        Transform.scale(
          scale: editorState.zoomScale,
          alignment: Alignment.topLeft,
          child: Stack(
            children: [
              EdgesLayer(),
              NodesLayer(),
            ],
          ),
        ),

        /// Pointer layer doesn't scale with edges/nodes to make sure even when
        /// drawing area is smaller than canvas background events outside that
        /// area are still handled.
        PointerLayer(),
      ],
    );
  }
}