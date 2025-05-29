// Pega aquí el código completo de la clase `CameraScreen` que te di antes.
import 'package:flutter/material.dart';
import 'package:camera/camera.dart';
import 'package:image/image.dart' as img;
import 'dart:typed_data';
import 'package:permission_handler/permission_handler.dart'; // Para manejar permisos

import 'object_detector.dart';
import 'sidebar_widget.dart';

// Asegúrate de que esta variable `cameras` se inicialice en `main.dart`
// y se pase a CameraScreen si es necesario.
List<CameraDescription> cameras = [];

class CameraScreen extends StatefulWidget {
  const CameraScreen({Key? key}) : super(key: key);

  @override
  _CameraScreenState createState() => _CameraScreenState();
}

class _CameraScreenState extends State<CameraScreen> {
  CameraController? _controller;
  ObjectDetector? _objectDetector;
  // Usamos el GlobalKey para acceder a la instancia del estado de SideBarWidget
  final SideBarWidget _sideBar = SideBarWidget(key: SideBarWidget.sideBarKey);

  bool _isDetecting = false;

  @override
  void initState() {
    super.initState();
    _requestPermissions(); // Solicitar permisos al iniciar
  }

  Future<void> _requestPermissions() async {
    if (await Permission.camera.request().isGranted) {
      _initializeCamera();
      _objectDetector = ObjectDetector(300); // 300 es INPUT_SIZE
      _objectDetector!.loadModel();
    } else {
      // Manejar el caso de permisos denegados
      print("Permiso de cámara denegado.");
      // Puedes mostrar un AlertDialog o un mensaje al usuario
    }
  }

  Future<void> _initializeCamera() async {
    // Asegurarse de que `cameras` esté inicializado globalmente en `main.dart`
    // o pasarlo como argumento a CameraScreen.
    if (cameras.isEmpty) {
      cameras = await availableCameras();
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
          // Manejar errores específicos de la cámara
        }
      });
    }
  }

  Future<void> _processCameraImage(CameraImage cameraImage) async {
    // Convertir CameraImage a img.Image (paquete 'image')
    // Este es el paso más complejo y puede requerir optimización.
    // La rotación y el volteo (Core.flip, mat_image.t()) de OpenCV
    // deben replicarse aquí si son necesarios para la inferencia del modelo.
    // `image` paquete ofrece funciones como `copyRotate` y `flip`.

    // Nota: La conversión de YUV420 a RGB para el paquete 'image'
    // puede ser compleja y requerir ajustes finos para la orientación y color.
    // Asegúrate de que los píxeles estén en el rango 0-255 y en el orden correcto (RGB).

    img.Image? originalImage = _convertYUV420toImage(cameraImage);
    if (originalImage == null) {
      _isDetecting = false;
      return;
    }

    // Si tu modelo espera una imagen rotada o volteada como en tu código Java,
    // aplica las transformaciones aquí con el paquete `image`.
    // En tu código Java, hacías: `Core.flip(mat_image.t(), rotated_mat_image, 1);`
    // Esto es una transposición seguida de un volteo horizontal.
    // En `image` package sería algo como:
    // originalImage = img.copyRotate(originalImage, 90); // Transponer
    // originalImage = img.flipHorizontal(originalImage); // Voltear horizontalmente

    final detectedClasses = _objectDetector!.recognizeImage(originalImage);

    // Actualizar contadores en la barra lateral usando la GlobalKey
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final sideBarState = SideBarWidget.sideBarKey.currentState;
      if (sideBarState != null) {
        sideBarState.resetCounters();
        for (int classValue in detectedClasses) {
          if (classValue == 2) {
            sideBarState.incrementCarCount();
          } else if (classValue == 3) {
            sideBarState.incrementMotorcycleCount();
          } else if (classValue == 5) {
            sideBarState.incrementBusCount();
          } else if (classValue == 7) {
            sideBarState.incrementTruckCount();
          }
        }
        sideBarState.updateEstimatedTime();
      }
      // No es necesario setState aquí en CameraScreen a menos que dibujes las bounding boxes
    });

    _isDetecting = false;
  }

  // Convierte CameraImage (YUV420_888) a img.Image (RGB)
  // Esta es una implementación genérica y puede necesitar ajustes
  // dependiendo del dispositivo y la orientación de la cámara.
  img.Image? _convertYUV420toImage(CameraImage image) {
    try {
      final int width = image.width;
      final int height = image.height;

      // Accede a los planos de la imagen YUV
      final Uint8List yPlane = image.planes[0].bytes;
      final Uint8List uPlane = image.planes[1].bytes;
      final Uint8List vPlane = image.planes[2].bytes;

      // Asumiendo que el formato es YUV420_888, los planos U y V están submuestreados 2x2.
      final int uvRowStride = image.planes[1].bytesPerRow;
      final int uvPixelStride = image.planes[1].bytesPerPixel ?? 1;

      final img.Image rgbImage = img.Image(width: width, height: height);

      // Iterar sobre cada píxel para convertir YUV a RGB
      for (int y = 0; y < height; y++) {
        for (int x = 0; x < width; x++) {
          final int Y = yPlane[y * image.planes[0].bytesPerRow + x];
          final int UV_x = (x ~/ 2);
          final int UV_y = (y ~/ 2);

          // Accede a U y V directamente desde sus planos submuestreados
          final int V = vPlane[UV_y * uvRowStride + UV_x * uvPixelStride];
          final int U = uPlane[UV_y * uvRowStride + UV_x * uvPixelStride];

          // Conversión YUV a RGB (Estándar BT.601)
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

    // Escalar la vista previa de la cámara para que ocupe todo el espacio manteniendo el aspecto
    final size = MediaQuery.of(context).size;
    final scale = size.aspectRatio / _controller!.value.aspectRatio;

    return Scaffold(
      body: Stack(
        children: [
          // Vista previa de la cámara
          Transform.scale(
            scale: scale,
            child: Center(
              child: CameraPreview(_controller!),
            ),
          ),
          // Aquí podrías dibujar las bounding boxes usando CustomPaint
          // Ejemplo:
          // Positioned.fill(
          //   child: CustomPaint(
          //     painter: BoundingBoxPainter(
          //       _objectDetector?.detectedBoundingBoxes ?? [],
          //       _controller!.value.previewSize!.height, // Altura de la vista previa
          //       _controller!.value.previewSize!.width,  // Ancho de la vista previa
          //       context, // Pasar context para Theme.of
          //     ),
          //   ),
          // ),

          // Barra lateral
          Align(
            alignment: Alignment.centerRight,
            child: _sideBar,
          ),
        ],
      ),
    );
  }
}

// Opcional: Clase para dibujar las bounding boxes (similar a Imgproc.rectangle)
// Puedes crear un nuevo archivo para esto o incluirlo aquí si es pequeño
class BoundingBoxPainter extends CustomPainter {
  final List<Map<String, dynamic>> detections;
  final double imageHeight;
  final double imageWidth;
  final BuildContext context; // Para acceder al tema y estilos

  BoundingBoxPainter(this.detections, this.imageHeight, this.imageWidth, this.context);

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = Colors.green // Color de la caja (similar a Scalar(0, 255, 0, 255))
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.0; // Ancho de la línea

    final textStyle = TextStyle(
      color: Colors.blue, // Color del texto (similar a Scalar(255, 0, 0, 255))
      fontSize: 16.0,
      fontWeight: FontWeight.bold,
    );

    for (var detection in detections) {
      final top = detection['top'] * size.height / imageHeight;
      final left = detection['left'] * size.width / imageWidth;
      final bottom = detection['bottom'] * size.height / imageHeight;
      final right = detection['right'] * size.width / imageWidth;
      final label = detection['label'];

      // Dibujar el rectángulo
      canvas.drawRect(Rect.fromLTRB(left, top, right, bottom), paint);

      // Dibujar el texto de la etiqueta
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
        maxWidth: size.width,
      );
      textPainter.paint(canvas, Offset(left, top - textPainter.height - 5)); // Ajusta la posición del texto
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) {
    return true; // Siempre repintar si hay nuevas detecciones
  }
}