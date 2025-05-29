import 'package:flutter/material.dart';
import 'package:camera/camera.dart';
import 'package:image/image.dart' as img;
import 'dart:typed_data';
import 'package:permission_handler/permission_handler.dart'; // Para manejar permisos

import 'object_detector.dart'; // Asegúrate de que este archivo exista
import 'sidebar_widget.dart'; // Asegúrate de que este archivo exista

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
  // Añadir un estado para las bounding boxes detectadas
  List<Map<String, dynamic>> _boundingBoxes = [];

  @override
  void initState() {
    super.initState();
    _requestPermissions(); // Solicitar permisos al iniciar
  }

  Future<void> _requestPermissions() async {
    if (await Permission.camera.request().isGranted) {
      _initializeCamera();
      // Asegúrate de que INPUT_SIZE en ObjectDetector sea 300, si tu modelo lo espera.
      _objectDetector = ObjectDetector(300);
      await _objectDetector!.loadModel(); // Esperar a que el modelo se cargue
    } else {
      // Manejar el caso de permisos denegados
      print("Permiso de cámara denegado.");
      // Puedes mostrar un AlertDialog o un mensaje al usuario para informar.
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
        cameras[0], // Usa la primera cámara disponible
        ResolutionPreset.medium, // Puedes probar con .high o .max si tu dispositivo lo soporta y no da OOM
        enableAudio: false,
        imageFormatGroup: ImageFormatGroup.yuv420,
      );

      _controller!.initialize().then((_) {
        if (!mounted) {
          return;
        }
        setState(() {}); // Forzar un rebuild para mostrar la CameraPreview

        // Iniciar el stream de imágenes para procesamiento
        _controller!.startImageStream((CameraImage image) {
          if (!_isDetecting) {
            _isDetecting = true;
            _processCameraImage(image);
          }
        });
      }).catchError((Object e) {
        if (e is CameraException) {
          print('Error initializing camera: ${e.code}');
          // Manejar errores específicos de la cámara, como si la cámara ya está en uso.
        }
      });
    } else {
      print("No se encontraron cámaras disponibles.");
      // Puedes mostrar un mensaje al usuario.
    }
  }

  Future<void> _processCameraImage(CameraImage cameraImage) async {
    img.Image? originalImage = _convertYUV420toImage(cameraImage);
    if (originalImage == null) {
      _isDetecting = false;
      return;
    }

    // **** CRÍTICO PARA EVITAR OutOfMemoryError Y AJUSTAR AL MODELO ****
    // Redimensionar la imagen a las dimensiones de entrada del modelo (300x300).
    // Esto reduce significativamente el consumo de memoria y se alinea con el modelo.
    img.Image resizedImage = img.copyResize(originalImage, width: 300, height: 300);

    // ** Considera las transformaciones de orientación aquí **
    // Si tu modelo fue entrenado con imágenes rotadas (como se infiere de algunos ejemplos de TFLite con Android CameraX)
    // o volteadas, aplica esas mismas transformaciones a `resizedImage`.
    // Por ejemplo:
    // resizedImage = img.copyRotate(resizedImage, 90); // Rotar 90 grados
    // resizedImage = img.flipHorizontal(resizedImage); // Voltear horizontalmente

    // Llama al detector de objetos con la imagen redimensionada
    await _objectDetector!.recognizeImage(resizedImage); // <-- Aquí le pasamos la imagen ya redimensionada

    // Obtener las detecciones del detector
    final detectedBoxes = _objectDetector!.detectedBoundingBoxes;

    // Actualizar el estado de _boundingBoxes para que CustomPaint repinte
    setState(() {
      _boundingBoxes = detectedBoxes;
    });

    // Actualizar contadores en la barra lateral usando la GlobalKey
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final sideBarState = SideBarWidget.sideBarKey.currentState;
      if (sideBarState != null) {
        sideBarState.resetCounters(); // Resetear contadores antes de actualizar
        // Iterar sobre las detecciones para actualizar los contadores
        for (var box in detectedBoxes) {
          final classValue = box['classIndex'] as int;
          // Asumiendo que 2: car, 3: motorcycle, 5: bus, 7: truck de tu labelmap
          if (classValue == 2) {
            sideBarState.incrementCarCount();
          } else if (classValue == 3) {
            sideBarState.incrementMotorcycleCount();
          } else if (classValue == 5) {
            sideBarState.incrementBusCount();
          } else if (classValue == 7) {
            sideBarState.incrementTruckCount();
          }
          // Si quieres ver las clases detectadas en el log para depurar:
          // print("DEBUG: Detected class $classValue (label: ${box['label']})");
        }
        sideBarState.updateEstimatedTime();
      }
    });

    _isDetecting = false; // Liberar el bloqueo para la siguiente detección
  }

  // Convierte CameraImage (YUV420_888) a img.Image (RGB)
  // Este código de conversión es estándar para YUV420_888 a RGB.
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

          // Asegurarse de no exceder los límites de los arrays UV
          int uIndex = UV_y * uvRowStride + UV_x * uvPixelStride;
          int vIndex = UV_y * uvRowStride + UV_x * uvPixelStride;

          // Clampear los índices para evitar OutOfBounds si hay un error de cálculo o formato inesperado
          uIndex = uIndex.clamp(0, uPlane.length - 1);
          vIndex = vIndex.clamp(0, vPlane.length - 1);


          final int V = vPlane[vIndex];
          final int U = uPlane[uIndex];

          // Conversión YUV a RGB (Estándar BT.601)
          // Estos son valores constantes para la conversión.
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

    final screenWidth = MediaQuery.of(context).size.width;
    final screenHeight = MediaQuery.of(context).size.height;

    // Obtener las dimensiones del preview de la cámara
    // NOTA: previewSize a menudo reporta en orientación de paisaje (width > height)
    // incluso si el dispositivo está en retrato. La CameraPreview lo rota visualmente.
    final cameraPreviewSize = _controller!.value.previewSize!;

    // Las dimensiones que usaremos para el SizedBox dentro de FittedBox
    // para que CameraPreview se muestre correctamente en retrato.
    // Invertimos porque previewSize a menudo es landscape y CameraPreview se rota.
    final double cameraPreviewDisplayWidth = cameraPreviewSize.height;
    final double cameraPreviewDisplayHeight = cameraPreviewSize.width;


    return Scaffold(
      body: Stack(
        children: [
          // Vista previa de la cámara (se ajustará para cubrir el espacio)
          SizedBox(
            width: screenWidth,
            height: screenHeight,
            child: FittedBox(
              fit: BoxFit.cover, // Para asegurar que la vista previa cubra todo el espacio
              child: SizedBox(
                width: cameraPreviewDisplayWidth,
                height: cameraPreviewDisplayHeight,
                child: CameraPreview(_controller!),
              ),
            ),
          ),
          // Capa para dibujar las bounding boxes
          Positioned.fill(
            child: LayoutBuilder( // Usamos LayoutBuilder para obtener las dimensiones reales de la capa de dibujo
              builder: (context, constraints) {
                // Estas son las dimensiones del lienzo donde dibujaremos las cajas
                final renderWidth = constraints.maxWidth;
                final renderHeight = constraints.maxHeight;

                // Importante: originalImageWidth/Height deben ser las dimensiones
                // DE LA IMAGEN TAL COMO LA VE EL PAINTER, que debe ser
                // como la ve la CameraPreview visualmente.
                // Si previewSize es (1280, 720) y la app está en retrato,
                // la CameraPreview lo muestra como (720, 1280) visualmente.
                // Por lo tanto, usamos cameraPreviewDisplayHeight/Width aquí.
                return CustomPaint(
                  painter: BoundingBoxPainter(
                    _boundingBoxes,
                    cameraPreviewDisplayHeight, // Altura visual de la vista previa de la cámara
                    cameraPreviewDisplayWidth,  // Ancho visual de la vista previa de la cámara
                    renderWidth,        // Ancho real donde se dibujan las cajas
                    renderHeight,       // Alto real donde se dibujan las cajas
                    context,
                  ),
                );
              },
            ),
          ),

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

// Clase para dibujar las bounding boxes
class BoundingBoxPainter extends CustomPainter {
  final List<Map<String, dynamic>> detections;
  final double originalImageRenderHeight; // Altura de la imagen tal como se muestra en la vista previa
  final double originalImageRenderWidth;  // Ancho de la imagen tal como se muestra en la vista previa
  final double renderWidth;               // Ancho del lienzo del CustomPaint
  final double renderHeight;              // Alto del lienzo del CustomPaint
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
      ..color = Colors.green // Color de la caja (mantengo tu color)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.0;

    final textStyle = TextStyle(
      color: Colors.blue, // Color del texto (mantengo tu color)
      fontSize: 16.0,
      fontWeight: FontWeight.bold,
      backgroundColor: Colors.white70, // Para que el texto sea más legible (mantengo tu color)
    );

    for (var detection in detections) {
      // Las coordenadas de detección (top, left, bottom, right) ya están normalizadas (0-1)
      // por el modelo. Ahora necesitamos escalarlas a las dimensiones del lienzo del CustomPaint.
      final double normalizedLeft = detection['left'] as double;
      final double normalizedTop = detection['top'] as double;
      final double normalizedRight = detection['right'] as double;
      final double normalizedBottom = detection['bottom'] as double;
      final String label = detection['label'];

      // Escalar las coordenadas normalizadas (0-1) a las dimensiones de renderizado del CustomPaint.
      // Ya no se requiere la doble escalada.
      final double actualLeft = normalizedLeft * renderWidth;
      final double actualTop = normalizedTop * renderHeight;
      final double actualRight = normalizedRight * renderWidth;
      final double actualBottom = normalizedBottom * renderHeight;

      // Dibujar el rectángulo
      canvas.drawRect(Rect.fromLTRB(actualLeft, actualTop, actualRight, actualBottom), paint);

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
        maxWidth: renderWidth,
      );
      // Posicionar el texto encima de la caja
      textPainter.paint(canvas, Offset(actualLeft, actualTop - textPainter.height - 5));
    }
  }

  @override
  bool shouldRepaint(covariant BoundingBoxPainter oldDelegate) {
    // Repintar solo si las detecciones han cambiado, o las dimensiones han cambiado.
    return oldDelegate.detections != detections ||
        oldDelegate.originalImageRenderHeight != originalImageRenderHeight ||
        oldDelegate.originalImageRenderWidth != originalImageRenderWidth ||
        oldDelegate.renderWidth != renderWidth ||
        oldDelegate.renderHeight != renderHeight;
  }
}