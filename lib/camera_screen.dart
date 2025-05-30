// lib/camera_screen.dart
import 'package:flutter/material.dart';
import 'package:camera/camera.dart';
import 'package:image/image.dart' as img;
import 'dart:typed_data';
import 'package:permission_handler/permission_handler.dart';

import 'object_detector.dart';
import 'sidebar_widget.dart';
import 'report_manager.dart';

// Definir cámaras como global para que main.dart pueda inicializarla
List<CameraDescription> cameras = [];

class CameraScreen extends StatefulWidget {
  const CameraScreen({Key? key}) : super(key: key);

  @override
  _CameraScreenState createState() => _CameraScreenState();
}

class _CameraScreenState extends State<CameraScreen> {
  CameraController? _controller;
  ObjectDetector? _objectDetector;
  final SideBarWidget _sideBar = SideBarWidget(key: SideBarWidget.sideBarKey);

  bool _isDetecting = false; // Flag para controlar si ya estamos detectando una imagen
  List<Map<String, dynamic>> _boundingBoxes = [];

  int _currentCarCount = 0;
  int _currentMotorcycleCount = 0;
  int _currentBusCount = 0;
  int _currentTruckCount = 0;
  String _currentEstimatedTime = "00:00";

  @override
  void initState() {
    super.initState();
    _requestPermissions();
  }

  Future<void> _requestPermissions() async {
    if (await Permission.camera.request().isGranted) {
      _initializeCamera();
      _objectDetector = ObjectDetector(300);
      await _objectDetector!.loadModel(); // Carga el modelo aquí
    } else {
      print("Permiso de cámara denegado.");
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Permiso de cámara denegado. No se puede iniciar la detección.')),
      );
    }
  }

  Future<void> _initializeCamera() async {
    if (cameras.isEmpty) {
      // Intenta obtener las cámaras si aún no están inicializadas
      try {
        cameras = await availableCameras();
      } on CameraException catch (e) {
        print('Error getting available cameras: $e');
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error al obtener cámaras: ${e.description}')),
        );
        return;
      }
    }

    if (cameras.isNotEmpty) {
      _controller = CameraController(
        cameras[0], // Usa la primera cámara disponible
        ResolutionPreset.medium, // Resolución media para mejor rendimiento
        enableAudio: false,
        imageFormatGroup: ImageFormatGroup.yuv420, // Formato YUV420 para procesamiento de imágenes
      );

      _controller!.initialize().then((_) {
        if (!mounted) {
          return;
        }
        setState(() {}); // Reconstruye el widget cuando la cámara esté lista

        // Inicia el stream de imágenes de la cámara
        _controller!.startImageStream((CameraImage image) {
          if (!_isDetecting) { // Si no estamos ya procesando una imagen
            _isDetecting = true; // Establece el flag a true
            _processCameraImage(image); // Procesa la imagen
          }
        });
      }).catchError((Object e) {
        if (e is CameraException) {
          print('Error initializing camera: ${e.code}');
          String errorMessage = 'Error al iniciar la cámara: ${e.code}';
          if (e.code == 'CameraAccessDenied') {
            errorMessage = 'Acceso a la cámara denegado. Por favor, conceda el permiso.';
          } else if (e.code == 'AlreadyStarted') {
            errorMessage = 'La cámara ya está en uso.';
          }
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(errorMessage)),
          );
        } else {
          print('Error initializing camera: $e');
        }
      });
    } else {
      print("No se encontraron cámaras disponibles.");
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('No se encontraron cámaras disponibles.')),
      );
    }
  }

  Future<void> _processCameraImage(CameraImage cameraImage) async {
    if (_objectDetector == null || !_objectDetector!.isModelLoaded) {
      // Evita procesar si el modelo no está listo
      _isDetecting = false;
      return;
    }

    img.Image? originalImage = _convertYUV420toImage(cameraImage);
    if (originalImage == null) {
      _isDetecting = false;
      return;
    }

    img.Image resizedImage = img.copyResize(originalImage, width: 300, height: 300);

    await _objectDetector!.recognizeImage(resizedImage);

    final detectedBoxes = _objectDetector!.detectedBoundingBoxes;

    setState(() {
      _boundingBoxes = detectedBoxes;
    });

    // Asegúrate de que el SideBarWidget se actualice en el siguiente frame
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final sideBarState = SideBarWidget.sideBarKey.currentState;
      if (sideBarState != null) {
        sideBarState.resetCounters(); // Reinicia contadores para esta nueva detección
        _currentCarCount = 0;
        _currentMotorcycleCount = 0;
        _currentBusCount = 0;
        _currentTruckCount = 0;

        for (var box in detectedBoxes) {
          final classValue = box['classIndex'] as int;
          if (classValue == 2) { // Carro
            sideBarState.incrementCarCount();
            _currentCarCount++;
          } else if (classValue == 3) { // Moto
            sideBarState.incrementMotorcycleCount();
            _currentMotorcycleCount++;
          } else if (classValue == 5) { // Bus
            sideBarState.incrementBusCount();
            _currentBusCount++;
          } else if (classValue == 7) { // Camión
            sideBarState.incrementTruckCount();
            _currentTruckCount++;
          }
        }
        sideBarState.updateEstimatedTime(); // Actualiza el tiempo estimado
        _currentEstimatedTime = sideBarState.getEstimatedTime();
      }
    });

    _isDetecting = false; // Restablece el flag para la siguiente imagen
  }

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
      print("Error converting YUV420 to Image: $e");
      return null;
    }
  }

  void _saveReport() {
    ReportManager.addReport(
      carCount: _currentCarCount,
      motorcycleCount: _currentMotorcycleCount,
      busCount: _currentBusCount,
      truckCount: _currentTruckCount,
      estimatedTime: _currentEstimatedTime,
      timestamp: DateTime.now(),
    );
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Reporte guardado exitosamente!')),
    );
  }

  @override
  void dispose() {
    _controller?.stopImageStream(); // Detén el stream de imágenes
    _controller?.dispose(); // Libera el controlador de la cámara
    _objectDetector?.close(); // Cierra el intérprete de TFLite
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (_controller == null || !_controller!.value.isInitialized) {
      return const Center(child: CircularProgressIndicator());
    }

    final screenWidth = MediaQuery.of(context).size.width;
    final screenHeight = MediaQuery.of(context).size.height;

    // Asegúrate de que los valores sean correctos para tu orientación (portrait)
    // Camera preview size might be swapped depending on device orientation
    // For a portrait app, width will be the smaller dimension of the preview size
    // and height will be the larger dimension.
    final double cameraPreviewDisplayWidth = _controller!.value.previewSize!.height;
    final double cameraPreviewDisplayHeight = _controller!.value.previewSize!.width;


    return Scaffold(
      appBar: AppBar(
        title: const Text('Detección en Vivo'),
        backgroundColor: Colors.transparent, // Fondo transparente para ver la cámara
        elevation: 0, // Sin sombra
        leading: IconButton( // Botón de volver al inicio
          icon: const Icon(Icons.arrow_back, color: Colors.white),
          onPressed: () {
            Navigator.pop(context); // Vuelve a la pantalla anterior (HomeScreen)
          },
        ),
      ),
      extendBodyBehindAppBar: true, // Extiende el body detrás de la AppBar
      body: Stack(
        children: [
          // Vista previa de la cámara
          SizedBox(
            width: screenWidth,
            height: screenHeight,
            child: FittedBox(
              fit: BoxFit.cover,
              child: SizedBox(
                width: cameraPreviewDisplayWidth,
                height: cameraPreviewDisplayHeight,
                child: CameraPreview(_controller!),
              ),
            ),
          ),
          // Bounding boxes para las detecciones
          Positioned.fill(
            child: LayoutBuilder(
              builder: (context, constraints) {
                final renderWidth = constraints.maxWidth;
                final renderHeight = constraints.maxHeight;

                return CustomPaint(
                  painter: BoundingBoxPainter(
                    _boundingBoxes,
                    cameraPreviewDisplayHeight, // Altura real de la imagen de la cámara
                    cameraPreviewDisplayWidth,  // Ancho real de la imagen de la cámara
                    renderWidth,                // Ancho del widget de renderizado
                    renderHeight,               // Altura del widget de renderizado
                    context,
                  ),
                );
              },
            ),
          ),
          // Sidebar
          Align(
            alignment: Alignment.centerRight,
            child: _sideBar,
          ),
          // Botón Guardar Reporte
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

// BoundingBoxPainter (sin cambios)
class BoundingBoxPainter extends CustomPainter {
  final List<Map<String, dynamic>> detections;
  final double originalImageRenderHeight;
  final double originalImageRenderWidth;
  final double renderWidth;
  final double renderHeight;
  final BuildContext context;

  BoundingBoxPainter(
    this.detections,
    this.originalImageRenderHeight,
    this.originalImageRenderWidth,
    this.renderWidth,
    this.renderHeight,
    this.context,
  );

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = Colors.green
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.0;

    final textStyle = TextStyle(
      color: Colors.blue,
      fontSize: 16.0,
      fontWeight: FontWeight.bold,
      backgroundColor: Colors.white70,
    );

    for (var detection in detections) {
      final double normalizedLeft = detection['left'] as double;
      final double normalizedTop = detection['top'] as double;
      final double normalizedRight = detection['right'] as double;
      final double normalizedBottom = detection['bottom'] as double;
      final String label = detection['label'];

      // Escalar las coordenadas normalizadas al tamaño de renderizado
      final double actualLeft = normalizedLeft * renderWidth;
      final double actualTop = normalizedTop * renderHeight;
      final double actualRight = normalizedRight * renderWidth;
      final double actualBottom = normalizedBottom * renderHeight;

      canvas.drawRect(Rect.fromLTRB(actualLeft, actualTop, actualRight, actualBottom), paint);

      final textSpan = TextSpan(
        text: label,
        style: textStyle,
      );
      final textPainter = TextPainter(
        text: textSpan,
        textDirection: TextDirection.ltr,
      );
      textPainter.layout(
        minWidth: 0,
        maxWidth: renderWidth,
      );
      // Posicionar el texto encima del bounding box
      textPainter.paint(canvas, Offset(actualLeft, actualTop - textPainter.height - 5));
    }
  }

  @override
  bool shouldRepaint(covariant BoundingBoxPainter oldDelegate) {
    return oldDelegate.detections != detections ||
        oldDelegate.originalImageRenderHeight != originalImageRenderHeight ||
        oldDelegate.originalImageRenderWidth != originalImageRenderWidth ||
        oldDelegate.renderWidth != renderWidth ||
        oldDelegate.renderHeight != renderHeight;
  }
}