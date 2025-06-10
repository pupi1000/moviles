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
      await _initializeCamera();
      _objectDetector = ObjectDetector(300);
      await _objectDetector!.loadModel();
    } else {
      print("Permiso de cámara denegado.");
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Permiso de cámara denegado. No se puede iniciar la detección.')),
        );
      }
    }
  }

  Future<void> _initializeCamera() async {
    if (cameras.isEmpty) {
      try {
        cameras = await availableCameras();
      } on CameraException catch (e) {
        print('Error getting available cameras: $e');
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Error al obtener cámaras: ${e.description}')),
          );
        }
        return;
      }
    }

    if (cameras.isNotEmpty) {
      _controller = CameraController(
        cameras[0],
        ResolutionPreset.medium,
        enableAudio: false,
        imageFormatGroup: ImageFormatGroup.yuv420,
      );

      await _controller!.initialize();

      if (!mounted) return;

      setState(() {});

      _controller!.startImageStream((CameraImage image) {
        if (!_isDetecting) {
          _isDetecting = true;
          _processCameraImage(image);
        }
      });
    } else {
      print("No se encontraron cámaras disponibles.");
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('No se encontraron cámaras disponibles.')),
        );
      }
    }
  }

  Future<void> _processCameraImage(CameraImage cameraImage) async {
    if (_objectDetector == null || !_objectDetector!.isModelLoaded) {
      _isDetecting = false;
      return;
    }

    img.Image? originalImage = _convertYUV420toImage(cameraImage);
    if (originalImage == null) {
      _isDetecting = false;
      return;
    }

    int sensorOrientation = _controller?.description.sensorOrientation ?? 0;

    // Rota la imagen según orientación del sensor para que el modelo reciba la imagen en la orientación correcta
    if (sensorOrientation == 90) {
      originalImage = img.copyRotate(originalImage, angle: 90);
    } else if (sensorOrientation == 270) {
      originalImage = img.copyRotate(originalImage, angle: -90);
    } else if (sensorOrientation == 180) {
      originalImage = img.copyRotate(originalImage, angle: 180);
    }

    // Cambia tamaño a 300x300 que es el tamaño esperado por el modelo
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
        _currentEstimatedTime = sideBarState.getEstimatedTime();
      }
    });

    _isDetecting = false;
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
    _controller?.stopImageStream();
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
      extendBodyBehindAppBar: true,
      body: Stack(
        children: [
          SizedBox(
            width: screenWidth,
            height: screenHeight,
            child: AspectRatio(
              aspectRatio: _controller!.value.aspectRatio,
              child: CameraPreview(_controller!),
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
                    renderWidth,
                    renderHeight,
                    _controller?.description.sensorOrientation ?? 0,
                  ),
                );
              },
            ),
          ),
          Align(
            alignment: Alignment.centerRight,
            child: _sideBar,
          ),
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
      final double left = detection['left'] as double;
      final double top = detection['top'] as double;
      final double right = detection['right'] as double;
      final double bottom = detection['bottom'] as double;
      final String label = detection['label'];

      double actualLeft, actualTop, actualRight, actualBottom;

      // Corrige las coordenadas según la orientación del sensor
      switch (sensorOrientation) {
        case 90:
          actualLeft = top * renderWidth;
          actualTop = (1 - right) * renderHeight;
          actualRight = bottom * renderWidth;
          actualBottom = (1 - left) * renderHeight;
          break;
        case 270:
          actualLeft = (1 - bottom) * renderWidth;
          actualTop = left * renderHeight;
          actualRight = (1 - top) * renderWidth;
          actualBottom = right * renderHeight;
          break;
        case 180:
          actualLeft = (1 - right) * renderWidth;
          actualTop = (1 - bottom) * renderHeight;
          actualRight = (1 - left) * renderWidth;
          actualBottom = (1 - top) * renderHeight;
          break;
        default:
          actualLeft = left * renderWidth;
          actualTop = top * renderHeight;
          actualRight = right * renderWidth;
          actualBottom = bottom * renderHeight;
      }

      canvas.drawRect(Rect.fromLTRB(actualLeft, actualTop, actualRight, actualBottom), paint);

      final textSpan = TextSpan(text: label, style: textStyle);
      final textPainter = TextPainter(text: textSpan, textDirection: TextDirection.ltr);
      textPainter.layout(minWidth: 0, maxWidth: renderWidth);

      // Ajusta la posición vertical para que no se superponga con la caja
      double labelY = actualTop - textPainter.height - 5;
      if (labelY < 0) {
        labelY = actualTop + 5;
      }

      textPainter.paint(canvas, Offset(actualLeft, labelY));
    }
  }

  @override
  bool shouldRepaint(covariant BoundingBoxPainter oldDelegate) {
    return oldDelegate.detections != detections ||
        oldDelegate.renderWidth != renderWidth ||
        oldDelegate.renderHeight != renderHeight ||
        oldDelegate.sensorOrientation != sensorOrientation;
  }
}
