import 'dart:async';
import 'dart:io';
import 'package:audioplayers/audioplayers.dart';
import 'package:carousel_slider/carousel_slider.dart';
import 'package:flutter_spinkit/flutter_spinkit.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:path_provider/path_provider.dart';
import 'package:timer_count_down/timer_count_down.dart';
import 'package:wav/wav.dart';
import './helpers/shake.dart';
import './helpers/audio_processing.dart';
import 'player_widget.dart';
import 'recordings.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();

  SystemChrome.setPreferredOrientations([
    DeviceOrientation.portraitUp,
  ]);

  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Instruments Demo',
      theme: ThemeData(),
      home: const MyHomePage(),
    );
  }
}

class MyHomePage extends StatefulWidget {
  const MyHomePage({super.key});

  @override
  State<MyHomePage> createState() => _MyHomePageState();
}

class _MyHomePageState extends State<MyHomePage> with WidgetsBindingObserver {
  List<String> instruments = [
    'shaker',
    'tambourine',
    'cabasa',
    'guiro',
    'drum',
    'hi-hat',
    'cymbal',
  ];

  final metronome1 = AudioPlayer();
  final metronome2 = AudioPlayer();
  final recordingPlayer = AudioPlayer();

  void _playSound(String instrument, double loudness) {
    final player = AudioPlayer();
    player.setPlayerMode(PlayerMode.lowLatency);
    if (volumeFixed) {
      player.setVolume(fixedVolume);
    } else {
      player.setVolume(loudness);
    }
    if (isRecording) {
      timestamps.add(DateTime.now().millisecondsSinceEpoch - timestamps[0]);
      if (volumeFixed) {
        volumes.add(fixedVolume);
      } else {
        volumes.add(loudness);
      }
    }
    switch (instrument) {
      case "drum":
        if (selectedDrum == "kick") {
          player.play(AssetSource('sounds/kick-drum.wav'));
        } else {
          player.play(AssetSource('sounds/snare-drum.wav'));
        }
        break;
      case "hi-hat":
        if (selectedHiHat == "closed") {
          player.play(AssetSource('sounds/hi-hat-closed.wav'));
        } else {
          player.play(AssetSource('sounds/hi-hat-open.wav'));
        }
        break;
      default:
        player.play(AssetSource('sounds/$instrument.wav'));
        break;
    }
  }

  Future<Uint8List> getInstrumentBytes(String instrument) async {
    ByteData data;
    switch (instrument) {
      case "drum":
        if (selectedDrum == "kick") {
          data = await rootBundle.load('assets/sounds/kick-drum.bin');
        } else {
          data = await rootBundle.load('assets/sounds/snare-drum.bin');
        }
      case "hi-hat":
        if (selectedHiHat == "closed") {
          data = await rootBundle.load('assets/sounds/hi-hat-closed.bin');
        } else {
          data = await rootBundle.load('assets/sounds/hi-hat-open.bin');
        }
      default:
        data = await rootBundle.load('assets/sounds/$instrument.bin');
    }
    return data.buffer.asUint8List();
  }

  int _currentIndex = 0;
  bool isMetronomeOn = false;
  double metronomeSpeed = 60;
  bool isRecording = false;
  List<double> timestamps = [];
  List<double> volumes = [];
  Wav? recording;
  late ShakeDetector detector;
  String selectedDrum = "kick";
  String selectedHiHat = "closed";
  bool volumeFixed = false;
  double fixedVolume = 1.0;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);

    detector = ShakeDetector.autoStart(
      onPhoneShake: (double loudness) {
        _playSound(instruments[_currentIndex], loudness);
      },
    );
    metronome1.setSourceAsset('sounds/metronome-60bpm.mp3');
    metronome1.setReleaseMode(ReleaseMode.loop);
    metronome1.setPlayerMode(PlayerMode.lowLatency);
    metronome1.onPlayerComplete.listen((_) => metronome2.resume());

    metronome2.setSourceAsset('sounds/metronome-60bpm.mp3');
    metronome2.setReleaseMode(ReleaseMode.loop);
    metronome2.setPlayerMode(PlayerMode.lowLatency);
    metronome2.onPlayerComplete.listen((_) => metronome1.resume());

    recordingPlayer.setReleaseMode(ReleaseMode.stop);
  }

  @override
  void dispose() {
    detector.stopListening();
    setState(() {
      if (isMetronomeOn) {
        isMetronomeOn = false;
      }
    });
    metronome1.stop();
    metronome2.stop();
    recordingPlayer.stop();
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      // App is resumed (brought to the foreground)
      detector.startListening();
    } else if (state == AppLifecycleState.paused) {
      // App is in background or inactive (user just exited the app)
      detector.stopListening();
      setState(() {
        if (isMetronomeOn) {
          isMetronomeOn = false;
        }
      });
      metronome1.stop();
      metronome2.stop();
      recordingPlayer.stop();
    }
  }

  Color _getPageColor(int index) {
    List<Color> pageColors = [
      Colors.purple,
      Colors.blue,
      Colors.green,
      Colors.red,
      Colors.orange,
      Colors.brown,
      Colors.indigo
    ];

    return pageColors[index % pageColors.length];
  }

  Future<void> _showMetronomeSpeedDialog(BuildContext context) async {
    return showDialog(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text('Set Metronome Speed'),
          content: StatefulBuilder(
            builder: (BuildContext context, StateSetter setState) {
              return Column(
                mainAxisSize: MainAxisSize.min,
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Align(
                    alignment: Alignment.center,
                    child: Text(
                      'Current Speed: ${metronomeSpeed.round()} BPM',
                      textAlign: TextAlign.center,
                    ),
                  ),
                  Slider(
                    value: metronomeSpeed,
                    min: 35.0,
                    max: 250.0,
                    divisions: 180,
                    onChanged: (value) async {
                      setState(() {
                        metronomeSpeed = value;
                      });
                      await metronome1.setPlaybackRate(metronomeSpeed / 60);
                      await metronome2.setPlaybackRate(metronomeSpeed / 60);
                    },
                    activeColor: _getPageColor(_currentIndex),
                    inactiveColor: Colors.grey,
                  ),
                  ElevatedButton(
                    onPressed: () {
                      Navigator.of(context).pop();
                      metronome1.resume();
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: _getPageColor(_currentIndex),
                    ),
                    child:
                        const Text('OK', style: TextStyle(color: Colors.white)),
                  ),
                ],
              );
            },
          ),
        );
      },
    );
  }

  Future<void> _showVolumeDialog(BuildContext context) {
    return showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text('Set Volume'),
          content: StatefulBuilder(
            builder: (BuildContext context, StateSetter setState) {
              return Column(
                mainAxisSize: MainAxisSize.min,
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Align(
                    alignment: Alignment.center,
                    child: Text(
                      'Current Volume: $fixedVolume',
                      textAlign: TextAlign.center,
                    ),
                  ),
                  Slider(
                    value: fixedVolume,
                    min: 0.0,
                    max: 1.0,
                    divisions: 10,
                    onChanged: (value) {
                      setState(() {
                        fixedVolume = value;
                      });
                    },
                    activeColor: _getPageColor(_currentIndex),
                    inactiveColor: Colors.grey,
                  ),
                  ElevatedButton(
                    onPressed: () {
                      Navigator.of(context).pop();
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: _getPageColor(_currentIndex),
                    ),
                    child:
                        const Text('OK', style: TextStyle(color: Colors.white)),
                  ),
                ],
              );
            },
          ),
        );
      },
    );
  }

  void showRecordingOptions(BuildContext context) async {
    Wav mixedSound = mixSounds(timestamps.sublist(1), volumes,
        await getInstrumentBytes(instruments[_currentIndex]), metronomeSpeed,
        existingWav: recording);
    AudioPlayer player = AudioPlayer()
      ..setReleaseMode(ReleaseMode.stop)
      ..setSourceBytes(mixedSound.write());
    // ignore: use_build_context_synchronously
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          backgroundColor: Colors.white,
          title: const Text('Recording Options', textAlign: TextAlign.center),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              PlayerWidget(player: player),
              const SizedBox(height: 20),
              ElevatedButton(
                onPressed: () {
                  player.stop();
                  Navigator.of(context).pop();
                  // reset variables
                  setState(() {
                    timestamps = [];
                    volumes = [];
                  });
                },
                child: Text('Re-record',
                    style: TextStyle(color: _getPageColor(_currentIndex))),
              ),
              ElevatedButton(
                onPressed: () {
                  player.stop();
                  setState(() {
                    recording = mixedSound;
                    timestamps = [];
                    volumes = [];
                  });
                  Navigator.of(context).pop();
                },
                child: Text('Continue Overlaying Sounds',
                    style: TextStyle(color: _getPageColor(_currentIndex))),
              ),
              ElevatedButton(
                onPressed: () async {
                  player.stop();
                  recording = mixedSound;
                  String? fileName = await showFileNameInputDialog(context);
                  // Get the application documents directory
                  Directory appDocDir =
                      await getApplicationDocumentsDirectory();
                  String appDocPath = appDocDir.path;
                  while (fileName != null &&
                      fileName.isNotEmpty &&
                      File(fileName).existsSync()) {
                    // ignore: use_build_context_synchronously
                    fileName = await showFileNameInputDialog(context);
                  }
                  if (fileName == null) {
                    // Get the current date and time
                    DateTime now = DateTime.now();
                    String timestamp =
                        '${now.year}_${now.month}_${now.day}_${now.hour}_${now.minute}_${now.second}';
                    fileName = 'recording_$timestamp';
                  }

                  File file = File('$appDocPath/$fileName.wav');
                  await file.writeAsBytes(recording!.write());

                  // reset variables
                  setState(() {
                    recording = null;
                    timestamps = [];
                    volumes = [];
                  });
                  Navigator.of(context).pop();
                },
                child: Text('Stop Overlaying and Save',
                    style: TextStyle(color: _getPageColor(_currentIndex))),
              ),
            ],
          ),
        );
      },
    );
  }

  Future<String?> showFileNameInputDialog(BuildContext context) {
    TextEditingController controller = TextEditingController();
    return showDialog<String>(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text('Enter File Name', textAlign: TextAlign.center),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: controller,
                decoration: const InputDecoration(hintText: 'File Name'),
              ),
              const Text('.wav', style: TextStyle(fontSize: 12.0)),
            ],
          ),
          actions: <Widget>[
            TextButton(
              onPressed: () {
                Navigator.of(context).pop(controller.text);
              },
              child: const Text('OK'),
            ),
          ],
        );
      },
    );
  }

  void showCountdownDialog() {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
            content: Countdown(
          seconds: 3,
          build: (BuildContext context, double time) => Text(
            time.toString(),
            style: const TextStyle(fontSize: 50),
            textAlign: TextAlign.center,
          ),
          interval: const Duration(milliseconds: 1000),
          onFinished: () async {
            Navigator.of(context).pop();
            if (recording != null) {
              await recordingPlayer.setSourceBytes(recording!.write());
              recordingPlayer.resume();
            }
            if (!isMetronomeOn) {
              setState(() {
                isMetronomeOn = true;
              });
              metronome1.resume();
            } else {
              metronome1.stop();
              metronome2.stop();
              metronome1.resume();
            }
            timestamps = [DateTime.now().millisecondsSinceEpoch.toDouble()];
          },
        ));
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
          decoration: BoxDecoration(
              color: _getPageColor(_currentIndex).withOpacity(0.1)),
          child: Stack(
            children: <Widget>[
              // metronome (top right)
              Positioned(
                top: 60.0,
                right: 0.0,
                child: GestureDetector(
                  onTap: () {
                    setState(() {
                      isMetronomeOn = !isMetronomeOn;
                    });

                    if (isMetronomeOn) {
                      _showMetronomeSpeedDialog(context);
                    } else {
                      metronome1.stop();
                      metronome2.stop();
                    }
                  },
                  child: Padding(
                    padding: const EdgeInsets.all(20.0),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Image.asset(
                          'assets/images/metronome.png',
                          width: 50,
                          height: 50,
                          fit: BoxFit.contain,
                        ),
                        const SizedBox(height: 8),
                        Text(
                          isMetronomeOn ? 'On' : 'Off',
                          style: const TextStyle(fontSize: 16),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
              // set volume (top right below metronome)
              Positioned(
                top: 160.0,
                right: 0.0,
                child: GestureDetector(
                  onTap: () {
                    setState(() {
                      volumeFixed = !volumeFixed;
                    });
                    if (volumeFixed) {
                      _showVolumeDialog(context);
                    }
                  },
                  child: Padding(
                    padding: const EdgeInsets.all(20.0),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Image.asset(
                          'assets/images/volume.png',
                          width: 40,
                          height: 40,
                          fit: BoxFit.contain,
                        ),
                        const SizedBox(height: 8),
                        Text(
                          volumeFixed ? 'Fixed' : 'Variable',
                          style: const TextStyle(fontSize: 16),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
              // recording (top left)
              Positioned(
                  top: 60.0,
                  left: 0.0,
                  child: GestureDetector(
                    onTap: () {
                      setState(() {
                        isRecording = !isRecording;
                      });

                      if (isRecording) {
                        showCountdownDialog();
                      } else {
                        setState(() {
                          isMetronomeOn = false;
                        });
                        metronome1.stop();
                        metronome2.stop();
                        recordingPlayer.stop();
                        showRecordingOptions(context);
                      }
                    },
                    child: AnimatedContainer(
                      margin: const EdgeInsets.all(20.0),
                      duration: const Duration(milliseconds: 300),
                      curve: Curves.easeInOut,
                      width: 60.0,
                      height: 60.0,
                      decoration: BoxDecoration(
                        color: isRecording
                            ? Colors.red
                            : _getPageColor(_currentIndex).withOpacity(0.5),
                        borderRadius: BorderRadius.circular(40.0),
                      ),
                      child: Center(
                        child: isRecording
                            ? const SpinKitPulse(
                                color: Colors.white,
                                size: 50.0,
                              )
                            : const Icon(
                                Icons.fiber_manual_record,
                                size: 35.0,
                                color: Colors.white,
                              ),
                      ),
                    ),
                  )),
              Positioned(
                  top: 85.0,
                  left: MediaQuery.of(context).size.width / 2 - 65.0,
                  child: GestureDetector(
                    onTap: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => const RecordingsPage(),
                        ),
                      );
                    },
                    child: Container(
                      padding: const EdgeInsets.all(10.0),
                      width: 130.0,
                      height: 50.0,
                      decoration: BoxDecoration(
                        color: _getPageColor(_currentIndex).withOpacity(0.5),
                        borderRadius: BorderRadius.circular(10.0),
                      ),
                      child: const Center(
                          child: Text("View Recordings",
                              style: TextStyle(
                                  color: Colors.white,
                                  fontWeight: FontWeight.bold))),
                    ),
                  )),
              Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: <Widget>[
                    CarouselSlider.builder(
                      itemCount: instruments.length,
                      itemBuilder: (context, index, realIndex) {
                        String instrument = instruments[index];
                        String imagePath = 'assets/images/$instrument.png';
                        return GestureDetector(
                          onTap: () {
                            _playSound(instrument, 1.0);
                          },
                          child: Padding(
                            padding: const EdgeInsets.all(12.0),
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Image.asset(
                                  imagePath,
                                  width: 150,
                                  height: 150,
                                  fit: BoxFit.contain,
                                ),
                                const SizedBox(height: 30),
                                Text(
                                  instrument,
                                  style: const TextStyle(fontSize: 32),
                                ),
                              ],
                            ),
                          ),
                        );
                      },
                      options: CarouselOptions(
                        height: 250,
                        enableInfiniteScroll: false,
                        onPageChanged: (index, reason) {
                          setState(() {
                            _currentIndex = index;
                          });
                        },
                      ),
                    ),
                    // instrument selection (for drum and hi-hat)'
                    instruments[_currentIndex] == "drum"
                        ? const SizedBox(height: 30.0)
                        : const SizedBox(height: 0.0),
                    instruments[_currentIndex] == "drum"
                        ? Container(
                            margin: const EdgeInsets.all(16.0),
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                // Kick
                                ElevatedButton(
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: selectedDrum == "kick"
                                        ? _getPageColor(_currentIndex)
                                            .withOpacity(0.8)
                                        : Colors.grey,
                                  ),
                                  onPressed: () {
                                    setState(() {
                                      selectedDrum = "kick";
                                    });
                                  },
                                  child: const Text("Kick Drum",
                                      style: TextStyle(color: Colors.white)),
                                ),
                                const SizedBox(width: 16.0),
                                // snare
                                ElevatedButton(
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: selectedDrum == "snare"
                                        ? _getPageColor(_currentIndex)
                                            .withOpacity(0.8)
                                        : Colors.grey,
                                  ),
                                  onPressed: () {
                                    setState(() {
                                      selectedDrum = "snare";
                                    });
                                  },
                                  child: const Text("Snare Drum",
                                      style: TextStyle(color: Colors.white)),
                                ),
                              ],
                            ))
                        : const SizedBox(height: 0.0),
                    instruments[_currentIndex] == "hi-hat"
                        ? const SizedBox(height: 30.0)
                        : const SizedBox(height: 0.0),
                    instruments[_currentIndex] == "hi-hat"
                        ? Container(
                            margin: const EdgeInsets.all(16.0),
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                // Kick
                                ElevatedButton(
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: selectedHiHat == "closed"
                                        ? _getPageColor(_currentIndex)
                                            .withOpacity(0.8)
                                        : Colors.grey,
                                  ),
                                  onPressed: () {
                                    setState(() {
                                      selectedHiHat = "closed";
                                    });
                                  },
                                  child: const Text("Closed",
                                      style: TextStyle(color: Colors.white)),
                                ),
                                const SizedBox(width: 16.0),
                                // snare
                                ElevatedButton(
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: selectedHiHat == "open"
                                        ? _getPageColor(_currentIndex)
                                            .withOpacity(0.8)
                                        : Colors.grey,
                                  ),
                                  onPressed: () {
                                    setState(() {
                                      selectedHiHat = "open";
                                    });
                                  },
                                  child: const Text("Open",
                                      style: TextStyle(color: Colors.white)),
                                ),
                              ],
                            ))
                        : const SizedBox(height: 0.0),
                  ],
                ),
              ),
              // dots indicator
              Positioned(
                bottom: 50.0,
                left: 0.0,
                right: 0.0,
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: List.generate(
                    instruments.length,
                    (index) => Padding(
                      padding: const EdgeInsets.only(
                          left: 12.0, top: 0.0, right: 12.0, bottom: 0.0),
                      child: CircleAvatar(
                        radius: 4,
                        backgroundColor: index == _currentIndex
                            ? _getPageColor(_currentIndex)
                            : Colors.grey,
                      ),
                    ),
                  ),
                ),
              ),
            ],
          )),
    );
  }
}
