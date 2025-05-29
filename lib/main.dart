import 'package:flutter/material.dart';
import 'package:camera/camera.dart'; // Importa el paquete de la cámara
import 'package:flutter/services.dart'; // Para controlar la orientación
import 'camera_screen.dart'; // Tu nueva pantalla de la cámara

// Declara una lista global para las cámaras disponibles
// Esto es común para el paquete `camera`
late List<CameraDescription> cameras;

Future<void> main() async {
  // Asegúrate de que Flutter esté inicializado
  WidgetsFlutterBinding.ensureInitialized();

  // Controlar la orientación de la pantalla (opcional, pero puede ser útil para apps de cámara)
  SystemChrome.setPreferredOrientations([
    DeviceOrientation.portraitUp,
    DeviceOrientation.portraitDown,
  ]);

  // Obtener las cámaras disponibles
  try {
    cameras = await availableCameras();
  } on CameraException catch (e) {
    print('Error getting available cameras: $e');
    // Manejar el error si no se pueden obtener las cámaras
  }

  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Detector de Filas de Gasolina',
      theme: ThemeData(
        primarySwatch: Colors.blue,
      ),
      home: const CameraScreen(), // Inicia la aplicación en tu pantalla de cámara
    );
  }
}