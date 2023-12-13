import 'package:audioplayers/audioplayers.dart';
import 'package:just_audio/just_audio.dart' as just_audio;
import 'package:carousel_slider/carousel_slider.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import './helpers/shake.dart';
import 'dart:async';

import 'drumkit_page.dart';

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
      theme: ThemeData(
          // primarySwatch: Colors.deepPurple,
          ),
      // home: const DrumkitPage(),
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
    'triangle',
    // 'drumkit'
  ];

  final player = AudioPlayer();
  final metronome = just_audio.AudioPlayer();

  Future<void> _playSound(String instrument, ShakeDirection direction) async {
    final player = AudioPlayer();
    await player.play(AssetSource('sounds/$instrument.wav'));
  }

  int _currentIndex = 0;
  bool isMetronomeOn = false;
  double metronomeSpeed = 60;
  bool isRecording = false;
  late ShakeDetector detector;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);

    detector = ShakeDetector.autoStart(
      onPhoneShake: (ShakeDirection direction) {
        _playSound(instruments[_currentIndex], direction);
      },
    );
    metronome.setAsset('assets/sounds/metronome-60bpm.mp3');
    metronome.setLoopMode(just_audio.LoopMode.one);
  }

  @override
  void dispose() {
    detector.stopListening();
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
    }
  }

  Color _getPageColor(int index) {
    List<Color> pageColors = [
      Colors.purple,
      Colors.blue,
      Colors.green,
      Colors.red,
      Colors.yellow,
      Colors.orange,
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
                    onChanged: (value) {
                      setState(() {
                        metronomeSpeed = value;
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
                    child: const Text('OK'),
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
              Positioned(
                top: 60.0,
                right: 0.0,
                child: GestureDetector(
                  onTap: () async {
                    setState(() {
                      isMetronomeOn = !isMetronomeOn;
                    });

                    if (isMetronomeOn) {
                      await metronome.setSpeed(metronomeSpeed / 60);
                      metronome.play();
                    } else {
                      metronome.stop();
                    }
                  },
                  onLongPress: () {
                    setState(() {
                      if (isMetronomeOn) {
                        isMetronomeOn = false;
                        metronome.stop();
                      }
                    });
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
              Positioned(
                top: 60.0,
                left: 0.0,
                child: GestureDetector(
                  onTap: () {
                    setState(() {
                      isRecording = !isRecording;
                    });
                  },
                  child: Padding(
                    padding: const EdgeInsets.all(20.0),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Image.asset(
                          isRecording
                              ? 'assets/images/pause-button.png'
                              : 'assets/images/rec-button.png',
                          width: 50,
                          height: 50,
                          fit: BoxFit.contain,
                        ),
                        const SizedBox(height: 8),
                        isRecording
                            ? const Text(
                                'Recording...',
                                style: TextStyle(fontSize: 16),
                              )
                            : Container(),
                      ],
                    ),
                  ),
                ),
              ),
              Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: <Widget>[
                    CarouselSlider.builder(
                      itemCount: instruments.length,
                      itemBuilder: (context, index, realIndex) {
                        String instrument = instruments[index];
                        if (instrument != 'drumkit') {
                          String imagePath = 'assets/images/$instrument.png';
                          return GestureDetector(
                            onTap: () {
                              _playSound(instrument, ShakeDirection.None);
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
                        } else {
                          return const DrumkitPage();
                        }
                      },
                      options: CarouselOptions(
                        height: 242,
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
