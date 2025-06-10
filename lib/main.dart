import 'package:flutter/material.dart';
// import 'package:flutter/services.dart'; // No es estrictamente necesario aquí
import 'camera_screen.dart';
import 'reports_screen.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart'; // Asegúrate de tener Riverpod instalado

void main() {
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return ProviderScope( // Riverpod provider scope para la gestión de estado
      child: MaterialApp(
        title: 'Detector de Filas de Gasolina',
        theme: ThemeData(
          primarySwatch: Colors.teal, // Color primario de la aplicación
          visualDensity: VisualDensity.adaptivePlatformDensity,
          appBarTheme: const AppBarTheme(
            backgroundColor: Colors.teal, // Color de la AppBar
            foregroundColor: Colors.white, // Color del texto en la AppBar
            centerTitle: true, // Centra el título de la AppBar
          ),
          colorScheme: ColorScheme.fromSwatch(primarySwatch: Colors.teal).copyWith(secondary: Colors.orange),
        ),
        home: const HomeScreen(), // La pantalla de inicio de la aplicación
        routes: {
          '/camera': (context) => const CameraScreen(), // Ruta para la pantalla de la cámara
          '/reports': (context) => const ReportsScreen(), // Ruta para la pantalla de reportes
        },
      ),
    );
  }
}

class HomeScreen extends StatelessWidget {
  const HomeScreen({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'Sistema de Detección de Filas',
          style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
        ),
        backgroundColor: Colors.teal,
        centerTitle: true,
      ),
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient( // Gradiente de fondo para una interfaz atractiva
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [Colors.teal, Colors.blueAccent], // Colores del gradiente
          ),
        ),
        child: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: <Widget>[
              // Título principal de la pantalla de inicio
              Text(
                'Bienvenido al sistema de Detección de Filas',
                style: TextStyle(
                  fontSize: 28,
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                  shadows: [ // Sombra para el texto para mejor visibilidad
                    Shadow(offset: Offset(2, 2), blurRadius: 5, color: Colors.black)
                  ],
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 40),
              // Botón para iniciar la detección
              _buildMainMenuButton(
                context,
                'Iniciar Detección',
                Icons.videocam,
                '/camera',
                Colors.green,
              ),
              const SizedBox(height: 25),
              // Botón para ver los reportes
              _buildMainMenuButton(
                context,
                'Ver Reportes',
                Icons.list_alt,
                '/reports',
                Colors.orange,
              ),
            ],
          ),
        ),
      ),
    );
  }

  // Widget helper para construir los botones del menú principal
  Widget _buildMainMenuButton(
      BuildContext context, String text, IconData icon, String route, Color color) {
    return SizedBox(
      width: 250, // Ancho fijo del botón
      height: 60, // Alto fijo del botón
      child: ElevatedButton.icon(
        onPressed: () {
          Navigator.pushNamed(context, route); // Navega a la ruta especificada
        },
        icon: Icon(icon, size: 30), // Icono del botón
        label: Text(
          text,
          style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
        ),
        style: ElevatedButton.styleFrom(
          backgroundColor: color, // Color de fondo del botón
          foregroundColor: Colors.white, // Color del texto y icono
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(30), // Bordes redondeados
          ),
          elevation: 10, // Elevación del botón
          shadowColor: color.withOpacity(0.5), // Color de la sombra
          animationDuration: Duration(milliseconds: 300), // Duración de la animación
        ),
      ),
    );
  }
}
