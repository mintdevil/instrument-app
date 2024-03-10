import 'dart:io';
import 'package:flutter/material.dart';
import 'package:path_provider/path_provider.dart';
import 'package:audioplayers/audioplayers.dart';
import 'player_widget.dart';

class RecordingsPage extends StatefulWidget {
  const RecordingsPage({super.key});

  @override
  RecordingsPageState createState() => RecordingsPageState();
}

class RecordingsPageState extends State<RecordingsPage> {
  bool isPlaying = false;

  int selectedPlayerIdx = 0;

  late List<AudioPlayer> audioPlayers;

  @override
  void initState() {
    super.initState();
  }

  void showDeleteConfirmationDialog(BuildContext context, String filePath, String fileName) {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          backgroundColor: Colors.white,
          title: Text('Are you sure you want to delete $fileName?', textAlign: TextAlign.center),
          actions: <Widget>[
            TextButton(
              onPressed: () {
                Navigator.of(context).pop(); // Close the dialog
              },
              style: TextButton.styleFrom(
                backgroundColor: Colors.grey,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10.0), 
                ),
              ),
              child: const Text('Cancel', style: TextStyle(color: Colors.white)),
            ),
            TextButton(
              onPressed: () async {
                await deleteRecording(filePath);
                setState(() {});
                Navigator.of(context).pop(); // Close the dialog
              },
              style: TextButton.styleFrom(
                backgroundColor: Colors.red,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10.0), 
                ),
              ),
              child: const Text('Delete', style: TextStyle(color: Colors.white)),
            ),
          ],
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Recordings'),
      ),
      body: FutureBuilder<List<String>>(
        future: _getRecordings(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(
              child: CircularProgressIndicator(),
            );
          } else if (snapshot.hasError) {
            return Center(
              child: Text('Error: ${snapshot.error}'),
            );
          } else {
            List<AudioPlayer> audioPlayers = List.generate(
              snapshot.data?.length ?? 0,
              (_) => AudioPlayer()..setReleaseMode(ReleaseMode.stop),
            );

            return Column(
              children: [
                Expanded(
                  child: ListView.builder(
                    itemCount: snapshot.data?.length ?? 0,
                    itemBuilder: (context, index) {
                      String filePath = snapshot.data?.elementAt(index) ?? "";
                      String fileName = filePath.split('/').last;
                      audioPlayers[index].setSource(DeviceFileSource(filePath));

                      return ListTile(
                          title: Center(
                              child: Text(fileName,
                                  style: const TextStyle(
                                      fontWeight: FontWeight.bold))),
                          onTap: () {
                            setState(() {
                              selectedPlayerIdx = index;
                            });
                          },
                          subtitle: Padding(
                            padding: const EdgeInsets.symmetric(vertical: 8.0),
                            child: Row(
                              children: [
                                Expanded(
                                  child: PlayerWidget(player: audioPlayers[index]),
                                ),
                                IconButton(
                                  icon: const Icon(Icons.delete),
                                  onPressed: () {
                                    showDeleteConfirmationDialog(context, filePath, fileName);
                                  },
                                ),
                              ],
                            ),
                          ));
                    },
                  ),
                ),
              ],
            );
          }
        },
      ),
    );
  }

  Future<List<String>> _getRecordings() async {
    Directory appDocDir = await getApplicationDocumentsDirectory();
    String appDocPath = appDocDir.path;

    List<FileSystemEntity> files =
        Directory(appDocPath).listSync().where((entity) {
      return entity.path.endsWith('.wav');
    }).toList();

    return files.map((file) => file.path).toList();
  }

  Future<void> deleteRecording(String filePath) async {
    File file = File(filePath);
    await file.delete();
  }
}
