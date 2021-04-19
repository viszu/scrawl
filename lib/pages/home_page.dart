import 'dart:async';
import 'dart:convert';

import 'package:bnotes/constants.dart';
import 'package:bnotes/pages/settings_page.dart';
import 'package:bnotes/widgets/search_textfield.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:bnotes/helpers/database_helper.dart';
import 'package:bnotes/helpers/note_color.dart';
import 'package:bnotes/helpers/storage.dart';
import 'package:bnotes/models/notes_model.dart';
import 'package:bnotes/pages/labels_page.dart';
import 'package:bnotes/widgets/color_palette.dart';
import 'package:flutter_markdown/flutter_markdown.dart';
import 'package:intl/intl.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:uuid/uuid.dart';

class HomePage extends StatefulWidget {
  HomePage({Key key, this.title}) : super(key: key);
  final String title;

  @override
  _HomePageState createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  SharedPreferences sharedPreferences;
  bool isAppLogged = false;
  String userFullname = "";
  String userId = "";
  String userEmail = "";
  Storage storage = new Storage();
  String backupPath = "";
  bool isTileView = false;
  ScrollController scrollController = new ScrollController();

  final GlobalKey<ScaffoldState> _scaffoldKey = new GlobalKey<ScaffoldState>();
  StreamController<List<Notes>> _notesController;
  final dbHelper = DatabaseHelper.instance;
  var uuid = Uuid();
  TextEditingController _noteTitleController = new TextEditingController();
  TextEditingController _noteTextController = new TextEditingController();
  String currentEditingNoteId = "";
  TextEditingController _searchController = new TextEditingController();

  getPref() async {
    sharedPreferences = await SharedPreferences.getInstance();
    setState(() {
      isAppLogged = sharedPreferences.getBool("is_logged");
      isTileView = sharedPreferences.getBool("is_tile");
      if (isTileView == null) {
        isTileView = false;
      }
    });
  }

  loadNotes() async {
    final allRows = await dbHelper.getNotesAll(_searchController.text);
    _notesController.add(allRows);
  }

  void _saveNote() async {
    if (currentEditingNoteId.isEmpty) {
      await dbHelper
          .insertNotes(new Notes(uuid.v1(), DateTime.now().toString(),
              _noteTitleController.text, _noteTextController.text, '', 0, 0))
          .then((value) {
        loadNotes();
      });
    } else {
      await dbHelper
          .updateNotes(new Notes(
              currentEditingNoteId,
              DateTime.now().toString(),
              _noteTitleController.text,
              _noteTextController.text,
              '',
              0,
              0))
          .then((value) {
        loadNotes();
      });
    }
  }

  void _updateColor(String noteId, int noteColor) async {
    await dbHelper.updateNoteColor(noteId, noteColor).then((value) {
      loadNotes();
    });
  }

  void _deleteNote() async {
    await dbHelper.deleteNotes(currentEditingNoteId).then((value) {
      loadNotes();
    });
  }

  @override
  void initState() {
    getPref();
    _notesController = new StreamController<List<Notes>>();
    loadNotes();
    super.initState();
  }

  void _onSearch() {
    loadNotes();
  }

  void _onClearSearch() {
    setState(() {
      _searchController.text = "";
      loadNotes();
    });
  }

  @override
  void dispose() {
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      key: _scaffoldKey,
      appBar: AppBar(
        bottom: PreferredSize(
          preferredSize: Size.fromHeight(10),
          child: SearchTexfield(
            searchController: _searchController,
            onSearch: _onSearch,
            onClearSearch: _onClearSearch,
            settingsCallback: () async {
              final result = await Navigator.of(context).push(
                  MaterialPageRoute(builder: (context) => SettingsPage()));
              loadNotes();
            },
          ),
        ),
      ),
      body: Container(
        padding: EdgeInsets.all(3.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.max,
          children: <Widget>[
            Expanded(
              child: StreamBuilder<List<Notes>>(
                stream: _notesController.stream,
                builder: (BuildContext context,
                    AsyncSnapshot<List<Notes>> snapshot) {
                  if (snapshot.connectionState == ConnectionState.waiting) {
                    return Center(
                      child: CircularProgressIndicator(),
                    );
                  }
                  if (snapshot.hasError) {
                    return Text(snapshot.error);
                  }
                  if (snapshot.hasData) {
                    if (isTileView)
                      return GridView.count(
                        mainAxisSpacing: 3.0,
                        crossAxisCount: 2,
                        children: List.generate(snapshot.data.length, (index) {
                          var note = snapshot.data[index];
                          return InkWell(
                            onTap: () {
                              _showNoteReader(context, note);
                            },
                            onLongPress: () {
                              _showOptionsSheet(context, note);
                            },
                            child: Card(
                              color: NoteColor.getColor(note.noteColor ?? 0),
                              elevation: 2,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(10.0),
                              ),
                              child: Container(
                                padding: const EdgeInsets.all(8.0),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Padding(
                                      padding: const EdgeInsets.all(8.0),
                                      child: Text(
                                        note.noteTitle,
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                        style: TextStyle(
                                            fontSize: 20.0,
                                            color: Colors.black),
                                      ),
                                    ),
                                    Expanded(
                                      child: Padding(
                                        padding: const EdgeInsets.all(8.0),
                                        child: Text(
                                          note.noteText,
                                          maxLines: 6,
                                          overflow: TextOverflow.ellipsis,
                                          style:
                                              TextStyle(color: Colors.black38),
                                        ),
                                      ),
                                    ),
                                    Container(
                                      padding: EdgeInsets.all(8.0),
                                      child: Row(
                                        mainAxisAlignment:
                                            MainAxisAlignment.spaceBetween,
                                        children: [
                                          Expanded(
                                              child: Text(
                                            note.noteLabel,
                                            maxLines: 1,
                                            overflow: TextOverflow.ellipsis,
                                            style: TextStyle(
                                                color: Colors.black45,
                                                fontSize: 12.0),
                                          )),
                                          Text(
                                            formatDateTime(note.noteDate),
                                            style: TextStyle(
                                                color: Colors.black45,
                                                fontSize: 12.0),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          );
                        }),
                      );
                    else
                      return ListView.builder(
                        itemCount: snapshot.data.length,
                        itemBuilder: (context, index) {
                          var note = snapshot.data[index];
                          return InkWell(
                            onTap: () => _showNoteReader(context, note),
                            onLongPress: () => _showOptionsSheet(context, note),
                            child: Container(
                              margin: EdgeInsets.all(5.0),
                              padding: EdgeInsets.all(8.0),
                              decoration: BoxDecoration(
                                  color:
                                      NoteColor.getColor(note.noteColor ?? 0),
                                  borderRadius: BorderRadius.circular(10.0),
                                  boxShadow: [
                                    BoxShadow(
                                        color: Colors.black26,
                                        blurRadius: 1.0,
                                        offset: new Offset(1, 1)),
                                  ]),
                              child: Column(
                                mainAxisAlignment: MainAxisAlignment.start,
                                mainAxisSize: MainAxisSize.min,
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Padding(
                                    padding: EdgeInsets.all(5.0),
                                    child: Text(
                                      note.noteTitle,
                                      style: TextStyle(
                                          fontSize: 16.0, color: Colors.black),
                                    ),
                                  ),
                                  Padding(
                                    padding: EdgeInsets.all(5.0),
                                    child: Text(
                                      note.noteText,
                                      style: TextStyle(color: Colors.black38),
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ),
                                  Container(
                                    alignment: Alignment.centerRight,
                                    padding: EdgeInsets.all(5.0),
                                    child: Text(
                                      formatDateTime(note.noteDate),
                                      style: TextStyle(
                                          color: Colors.black38,
                                          fontSize: 12.0),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          );
                        },
                      );
                  } else {
                    return Center(
                      child: Text('No notes yet!'),
                    );
                  }
                },
              ),
            ),
          ],
        ),
      ),
      floatingActionButtonLocation: FloatingActionButtonLocation.endDocked,
      floatingActionButton: FloatingActionButton(
        onPressed: () {
          setState(() {
            _noteTextController.text = '';
            _noteTitleController.text = '';
            currentEditingNoteId = "";
          });
          _showEdit(context);
        },
        child: Icon(CupertinoIcons.add),
      ),
      bottomNavigationBar: BottomAppBar(
        shape: const CircularNotchedRectangle(),
        child: Row(
          children: <Widget>[
            // IconButton(
            //   icon: Icon(MyFlutterApp.menu),
            //   onPressed: () {
            //     _showMenuModalSheet(context);
            //   },
            // ),
            Visibility(
              visible: isTileView,
              child: IconButton(
                icon: Icon(CupertinoIcons.rectangle_grid_1x2),
                onPressed: () {
                  setState(() {
                    sharedPreferences.setBool("is_tile", false);
                    isTileView = false;
                  });
                },
              ),
            ),
            Visibility(
              visible: !isTileView,
              child: IconButton(
                icon: Icon(CupertinoIcons.rectangle_grid_2x2),
                onPressed: () {
                  setState(() {
                    sharedPreferences.setBool("is_tile", true);
                    isTileView = true;
                  });
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _showOptionsSheet(BuildContext context, Notes _note) {
    showModalBottomSheet(
        context: context,
        builder: (context) {
          return Container(
            padding: EdgeInsets.only(bottom: 20.0),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: <Widget>[
                Padding(
                  padding: const EdgeInsets.all(8.0),
                  child: Row(
                    children: [
                      ColorPalette(
                        color: Color(0xFFA8EAD5),
                        onTap: () => _updateColor(_note.noteId, 0),
                      ),
                      ColorPalette(
                        color: Colors.red.shade300,
                        onTap: () => _updateColor(_note.noteId, 1),
                      ),
                      ColorPalette(
                        color: Colors.pink.shade300,
                        onTap: () => _updateColor(_note.noteId, 2),
                      ),
                      ColorPalette(
                        color: Colors.yellow.shade300,
                        onTap: () => _updateColor(_note.noteId, 3),
                      ),
                      ColorPalette(
                        color: Colors.blue.shade300,
                        onTap: () => _updateColor(_note.noteId, 4),
                      ),
                    ],
                  ),
                ),
                InkWell(
                  onTap: () {
                    Navigator.of(context).pop();
                    setState(() {
                      _noteTextController.text = _note.noteText;
                      _noteTitleController.text = _note.noteTitle;
                      currentEditingNoteId = _note.noteId;
                    });
                    _showEdit(context);
                  },
                  child: Padding(
                    padding: const EdgeInsets.all(8.0),
                    child: Row(
                      children: <Widget>[
                        Padding(
                          padding: const EdgeInsets.all(8.0),
                          child: Icon(CupertinoIcons.pencil),
                        ),
                        Padding(
                          padding: const EdgeInsets.all(8.0),
                          child: Text('Edit'),
                        ),
                      ],
                    ),
                  ),
                ),
                InkWell(
                  onTap: () {
                    Navigator.pop(context);
                    _assignLabel(_note);
                  },
                  child: Padding(
                    padding: const EdgeInsets.all(8.0),
                    child: Row(
                      children: <Widget>[
                        Padding(
                          padding: const EdgeInsets.all(8.0),
                          child: Icon(CupertinoIcons.tag),
                        ),
                        Padding(
                          padding: const EdgeInsets.all(8.0),
                          child: Text('Assign Labels'),
                        ),
                      ],
                    ),
                  ),
                ),
                InkWell(
                  onTap: () {
                    Navigator.of(context).pop();
                    setState(() {
                      currentEditingNoteId = _note.noteId;
                    });
                    _deleteNote();
                  },
                  child: Padding(
                    padding: const EdgeInsets.all(8.0),
                    child: Row(
                      children: <Widget>[
                        Padding(
                          padding: const EdgeInsets.all(8.0),
                          child: Icon(CupertinoIcons.trash),
                        ),
                        Padding(
                          padding: const EdgeInsets.all(8.0),
                          child: Text('Delete'),
                        ),
                      ],
                    ),
                  ),
                ),
                InkWell(
                  onTap: () {
                    Navigator.pop(context);
                  },
                  child: Padding(
                    padding: const EdgeInsets.all(8.0),
                    child: Row(
                      children: <Widget>[
                        Padding(
                          padding: const EdgeInsets.all(8.0),
                          child: Icon(CupertinoIcons.clear),
                        ),
                        Padding(
                          padding: const EdgeInsets.all(8.0),
                          child: Text('Cancel'),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          );
        });
  }

  void _showNoteReader(BuildContext context, Notes _note) {
    Navigator.of(context).push(new MaterialPageRoute<Null>(
      builder: (context) {
        return new Scaffold(
          backgroundColor: NoteColor.getColor(_note.noteColor),
          appBar: AppBar(
            title: Text(
              _note.noteTitle,
              style: TextStyle(color: Colors.black),
            ),
            elevation: 0,
            iconTheme: IconThemeData(color: Colors.black),
            backgroundColor: NoteColor.getColor(_note.noteColor),
          ),
          body: Markdown(
            styleSheet: MarkdownStyleSheet.fromTheme(Theme.of(context).copyWith(
              textTheme: TextTheme(
                bodyText1: TextStyle(color: Colors.black, fontSize: 14),
                bodyText2: TextStyle(color: Colors.black, fontSize: 14),
                headline1: TextStyle(color: Colors.black),
                headline2: TextStyle(color: Colors.black),
                headline3: TextStyle(color: Colors.black),
                headline4: TextStyle(color: Colors.black),
                headline5: TextStyle(color: Colors.black),
                headline6: TextStyle(color: Colors.black),
              ),
            )),
            data: _note.noteText,
            controller: scrollController,
          ),
          bottomNavigationBar: BottomAppBar(
            color: NoteColor.getColor(_note.noteColor),
            child: Padding(
              padding: const EdgeInsets.all(10.0),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      _note.noteLabel.replaceAll(",", ", "),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(color: Colors.black),
                    ),
                  ),
                  Text(formatDateTime(_note.noteDate),
                      style: TextStyle(color: Colors.black)),
                ],
              ),
            ),
          ),
        );
      },
    ));
  }

  void _assignLabel(Notes note) async {
    bool res = await Navigator.of(context).push(new MaterialPageRoute(
        builder: (BuildContext context) => new LabelsPage(
              noteid: note.noteId,
              notelabel: note.noteLabel,
            )));
    if (res ?? false) loadNotes();
  }

  void _showEdit(BuildContext context) {
    Navigator.of(context).push(new MaterialPageRoute(
      builder: (context) {
        return WillPopScope(
          onWillPop: _onBackPressed,
          child: new Scaffold(
              appBar: AppBar(
                backgroundColor: Colors.transparent,
                title: Text('Edit'),
                bottom: PreferredSize(
                  preferredSize: Size.fromHeight(65.0),
                  // child: Container(
                  //   padding:
                  //       EdgeInsets.symmetric(horizontal: 25.0, vertical: 5.0),
                  //   child: TextField(
                  //     textCapitalization: TextCapitalization.sentences,
                  //     controller: _noteTitleController,
                  //     decoration: InputDecoration(
                  //       filled: false,
                  //       hintText: 'Title',
                  //     ),
                  //   ),
                  // ),
                  child: Container(
                    margin: EdgeInsets.symmetric(horizontal: 20.0),
                    padding:
                        EdgeInsets.symmetric(horizontal: 5.0, vertical: 10.0),
                    child: TextField(
                      controller: _noteTitleController,
                      decoration: InputDecoration(
                        prefixIcon: const Icon(
                          CupertinoIcons.doc_text,
                        ),
                        labelText: 'Title',
                        hintStyle: TextStyle(color: Colors.black),
                        border: new OutlineInputBorder(
                            borderSide: new BorderSide(color: Colors.white)),
                      ),
                    ),
                  ),
                ),
              ),
              body: SingleChildScrollView(
                child: Padding(
                  padding: const EdgeInsets.all(20.0),
                  child: Column(
                    children: <Widget>[
                      Container(
                        padding: EdgeInsets.all(10.0),
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(10.0),
                        ),
                        child: TextField(
                          maxLines: 20,
                          textCapitalization: TextCapitalization.sentences,
                          controller: _noteTextController,
                          decoration: InputDecoration.collapsed(
                            hintText: 'Write something here...',
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              bottomNavigationBar: BottomAppBar(
                child: Container(
                  padding: EdgeInsets.only(
                      bottom: MediaQuery.of(context).viewInsets.bottom),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      IconButton(
                        icon: Icon(CupertinoIcons.checkmark_square),
                        onPressed: () {},
                        tooltip: 'Insert Checkbox',
                      ),
                      IconButton(
                        icon: Icon(CupertinoIcons.photo_fill_on_rectangle_fill),
                        onPressed: () {},
                        tooltip: 'Insert Pictures',
                      ),
                      IconButton(
                        icon: Icon(CupertinoIcons.list_bullet),
                        onPressed: () {},
                        tooltip: 'Insert List',
                      ),
                    ],
                  ),
                ),
              )),
        );
      },
    ));
  }

  Future<bool> _onBackPressed() async {
    if (!(_noteTitleController.text.isEmpty ||
        _noteTextController.text.isEmpty)) {
      _saveNote();
    }
    return true;
  }

  // void _showMenuModalSheet(BuildContext context) {
  //   showModalBottomSheet(
  //     context: context,
  //     builder: (context) {
  //       return Container(
  //         height: 150,
  //         padding: EdgeInsets.all(10.0),
  //         child: Column(
  //           mainAxisAlignment: MainAxisAlignment.center,
  //           children: <Widget>[
  //             InkWell(
  //               onTap: () {
  //                 Navigator.pop(context);
  //                 _showAppLock(context);
  //               },
  //               child: Padding(
  //                 padding: const EdgeInsets.symmetric(
  //                     horizontal: 10.0, vertical: 15.0),
  //                 child: Row(
  //                   children: <Widget>[
  //                     Icon(MyFlutterApp.archive),
  //                     Container(
  //                       margin: EdgeInsets.only(right: 10.0),
  //                     ),
  //                     Text('Archived'),
  //                   ],
  //                 ),
  //               ),
  //             ),
  //             InkWell(
  //               onTap: () {
  //                 Navigator.pop(context);
  //                 _showBackupRestore(context);
  //               },
  //               child: Padding(
  //                 padding: const EdgeInsets.symmetric(
  //                     horizontal: 10.0, vertical: 15.0),
  //                 child: Row(
  //                   children: <Widget>[
  //                     Icon(MyFlutterApp.backup),
  //                     Container(
  //                       margin: EdgeInsets.only(right: 10.0),
  //                     ),
  //                     Text('Backup & Restore'),
  //                   ],
  //                 ),
  //               ),
  //             ),
  //           ],
  //         ),
  //       );
  //     },
  //   );
  // }

  // void _showBackupRestore(BuildContext context) {
  //   _getBackupPath();
  //   Navigator.of(context).push(new MaterialPageRoute<Null>(
  //     builder: (context) {
  //       return new Scaffold(
  //         appBar: AppBar(
  //           title: Text('Backup & Restore'),
  //         ),
  //         body: SingleChildScrollView(
  //           child: Container(
  //             padding: EdgeInsets.all(20.0),
  //             child: Column(
  //               crossAxisAlignment: CrossAxisAlignment.stretch,
  //               children: <Widget>[
  //                 Container(
  //                   padding: EdgeInsets.all(20.0),
  //                   child: Text('Path: $backupPath'),
  //                 ),
  //                 Container(
  //                   padding: EdgeInsets.all(20.0),
  //                   child: OutlineButton.icon(
  //                     onPressed: () {
  //                       _makeBackup();
  //                       Navigator.pop(context);
  //                     },
  //                     highlightedBorderColor: Theme.of(context).accentColor,
  //                     highlightColor: Colors.white10,
  //                     icon: Icon(MyFlutterApp.backup),
  //                     label: Text('Backup'),
  //                   ),
  //                 ),
  //                 Container(
  //                   padding: EdgeInsets.all(20.0),
  //                   child: OutlineButton.icon(
  //                     onPressed: () {
  //                       _restore();
  //                       Navigator.pop(context);
  //                     },
  //                     highlightedBorderColor: Theme.of(context).accentColor,
  //                     highlightColor: Colors.white10,
  //                     icon: Icon(MyFlutterApp.restore),
  //                     label: Text('Restore'),
  //                   ),
  //                 ),
  //               ],
  //             ),
  //           ),
  //         ),
  //       );
  //     },
  //   ));
  // }

  Future<void> _getBackupPath() async {
    final _path = await storage.localPath;
    setState(() {
      backupPath = _path;
    });
  }

  Future _makeBackup() async {
    var _notes = await dbHelper.getNotesAll('');
    String out = "";
    _notes.forEach((element) {
      out += "{\"note_id\":\"${element.noteId}\", " +
          "\"note_date\": \"${element.noteDate}\", " +
          "\"note_title\": \"${element.noteTitle}\", " +
          "\"note_text\": \"${element.noteText.replaceAll('\n', '\\n')}\", " +
          "\"note_label\": \"${element.noteLabel}\", " +
          "\"note_archived\": ${element.noteArchived}, " +
          "\"note_color\": ${element.noteColor} },";
    });
    if (_notes.length > 0)
      await storage
          .writeData("[" + out.substring(0, out.length - 1) + "]")
          .then((value) {
        ScaffoldMessenger.of(context).showSnackBar(new SnackBar(
          content: Text('Backup done!'),
          duration: Duration(seconds: 5),
        ));
      });
  }

  Future _restore() async {
    await storage.readData().then((value) {
      final parsed = json.decode(value).cast<Map<String, dynamic>>();
      List<Notes> notesList = [];
      notesList = parsed.map<Notes>((json) => Notes.fromJson(json)).toList();
      dbHelper.deleteNotesAll();
      notesList.forEach((element) {
        dbHelper.insertNotes(new Notes(
            element.noteId,
            element.noteDate,
            element.noteTitle,
            element.noteText,
            element.noteLabel,
            element.noteArchived,
            element.noteColor ?? 0));
      });
      loadNotes();
      ScaffoldMessenger.of(context).showSnackBar(new SnackBar(
        content: Text('Backup restored!'),
        duration: Duration(seconds: 5),
      ));
    });
  }

  void _showAppLock(BuildContext context) {
    Navigator.of(context).push(new MaterialPageRoute<Null>(builder: (context) {
      return new Scaffold(
        appBar: AppBar(
          title: Text('Manage Pin'),
        ),
        body: SingleChildScrollView(
          child: Container(
            padding: EdgeInsets.all(20.0),
            child: Column(
              children: [
                TextField(
                  decoration: InputDecoration(
                    labelText: 'Old Pin',
                  ),
                ),
                TextField(
                  decoration: InputDecoration(
                    labelText: 'New Pin',
                  ),
                ),
                TextField(
                  decoration: InputDecoration(
                    labelText: 'Confirm Pin',
                  ),
                ),
              ],
            ),
          ),
        ),
      );
    }));
  }

  String getDateString() {
    var formatter = new DateFormat('yyyy-MM-dd HH:mm:ss');
    DateTime dt = DateTime.now();
    return formatter.format(dt);
  }

  String formatDateTime(String dateTime) {
    var formatter = new DateFormat('MMM dd, yyyy');
    var formatter2 = new DateFormat('hh:mm a');
    DateTime dt = DateTime.parse(dateTime);
    if (dt.day == DateTime.now().day)
      return formatter2.format(dt);
    else
      return formatter.format(dt);
  }
}
