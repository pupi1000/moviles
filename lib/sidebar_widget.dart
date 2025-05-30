// lib/sidebar_widget.dart
import 'package:flutter/material.dart';

class SideBarWidget extends StatefulWidget {
  static GlobalKey<_SideBarWidgetState> sideBarKey =
      GlobalKey<_SideBarWidgetState>();

  SideBarWidget({Key? key}) : super(key: sideBarKey);

  @override
  _SideBarWidgetState createState() => _SideBarWidgetState();
}

class _SideBarWidgetState extends State<SideBarWidget> {
  int _carCount = 0;
  int _motorcycleCount = 0;
  int _busCount = 0;
  int _truckCount = 0;
  String _estimatedTime = "00:00";

  void incrementCarCount() {
    setState(() {
      _carCount++;
    });
  }

  void incrementMotorcycleCount() {
    setState(() {
      _motorcycleCount++;
    });
  }

  void incrementBusCount() {
    setState(() {
      _busCount++;
    });
  }

  void incrementTruckCount() {
    setState(() {
      _truckCount++;
    });
  }

  void resetCounters() {
    setState(() {
      _carCount = 0;
      _motorcycleCount = 0;
      _busCount = 0;
      _truckCount = 0;
    });
  }

  void updateEstimatedTime() {
    // *** Lógica de cálculo de tiempo modificada: 2 minutos por cada vehículo ***
    int totalVehicles = _carCount + _motorcycleCount + _busCount + _truckCount;
    int estimatedMinutes = totalVehicles * 2; // 2 minutos por cada vehículo

    int hours = estimatedMinutes ~/ 60;
    int minutes = estimatedMinutes % 60;

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
      width: 150,
      color: Colors.black54,
      padding: const EdgeInsets.all(16.0),
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
            ),
          ),
          const SizedBox(height: 10),
          Text(
            'Carros: $_carCount',
            style: const TextStyle(color: Colors.white, fontSize: 16),
          ),
          Text(
            'Motos: $_motorcycleCount',
            style: const TextStyle(color: Colors.white, fontSize: 16),
          ),
          Text(
            'Buses: $_busCount',
            style: const TextStyle(color: Colors.white, fontSize: 16),
          ),
          Text(
            'Camiones: $_truckCount',
            style: const TextStyle(color: Colors.white, fontSize: 16),
          ),
          const SizedBox(height: 20),
          const Text(
            'Tiempo estimado:',
            style: TextStyle(
              color: Colors.white,
              fontSize: 18,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 10),
          Text(
            _estimatedTime,
            style: const TextStyle(
              color: Colors.orange,
              fontSize: 24,
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ),
    );
  }
}