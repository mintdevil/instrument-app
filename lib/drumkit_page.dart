import 'package:flutter/material.dart';

class DrumkitPage extends StatelessWidget {
  const DrumkitPage({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        decoration: BoxDecoration(
          color: Colors.red.shade50,
        ),
        child: Center(
          child: Stack(
            alignment: Alignment.center,
            children: <Widget>[
              // hi-hat
              Positioned(
                left: 20.0,
                child: Image.asset(
                  'assets/images/hi-hat.png',
                  width: 90,
                  height: 90,
                ),
              ),
              // cymbal
              Positioned(
                right: 20.0,
                child: Image.asset(
                  'assets/images/cymbal.png',
                  width: 90,
                  height: 90,
                ),
              ),
              // snare drum
              Positioned(
                left: 80.0,
                top: 450.0,
                child: Image.asset(
                  'assets/images/snare-drum.png',
                  width: 100,
                  height: 100,
                ),
              ),
              // bass drum
              Positioned(
                left: 125.0,
                bottom: 320.0,
                child: Image.asset(
                  'assets/images/bass-drum.png',
                  width: 150,
                  height: 150,
                ),
              ),
              // low tom
              Positioned(
                right: 60.0,
                top: 460.0,
                child: Image.asset(
                  'assets/images/drum.png',
                  width: 100,
                  height: 100,
                ),
              ),
              // top tom
              Positioned(
                top: 240.0,
                left: 70.0,
                child: Image.asset(
                  'assets/images/drum.png',
                  width: 80,
                  height: 80,
                ),
              ),
              // mid tom
              Positioned(
                top: 230.0,
                right: 70.0,
                child: Image.asset(
                  'assets/images/drum.png',
                  width: 90,
                  height: 90,
                ),
              ),
              const Positioned(
                bottom: 160.0,
                child: Text(
                  "drumkit",
                  style: TextStyle(fontSize: 32),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
