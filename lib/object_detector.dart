import 'package:flutter/services.dart';
import 'package:tflite_flutter/tflite_flutter.dart';
import 'package:image/image.dart' as img; // Importar el paquete 'image'
import 'dart:typed_data';
import 'dart:math';

class ObjectDetector {
  late Interpreter _interpreter;
  late List<String> _labels;
  final int inputSize;

  List<Map<String, dynamic>> _detectedVehicles = [];
  static const double _trackingThreshold = 100.0;

  ObjectDetector(this.inputSize);

  Future<void> loadModel() async {
    try {
      final interpreterOptions = InterpreterOptions();
      try {
        interpreterOptions.addDelegate(GpuDelegate());
        print('Using GPU delegate.');
      } catch (e) {
        print('GPU delegate not available or failed to initialize, using CPU. Error: $e');
      }
      interpreterOptions.threads = 4; // Similar a setNumThreads(4) en Java

      _interpreter = await Interpreter.fromAsset(
        'assets/tflite/ssd_mobilenet.tflite',
        options: interpreterOptions,
      );
      print('Model loaded successfully');

      final labelData = await rootBundle.loadString('assets/tflite/labelmap.txt');
      _labels = labelData.split('\n').where((s) => s.isNotEmpty).toList();
      print('Labels loaded: $_labels');
    } catch (e) {
      print('Error loading model or labels: $e');
      // Puedes relanzar la excepción o manejarla apropiadamente
    }
  }

  List<int> recognizeImage(img.Image image) {
    final resizedImage = img.copyResize(image, width: inputSize, height: inputSize);

    final inputBytes = _imageToByteBuffer(resizedImage);

    var outputBoxes = List.filled(1 * 10 * 4, 0.0).reshape([1, 10, 4]); // [1, 10, 4]
    var outputClasses = List.filled(1 * 10, 0.0).reshape([1, 10]); // [1, 10]
    var outputScores = List.filled(1 * 10, 0.0).reshape([1, 10]); // [1, 10]
    var numDetections = List.filled(1, 0.0).reshape([1]); // [1]

    Map<int, Object> outputs = {
      0: outputBoxes,
      1: outputClasses,
      2: outputScores,
      3: numDetections,
    };

    _interpreter.runForMultipleInputs([inputBytes], outputs);

    _detectedVehicles.clear();
    List<int> currentDetectedClasses = [];

    int count = numDetections[0][0].toInt();

    for (int i = 0; i < count; i++) {
      final score = outputScores[0][i] as double;
      if (score > 0.5) {
        final classIndex = outputClasses[0][i].toInt();
        final box = outputBoxes[0][i];

        double top = box[0] * image.height;
        double left = box[1] * image.width;
        double bottom = box[2] * image.height;
        double right = box[3] * image.width;

        if ([2, 3, 5, 7].contains(classIndex)) {
          bool isNewVehicle = true;
          for (var existingBox in _detectedVehicles) {
            double existingTop = existingBox['top'];
            double existingLeft = existingBox['left'];
            double existingBottom = existingBox['bottom'];
            double existingRight = existingBox['right'];

            double newCenterX = left + (right - left) / 2;
            double newCenterY = top + (bottom - top) / 2;
            double existingCenterX = existingLeft + (existingRight - existingLeft) / 2;
            double existingCenterY = existingTop + (existingBottom - existingTop) / 2;

            double distance = sqrt(pow(newCenterX - existingCenterX, 2) + pow(newCenterY - existingCenterY, 2));

            if (distance < _trackingThreshold) {
              isNewVehicle = false;
              break;
            }
          }

          if (isNewVehicle) {
            currentDetectedClasses.add(classIndex);
            _detectedVehicles.add({
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
    return currentDetectedClasses;
  }

  // Convierte img.Image (paquete 'image') a ByteBuffer RGB.
  ByteBuffer _imageToByteBuffer(img.Image image) {
    // Aseguramos que la imagen sea RGB, incluso si la original tenía alfa.
    // Esto se logra creando una nueva imagen con el formato RGB y copiando los píxeles.
    final img.Image rgbImage = img.Image(width: image.width, height: image.height);
    for (int y = 0; y < image.height; y++) {
      for (int x = 0; x < image.width; x++) {
        final pixel = image.getPixel(x, y);
        // Usamos setPixelRgb, que se asegura de guardar solo R, G, B.
        //rgbImage.setPixelRgb(x, y, img.getRed(pixel), img.getG(pixel), img.getBlue(pixel));
      }
    }

    // Ahora obtenemos los bytes de la imagen RGB.
    // getBytes() en el paquete 'image' devuelve un List<int> de los píxeles.
    // Luego lo convertimos a Uint8List y finalmente a ByteBuffer.
    final List<int> pixelData = rgbImage.getBytes();
    final Uint8List bytes = Uint8List.fromList(pixelData);
   // return bytes.buffer.asByteBuffer();

    // Si algo falla, lanzamos una excepción.
    throw Exception('Failed to convert image to ByteBuffer');
  }

  void close() {
    _interpreter.close();
  }

  List<Map<String, dynamic>> get detectedBoundingBoxes => _detectedVehicles;
}