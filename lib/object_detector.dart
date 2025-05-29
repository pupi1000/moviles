import 'package:flutter/services.dart';
import 'package:tflite_flutter/tflite_flutter.dart';
import 'package:image/image.dart' as img; // Importar el paquete 'image'
import 'dart:typed_data'; // Importar para Uint8List si es necesario, aunque con List<List<...>> no lo es directamente
import 'dart:math'; // Para la función sqrt y pow en el tracking

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
      interpreterOptions.threads = 4;

      _interpreter = await Interpreter.fromAsset(
        'assets/tflite/ssd_mobilenet.tflite',
        options: interpreterOptions,
      );
      print('Model loaded successfully');

      // IMPRIMIR INFORMACIÓN DEL TENSO DE ENTRADA DEL MODELO
      // Esto te ayudará a confirmar el tipo de dato y la forma esperada
      final inputTensorInfo = _interpreter.getInputTensor(0);
      print('Input Tensor Type: ${inputTensorInfo.type}'); // ¡Esto debería decir TensorType.uint8!
      print('Input Tensor Shape: ${inputTensorInfo.shape}'); // Debería ser [1, 300, 300, 3]


      final labelData = await rootBundle.loadString('assets/tflite/labelmap.txt');
      _labels = labelData.split('\n').where((s) => s.isNotEmpty).toList();
      print('Labels loaded: $_labels');
    } catch (e) {
      print('Error loading model or labels: $e');
    }
  }

  Future<void> recognizeImage(img.Image resizedInputImage) async {
    if (_interpreter == null) {
      print("Error: Modelo no cargado. Llama loadModel() primero.");
      return;
    }

    // ¡Aquí llamamos a la función que produce enteros (uint8)!
    final inputTensor = _imageToUint8_4DTensor(resizedInputImage); 

    // Definir las salidas del modelo. Estas formas son comunes para SSD MobileNet.
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
      _interpreter.runForMultipleInputs([inputTensor], outputs);

      _detectedVehicles.clear();
      List<Map<String, dynamic>> tempDetectedVehicles = [];

      int count = numDetections[0].toInt();

      for (int i = 0; i < count; i++) {
        final score = outputScores[0][i] as double;
        final classIndex = outputClasses[0][i].toInt();
        final box = outputBoxes[0][i];

        if (score > 0.5) {
          double top = box[0] as double;
          double left = box[1] as double;
          double bottom = box[2] as double;
          double right = box[3] as double;

          if ([2, 3, 5, 7].contains(classIndex)) {
            bool isNewVehicle = true;
            
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
            }
          }
        }
      }
      _detectedVehicles = tempDetectedVehicles;
    } catch (e) {
      print("Error running interpreter: $e");
    }
  }

  // FUNCIÓN CORREGIDA para producir List<List<List<List<int>>>> (que es uint8)
  List<List<List<List<int>>>> _imageToUint8_4DTensor(img.Image image) {
    final int height = image.height;
    final int width = image.width;

    // Declara la lista con tipo `int` explícitamente
    final List<List<List<List<int>>>> input =
        List.generate(1, (_) => // Batch
            List.generate(height, (_) => // Height
                List.generate(width, (_) => // Width
                    List.generate(3, (_) => 0)))); // Channels (RGB), inicializados a 0

    for (int y = 0; y < height; y++) {
      for (int x = 0; x < width; x++) {
        final pixel = image.getPixel(x, y);
        
        // Asegúrate de que los valores sean enteros y estén en el rango 0-255
        // `pixel.r`, `pixel.g`, `pixel.b` ya son int, pero el `.toInt()` es por robustez.
        input[0][y][x][0] = pixel.r.toInt(); // Rojo
        input[0][y][x][1] = pixel.g.toInt(); // Verde
        input[0][y][x][2] = pixel.b.toInt(); // Azul
      }
    }
    return input;
  }

  void close() {
    _interpreter.close();
  }

  List<Map<String, dynamic>> get detectedBoundingBoxes => _detectedVehicles;
}