import 'package:flutter/services.dart';
import 'package:tflite_flutter/tflite_flutter.dart';
import 'package:image/image.dart' as img;
import 'dart:typed_data';
import 'dart:math';

// Clase para encapsular la detección de matrículas y reconocimiento de caracteres
class LicensePlateRecognizer {
  Interpreter? _plateDetectorInterpreter; // Intérprete para detectar la placa
  Interpreter? _ocrInterpreter; // Intérprete para reconocer caracteres de la placa
  List<String>? _plateLabels; // Etiquetas del detector de placas (ej. 'LicensePlate')
  List<String>? _ocrLabels; // Etiquetas para el OCR (generalmente 0-9, A-Z)

  final int plateDetectorInputSize;
  final int ocrInputSize; // Tamaño de entrada para el modelo OCR (ej. 28x28 o 60x60)

  bool _isPlateDetectorLoaded = false;
  bool _isOcrLoaded = false;

  LicensePlateRecognizer({
    required this.plateDetectorInputSize,
    required this.ocrInputSize,
  });

  // Getter que indica si al menos el detector de placas principal está cargado.
  bool get isModelsLoaded => _isPlateDetectorLoaded; 

  // Carga ambos modelos: detector de placas y OCR
  Future<void> loadModels() async {
    // Evita recargar si ambos modelos ya están cargados.
    if (_isPlateDetectorLoaded && _isOcrLoaded) {
      print("Modelos LPR ya cargados.");
      return;
    }

    final interpreterOptions = InterpreterOptions();
    interpreterOptions.threads = 2; // Configura el número de hilos para la inferencia

    // --- Carga del modelo de detección de placa ---
    try {
      _plateDetectorInterpreter = await Interpreter.fromAsset(
        'assets/tflite/lpr/detect.tflite', // RUTA A TU MODELO DE DETECCIÓN DE PLACA (¡VERIFICA EL NOMBRE EXACTO!)
        options: interpreterOptions,
      );
      _isPlateDetectorLoaded = true;
      print('Modelo de detección de placa cargado exitosamente.');

      // Cargar etiquetas del modelo de detección de placa (el 'labelmap.txt' de tu repositorio)
      _plateLabels = (await rootBundle.loadString('assets/tflite/lpr/labelmap.txt'))
          .split('\n')
          .where((s) => s.isNotEmpty)
          .toList();
      print('Etiquetas del detector de placa cargadas: $_plateLabels');

    } catch (e) {
      print('Error al cargar el modelo de detección de placa o sus etiquetas: $e');
      _isPlateDetectorLoaded = false;
      // No retorna aquí para permitir que el OCR intente cargar, ya que es opcional para la detección de placa.
    }

    // --- Carga del modelo OCR (opcional) ---
    // Si aún no tienes un modelo OCR y sus etiquetas, este bloque fallará.
    // La aplicación seguirá funcionando para la detección de placas, pero sin reconocimiento de texto.
    try {
      _ocrInterpreter = await Interpreter.fromAsset(
        'assets/tflite/lpr/license_plate_ocr.tflite', // RUTA A TU MODELO OCR (¡REEMPLAZA ESTO!)
        options: interpreterOptions,
      );
      print('Modelo OCR de placa cargado exitosamente.');

      _ocrLabels = (await rootBundle.loadString('assets/tflite/lpr/labelmap_ocr.txt')) // RUTA A LAS ETIQUETAS OCR (¡REEMPLAZA ESTO!)
          .split('\n')
          .where((s) => s.isNotEmpty)
          .toList();
      print('Etiquetas del OCR de placa cargadas: $_ocrLabels');
      _isOcrLoaded = true; // Marca el OCR como cargado si todo fue bien.

    } catch (e) {
      print('Error al cargar el modelo OCR o sus etiquetas (esto es opcional para la detección de placa): $e');
      _isOcrLoaded = false; // Marca el OCR como no cargado si hubo un error.
    }
  }

  // Método principal para detectar y reconocer la matrícula dentro de una imagen de vehículo
  // Recibe la imagen completa del vehículo (recortada previamente de la imagen de la cámara).
  Future<List<Map<String, dynamic>>> recognizePlates(img.Image inputImage) async {
    // Si el detector de placa no está cargado, no se puede realizar la detección.
    if (!_isPlateDetectorLoaded || _plateDetectorInterpreter == null) {
      print("Error: El detector de placa no está cargado. No se puede detectar la matrícula.");
      return [];
    }

    List<Map<String, dynamic>> detectedPlates = [];

    // 1. Preprocesar la imagen de entrada (región del vehículo) para el detector de placas
    // Redimensiona la imagen a la resolución de entrada esperada por el modelo de detección de placas.
    img.Image resizedForPlateDetector = img.copyResize(inputImage, width: plateDetectorInputSize, height: plateDetectorInputSize);
    var inputBytesPlateDetector = _imageToByteListUint8(resizedForPlateDetector, plateDetectorInputSize);

    // Salidas esperadas del modelo de detección de placas (ajusta esto si tu 'detect.tflite' es diferente)
    // El modelo del repositorio de GitHub suele tener 4 salidas: ubicaciones, clases, puntuaciones, número de detecciones.
    // El orden de las salidas (0, 1, 2, 3) puede variar según cómo se exportó el modelo.
    var plateLocations = List.filled(1 * 10 * 4, 0.0).reshape([1, 10, 4]); // Bounding box locations [ymin, xmin, ymax, xmax]
    var plateClasses = List.filled(1 * 10, 0.0).reshape([1, 10]); // Class indices
    var plateScores = List.filled(1 * 10, 0.0).reshape([1, 10]); // Confidence scores
    var plateNumDetections = List<double>.filled(1, 0.0); // Number of detections

    Map<int, Object> plateDetectorOutputs = {
      0: plateLocations,
      1: plateClasses,
      2: plateScores,
      3: plateNumDetections,
    };

    try {
      // Ejecuta la inferencia del modelo de detección de placas.
      _plateDetectorInterpreter!.runForMultipleInputs([inputBytesPlateDetector], plateDetectorOutputs);

      int plateCount = plateNumDetections[0].toInt(); // Número de detecciones de placas.

      for (int i = 0; i < plateCount; i++) {
        final score = plateScores[0][i] as double; // Puntuación de confianza de la detección.
        final classIndex = plateClasses[0][i].toInt(); // Índice de la clase detectada.
        final box = plateLocations[0][i]; // Coordenadas normalizadas de la caja delimitadora.

        // Filtra detecciones por umbral de confianza y validez de la clase.
        if (score > 0.6 && _plateLabels != null && classIndex < _plateLabels!.length) {
          // Asegúrate de que la clase detectada sea 'LicensePlate' según tu labelmap.
          if (_plateLabels![classIndex] != 'LicensePlate') {
              continue; // Si no es una matrícula, ignora esta detección.
          }

          // Extrae coordenadas de la caja delimitadora.
          double ymin = box[0] as double;
          double xmin = box[1] as double;
          double ymax = box[2] as double;
          double xmax = box[3] as double;

          // Convierte las coordenadas normalizadas a píxeles de la 'inputImage' (región del vehículo).
          int plateLeft = (xmin * inputImage.width).toInt();
          int plateTop = (ymin * inputImage.height).toInt();
          int plateWidth = ((xmax - xmin) * inputImage.width).toInt();
          int plateHeight = ((ymax - ymin) * inputImage.height).toInt();

          // Asegura que las dimensiones de la caja delimitadora sean válidas y dentro de los límites de la imagen.
          plateLeft = max(0, plateLeft);
          plateTop = max(0, plateTop);
          plateWidth = min(inputImage.width - plateLeft, plateWidth);
          plateHeight = min(inputImage.height - plateTop, plateHeight);

          // Si la caja es inválida (ancho o alto cero/negativo), salta esta detección.
          if (plateWidth <= 0 || plateHeight <= 0) {
              print("Advertencia: Caja de matrícula inválida (width o height <= 0). Saltando.");
              continue;
          }

          // Recorta la imagen de la matrícula de la región del vehículo.
          img.Image plateImage = img.copyCrop(
            inputImage,
            x: plateLeft,
            y: plateTop,
            width: plateWidth,
            height: plateHeight,
          );

          String plateText = "N/A"; // Valor por defecto para el texto de la matrícula.

          // --- Sección de reconocimiento OCR (opcional) ---
          // Solo se ejecuta si el modelo OCR y sus etiquetas se cargaron correctamente.
          if (_isOcrLoaded && _ocrInterpreter != null && _ocrLabels != null && _ocrLabels!.isNotEmpty) {
            // Preprocesa la imagen de la matrícula para el modelo OCR.
            img.Image resizedForOcr = img.copyResize(plateImage, width: ocrInputSize, height: ocrInputSize);
            var inputBytesOcr = _imageToByteListUint8(resizedForOcr, ocrInputSize);

            // Ajusta las salidas del modelo OCR según su formato específico.
            // Esto es un PLACEHOLDER. La estructura REAL de tu modelo OCR dictará esta configuración.
            // Por ejemplo, si es un clasificador de caracteres individuales, o un modelo CTC.
            var ocrOutput = List.filled(1 * _ocrLabels!.length, 0.0).reshape([1, _ocrLabels!.length]);

            Map<int, Object> ocrOutputs = {
              0: ocrOutput,
            };

            _ocrInterpreter!.runForMultipleInputs([inputBytesOcr], ocrOutputs);

            // POST-PROCESAMIENTO OCR: Obtener el texto de la matrícula.
            plateText = _decodeOcrOutput(ocrOutput.cast<List<double>>());
          } else {
             print("Advertencia: Modelo OCR no cargado o no disponible. No se realizará reconocimiento de texto.");
          }
          // --- Fin de la sección OCR ---

          // Añade la matrícula detectada a la lista de resultados.
          detectedPlates.add({
            'label': plateText.isNotEmpty ? plateText : (_plateLabels![classIndex]), // Muestra el texto de la placa o la etiqueta "LicensePlate"
            'score': score, // Puntuación de confianza de la detección de la placa.
            // Coordenadas normalizadas de la matrícula (relativas a la 'inputImage' de este método).
            'top': ymin,
            'left': xmin,
            'bottom': ymax,
            'right': xmax,
            'isPlate': true, // Indicador para distinguir que es una matrícula.
          });
        }
      }
    } catch (e) {
      print("Error al ejecutar la detección de placas o OCR: $e");
    }
    return detectedPlates;
  }

  // Convierte un objeto image.Image a un Uint8List compatible con TensorFlow Lite.
  // Los modelos TF Lite suelen esperar datos en formato RGB (0-255).
  Uint8List _imageToByteListUint8(img.Image image, int inputSize) {
    var convertedBytes = Uint8List(1 * inputSize * inputSize * 3); // Para imagen RGB
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

  // **¡¡¡IMPORTANTE: Esta función necesita ser implementada según la salida de tu modelo OCR!!!**
  // La implementación actual es un PLACEHOLDER y probablemente NO FUNCIONARÁ con tu modelo real.
  // Debes consultar la documentación o ejemplos de tu modelo OCR para saber cómo decodificar su salida.
  String _decodeOcrOutput(List<List<double>> output) {
    if (_ocrLabels == null || _ocrLabels!.isEmpty || output.isEmpty || output[0].isEmpty) {
      print("Advertencia: _decodeOcrOutput llamado sin _ocrLabels o output válido.");
      return "";
    }

    String recognizedText = "";

    // === Lógica de Decodificación de EJEMPLO (MUY BÁSICA - PROBABLEMENTE INSUFICIENTE) ===
    // Asumiendo que output[0] es una lista de logits/probabilidades donde el índice
    // con el valor más alto corresponde al carácter reconocido.
    try {
      int maxIndex = 0;
      double maxValue = output[0][0];
      for (int i = 1; i < output[0].length; i++) {
        if (output[0][i] > maxValue) {
          maxValue = output[0][i];
          maxIndex = i;
        }
      }

      if (maxIndex < _ocrLabels!.length) {
        recognizedText = _ocrLabels![maxIndex];
      }
    } catch (e) {
      print("Error al decodificar la salida OCR: $e");
      recognizedText = "ErrorOCR"; // Devuelve un error para depuración
    }
    // ==============================================================================

    // Elimina espacios y recorta el texto resultante.
    return recognizedText.replaceAll(" ", "").trim();
  }

  // Cierra los intérpretes de TensorFlow Lite para liberar recursos.
  void close() {
    _plateDetectorInterpreter?.close();
    _ocrInterpreter?.close();
    _isPlateDetectorLoaded = false;
    _isOcrLoaded = false;
    print("Modelos LPR cerrados.");
  }
}
