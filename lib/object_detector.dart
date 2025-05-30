// lib/object_detector.dart
import 'package:flutter/services.dart';
import 'package:tflite_flutter/tflite_flutter.dart';
import 'package:image/image.dart' as img;
import 'dart:typed_data';
import 'dart:math';

class ObjectDetector {
  Interpreter? _interpreter; // Hacerlo nullable
  late List<String> _labels;
  final int inputSize;
  bool _isModelLoaded = false; // Nuevo flag

  List<Map<String, dynamic>> _detectedVehicles = [];
  static const double _trackingThreshold = 100.0;

  ObjectDetector(this.inputSize);

  bool get isModelLoaded => _isModelLoaded; // Getter para el flag

  Future<void> loadModel() async {
    if (_isModelLoaded) {
      print("Model already loaded.");
      return;
    }
    try {
      final interpreterOptions = InterpreterOptions();
      try {
        interpreterOptions.addDelegate(GpuDelegate());
        print('Using GPU delegate.');
      } catch (e) {
        print('GPU delegate not available or failed to initialize, using CPU. Error: $e');
      }
      interpreterOptions.threads = 4;

      _interpreter = await Interpreter.fromAsset(
        'assets/tflite/ssd_mobilenet.tflite',
        options: interpreterOptions,
      );
      _isModelLoaded = true; // Establece el flag a true al cargar exitosamente
      print('Model loaded successfully');

      final inputTensorInfo = _interpreter!.getInputTensor(0);
      print('Input Tensor Type: ${inputTensorInfo.type}');
      print('Input Tensor Shape: ${inputTensorInfo.shape}');

      final labelData = await rootBundle.loadString('assets/tflite/labelmap.txt');
      _labels = labelData.split('\n').where((s) => s.isNotEmpty).toList();
      print('Labels loaded: $_labels');
    } catch (e) {
      print('Error loading model or labels: $e');
      _isModelLoaded = false; // Asegura que el flag esté en false si falla la carga
    }
  }

  Future<void> recognizeImage(img.Image resizedInputImage) async {
    if (_interpreter == null || !_isModelLoaded) {
      // Solo intenta reconocer si el intérprete existe y el modelo está cargado
      print("Error: Modelo no cargado o no disponible para reconocimiento.");
      return;
    }

    final inputBytes = _imageToByteListUint8(resizedInputImage, inputSize);

    var outputBoxes = List.filled(1 * 10 * 4, 0.0).reshape([1, 10, 4]);
    var outputClasses = List.filled(1 * 10, 0.0).reshape([1, 10]);
    var outputScores = List.filled(1 * 10, 0.0).reshape([1, 10]);
    var numDetections = List<double>.filled(1, 0.0);

    Map<int, Object> outputs = {
      0: outputBoxes,
      1: outputClasses,
      2: outputScores,
      3: numDetections,
    };

    try {
      _interpreter!.runForMultipleInputs([inputBytes], outputs);

      _detectedVehicles.clear();
      List<Map<String, dynamic>> tempDetectedVehicles = [];

      int count = numDetections[0].toInt();

      for (int i = 0; i < count; i++) {
        final score = outputScores[0][i] as double;
        final classIndex = outputClasses[0][i].toInt();
        final box = outputBoxes[0][i];

        if (score > 0.5) { // Umbral de confianza
          double top = box[0] as double;
          double left = box[1] as double;
          double bottom = box[2] as double;
          double right = box[3] as double;

          // Clases de vehículos que te interesan (revisa tu labelmap.txt)
          // 2: car, 3: motorcycle, 5: bus, 7: truck
          if ([2, 3, 5, 7].contains(classIndex) && classIndex < _labels.length) {
            bool isNewVehicle = true;

            // Escalar coordenadas para el cálculo de distancia
            double scaledLeft = left * inputSize;
            double scaledTop = top * inputSize;
            double scaledRight = right * inputSize;
            double scaledBottom = bottom * inputSize;

            double newCenterX = scaledLeft + (scaledRight - scaledLeft) / 2;
            double newCenterY = scaledTop + (scaledBottom - scaledTop) / 2;

            // Simple seguimiento para evitar conteos duplicados si el vehículo está quieto
            for (var existingBox in _detectedVehicles) {
              double existingScaledLeft = existingBox['left'] * inputSize;
              double existingScaledTop = existingBox['top'] * inputSize;
              double existingScaledRight = existingBox['right'] * inputSize;
              double existingScaledBottom = existingBox['bottom'] * inputSize;

              double existingCenterX = existingScaledLeft + (existingScaledRight - existingScaledLeft) / 2;
              double existingCenterY = existingScaledTop + (existingScaledBottom - existingScaledTop) / 2;

              double distance = sqrt(pow(newCenterX - existingCenterX, 2) + pow(newCenterY - existingCenterY, 2));

              if (distance < _trackingThreshold) {
                isNewVehicle = false;
                break;
              }
            }

            if (isNewVehicle) {
              tempDetectedVehicles.add({
                'classIndex': classIndex,
                'label': _labels[classIndex],
                'score': score,
                'top': top,
                'left': left,
                'bottom': bottom,
                'right': right,
              });
            }
          }
        }
      }
      _detectedVehicles = tempDetectedVehicles;
    } catch (e) {
      print("Error running interpreter: $e");
      // Considerar un restablecimiento o un mensaje de error aquí
    }
  }

  Uint8List _imageToByteListUint8(img.Image image, int inputSize) {
    var convertedBytes = Uint8List(1 * inputSize * inputSize * 3);
    var buffer = ByteData.view(convertedBytes.buffer);
    int pixelIndex = 0;
    for (var i = 0; i < inputSize; i++) {
      for (var j = 0; j < inputSize; j++) {
        var pixel = image.getPixel(j, i);
        buffer.setUint8(pixelIndex++, pixel.r.toInt());
        buffer.setUint8(pixelIndex++, pixel.g.toInt());
        buffer.setUint8(pixelIndex++, pixel.b.toInt());
      }
    }
    return convertedBytes;
  }

  void close() {
    if (_interpreter != null) {
      _interpreter!.close();
      _interpreter = null; // Anula el intérprete después de cerrarlo
      _isModelLoaded = false;
      print("Interpreter closed.");
    }
  }

  List<Map<String, dynamic>> get detectedBoundingBoxes => _detectedVehicles;
}