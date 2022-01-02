import 'dart:convert';
import 'dart:io';
import 'dart:math';
import 'package:path_provider/path_provider.dart';
import 'package:flutter/material.dart';
import 'package:device_apps/device_apps.dart';
import 'package:flutter/painting.dart';
import 'package:intent/intent.dart' as android_intent;
import 'package:intent/action.dart' as android_action;

void main() {
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({Key? key}) : super(key: key);

  // This widget is the root of your application.
  @override
  Widget build(BuildContext context) {
    return RootRestorationScope(
      // <--fix
      restorationId: 'root',
      child: MaterialApp(
        title: 'Buttons test',
        theme: ThemeData(
          // This is the theme of your application.
          //
          // Try running your application with "flutter run". You'll see the
          // application has a blue toolbar. Then, without quitting the app, try
          // changing the primarySwatch below to Colors.green and then invoke
          // "hot reload" (press "r" in the console where you ran "flutter run",
          // or simply save your changes to "hot reload" in a Flutter IDE).
          // Notice that the counter didn't reset back to zero; the application
          // is not restarted.
          primarySwatch: Colors.blue,
        ),
        home: const MyHomePage(),
      ),
    );
  }
}

class MyHomePage extends StatefulWidget {
  const MyHomePage({Key? key}) : super(key: key);

  @override
  State<MyHomePage> createState() => MyHomeWidgetState();
}

class MyHomeWidgetState extends State<MyHomePage> {
  final List<App> _apps = [];
  late List<List<GreedHelper>> data = List.generate(
      7, (int ind) => List.generate(5, (int ind) => GreedHelper(false, null)));
  bool hover = false;
  double progress = 0;

  Future<String> get _localPath async {
    final directory = await getApplicationDocumentsDirectory();

    return directory.path;
  }

  Future<File> get _localFile async {
    final path = await _localPath;
    return File('$path/greed.json');
  }

  Future<String> read() async {
    try {
      final file = await _localFile;

      // Read the file
      final contents = await file.readAsString();

      return contents;
    } catch (e) {
      // If encountering an error, return 0
      write('[[]]');
      return await read();
    }
  }

  Future<File> write(String data) async {
    final file = await _localFile;

    // Write the file
    return file.writeAsString(data);
  }

  fromJson(List parsedJson) async {
    for (int y = 0; y < parsedJson.length; y++) {
      for (int x = 0; x < parsedJson[y].length; x++) {
        GreedHelper gr;
        if (parsedJson[y][x]['isFolder'] == true) {
          Folder folder = Folder.fromJson(parsedJson[y][x]);
          folder.onAdd = onAdd;
          gr = GreedHelper(false, folder);
        } else if (parsedJson[y][x]['isFolder'] == false) {
          gr = GreedHelper(false, await App.fromJson(parsedJson[y][x]));
        } else {
          gr = GreedHelper(false, null);
        }
        data[y][x] = gr;
      }
    }
    setState(() {});
  }

  List<List<Map<String, dynamic>>> toJson() {
    return List.generate(
        data.length,
        (index) => List.generate(data[index].length, (i) {
              Map<String, dynamic> obj = {};
              GreedHelper gr = data[index][i];
              Widget? app = gr.body;
              if (app is App) {
                obj = app.toJson();
                obj['x'] = i;
                obj['y'] = index;
              }
              if (app is Folder) {
                obj = app.toJson();
                obj['x'] = i;
                obj['y'] = index;
              }
              return obj;
            }));
  }

  save() {
    write(jsonEncode(toJson()));
  }

  @override
  initState() {
    super.initState();
    loadApps();
  }

  onAdd(y, x) {
    setState(() {
      hover = false;
    });
    if (x != -1 && y != -1) {
      data[y][x].body = null;
    }
  }

  loadApps() async {
    List<Application> apps = await DeviceApps.getInstalledApplications(
      includeSystemApps: true,
      includeAppIcons: true,
      onlyAppsWithLaunchIntent: true,
    );
    int i = 0;
    for (var app in apps) {
      if (app is ApplicationWithIcon) {
        i++;
        progress = i * 100 / apps.length;
        _apps.add(
          App(
            data: app,
            size: 5,
          ),
        );
      }
    }
    fromJson(jsonDecode(await read()));
    setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    // TODO: implement build
    double q = MediaQuery.of(context).size.width / 5;
    return Scaffold(
      backgroundColor: Colors.grey.shade200,
      body: SafeArea(
        child: Column(
          children: [
            DragTarget(
              onAccept: (item) {
                if (item is Folder && item.lastX != -1) {
                  data[item.lastY][item.lastX].body = null;
                }
                if (item is App && item.lastX != -1) {
                  data[item.lastY][item.lastX].body = null;
                }
                hover = false;
              },
              onLeave: (item) {
                hover = false;
              },
              onMove: (item) {
                hover = true;
              },
              builder: (BuildContext context, List<Object?> candidateData,
                  List<dynamic> rejectedData) {
                return SizedBox(
                  height: q * 7,
                  child: Row(
                    children: [
                      Visibility(
                        visible: hover,
                        child: DragTarget(
                          onAccept: (item) {
                            if (item is App) {
                              setState(() {
                                hover = false;
                              });
                              item.data.openSettingsScreen();
                            }
                          },
                          builder: (BuildContext context,
                              List<Object?> candidateData,
                              List<dynamic> rejectedData) {
                            return SizedBox(
                              width: q / 2 - 1,
                              child: const Center(
                                child: Icon(
                                  Icons.info_outline_rounded,
                                  color: Colors.blue,
                                ),
                              ),
                            );
                          },
                        ),
                      ),
                      Container(
                        decoration:
                            BoxDecoration(border: !hover ? null : Border.all()),
                        child: Column(
                          children: [
                            buildGreed(q),
                            Expanded(
                              child: GestureDetector(
                                onTap: () {
                                  setState(() {
                                    hover = false;
                                  });
                                },
                                child: Center(
                                  child: Visibility(
                                    visible: hover,
                                    child: const Icon(
                                      Icons.close,
                                      color: Colors.redAccent,
                                      size: 50,
                                    ),
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                      Visibility(
                        visible: hover,
                        child: DragTarget(
                          onAccept: (item) {
                            if (item is App) {
                              setState(() {
                                hover = false;
                              });
                              android_intent.Intent()
                                ..setAction(android_action.Action.ACTION_DELETE)
                                ..setData(Uri.parse(
                                    "package:${item.data.packageName}"))
                                ..startActivityForResult().then((data) {
                                  print(data);
                                }, onError: (e) {
                                  print(e);
                                });
                            }
                          },
                          builder: (BuildContext context,
                              List<Object?> candidateData,
                              List<dynamic> rejectedData) {
                            return SizedBox(
                              width: q / 2 - 1,
                              child: const Center(
                                child: Icon(
                                  Icons.delete,
                                  color: Colors.red,
                                ),
                              ),
                            );
                          },
                        ),
                      ),
                    ],
                  ),
                );
              },
            ),
            Expanded(
              child: Container(
                decoration: const BoxDecoration(
                  borderRadius:
                      BorderRadius.vertical(top: Radius.circular(15.0)),
                  color: Colors.white,
                  boxShadow: [
                    BoxShadow(
                      color: Colors.grey,
                      offset: Offset(0.0, 1.0), //(x,y)
                      blurRadius: 5.0,
                    ),
                  ],
                ),
                child: _apps.isNotEmpty ? SingleChildScrollView(
                  child: Wrap(
                    children: _apps,
                  ),
                ) : Center(
                  child: LinearProgressIndicator(
                    value: progress,
                    semanticsLabel: 'Loading...',
                  ),
                )
              ),
            ),
          ],
        ),
      ),
    );
  }

  Column buildGreed(double q) {
    return Column(
      children: List<Widget>.generate(
        7,
        (int y) => Row(
          children: List<Widget>.generate(
            5,
            (int x) => DragTarget(
              builder: (BuildContext context, List<Object?> candidateData,
                  List<dynamic> rejectedData) {
                return Container(
                  decoration: BoxDecoration(
                    color: hover ? Colors.white : Colors.transparent,
                    borderRadius: const BorderRadius.horizontal(
                        left: Radius.circular(15), right: Radius.circular(15)),
                  ),
                  width: !hover ? q.toDouble() : q.toDouble() - q / 5,
                  height: !hover ? q.toDouble() : q.toDouble() - q / 5,
                  child: data[y][x].body,
                );
              },
              onMove: (item) {
                setState(() {
                  data[y][x].onMe = true;
                  hover = true;
                });
              },
              onAccept: (item) {
                if (item is Folder) {
                  if (item.lastX != -1 && item.lastY != -1) {
                    data[item.lastY][item.lastX].body = null;
                  }
                  hover = false;
                  item.lastX = x;
                  item.lastY = y;
                  data[y][x].body = item;
                  data[y][x].onMe = false;
                }
                if (item is App) {
                  if (item.lastX != -1 && item.lastY != -1) {
                    data[item.lastY][item.lastX].body = null;
                  }
                  hover = false;
                  item.lastX = x;
                  item.lastY = y;
                  data[y][x].onMe = false;
                  Widget? f = data[y][x].body;

                  if (f is App) {
                    Folder fold =
                        Folder(apps: [f.data, item.data], onAdd: onAdd);
                    fold.lastY = y;
                    fold.lastX = x;
                    data[y][x].body = fold;
                  } else {
                    data[y][x].body = item;
                  }
                }
                save();
                setState(() {});
              },
              onLeave: (item) {
                data[y][x].onMe = false;
              },
            ),
          ),
        ),
      ),
    );
  }
}

class App extends StatelessWidget {
  ApplicationWithIcon data;
  int size;
  bool vis = true;
  late Size wh;
  int lastX = -1;
  int lastY = -1;

  App({Key? key, required this.data, required this.size}) : super(key: key);

  static fromJson(Map<String, dynamic> parsedJson) async {
    String packageName = parsedJson['app'];
    App myApp;
    Application? ap = await DeviceApps.getApp(packageName, true);
    if (ap is ApplicationWithIcon) {
      myApp = App(
        size: 5,
        data: ap,
      );

      myApp.lastX = parsedJson['x'];
      myApp.lastY = parsedJson['y'];
      return myApp;
    }
  }

  Map<String, dynamic> toJson() {
    return {
      "isFolder": false,
      "app": data.packageName,
      "x": lastX,
      "y": lastY,
    };
  }

  get copy {
    return Container(
      padding: const EdgeInsets.all(10),
      width: wh.width / size,
      height: wh.width / size,
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Expanded(
            flex: 2,
            child: Image.memory(data.icon),
          ),
          Center(
            child: Text(
              data.appName.substring(
                  0, data.appName.length <= 10 ? data.appName.length : 10),
              maxLines: 1,
              style: const TextStyle(
                fontSize: 10,
                color: Colors.black,
                inherit: false,
              ),
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    wh = MediaQuery.of(context).size;
    return LongPressDraggable(
      data: this,
      feedback: copy,
      onDragStarted: () {
        vis = false;
      },
      onDragEnd: (it) {
        vis = true;
      },
      onDragCompleted: () {
        vis = true;
      },
      onDraggableCanceled: (it, it2) {
        vis = true;
      },
      child: GestureDetector(
        onTap: () {
          data.openApp();
        },
        child: Visibility(
          visible: vis,
          child: Container(
            padding: const EdgeInsets.all(10),
            width: wh.width / size,
            height: wh.width / size,
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                Expanded(
                  flex: 2,
                  child: Image.memory(data.icon),
                ),
                Center(
                  child: Text(
                    data.appName.substring(0,
                        data.appName.length <= 10 ? data.appName.length : 10),
                    maxLines: 1,
                    style: const TextStyle(
                      fontSize: 10,
                      color: Colors.black,
                      inherit: false,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class GreedHelper {
  bool onMe;
  Widget? body;

  GreedHelper(this.onMe, this.body);
}

class Folder extends StatefulWidget {
  List<ApplicationWithIcon> apps;
  int lastX = -1;
  int lastY = -1;
  Function? onAdd;

  Folder({Key? key, required this.apps, this.onAdd}) : super(key: key);

  factory Folder.fromJson(Map<String, dynamic> parsedJson) {
    List packageNames = parsedJson['apps'];
    List<ApplicationWithIcon> appsList = [];
    for (String i in packageNames) {
      DeviceApps.getApp(i, true).then((value) {
        if (value is ApplicationWithIcon) {
          appsList.add(value);
        }
      });
    }
    Folder folder = Folder(
      apps: appsList,
    );
    folder.lastX = parsedJson['x'];
    folder.lastY = parsedJson['y'];
    return folder;
  }

  Map<String, dynamic> toJson() {
    return {
      "isFolder": true,
      "apps": List.generate(apps.length, (i) => apps[i].packageName),
      "x": lastX,
      "y": lastY,
    };
  }

  @override
  _FolderState createState() => _FolderState();
}

class _FolderState extends State<Folder> {
  bool closed = true;
  late double wh;
  bool vis = true;

  closedFolder() {
    List<Widget> icons = [];
    // if (widget.apps.length == 1) {
    //   App app = App(
    //     data: widget.apps.first,
    //     size: 5,
    //   );
    //   app.lastX = widget.lastX;
    //   app.lastY = widget.lastY;
    //   Navigator.pop(context);
    //   return app;
    // }
    for (int i = 0; i < min(4, widget.apps.length); i++) {
      icons.add(
        Container(
          margin: EdgeInsets.all(wh / 14 / 14 / 2),
          child: Image.memory(
            widget.apps[i].icon,
            width: wh / 12,
            height: wh / 12,
          ),
        ),
      );
    }
    return LongPressDraggable(
      data: super.widget,
      feedback: Container(
        decoration: BoxDecoration(
          border: Border.all(),
          borderRadius: BorderRadius.circular(10),
        ),
        child: Center(
          child: Wrap(
            children: icons,
          ),
        ),
      ),
      child: GestureDetector(
        onTap: () {
          closed = false;
          openedFolder();
        },
        child: DragTarget(
          builder: (BuildContext context, List<Object?> candidateData,
              List<dynamic> rejectedData) {
            return Container(
              decoration: BoxDecoration(
                  border: Border.all(),
                  borderRadius: BorderRadius.circular(10)),
              child: Center(
                child: SingleChildScrollView(
                  child: Wrap(
                    children: icons,
                  ),
                ),
              ),
            );
          },
          onAccept: (App app) {
            widget.apps.add(app.data);
            setState(() {});
            widget.onAdd!(app.lastY, app.lastX);
          },
        ),
      ),
    );
  }

  openedFolder() {
    List<Widget> l = List.generate(
      widget.apps.length,
      (index) => App(
        data: widget.apps[index],
        size: 5,
      ),
    );
    closed = true;
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (builder) {
        return Container(
          color: Colors.transparent,
          child: Column(
            children: [
              Expanded(
                child: DragTarget(
                  builder: (BuildContext context, List<Object?> candidateData,
                      List<dynamic> rejectedData) {
                    return GestureDetector(
                      onTap: () {
                        Navigator.pop(context);
                      },
                      child: const CircleAvatar(
                        backgroundColor: Colors.red,
                        radius: 40,
                        child: Icon(
                          Icons.close,
                          color: Colors.white,
                          size: 40,
                        ),
                      ),
                    );
                  },
                  onAccept: (App? i) {
                    widget.apps.removeWhere(
                        (item) => item.packageName == i!.data.packageName);
                    Navigator.pop(context);
                    openedFolder();
                    setState(() {});
                  },
                ),
              ),
              Expanded(
                flex: 2,
                child: Container(
                  width: wh / 5 * 4,
                  decoration: const BoxDecoration(
                    borderRadius:
                        BorderRadius.vertical(top: Radius.circular(15.0)),
                    color: Colors.white,
                    boxShadow: [
                      BoxShadow(
                        color: Colors.grey,
                        offset: Offset(0.0, 1.0), //(x,y)
                        blurRadius: 5.0,
                      ),
                    ],
                  ),
                  child: SingleChildScrollView(
                    child: Wrap(
                      children: l,
                    ),
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    wh = MediaQuery.of(context).size.width;
    return closed
        ? Visibility(
            child: closedFolder(),
            visible: vis,
          )
        : openedFolder();
  }
}
