import 'package:audioplayers/audioplayers.dart';
import 'package:carousel_slider/carousel_slider.dart';
import 'package:flutter_spinkit/flutter_spinkit.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import './helpers/shake.dart';
import './enums.dart';
import 'dart:async';

import 'test_page.dart';

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
    // 'triangle',
    'drumkit'
  ];

  final metronome1 = AudioPlayer();
  final metronome2 = AudioPlayer();

  Future<void> _playSound(String instrument, ShakeAxis axis) async {
    final player = AudioPlayer();
    player.setPlayerMode(PlayerMode.lowLatency);
    if (isRecording) {
      recordTimes.add(DateTime.now().millisecondsSinceEpoch - recordTimes[0]);
    }
    switch (instrument) {
      case "shaker":
        switch (axis) {
          case ShakeAxis.lr:
            await player
                .play(AssetSource('sounds/$instrument/synth-shaker.wav'));
            break;
          case ShakeAxis.ud:
            await player
                .play(AssetSource('sounds/$instrument/wood-shaker.wav'));
            break;
          case ShakeAxis.fb:
            await player
                .play(AssetSource('sounds/$instrument/glass-shaker.wav'));
            break;
        }
      case "drumkit":
        switch (axis) {
          case ShakeAxis.lr:
            await player.play(AssetSource('sounds/$instrument/cymbal.wav'));
            break;
          case ShakeAxis.ud:
            await player
                .play(AssetSource('sounds/$instrument/hi-hat-closed.wav'));
            break;
          case ShakeAxis.fb:
            await player.play(AssetSource('sounds/$instrument/kick-drum.wav'));
            break;
        }
        break;
      default:
        await player.play(AssetSource('sounds/$instrument.wav'));
        break;
    }
  }

  Future<void> _playRecording() async {
    for (int i = 1; i < recordTimes.length; i++) {
      int time = recordTimes[i];
      await Future.delayed(Duration(milliseconds: time));
      _playSound(instruments[_currentIndex], ShakeAxis.lr);
    }
  }

  int _currentIndex = 0;
  bool isMetronomeOn = false;
  double metronomeSpeed = 60;
  bool isRecording = false;
  List<int> recordTimes = [];
  late ShakeDetector detector;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);

    detector = ShakeDetector.autoStart(
      onPhoneShake: (ShakeAxis axis) {
        _playSound(instruments[_currentIndex], axis);
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
    }
  }

  Color _getPageColor(int index) {
    List<Color> pageColors = [
      Colors.purple,
      Colors.blue,
      Colors.green,
      Colors.red,
      Colors.orange,
      Colors.brown
    ];

    return pageColors[index % pageColors.length];
  }

  Future<void> _showMetronomeSpeedDialog(BuildContext context) async {
    return showDialog(
      context: context,
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
                  onTap: () async {
                    setState(() {
                      isMetronomeOn = !isMetronomeOn;
                    });

                    if (isMetronomeOn) {
                      metronome1.resume();
                    } else {
                      metronome1.stop();
                      metronome2.stop();
                    }
                  },
                  onLongPress: () {
                    setState(() {
                      if (isMetronomeOn) {
                        isMetronomeOn = false;
                      }
                    });
                    metronome1.stop();
                    metronome2.stop();
                    _showMetronomeSpeedDialog(context);
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
                        recordTimes = [DateTime.now().millisecondsSinceEpoch];
                      } else {
                        print(recordTimes);
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
                        child: Text("View Recordings", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold))
                      ),
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
                            _playSound(instrument, ShakeAxis.lr);
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
