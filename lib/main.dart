// lib/main.dart
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:camera/camera.dart';
import 'camera_screen.dart';
import 'reports_screen.dart';

// cameras ahora es `late` y se inicializa en main()
late List<CameraDescription> cameras;

Future<void> main() async {
  // Asegúrate de que los widgets de Flutter estén inicializados.
  WidgetsFlutterBinding.ensureInitialized();

  // Configura la orientación preferida de la pantalla a vertical.
  SystemChrome.setPreferredOrientations([
    DeviceOrientation.portraitUp,
    DeviceOrientation.portraitDown,
  ]);

  // Inicializa las cámaras disponibles una vez al inicio de la aplicación.
  try {
    cameras = await availableCameras();
  } on CameraException catch (e) {
    // Manejo de errores si no se pueden obtener las cámaras.
    print('Error getting available cameras: $e');
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
        // Define un tema de colores primario.
        primarySwatch: Colors.blue,
        visualDensity: VisualDensity.adaptivePlatformDensity,
        appBarTheme: const AppBarTheme(
          backgroundColor: Colors.deepPurple, // Color de AppBar global
          foregroundColor: Colors.white, // Color del texto e iconos en la AppBar
          centerTitle: true, // Centra el título de la AppBar
        ),
        // Define un esquema de colores para Flutter 2.0+
        colorScheme: ColorScheme.fromSwatch(primarySwatch: Colors.deepPurple).copyWith(secondary: Colors.orangeAccent),
      ),
      // Define las rutas de navegación de la aplicación.
      initialRoute: '/', // Ruta inicial
      routes: {
        '/': (context) => const HomeScreen(), // Pantalla de inicio
        '/camera': (context) => const CameraScreen(), // Pantalla de la cámara
        '/reports': (context) => const ReportsScreen(), // Pantalla de reportes
      },
    );
  }
}

class HomeScreen extends StatelessWidget {
  const HomeScreen({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Detector de Filas de Vehículos'),
      ),
      body: Container(
        // Fondo con un gradiente de color para un diseño más atractivo.
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [Colors.blueAccent, Colors.purpleAccent],
          ),
        ),
        child: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: <Widget>[
              // Título principal con estilo y sombra para destacar.
              Text(
                'Sistema de Detección de Filas',
                style: TextStyle(
                  fontSize: 32,
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                  shadows: [
                    Shadow(
                      offset: Offset(2, 2),
                      blurRadius: 3.0,
                      color: Colors.black.withOpacity(0.5),
                    ),
                  ],
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 60), // Espacio vertical

              // Botón "Iniciar Detección" con estilo personalizado.
              _buildMainMenuButton(
                context,
                'Iniciar Detección',
                Icons.videocam,
                '/camera',
                Colors.green.shade600, // Color de fondo del botón
              ),
              const SizedBox(height: 25), // Espacio vertical

              // Botón "Ver Reportes" con estilo personalizado.
              _buildMainMenuButton(
                context,
                'Ver Reportes',
                Icons.list_alt,
                '/reports',
                Colors.orange.shade600, // Color de fondo del botón
              ),
            ],
          ),
        ),
      ),
    );
  }

  // Función auxiliar para construir botones de menú con estilo consistente.
  Widget _buildMainMenuButton(BuildContext context, String text, IconData icon, String route, Color color) {
    return SizedBox(
      width: 250, // Ancho fijo para los botones
      height: 60, // Altura fija para los botones
      child: ElevatedButton.icon(
        onPressed: () {
          Navigator.pushNamed(context, route); // Navega a la ruta especificada al presionar
        },
        icon: Icon(icon, size: 30), // Icono del botón más grande
        label: Text(
          text,
          style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
        ),
        style: ElevatedButton.styleFrom(
          backgroundColor: color, // Color de fondo personalizado
          foregroundColor: Colors.white, // Color del texto e icono
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(30), // Bordes más redondeados
          ),
          elevation: 8, // Mayor sombra para un efecto 3D
          animationDuration: const Duration(milliseconds: 300), // Duración de la animación al presionar
          shadowColor: color.withOpacity(0.5), // Color de la sombra basado en el color del botón
        ),
      ),
    );
  }
}