import 'package:flutter/material.dart';
import 'package:camera/camera.dart';
import 'package:image/image.dart' as img;
import 'dart:typed_data';
import 'package:permission_handler/permission_handler.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'object_detector.dart'; // Tu detector de vehículos existente
import 'license_plate_recognizer.dart'; // ¡El nuevo detector de matrículas!
import 'sidebar_widget.dart';
import 'report_manager.dart';

List<CameraDescription> cameras = [];

class CameraScreen extends ConsumerStatefulWidget {
  const CameraScreen({Key? key}) : super(key: key);

  @override
  _CameraScreenState createState() => _CameraScreenState();
}

class _CameraScreenState extends ConsumerState<CameraScreen> {
  CameraController? _controller;
  ObjectDetector? _objectDetector;
  LicensePlateRecognizer? _licensePlateRecognizer; // Instancia del nuevo LPR
  final SideBarWidget _sideBar = SideBarWidget(key: SideBarWidget.sideBarKey);

  bool _isDetecting = false; // Flag para controlar si una detección está en curso
  List<Map<String, dynamic>> _boundingBoxes = []; // Contendrá las cajas de vehículos Y matrículas

  int _currentCarCount = 0;
  int _currentMotorcycleCount = 0;
  int _currentBusCount = 0;
  int _currentTruckCount = 0;

  @override
  void initState() {
    super.initState();
    _requestPermissions(); // Inicia el proceso de solicitud de permisos y carga de modelos
  }

  Future<void> _requestPermissions() async {
    // Solicita permiso de cámara
    if (await Permission.camera.request().isGranted) {
      print("CameraScreen: Permiso de cámara concedido.");
      await _initializeCamera(); // Inicializa la cámara si el permiso es concedido

      // Inicializa y carga el modelo de detección de objetos general
      _objectDetector = ObjectDetector(300);
      await _objectDetector!.loadModel(); // Carga el modelo de vehículos

      // Inicializa y carga los modelos del detector de matrículas
      _licensePlateRecognizer = LicensePlateRecognizer(
        plateDetectorInputSize: 300, // Ajusta este tamaño al de tu modelo de detección de placa
        ocrInputSize: 60, // Ajusta este tamaño al de tu modelo OCR
      );
      // Solo intenta cargar los modelos LPR si la instancia no es nula.
      if (_licensePlateRecognizer != null) {
         await _licensePlateRecognizer!.loadModels(); // Carga ambos modelos LPR/OCR (si existen)
      }

    } else {
      // Muestra un mensaje si el permiso es denegado
      print("CameraScreen: Permiso de cámara denegado.");
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Permiso de cámara denegado. No se puede iniciar la detección.')),
        );
      }
    }
  }

  Future<void> _initializeCamera() async {
    // Obtiene las cámaras disponibles
    if (cameras.isEmpty) {
      try {
        cameras = await availableCameras();
      } on CameraException catch (e) {
        print('CameraScreen: Error al obtener cámaras disponibles: $e');
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Error al obtener cámaras: ${e.description}')),
          );
        }
        return;
      }
    }

    // Inicializa el controlador de la cámara
    if (cameras.isNotEmpty) {
      _controller = CameraController(
        cameras[0], // Usa la primera cámara disponible
        ResolutionPreset.medium, // Resolución de la vista previa
        enableAudio: false, // Deshabilita el audio
        imageFormatGroup: ImageFormatGroup.yuv420, // Formato de imagen para el procesamiento
      );

      await _controller!.initialize(); // Inicializa el controlador de la cámara

      if (!mounted) return; // Si el widget ya no está montado, retorna

      setState(() {}); // Reconstruye el widget para mostrar la vista previa de la cámara

      // Inicia el stream de imágenes de la cámara para el procesamiento
      _controller!.startImageStream((CameraImage image) {
        // Solo procesa una imagen a la vez
        if (!_isDetecting) {
          _isDetecting = true;
          _processCameraImage(image);
        }
      });
      print("CameraScreen: Stream de cámara iniciado.");
    } else {
      print("CameraScreen: No se encontraron cámaras disponibles.");
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('No se encontraron cámaras disponibles.')),
        );
      }
    }
  }

  Future<void> _processCameraImage(CameraImage cameraImage) async {
    // Verifica si el detector de objetos general está cargado.
    // Si no lo está, no tiene sentido continuar con la detección de vehículos.
    if (_objectDetector == null || !_objectDetector!.isModelLoaded) {
      print("CameraScreen: Detector de objetos general no cargado. Saltando procesamiento de imagen.");
      _isDetecting = false;
      return;
    }
    
    // Convierte la CameraImage (formato YUV420) a un objeto Image (formato RGB)
    img.Image? originalImage = _convertYUV420toImage(cameraImage);
    if (originalImage == null) {
      print("CameraScreen: Fallo al convertir CameraImage a Image. Saltando procesamiento.");
      _isDetecting = false;
      return;
    }

    // Obtiene la orientación del sensor de la cámara para rotar la imagen si es necesario
    int sensorOrientation = _controller?.description.sensorOrientation ?? 0;

    // Rota la imagen original para que el detector de objetos la procese correctamente
    if (sensorOrientation == 90) {
      originalImage = img.copyRotate(originalImage, angle: 90);
    } else if (sensorOrientation == 270) {
      originalImage = img.copyRotate(originalImage, angle: -90);
    } else if (sensorOrientation == 180) {
      originalImage = img.copyRotate(originalImage, angle: 180);
    }

    // Paso 1: Detección de vehículos con tu modelo existente (ssd_mobilenet.tflite)
    // Redimensiona la imagen para que coincida con el tamaño de entrada del modelo.
    img.Image resizedForVehicleDetector = img.copyResize(originalImage, width: 300, height: 300);
    await _objectDetector!.recognizeImage(resizedForVehicleDetector); // Ejecuta la detección
    final detectedVehicleBoxes = _objectDetector!.detectedBoundingBoxes; // Obtiene los resultados

    List<Map<String, dynamic>> allBoundingBoxes = []; // Lista para almacenar todas las cajas a dibujar (vehículos y placas)

    // Reinicia los contadores de vehículos para el frame actual
    _currentCarCount = 0;
    _currentMotorcycleCount = 0;
    _currentBusCount = 0;
    _currentTruckCount = 0;

    // Procesa las detecciones de vehículos
    for (var vehicleBox in detectedVehicleBoxes) {
      // Añade la caja del vehículo a la lista general para dibujar
      allBoundingBoxes.add(vehicleBox);

      // Actualiza los contadores de vehículos según la clase detectada
      final classValue = vehicleBox['classIndex'] as int;
      if (classValue == 2) { // Índice 2 para 'car' (según labelmap.txt)
        _currentCarCount++;
      } else if (classValue == 3) { // Índice 3 para 'motorcycle'
        _currentMotorcycleCount++;
      } else if (classValue == 5) { // Índice 5 para 'bus'
        _currentBusCount++;
      } else if (classValue == 7) { // Índice 7 para 'truck'
        _currentTruckCount++;
      }

      // Paso 2: Recortar la región del vehículo para pasarla al detector de placas
      // Las coordenadas en 'vehicleBox' son normalizadas (0-1) y relativas a la imagen de entrada del modelo (300x300).
      // Necesitamos escalarlas a la imagen original de la cámara para realizar el recorte preciso.
      int vehicleLeft = (vehicleBox['left'] * originalImage.width).toInt();
      int vehicleTop = (vehicleBox['top'] * originalImage.height).toInt();
      int vehicleRight = (vehicleBox['right'] * originalImage.width).toInt();
      int vehicleBottom = (vehicleBox['bottom'] * originalImage.height).toInt();

      // Asegurar que las coordenadas estén dentro de los límites de la imagen original y sean positivas.
      vehicleLeft = vehicleLeft.clamp(0, originalImage.width);
      vehicleTop = vehicleTop.clamp(0, originalImage.height);
      vehicleRight = vehicleRight.clamp(0, originalImage.width);
      vehicleBottom = vehicleBottom.clamp(0, originalImage.height);

      int cropWidth = (vehicleRight - vehicleLeft).abs(); // Ancho de la región del vehículo
      int cropHeight = (vehicleBottom - vehicleTop).abs(); // Alto de la región del vehículo

      // Solo procede si la región del vehículo es válida (ancho y alto > 0)
      if (cropWidth > 0 && cropHeight > 0) {
        // Recorta la imagen de la región del vehículo.
        img.Image vehicleRegion = img.copyCrop(
          originalImage,
          x: vehicleLeft,
          y: vehicleTop,
          width: cropWidth,
          height: cropHeight,
        );

        // Paso 3: Detectar y reconocer la matrícula dentro de la región del vehículo (si el LPR está cargado)
        if (_licensePlateRecognizer != null && _licensePlateRecognizer!.isModelsLoaded) {
            final detectedPlates = await _licensePlateRecognizer!.recognizePlates(vehicleRegion);

            // Ajusta las coordenadas de la placa a la imagen original completa y las añade para dibujar.
            for (var plateBox in detectedPlates) {
              // Las coordenadas de 'plateBox' son relativas a 'vehicleRegion' (0-1).
              // Necesitamos re-escalarlas y ajustarlas a la posición original en la imagen completa de la cámara.
              double plateLeft = (plateBox['left'] * cropWidth) + vehicleLeft;
              double plateTop = (plateBox['top'] * cropHeight) + vehicleTop;
              double plateRight = (plateBox['right'] * cropWidth) + vehicleLeft;
              double plateBottom = (plateBox['bottom'] * cropHeight) + vehicleTop;

              allBoundingBoxes.add({
                'label': plateBox['label'], // Texto de la matrícula reconocida (o "Placa detectada")
                'score': plateBox['score'], // Confianza de la detección de la placa
                'left': plateLeft / originalImage.width, // Normaliza a la imagen completa
                'top': plateTop / originalImage.height,
                'right': plateRight / originalImage.width,
                'bottom': plateBottom / originalImage.height,
                'isPlate': true, // Flag para que el pintor sepa que es una matrícula
              });
            }
        } else {
          print("CameraScreen: Advertencia: Detector de placas no inicializado o sus modelos no están cargados. No se detectarán placas.");
        }
      }
    }

    // Actualiza el estado para redibujar las cajas delimitadoras en la pantalla
    setState(() {
      _boundingBoxes = allBoundingBoxes; // Ahora incluye cajas de vehículos y placas
    });

    // Actualiza la barra lateral con los conteos de vehículos detectados.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final sideBarState = SideBarWidget.sideBarKey.currentState;
      if (sideBarState != null) {
        sideBarState.resetCounters(); // Reinicia los contadores en la barra lateral
        sideBarState.updateCarCount(_currentCarCount);
        sideBarState.updateMotorcycleCount(_currentMotorcycleCount);
        sideBarState.updateBusCount(_currentBusCount);
        sideBarState.updateTruckCount(_currentTruckCount);
        sideBarState.updateEstimatedTime(); // Recalcula y muestra el tiempo estimado
      }
    });

    _isDetecting = false; // Permite que se procese el siguiente frame de la cámara
  }

  // Convierte una CameraImage (formato YUV420) a un objeto Image (formato RGB)
  img.Image? _convertYUV420toImage(CameraImage image) {
    try {
      final int width = image.width;
      final int height = image.height;

      final Uint8List yPlane = image.planes[0].bytes;
      final Uint8List uPlane = image.planes[1].bytes;
      final Uint8List vPlane = image.planes[2].bytes;

      final int uvRowStride = image.planes[1].bytesPerRow;
      final int uvPixelStride = image.planes[1].bytesPerPixel ?? 1;

      final img.Image rgbImage = img.Image(width: width, height: height);

      for (int y = 0; y < height; y++) {
        for (int x = 0; x < width; x++) {
          final int Y = yPlane[y * image.planes[0].bytesPerRow + x];
          final int UV_x = (x ~/ 2);
          final int UV_y = (y ~/ 2);

          int uIndex = UV_y * uvRowStride + UV_x * uvPixelStride;
          int vIndex = UV_y * uvRowStride + UV_x * uvPixelStride;

          uIndex = uIndex.clamp(0, uPlane.length - 1);
          vIndex = vIndex.clamp(0, vPlane.length - 1);

          final int V = vPlane[vIndex];
          final int U = uPlane[uIndex];

          int C = Y - 16;
          int D = U - 128;
          int E = V - 128;

          int R = (298 * C + 409 * E + 128) >> 8;
          int G = (298 * C - 100 * D - 208 * E + 128) >> 8;
          int B = (298 * C + 516 * D + 128) >> 8;

          R = R.clamp(0, 255);
          G = G.clamp(0, 255);
          B = B.clamp(0, 255);

          rgbImage.setPixelRgb(x, y, R, G, B);
        }
      }
      return rgbImage;
    } catch (e) {
      print("CameraScreen: Error al convertir YUV420 a Image: $e");
      return null;
    }
  }

  // Guarda el reporte de conteo de vehículos
  void _saveReport() {
    // El cálculo de totalMinutes ya se hace dentro de ReportManager.addReport
    ReportManager.addReport(
      carCount: _currentCarCount,
      motorcycleCount: _currentMotorcycleCount,
      busCount: _currentBusCount,
      truckCount: _currentTruckCount,
      timestamp: DateTime.now(),
    );

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('¡Reporte guardado exitosamente!')),
    );
  }

  @override
  void dispose() {
    // Asegura que el stream de la cámara se detenga y los controladores/intérpretes se cierren al salir.
    _controller?.stopImageStream();
    _controller?.dispose();
    _objectDetector?.close(); // Cierra el detector de objetos
    _licensePlateRecognizer?.close(); // Cierra el detector de matrículas
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // Muestra un indicador de carga si la cámara no está inicializada.
    if (_controller == null || !_controller!.value.isInitialized) {
      return const Center(child: CircularProgressIndicator());
    }

    final screenWidth = MediaQuery.of(context).size.width;
    final screenHeight = MediaQuery.of(context).size.height;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Detección en Vivo'),
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.white),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      extendBodyBehindAppBar: true, // Extiende el cuerpo detrás de la AppBar transparente
      body: Stack(
        children: [
          // Vista previa de la cámara, ocupando todo el espacio disponible
          SizedBox(
            width: screenWidth,
            height: screenHeight,
            child: AspectRatio(
              aspectRatio: _controller!.value.aspectRatio,
              child: CameraPreview(_controller!),
            ),
          ),
          // Capa para dibujar las cajas delimitadoras de las detecciones
          Positioned.fill(
            child: LayoutBuilder(
              builder: (context, constraints) {
                final renderWidth = constraints.maxWidth;
                final renderHeight = constraints.maxHeight;

                return CustomPaint(
                  painter: BoundingBoxPainter(
                    _boundingBoxes, // Pasa la lista de cajas (vehículos y placas)
                    renderWidth,
                    renderHeight,
                    _controller?.description.sensorOrientation ?? 0,
                  ),
                );
              },
            ),
          ),
          // Barra lateral para mostrar los contadores
          Align(
            alignment: Alignment.centerRight,
            child: _sideBar,
          ),
          // Botón para guardar el reporte
          Positioned(
            bottom: 30,
            left: 0,
            right: 0,
            child: Center(
              child: ElevatedButton.icon(
                onPressed: _saveReport,
                icon: const Icon(Icons.save, size: 28),
                label: const Text(
                  'Guardar Reporte',
                  style: TextStyle(fontSize: 18),
                ),
                style: ElevatedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(horizontal: 30, vertical: 12),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(30),
                  ),
                  backgroundColor: Colors.blueAccent.withOpacity(0.8),
                  foregroundColor: Colors.white,
                  elevation: 5,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// CustomPainter para dibujar las cajas delimitadoras y etiquetas
class BoundingBoxPainter extends CustomPainter {
  final List<Map<String, dynamic>> detections;
  final double renderWidth;
  final double renderHeight;
  final int sensorOrientation;

  BoundingBoxPainter(
    this.detections,
    this.renderWidth,
    this.renderHeight,
    this.sensorOrientation,
  );

  @override
  void paint(Canvas canvas, Size size) {
    // Pintura para vehículos (cajas verdes)
    final vehiclePaint = Paint()
      ..color = Colors.green
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.0;

    // Pintura para matrículas (cajas amarillas, más gruesas)
    final platePaint = Paint()
      ..color = Colors.yellow
      ..style = PaintingStyle.stroke
      ..strokeWidth = 3.0;

    // Estilo de texto para etiquetas de vehículos (texto azul con fondo blanco)
    final vehicleTextStyle = const TextStyle(
      color: Colors.blue,
      fontSize: 16.0,
      fontWeight: FontWeight.bold,
      backgroundColor: Colors.white70,
    );

    // Estilo de texto para etiquetas de matrículas (texto negro con fondo amarillo)
    final plateTextStyle = const TextStyle(
      color: Colors.black,
      fontSize: 18.0,
      fontWeight: FontWeight.bold,
      backgroundColor: Colors.yellow,
    );

    // Itera sobre cada detección para dibujarla
    for (var detection in detections) {
      // Obtiene las coordenadas normalizadas de la detección
      final double left = detection['left'] as double;
      final double top = detection['top'] as double;
      final double right = detection['right'] as double;
      final double bottom = detection['bottom'] as double;
      final String label = detection['label']; // Etiqueta (ej. "car", "LicensePlate", o el texto de la placa)
      final bool isPlate = detection['isPlate'] ?? false; // Flag para saber si es una matrícula

      double actualLeft, actualTop, actualRight, actualBottom;

      // Ajusta las coordenadas de la caja según la orientación del sensor de la cámara
      // Esto es crucial para que las cajas se dibujen correctamente sin importar la rotación del dispositivo.
      switch (sensorOrientation) {
        case 90: // Orientación de la cámara horizontal derecha
          actualLeft = top * renderWidth;
          actualTop = (1 - right) * renderHeight;
          actualRight = bottom * renderWidth;
          actualBottom = (1 - left) * renderHeight;
          break;
        case 270: // Orientación de la cámara horizontal izquierda
          actualLeft = (1 - bottom) * renderWidth;
          actualTop = left * renderHeight;
          actualRight = (1 - top) * renderWidth;
          actualBottom = right * renderHeight;
          break;
        case 180: // Orientación de la cámara invertida
          actualLeft = (1 - right) * renderWidth;
          actualTop = (1 - bottom) * renderHeight;
          actualRight = (1 - left) * renderWidth;
          actualBottom = (1 - top) * renderHeight;
          break;
        default: // Orientación por defecto (portrait)
          actualLeft = left * renderWidth;
          actualTop = top * renderHeight;
          actualRight = right * renderWidth;
          actualBottom = bottom * renderHeight;
      }

      // Dibuja el rectángulo de la caja delimitadora con el color apropiado
      canvas.drawRect(Rect.fromLTRB(actualLeft, actualTop, actualRight, actualBottom), isPlate ? platePaint : vehiclePaint);

      // Prepara y dibuja el texto de la etiqueta
      final currentTextStyle = isPlate ? plateTextStyle : vehicleTextStyle;
      final textSpan = TextSpan(text: label, style: currentTextStyle);
      final textPainter = TextPainter(text: textSpan, textDirection: TextDirection.ltr);
      textPainter.layout(minWidth: 0, maxWidth: renderWidth);

      // Calcula la posición del texto (encima de la caja si hay espacio, o debajo si no)
      double labelY = actualTop - textPainter.height - 5;
      if (labelY < 0) {
        labelY = actualTop + 5;
      }

      textPainter.paint(canvas, Offset(actualLeft, labelY));
    }
  }

  @override
  bool shouldRepaint(covariant BoundingBoxPainter oldDelegate) {
    // Solo redibuja si las detecciones o las dimensiones de renderizado han cambiado
    return oldDelegate.detections != detections ||
        oldDelegate.renderWidth != renderWidth ||
        oldDelegate.renderHeight != renderHeight ||
        oldDelegate.sensorOrientation != sensorOrientation;
  }
}
