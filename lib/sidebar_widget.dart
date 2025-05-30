// lib/sidebar_widget.dart
import 'package:flutter/material.dart';

class SideBarWidget extends StatefulWidget {
  // ¡IMPORTANTE! REMUEVE 'final' y 'const' de aquí si los tienes
  static GlobalKey<_SideBarWidgetState> sideBarKey =
      GlobalKey<_SideBarWidgetState>();

  // ¡IMPORTANTE! REMUEVE 'const' del constructor si lo tienes
  SideBarWidget({Key? key}) : super(key: sideBarKey);

  @override
  _SideBarWidgetState createState() => _SideBarWidgetState();
}

class _SideBarWidgetState extends State<SideBarWidget> {
  int _carCount = 0;
  int _motorcycleCount = 0;
  int _busCount = 0;
  int _truckCount = 0;
  String _estimatedTime = "00:00"; // Formato HH:MM

  void incrementCarCount() {
    setState(() {
      _carCount++;
      updateEstimatedTime(); // Llama a la actualización cada vez que un contador cambia
    });
  }

  void incrementMotorcycleCount() {
    setState(() {
      _motorcycleCount++;
      updateEstimatedTime(); // Llama a la actualización cada vez que un contador cambia
    });
  }

  void incrementBusCount() {
    setState(() {
      _busCount++;
      updateEstimatedTime(); // Llama a la actualización cada vez que un contador cambia
    });
  }

  void incrementTruckCount() {
    setState(() {
      _truckCount++;
      updateEstimatedTime(); // Llama a la actualización cada vez que un contador cambia
    });
  }

  void resetCounters() {
    setState(() {
      _carCount = 0;
      _motorcycleCount = 0;
      _busCount = 0;
      _truckCount = 0;
      updateEstimatedTime(); // Resetea el tiempo al resetear contadores
    });
  }

  void updateEstimatedTime() {
    // Lógica de cálculo de tiempo: 2 minutos por cada vehículo
    int totalVehicles = _carCount + _motorcycleCount + _busCount + _truckCount;
    int estimatedMinutes = totalVehicles * 2; // 2 minutos por cada vehículo

    int hours = estimatedMinutes ~/ 60;
    int minutes = estimatedMinutes % 60;

    // Asegurarse de que el formato sea HH:MM
    setState(() {
      _estimatedTime =
          "${hours.toString().padLeft(2, '0')}:${minutes.toString().padLeft(2, '0')}";
    });
  }

  String getEstimatedTime() {
    return _estimatedTime;
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 160, // Aumenta un poco el ancho para evitar el overflow
      decoration: BoxDecoration(
        color: Colors.black54,
        borderRadius: BorderRadius.circular(15),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.3),
            spreadRadius: 3,
            blurRadius: 7,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      padding: const EdgeInsets.all(16.0),
      margin: const EdgeInsets.all(10.0),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          const Text(
            'Conteo:',
            style: TextStyle(
              color: Colors.white,
              fontSize: 18,
              fontWeight: FontWeight.bold,
              shadows: [
                Shadow(offset: Offset(1, 1), blurRadius: 2.0, color: Colors.black),
              ],
            ),
          ),
          const SizedBox(height: 10),
          _buildCountRow('Carros:', _carCount, Icons.car_rental),
          _buildCountRow('Motos:', _motorcycleCount, Icons.two_wheeler),
          _buildCountRow('Buses:', _busCount, Icons.directions_bus),
          _buildCountRow('Camiones:', _truckCount, Icons.local_shipping), // Eliminada la alerta visual
          const SizedBox(height: 20),
          const Text(
            'Tiempo estimado:',
            style: TextStyle(
              color: Colors.white,
              fontSize: 18,
              fontWeight: FontWeight.bold,
              shadows: [
                Shadow(offset: Offset(1, 1), blurRadius: 2.0, color: Colors.black),
              ],
            ),
          ),
          const SizedBox(height: 10),
          Container(
            padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 12),
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.2),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Text(
              _estimatedTime, // Aquí se muestra la cadena HH:MM
              style: const TextStyle(
                color: Colors.orange,
                fontSize: 28,
                fontWeight: FontWeight.bold,
                shadows: [
                  Shadow(offset: Offset(1, 1), blurRadius: 2.0, color: Colors.black),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCountRow(String label, int count, IconData icon) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4.0),
      child: Row(
        children: [
          Icon(icon, color: Colors.white70, size: 20),
          const SizedBox(width: 8),
          Text(
            '$label $count',
            style: const TextStyle(color: Colors.white, fontSize: 16),
          ),
        ],
      ),
    );
  }
}