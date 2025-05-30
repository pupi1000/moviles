// lib/main.dart
// (Contenido completo para referencia, asegúrate de que el tuyo sea idéntico)

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:camera/camera.dart';
import 'camera_screen.dart';
import 'reports_screen.dart';

// Esta variable debe ser global para que CameraScreen pueda acceder a ella
late List<CameraDescription> cameras;

Future<void> main() async {
  // Asegúrate de que los widgets de Flutter estén inicializados
  WidgetsFlutterBinding.ensureInitialized();

  // Bloquear la orientación de la pantalla a vertical
  SystemChrome.setPreferredOrientations([
    DeviceOrientation.portraitUp,
    DeviceOrientation.portraitDown,
  ]);

  // Obtener las cámaras disponibles (se hace aquí para que sea global)
  try {
    cameras = await availableCameras();
  } on CameraException catch (e) {
    print('Error getting available cameras: $e');
    // Puedes mostrar un AlertDialog al usuario aquí si no hay cámaras
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
        visualDensity: VisualDensity.adaptivePlatformDensity,
      ),
      // *** ESTO ES CLAVE: Define la ruta inicial a tu HomeScreen ***
      initialRoute: '/',
      routes: {
        '/': (context) => const HomeScreen(),        // Tu pantalla de inicio
        '/camera': (context) => const CameraScreen(), // Tu pantalla de la cámara
        '/reports': (context) => const ReportsScreen(), // Tu pantalla de reportes
      },
    );
  }
}

// HomeScreen (la pantalla de inicio con los botones)
class HomeScreen extends StatelessWidget {
  const HomeScreen({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Detector de Filas de Vehículos'),
        centerTitle: true,
      ),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: <Widget>[
            const Text(
              'Detector de Filas de Vehículos',
              style: TextStyle(
                fontSize: 28,
                fontWeight: FontWeight.bold,
                color: Colors.blueAccent,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 50),
            ElevatedButton.icon(
              onPressed: () {
                // Navega a la pantalla de la cámara
                Navigator.pushNamed(context, '/camera');
              },
              icon: const Icon(Icons.videocam, size: 28),
              label: const Text(
                'Iniciar Detección',
                style: TextStyle(fontSize: 20),
              ),
              style: ElevatedButton.styleFrom(
                padding: const EdgeInsets.symmetric(horizontal: 40, vertical: 15),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(30),
                ),
                elevation: 5,
              ),
            ),
            const SizedBox(height: 20),
            ElevatedButton.icon(
              onPressed: () {
                // Navega a la pantalla de reportes
                Navigator.pushNamed(context, '/reports');
              },
              icon: const Icon(Icons.list_alt, size: 28),
              label: const Text(
                'Ver Reportes',
                style: TextStyle(fontSize: 20),
              ),
              style: ElevatedButton.styleFrom(
                padding: const EdgeInsets.symmetric(horizontal: 40, vertical: 15),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(30),
                ),
                elevation: 5,
              ),
            ),
          ],
        ),
      ),
    );
  }
}