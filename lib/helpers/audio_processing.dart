import 'dart:typed_data';
import 'dart:math';
import 'package:wav/wav.dart';
import 'package:wav/raw_file.dart';

// function to snap timestamps to the nearest metronome time
double snapToBeat(double timestamp, double beat, double halfBeat) {
  double nearestBeat = (timestamp / beat).roundToDouble() * beat;
  double nearestHalfBeat = (timestamp / halfBeat).roundToDouble() * halfBeat;

  return [nearestBeat, nearestHalfBeat]
      .reduce((a, b) => (a - timestamp).abs() < (b - timestamp).abs() ? a : b);
}

// function to remove duplicates in timestamps and volumes
List<List<double>> removeDuplicates(List<double> timestamps, List<double> volumes) {
  Set<double> uniqueTimestamps = {};
  List<double> newTimestamps = [];
  List<double> newVolumes = [];

  for (int i = 0; i < timestamps.length; i++) {
    if (!uniqueTimestamps.contains(timestamps[i])) {
      uniqueTimestamps.add(timestamps[i]);
      newTimestamps.add(timestamps[i]);
      newVolumes.add(volumes[i]);
    }
  }

  return [newTimestamps, newVolumes];
}

// function to mix sounds
Wav mixSounds(List<double> timestamps, List<double> volumes, Uint8List byteArray, double speed, {Wav? existingWav}) {
  final channels = readRawAudio(byteArray, 1, WavFormat.pcm32bit);
  final soundData = Wav(channels, 44100, WavFormat.pcm32bit);
  final chan = <Float64List>[];
  List<double> combinedList = [];

  double beat = 60 / speed * 1000;
  double halfBeat = 60 / speed * 500;

  timestamps = timestamps.map((timestamp) => snapToBeat(timestamp, beat, halfBeat)).toList();
  [timestamps, volumes] = removeDuplicates(timestamps, volumes);

  if (existingWav == null) {
    for (int i = 0; i < timestamps.length; i++) {
      int delay = 44100 * timestamps[i]  ~/ 1000 - combinedList.length;
      combinedList.addAll(List.filled(delay, 0.0));

      num volumeFactor = pow(2, (sqrt(sqrt(sqrt(volumes[i]))) * 192 - 192) / 6);
      List<double> scaledSoundSegment = List<double>.from(soundData.channels[0].map((value) => (value * volumes[i])));
      combinedList.addAll(scaledSoundSegment);
    }
  } else {
    combinedList.addAll(existingWav.channels[0]);

    for (int i = 0; i < timestamps.length; i++) {
      int overlapStartIndex = timestamps[i] * 44100 ~/ 1000;
      int overlapEndIndex = overlapStartIndex + soundData.channels[0].length;
      
      num volumeFactor = pow(2, (sqrt(sqrt(sqrt(volumes[i]))) * 192 - 192) / 6);
      List<double> scaledSoundSegment = List<double>.from(soundData.channels[0].map((value) => (value * volumes[i])));
      
      if (overlapStartIndex > combinedList.length) {
        // pad with 0s until the start index
        int padding = overlapStartIndex - combinedList.length;
        combinedList.addAll(List.filled(padding, 0.0));
        combinedList.addAll(scaledSoundSegment);
      } else if (overlapStartIndex < combinedList.length && overlapEndIndex > combinedList.length) {
        int lastOverlapIndex = combinedList.length - overlapStartIndex;
        for (int index = overlapStartIndex; index < overlapStartIndex + lastOverlapIndex; index++) {
          combinedList[index] += scaledSoundSegment[index - overlapStartIndex];
        }
        combinedList.addAll(scaledSoundSegment.sublist(lastOverlapIndex));
      } else {
        for (int index = overlapStartIndex; index < overlapEndIndex; index++) {
          combinedList[index] += scaledSoundSegment[index - overlapStartIndex];
        }
      }
    }
  }

  // add a 0.1 seconds after the audio so that it does not sound cut off
  combinedList.addAll(List.filled(44100 * 100 ~/ 1000, 0.0));

  chan.add(Float64List.fromList(combinedList));

  return Wav(chan, 44100, WavFormat.pcm32bit);
}