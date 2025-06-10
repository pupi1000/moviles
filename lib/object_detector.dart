import 'package:flutter/services.dart';
import 'package:tflite_flutter/tflite_flutter.dart';
import 'package:image/image.dart' as img;
import 'dart:typed_data';
import 'dart:math';

class ObjectDetector {
  Interpreter? _interpreter; // Intérprete de TensorFlow Lite para la detección de objetos
  late List<String> _labels; // Lista de etiquetas del modelo (ej. "car", "bus")
  final int inputSize; // Tamaño de entrada que espera el modelo (ej. 300x300 píxeles)
  bool _isModelLoaded = false; // Flag para indicar si el modelo está cargado y listo

  // Lista de vehículos detectados en el último frame, incluyendo sus cajas delimitadoras y propiedades
  List<Map<String, dynamic>> _detectedVehicles = [];
  // Umbral de distancia para el seguimiento de vehículos (para evitar contar el mismo vehículo varias veces en frames consecutivos)
  static const double _trackingThreshold = 100.0; // Ajustar según sea necesario para tu caso

  ObjectDetector(this.inputSize);

  // Getter para verificar si el modelo está cargado
  bool get isModelLoaded => _isModelLoaded;

  // Método para cargar el modelo de TensorFlow Lite y las etiquetas
  Future<void> loadModel() async {
    // Evita recargar el modelo si ya está cargado
    if (_isModelLoaded) {
      print("ObjectDetector: Modelo ya cargado.");
      return;
    }
    try {
      final interpreterOptions = InterpreterOptions();
      interpreterOptions.threads = 4; // Configura el número de hilos para la inferencia en CPU

      // Carga el modelo TensorFlow Lite desde los assets
      _interpreter = await Interpreter.fromAsset(
        'assets/tflite/ssd_mobilenet.tflite', // Ruta a tu modelo .tflite para detección de vehículos
        options: interpreterOptions,
      );
      _isModelLoaded = true; // Marca el modelo como cargado exitosamente
      print('ObjectDetector: Modelo ssd_mobilenet.tflite cargado exitosamente.');

      // Imprime información sobre el tensor de entrada (útil para depuración)
      final inputTensorInfo = _interpreter!.getInputTensor(0);
      print('ObjectDetector: Tipo de Tensor de Entrada: ${inputTensorInfo.type}');
      print('ObjectDetector: Forma del Tensor de Entrada: ${inputTensorInfo.shape}');

      // Carga las etiquetas del modelo desde un archivo de texto
      final labelData = await rootBundle.loadString('assets/tflite/labelmap.txt');
      _labels = labelData.split('\n').where((s) => s.isNotEmpty).toList();
      print('ObjectDetector: Etiquetas cargadas: $_labels');
    } catch (e) {
      print('ObjectDetector: ERROR al cargar el modelo o las etiquetas: $e');
      _isModelLoaded = false; // Asegura que el flag esté en false si falla la carga
    }
  }

  // Método para reconocer objetos en una imagen de entrada
  Future<void> recognizeImage(img.Image resizedInputImage) async {
    // Verifica si el intérprete está cargado y listo para usar
    if (_interpreter == null || !_isModelLoaded) {
      print("ObjectDetector: Error: Modelo no cargado o no disponible para reconocimiento.");
      return;
    }

    // Convierte la imagen a una lista de bytes en el formato esperado por el modelo
    final inputBytes = _imageToByteListUint8(resizedInputImage, inputSize);

    // Inicializa los arrays de salida del modelo.
    // SSD MobileNet suele tener 4 salidas: cajas, clases, puntuaciones, número de detecciones.
    var outputBoxes = List.filled(1 * 10 * 4, 0.0).reshape([1, 10, 4]); // [1, num_detecciones_max, 4] (ymin, xmin, ymax, xmax)
    var outputClasses = List.filled(1 * 10, 0.0).reshape([1, 10]); // [1, num_detecciones_max] (índice de clase)
    var outputScores = List.filled(1 * 10, 0.0).reshape([1, 10]); // [1, num_detecciones_max] (confianza)
    var numDetections = List<double>.filled(1, 0.0); // [1] (número real de detecciones)

    // Mapea los índices de salida a los arrays correspondientes
    Map<int, Object> outputs = {
      0: outputBoxes,
      1: outputClasses,
      2: outputScores,
      3: numDetections,
    };

    try {
      // Ejecuta la inferencia del modelo con las entradas y salidas definidas
      _interpreter!.runForMultipleInputs([inputBytes], outputs);

      _detectedVehicles.clear(); // Limpia la lista de detecciones previas
      List<Map<String, dynamic>> tempDetectedVehicles = []; // Lista temporal para nuevas detecciones

      int count = numDetections[0].toInt(); // Obtiene el número real de detecciones
      print('ObjectDetector: Detectadas $count detecciones en total.');

      // Itera sobre las detecciones obtenidas
      for (int i = 0; i < count; i++) {
        final score = outputScores[0][i] as double;
        final classIndex = outputClasses[0][i].toInt();
        final box = outputBoxes[0][i];

        // Filtra las detecciones por un umbral de confianza (ej. 0.5 o 50%)
        if (score > 0.5) { // Umbral de confianza mínimo para considerar una detección válida
          // Extrae las coordenadas normalizadas de la caja delimitadora
          double top = box[0] as double;
          double left = box[1] as double;
          double bottom = box[2] as double;
          double right = box[3] as double;

          // **IMPORTANTE**: La transformación de coordenadas de [ymin, xmin, ymax, xmax]
          // a un formato que el `BoundingBoxPainter` pueda usar correctamente después de la rotación
          // de la imagen de la cámara. Si la cámara rota la imagen 90/270 grados,
          // las coordenadas de la caja deben ajustarse.
          // Basado en experiencias anteriores, esta transformación suele ser necesaria
          // si el modelo fue entrenado en una orientación y la cámara produce otra.
          // Aquí asumimos que se necesita una rotación de 90 grados para alinear
          // las coordenadas del modelo con la vista del pintor.
          double newLeft = top;
          double newTop = 1 - right;
          double newRight = bottom;
          double newBottom = 1 - left;

          // Solo considera las clases de vehículos de interés (car, motorcycle, bus, truck)
          // y asegura que el índice de clase sea válido dentro de las etiquetas cargadas.
          // Los índices [2, 3, 5, 7] corresponden a 'car', 'motorcycle', 'bus', 'truck'
          // en el labelmap.txt estándar de COCO (que ssd_mobilenet suele usar).
          if ([2, 3, 5, 7].contains(classIndex) && classIndex < _labels.length) {
            final detectedLabel = _labels[classIndex];
            print('ObjectDetector: Detectado: $detectedLabel con confianza: ${score.toStringAsFixed(2)}');

            bool isNewVehicle = true; // Flag para determinar si es un vehículo nuevo o ya detectado

            // Escala las coordenadas de la caja al tamaño de entrada del modelo para calcular el centro
            // Esto es para el algoritmo de seguimiento, no para dibujar en pantalla.
            double scaledLeft = newLeft * inputSize;
            double scaledTop = newTop * inputSize;
            double scaledRight = newRight * inputSize;
            double scaledBottom = newBottom * inputSize;

            double newCenterX = scaledLeft + (scaledRight - scaledLeft) / 2;
            double newCenterY = scaledTop + (scaledBottom - scaledTop) / 2;

            // Simple algoritmo de seguimiento para evitar contar el mismo vehículo en frames consecutivos
            for (var existingBox in _detectedVehicles) {
              double existingScaledLeft = existingBox['left'] * inputSize;
              double existingScaledTop = existingBox['top'] * inputSize;
              double existingScaledRight = existingBox['right'] * inputSize;
              double existingScaledBottom = existingBox['bottom'] * inputSize;

              double existingCenterX = existingScaledLeft + (existingScaledRight - existingScaledLeft) / 2;
              double existingCenterY = existingScaledTop + (existingScaledBottom - existingScaledTop) / 2;

              double distance = sqrt(pow(newCenterX - existingCenterX, 2) + pow(newCenterY - existingCenterY, 2));

              if (distance < _trackingThreshold) { // Si la distancia es menor que el umbral, es el mismo vehículo
                isNewVehicle = false;
                break;
              }
            }

            // Si es un vehículo nuevo, lo añade a la lista temporal
            if (isNewVehicle) {
              tempDetectedVehicles.add({
                'classIndex': classIndex,
                'label': detectedLabel, // Etiqueta del objeto (ej. "car", "motorcycle")
                'score': score, // Puntuación de confianza
                'top': newTop, // Coordenadas normalizadas para el pintor
                'left': newLeft,
                'bottom': newBottom,
                'right': newRight,
              });
            }
          }
        }
      }

      _detectedVehicles = tempDetectedVehicles; // Actualiza la lista final de vehículos detectados
      print('ObjectDetector: Vehículos únicos detectados en este frame: ${_detectedVehicles.length}');
    } catch (e) {
      print("ObjectDetector: ERROR al ejecutar el intérprete o procesar salidas: $e");
    }
  }

  // Convierte un objeto image.Image a un Uint8List compatible con TensorFlow Lite
  // Los modelos TF Lite suelen esperar datos en formato RGB (0-255).
  Uint8List _imageToByteListUint8(img.Image image, int inputSize) {
    var convertedBytes = Uint8List(1 * inputSize * inputSize * 3); // Para imagen RGB (Height * Width * 3 canales)
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

  // Cierra el intérprete de TensorFlow Lite para liberar recursos
  void close() {
    if (_interpreter != null) {
      _interpreter!.close();
      _interpreter = null; // Anula el intérprete después de cerrarlo
      _isModelLoaded = false; // Resetea el flag de carga
      print("ObjectDetector: Intérprete cerrado.");
    }
  }

  // Getter para obtener la lista de cajas delimitadoras detectadas (vehículos)
  List<Map<String, dynamic>> get detectedBoundingBoxes => _detectedVehicles;
}
