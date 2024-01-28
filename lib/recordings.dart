import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
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
          } else if (!snapshot.hasData || snapshot.data!.isEmpty) {
            return Center(
                child: Column(
              children: [
                const Text('No recordings available.'),
                GestureDetector(
                  onTap: () {
                    copyWavFileFromAssets();
                  },
                  child: Container(
                    padding: const EdgeInsets.all(10.0),
                    width: 130.0,
                    height: 50.0,
                    decoration: BoxDecoration(
                      color: Colors.red,
                      borderRadius: BorderRadius.circular(10.0),
                    ),
                    child: const Text("Copy Wav File",
                        style: TextStyle(
                            color: Colors.white, fontWeight: FontWeight.bold)),
                  ),
                ),
              ],
            ));
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
                              padding:
                                  const EdgeInsets.symmetric(vertical: 8.0),
                              child:
                                  PlayerWidget(player: audioPlayers[index])));
                    },
                  ),
                ),
                // GestureDetector(
                //   onTap: () {
                //     copyWavFileFromAssets();
                //   },
                //   child: Container(
                //     padding: const EdgeInsets.all(10.0),
                //     width: 130.0,
                //     height: 50.0,
                //     decoration: BoxDecoration(
                //       color: Colors.red,
                //       borderRadius: BorderRadius.circular(10.0),
                //     ),
                //     child: const Text("Copy Wav File",
                //         style: TextStyle(
                //             color: Colors.white, fontWeight: FontWeight.bold)),
                //   ),
                // ),
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

  Future<void> copyWavFileFromAssets() async {
    // Get the current date and time
    DateTime now = DateTime.now();
    String timestamp =
        '${now.year}_${now.month}_${now.day}_${now.hour}_${now.minute}_${now.second}';

    // Get the application documents directory
    Directory appDocDir = await getApplicationDocumentsDirectory();
    String appDocPath = appDocDir.path;

    // Construct the file path with a timestamp for the WAV file in the documents directory
    String filePath = '$appDocPath/wavfile_$timestamp.wav';

    // Check if the file already exists to avoid overwriting
    int index = 1;
    while (File(filePath).existsSync()) {
      // If the file exists, modify the file name by adding an index
      filePath = '$appDocPath/wavfile_${timestamp}_$index.wav';
      index++;
    }

    // Copy the WAV file from assets to the documents directory
    ByteData data = await rootBundle.load('assets/sounds/metronome-60bpm.mp3');
    List<int> bytes = data.buffer.asUint8List();
    await File(filePath).writeAsBytes(bytes);

    // Show a SnackBar after saving
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('file saved successfully.'),
      ),
    );
  }
}
