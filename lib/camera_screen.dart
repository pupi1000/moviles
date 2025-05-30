import 'package:flutter/material.dart';
import 'package:camera/camera.dart';
import 'package:image/image.dart' as img;
import 'dart:typed_data';
import 'package:permission_handler/permission_handler.dart';

import 'object_detector.dart';
import 'sidebar_widget.dart';
import 'report_manager.dart'; // Importa el manejador de reportes

// Asegúrate de que esta variable `cameras` se inicialice en `main.dart`
// y se pase a CameraScreen si es necesario.
// Nota: 'cameras' está declarada como 'late List<CameraDescription> cameras;' en main.dart
// y se inicializa antes de runApp. Flutter automáticamente la hace accesible.
// Si esta 'cameras' en CameraScreen no está inicializada, es porque no se está
// pasando correctamente o main.dart no la inicializó.
// Para este ejemplo, asumimos que se inicializa globalmente o se pasa.
// Si no, podrías pasarla como argumento al constructor de CameraScreen.
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

  bool _isDetecting = false;
  List<Map<String, dynamic>> _boundingBoxes = [];

  // Datos actuales para el reporte
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
      await _objectDetector!.loadModel();
    } else {
      print("Permiso de cámara denegado.");
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Permiso de cámara denegado. No se puede iniciar la detección.')),
      );
    }
  }

  Future<void> _initializeCamera() async {
    // Accede a la variable `cameras` globalmente desde main.dart si está inicializada
    // O podrías pasarla a CameraScreen si la inicializas solo en main.dart
    if (cameras.isEmpty) {
      cameras = await availableCameras(); // Intentar obtenerlas de nuevo si están vacías aquí
    }

    if (cameras.isNotEmpty) {
      _controller = CameraController(
        cameras[0],
        ResolutionPreset.medium,
        enableAudio: false,
        imageFormatGroup: ImageFormatGroup.yuv420,
      );

      _controller!.initialize().then((_) {
        if (!mounted) {
          return;
        }
        setState(() {});

        _controller!.startImageStream((CameraImage image) {
          if (!_isDetecting) {
            _isDetecting = true;
            _processCameraImage(image);
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

    WidgetsBinding.instance.addPostFrameCallback((_) {
      final sideBarState = SideBarWidget.sideBarKey.currentState;
      if (sideBarState != null) {
        sideBarState.resetCounters();
        _currentCarCount = 0;
        _currentMotorcycleCount = 0;
        _currentBusCount = 0;
        _currentTruckCount = 0;

        for (var box in detectedBoxes) {
          final classValue = box['classIndex'] as int;
          if (classValue == 2) {
            sideBarState.incrementCarCount();
            _currentCarCount++;
          } else if (classValue == 3) {
            sideBarState.incrementMotorcycleCount();
            _currentMotorcycleCount++;
          } else if (classValue == 5) {
            sideBarState.incrementBusCount();
            _currentBusCount++;
          } else if (classValue == 7) {
            sideBarState.incrementTruckCount();
            _currentTruckCount++;
          }
        }
        sideBarState.updateEstimatedTime();
        _currentEstimatedTime = sideBarState.getEstimatedTime(); // Obtener el tiempo estimado
      }
    });

    _isDetecting = false;
  }

  // Convierte CameraImage (YUV420_888) a img.Image (RGB)
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
    // Asegúrate de que ReportManager esté importado y accesible
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
    _controller?.dispose();
    _objectDetector?.close();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (_controller == null || !_controller!.value.isInitialized) {
      return const Center(child: CircularProgressIndicator());
    }

    final screenWidth = MediaQuery.of(context).size.width;
    final screenHeight = MediaQuery.of(context).size.height;

    final cameraPreviewSize = _controller!.value.previewSize!;

    // Invertir width y height si la orientación de la cámara es vertical para hacer un ajuste correcto
    // Esto es común con CameraController
    final double cameraPreviewDisplayWidth = cameraPreviewSize.height;
    final double cameraPreviewDisplayHeight = cameraPreviewSize.width;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Detección en Vivo'),
        backgroundColor: Colors.transparent, // Fondo transparente para que se vea la cámara
        elevation: 0, // Sin sombra
      ),
      extendBodyBehindAppBar: true, // Extender el cuerpo detrás del AppBar
      body: Stack(
        children: [
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
          Positioned.fill(
            child: LayoutBuilder(
              builder: (context, constraints) {
                final renderWidth = constraints.maxWidth;
                final renderHeight = constraints.maxHeight;

                return CustomPaint(
                  painter: BoundingBoxPainter(
                    _boundingBoxes,
                    cameraPreviewDisplayHeight,
                    cameraPreviewDisplayWidth,
                    renderWidth,
                    renderHeight,
                    context,
                  ),
                );
              },
            ),
          ),
          Align(
            alignment: Alignment.centerRight,
            child: _sideBar,
          ),
          // Botón de guardar reporte
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
                  backgroundColor: Colors.blueAccent.withOpacity(0.8), // Color más visible
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

// Clase para dibujar las bounding boxes (sin cambios, solo se incluye para que sea un código completo)
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