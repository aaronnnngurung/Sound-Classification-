import 'dart:async';
import 'dart:math';
import 'dart:math' as math;
import 'dart:typed_data';
import 'package:record/record.dart';
import 'package:tflite_flutter/tflite_flutter.dart';
import 'package:fftea/fftea.dart';

class AudioMLService {
  static final AudioMLService instance = AudioMLService._internal();
  AudioMLService._internal();

  Interpreter? _interpreter;
  final AudioRecorder _audioRecorder = AudioRecorder();
  StreamSubscription<Uint8List>? _audioStreamSubscription;
  bool _isListening = false;

  bool get isListening => _isListening;

  // MUST match the exact order of the 12 output classes from your training model
  final List<String> _labels = [
    'siren',
    'crying_baby',
    'door_wood_knock',
    'glass_breaking',
    'fireworks',
    'car_horn',
    'keyboard_typing',
    'clock_tick',
    'rain',
    'breathing',
    'chirping_birds',
    'laughing',
  ];

  static bool isDetectionValid(String label, double confidence) {
    const emergencyClasses = {
      'siren',
      'crying_baby',
      'door_wood_knock',
      'glass_breaking',
      'fireworks',
      'car_horn',
    };

    // Ignore non-emergency background classes completely
    if (!emergencyClasses.contains(label)) return false;

    // Short transient sounds dilute across a 5-second buffer (lower threshold needed)
    const transientClasses = {'glass_breaking', 'door_wood_knock', 'fireworks'};
    final double threshold = transientClasses.contains(label) ? 0.45 : 0.65;

    return confidence >= threshold;
  }

  // Audio parameters
  static const int _sampleRate = 22050;
  static const int _clipDurationSeconds = 5;
  static const int _clipSamples = _sampleRate * _clipDurationSeconds; // 110250
  static const int _nFft = 2048;
  static const int _hopLength = 512;
  static const int _nMels = 64;
  static const int _maxPadLen = 216;
  static const double _topDb = 80.0;

  final List<double> _audioBuffer = [];
  late final List<Float64List> _melFilterBank;

  Future<void> _loadModel() async {
    if (_interpreter != null) return;

    try {
      print('AudioMLService: Loading model...');
      _interpreter = await Interpreter.fromAsset(
        'assets/models/finalmodel.tflite',
      );

      _melFilterBank = _buildMelFilterBank(
        sampleRate: _sampleRate,
        fftSize: _nFft,
        numMels: _nMels,
      );

      print('AudioMLService: Model loaded.');
    } catch (e) {
      print('AudioMLService: Load error: $e');
    }
  }

  Future<void> startListening({
    required Function(String classLabel, double confidence) onResult,
  }) async {
    if (_isListening) return;

    await _loadModel();
    if (_interpreter == null) return;

    final hasPerm = await _audioRecorder.hasPermission();
    if (!hasPerm) return;

    _isListening = true;
    _audioBuffer.clear();

    try {
      final audioStream = await _audioRecorder.startStream(
        const RecordConfig(
          encoder: AudioEncoder.pcm16bits,
          sampleRate: _sampleRate,
          numChannels: 1,
        ),
      );

      _audioStreamSubscription = audioStream.listen((Uint8List chunk) {
        if (!_isListening) return;

        _convertBytesToFloats(chunk);

        if (_audioBuffer.length >= _clipSamples) {
          _runInference(onResult);
        }
      });
    } catch (e) {
      print('AudioMLService: Stream error: $e');
      stopListening();
    }
  }

  void _convertBytesToFloats(Uint8List chunk) {
    for (int i = 0; i < chunk.length; i += 2) {
      if (i + 1 >= chunk.length) break;

      int pcm16 = (chunk[i + 1] << 8) | chunk[i];
      if (pcm16 & 0x8000 != 0) {
        pcm16 -= 0x10000;
      }

      double floatSample = pcm16 / 32768.0;
      _audioBuffer.add(floatSample);
    }
  }

  void _runInference(Function(String classLabel, double confidence) onResult) {
    if (_interpreter == null) return;

    try {
      List<double> clip = _audioBuffer.sublist(0, _clipSamples);
      _audioBuffer.removeRange(0, _clipSamples ~/ 2);

      // RMS Silence check (0.008 threshold catches quiet transient impacts)
      double sumSquares = 0.0;
      for (final sample in clip) {
        sumSquares += sample * sample;
      }
      final rms = math.sqrt(sumSquares / clip.length);

      if (rms < 0.008) {
        return;
      }

      List<List<double>> melSpectrogramDb = _computeMelSpectrogramDb(clip);
      melSpectrogramDb = _padOrTrim(melSpectrogramDb, _maxPadLen);

      var inputTensor = List.generate(
        1,
        (_) => List.generate(
          _nMels,
          (melIndex) => List.generate(
            _maxPadLen,
            (timeIndex) => [melSpectrogramDb[melIndex][timeIndex]],
          ),
        ),
      );

      var outputTensor = List.generate(
        1,
        (_) => List<double>.filled(_labels.length, 0.0),
      );

      _interpreter!.run(inputTensor, outputTensor);

      List<double> probabilities = outputTensor.first;

      double highestConfidence = -1.0;
      int bestMatchIndex = -1;

      for (int i = 0; i < probabilities.length; i++) {
        if (probabilities[i] > highestConfidence) {
          highestConfidence = probabilities[i];
          bestMatchIndex = i;
        }
      }

      if (bestMatchIndex != -1 && bestMatchIndex < _labels.length) {
        String detectedLabel = _labels[bestMatchIndex];
        print(
          'AudioMLService: Predicted $detectedLabel (${(highestConfidence * 100).toStringAsFixed(1)}%)',
        );
        if (isDetectionValid(detectedLabel, highestConfidence)) {
          onResult(detectedLabel, highestConfidence);
        }
      }
    } catch (e) {
      print('AudioMLService: Inference error: $e');
    }
  }

  List<List<double>> _computeMelSpectrogramDb(List<double> audio) {
    final paddedAudio = _reflectPad(audio, _nFft ~/ 2);
    final hannWindow = _hannWindow(_nFft);

    final fft = FFT(_nFft);
    final numFrames = 1 + ((paddedAudio.length - _nFft) ~/ _hopLength);
    final numFrequencyBins = _nFft ~/ 2 + 1;

    List<List<double>> powerSpectrogram = List.generate(
      numFrequencyBins,
      (_) => List<double>.filled(numFrames, 0.0),
    );

    for (int frameIndex = 0; frameIndex < numFrames; frameIndex++) {
      final frameStart = frameIndex * _hopLength;

      final windowedFrame = Float64List(_nFft);
      for (int i = 0; i < _nFft; i++) {
        windowedFrame[i] = paddedAudio[frameStart + i] * hannWindow[i];
      }

      final frequencyDomain = fft.realFft(windowedFrame);

      for (int bin = 0; bin < numFrequencyBins; bin++) {
        final realPart = frequencyDomain[bin].x;
        final imaginaryPart = frequencyDomain[bin].y;
        powerSpectrogram[bin][frameIndex] =
            realPart * realPart + imaginaryPart * imaginaryPart;
      }
    }

    List<List<double>> melSpectrogram = List.generate(
      _nMels,
      (_) => List<double>.filled(numFrames, 0.0),
    );

    for (int melIndex = 0; melIndex < _nMels; melIndex++) {
      final filterWeights = _melFilterBank[melIndex];

      for (int frameIndex = 0; frameIndex < numFrames; frameIndex++) {
        double weightedSum = 0.0;
        for (int bin = 0; bin < numFrequencyBins; bin++) {
          weightedSum += filterWeights[bin] * powerSpectrogram[bin][frameIndex];
        }
        melSpectrogram[melIndex][frameIndex] = weightedSum;
      }
    }

    double maxPower = 1e-10;
    for (final row in melSpectrogram) {
      for (final value in row) {
        if (value > maxPower) maxPower = value;
      }
    }
    final referenceDb = 10 * (log(maxPower) / ln10);

    List<List<double>> melSpectrogramDb = List.generate(
      _nMels,
      (_) => List<double>.filled(numFrames, 0.0),
    );

    double loudestDb = -1e9;
    for (int melIndex = 0; melIndex < _nMels; melIndex++) {
      for (int frameIndex = 0; frameIndex < numFrames; frameIndex++) {
        double safeValue = melSpectrogram[melIndex][frameIndex];
        if (safeValue < 1e-10) safeValue = 1e-10;

        double db = 10 * (log(safeValue) / ln10) - referenceDb;
        melSpectrogramDb[melIndex][frameIndex] = db;

        if (db > loudestDb) loudestDb = db;
      }
    }

    final decibelFloor = loudestDb - _topDb;
    for (int melIndex = 0; melIndex < _nMels; melIndex++) {
      for (int frameIndex = 0; frameIndex < numFrames; frameIndex++) {
        if (melSpectrogramDb[melIndex][frameIndex] < decibelFloor) {
          melSpectrogramDb[melIndex][frameIndex] = decibelFloor;
        }
      }
    }

    return melSpectrogramDb;
  }

  List<List<double>> _padOrTrim(
    List<List<double>> spectrogram,
    int targetLength,
  ) {
    final currentLength = spectrogram[0].length;

    if (currentLength == targetLength) {
      return spectrogram;
    }

    if (currentLength < targetLength) {
      final paddingNeeded = targetLength - currentLength;
      return spectrogram
          .map((row) => [...row, ...List.filled(paddingNeeded, 0.0)])
          .toList();
    }

    return spectrogram.map((row) => row.sublist(0, targetLength)).toList();
  }

  List<double> _reflectPad(List<double> audio, int padSize) {
    final leftPadding = List.generate(
      padSize,
      (i) => audio[(padSize - i).clamp(0, audio.length - 1)],
    );

    final rightPadding = List.generate(
      padSize,
      (i) => audio[(audio.length - 2 - i).clamp(0, audio.length - 1)],
    );

    return [...leftPadding, ...audio, ...rightPadding];
  }

  Float64List _hannWindow(int length) {
    final window = Float64List(length);
    for (int i = 0; i < length; i++) {
      window[i] = 0.5 - 0.5 * cos(2 * pi * i / (length - 1));
    }
    return window;
  }

  List<Float64List> _buildMelFilterBank({
    required int sampleRate,
    required int fftSize,
    required int numMels,
  }) {
    double hertzToMel(double hertz) {
      const double minFrequency = 0.0;
      const double frequencyStep = 200.0 / 3;

      double mel = (hertz - minFrequency) / frequencyStep;

      const double logRegionStartHz = 1000.0;
      final double logRegionStartMel =
          (logRegionStartHz - minFrequency) / frequencyStep;
      const double logStep = 0.06875177742094912;

      if (hertz >= logRegionStartHz) {
        mel = logRegionStartMel + log(hertz / logRegionStartHz) / logStep;
      }

      return mel;
    }

    double melToHertz(double mel) {
      const double minFrequency = 0.0;
      const double frequencyStep = 200.0 / 3;

      double hertz = minFrequency + frequencyStep * mel;

      const double logRegionStartHz = 1000.0;
      final double logRegionStartMel =
          (logRegionStartHz - minFrequency) / frequencyStep;
      const double logStep = 0.06875177742094912;

      if (mel >= logRegionStartMel) {
        hertz = logRegionStartHz * exp(logStep * (mel - logRegionStartMel));
      }

      return hertz;
    }

    final int numFrequencyBins = fftSize ~/ 2 + 1;
    final double maxFrequency = sampleRate / 2;

    final double minMel = hertzToMel(0.0);
    final double maxMel = hertzToMel(maxFrequency);

    final melPoints = List<double>.generate(
      numMels + 2,
      (i) => minMel + (maxMel - minMel) * i / (numMels + 1),
    );

    final hertzPoints = melPoints.map(melToHertz).toList();
    final binPoints = hertzPoints
        .map((hertz) => (fftSize + 1) * hertz / sampleRate)
        .toList();

    final filters = List.generate(
      numMels,
      (_) => Float64List(numFrequencyBins),
    );

    for (int melIndex = 1; melIndex <= numMels; melIndex++) {
      final leftBin = binPoints[melIndex - 1];
      final centerBin = binPoints[melIndex];
      final rightBin = binPoints[melIndex + 1];

      for (int bin = 0; bin < numFrequencyBins; bin++) {
        double weight = 0.0;

        if (bin >= leftBin && bin <= centerBin && centerBin != leftBin) {
          weight = (bin - leftBin) / (centerBin - leftBin);
        } else if (bin > centerBin &&
            bin <= rightBin &&
            rightBin != centerBin) {
          weight = (rightBin - bin) / (rightBin - centerBin);
        }

        filters[melIndex - 1][bin] = weight;
      }

      final normalizationFactor =
          2.0 / (hertzPoints[melIndex + 1] - hertzPoints[melIndex - 1]);

      for (int bin = 0; bin < numFrequencyBins; bin++) {
        filters[melIndex - 1][bin] *= normalizationFactor;
      }
    }

    return filters;
  }

  Future<void> stopListening() async {
    if (!_isListening) return;
    _isListening = false;

    await _audioStreamSubscription?.cancel();
    _audioStreamSubscription = null;
    await _audioRecorder.stop();
    _audioBuffer.clear();
  }

  void dispose() {
    stopListening();
    _interpreter?.close();
    _interpreter = null;
    _audioRecorder.dispose();
  }
}