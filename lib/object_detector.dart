import 'package:flutter/services.dart';
import 'package:tflite_flutter/tflite_flutter.dart';
import 'package:image/image.dart' as img; // Importar el paquete 'image'
import 'dart:typed_data';
import 'dart:math'; // Para la función sqrt y pow en el tracking

class ObjectDetector {
  late Interpreter _interpreter;
  late List<String> _labels;
  final int inputSize; // Esto debería ser 300 para ssd_mobilenet, tal como lo pasas desde CameraScreen

  List<Map<String, dynamic>> _detectedVehicles = [];
  // NOTA: _trackingThreshold en 100.0 píxeles. Si las coordenadas del modelo son 0-1,
  // esta métrica de distancia es para la imagen *original* de la cámara antes del redimensionado.
  // Podrías necesitar ajustar esto si el tracking se basa en las coordenadas 0-1.
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

      // IMPRIMIR INFORMACIÓN DEL TENSO DE ENTRADA DEL MODELO
      // Esto te ayudará a confirmar el tipo de dato y la forma esperada
      final inputTensorInfo = _interpreter.getInputTensor(0);
      print('Input Tensor Type: ${inputTensorInfo.type}'); // ¡Verifica esto!
      print('Input Tensor Shape: ${inputTensorInfo.shape}'); // Debería ser [1, 300, 300, 3]


      final labelData = await rootBundle.loadString('assets/tflite/labelmap.txt');
      _labels = labelData.split('\n').where((s) => s.isNotEmpty).toList();
      print('Labels loaded: $_labels');
    } catch (e) {
      print('Error loading model or labels: $e');
      // Puedes relanzar la excepción o manejarla apropiadamente
    }
  }

  // Modificado: Ahora recibe directamente la imagen ya redimensionada (300x300)
  // y la convierte al formato de entrada del modelo (Float32 normalizado).
  Future<void> recognizeImage(img.Image resizedInputImage) async {
    if (_interpreter == null) {
      print("Error: Modelo no cargado. Llama loadModel() primero.");
      return;
    }

    // Convertir la imagen a un List<List<List<List<double>>>> para representar la forma [1, H, W, C]
    final inputTensor = _imageToNormalized4DTensor(resizedInputImage); // Llamar a la función que devuelve double

    // Definir las salidas del modelo. Estas formas son comunes para SSD MobileNet.
    var outputBoxes = List.filled(1 * 10 * 4, 0.0).reshape([1, 10, 4]); // [1, num_detections, 4]
    var outputClasses = List.filled(1 * 10, 0.0).reshape([1, 10]);     // [1, num_detections]
    var outputScores = List.filled(1 * 10, 0.0).reshape([1, 10]);      // [1, num_detections]
    var numDetections = List<double>.filled(1, 0.0);                   // [1]

    Map<int, Object> outputs = {
      0: outputBoxes,
      1: outputClasses,
      2: outputScores,
      3: numDetections,
    };

    try {
      // Usamos runForMultipleInputs para pasar el tensor de entrada
      // El `inputTensor` ahora es un List<List<...>> que representa la forma 4D
      _interpreter.runForMultipleInputs([inputTensor], outputs);

      _detectedVehicles.clear();
      List<Map<String, dynamic>> tempDetectedVehicles = [];

      int count = numDetections[0].toInt();
      // print('DEBUG: Number of detections: $count');

      for (int i = 0; i < count; i++) {
        final score = outputScores[0][i] as double;
        final classIndex = outputClasses[0][i].toInt();
        final box = outputBoxes[0][i];

        // print('DEBUG: Detection $i - Score: $score, ClassIndex: $classIndex, Box: $box');

        if (score > 0.5) {
          double top = box[0] as double;
          double left = box[1] as double;
          double bottom = box[2] as double;
          double right = box[3] as double;

          if ([2, 3, 5, 7].contains(classIndex)) {
            bool isNewVehicle = true;
            
            // Para el cálculo de distancia, escalaremos las coordenadas normalizadas a un tamaño de referencia
            // Usaremos el inputSize (300) para este cálculo interno.
            double scaledLeft = left * inputSize;
            double scaledTop = top * inputSize;
            double scaledRight = right * inputSize;
            double scaledBottom = bottom * inputSize;

            double newCenterX = scaledLeft + (scaledRight - scaledLeft) / 2;
            double newCenterY = scaledTop + (scaledBottom - scaledTop) / 2;

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
              // print('DEBUG: Added detected vehicle: Class: ${_labels[classIndex]}, Score: $score');
            }
          } else {
              // print('DEBUG: Detected class $classIndex (label: ${classIndex < _labels.length ? _labels[classIndex] : "unknown"}) is not a vehicle.');
          }
        }
      }
      _detectedVehicles = tempDetectedVehicles;
    } catch (e) {
      print("Error running interpreter: $e");
    }
  }

  // CAMBIO CLAVE: Esta función ahora vuelve a devolver una lista anidada de DOULBLES (normalizado 0.0-1.0).
  List<List<List<List<double>>>> _imageToNormalized4DTensor(img.Image image) {
    // La imagen ya viene redimensionada a inputSize x inputSize
    final int height = image.height;
    final int width = image.width;

    // Crea una lista de 4 dimensiones: [batch, height, width, channels]
    // Asegurarse de que el tipo genérico sea `double`
    final List<List<List<List<double>>>> input =
        List.generate(1, (_) => // Batch (siempre 1 para una sola imagen)
            List.generate(height, (_) => // Height
                List.generate(width, (_) => // Width
                    List.generate(3, (_) => 0.0)))); // Channels (RGB), inicializados a 0.0

    for (int y = 0; y < height; y++) {
      for (int x = 0; x < width; x++) {
        final pixel = image.getPixel(x, y);
        // Normaliza los valores de píxel a 0-1 y asegura que sean double
        input[0][y][x][0] = pixel.r / 255.0;   // Rojo (resultado es double)
        input[0][y][x][1] = pixel.g / 255.0; // Verde (resultado es double)
        input[0][y][x][2] = pixel.b / 255.0;  // Azul (resultado es double)
      }
    }
    return input;
  }

  void close() {
    _interpreter.close();
  }

  List<Map<String, dynamic>> get detectedBoundingBoxes => _detectedVehicles;
}