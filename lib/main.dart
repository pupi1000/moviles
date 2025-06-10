import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
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
    return ProviderScope( // Riverpod provider scope
      child: MaterialApp(
        title: 'Detector de Filas de Gasolina',
        theme: ThemeData(
          primarySwatch: Colors.teal,
          visualDensity: VisualDensity.adaptivePlatformDensity,
          appBarTheme: const AppBarTheme(
            backgroundColor: Colors.teal, // Color de la AppBar
            foregroundColor: Colors.white, // Color del texto en la AppBar
            centerTitle: true,
          ),
          colorScheme: ColorScheme.fromSwatch(primarySwatch: Colors.teal).copyWith(secondary: Colors.orange),
        ),
        home: const HomeScreen(),
        routes: {
          '/camera': (context) => const CameraScreen(),
          '/reports': (context) => const ReportsScreen(),
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
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [Colors.teal, Colors.blueAccent],
          ),
        ),
        child: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: <Widget>[
              Text(
                'Bienvenido al sistema de Detección de Filas',
                style: TextStyle(
                  fontSize: 28,
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                  shadows: [
                    Shadow(offset: Offset(2, 2), blurRadius: 5, color: Colors.black)
                  ],
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 40),
              _buildMainMenuButton(
                context,
                'Iniciar Detección',
                Icons.videocam,
                '/camera',
                Colors.green,
              ),
              const SizedBox(height: 25),
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

  Widget _buildMainMenuButton(
      BuildContext context, String text, IconData icon, String route, Color color) {
    return SizedBox(
      width: 250,
      height: 60,
      child: ElevatedButton.icon(
        onPressed: () {
          Navigator.pushNamed(context, route);
        },
        icon: Icon(icon, size: 30),
        label: Text(
          text,
          style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
        ),
        style: ElevatedButton.styleFrom(
          backgroundColor: color,
          foregroundColor: Colors.white,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(30),
          ),
          elevation: 10,
          shadowColor: color.withOpacity(0.5),
          animationDuration: Duration(milliseconds: 300),
        ),
      ),
    );
  }
}
