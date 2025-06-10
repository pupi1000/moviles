import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'vehicle_count_provider.dart';

// Definir una clave global para poder acceder al estado de SideBarWidget
class SideBarWidget extends ConsumerStatefulWidget {
  static final GlobalKey<_SideBarWidgetState> sideBarKey = GlobalKey<_SideBarWidgetState>();

  SideBarWidget({Key? key}) : super(key: key ?? sideBarKey);

  @override
  _SideBarWidgetState createState() => _SideBarWidgetState();
}

class _SideBarWidgetState extends ConsumerState<SideBarWidget> {
  int _carCount = 0;
  int _motorcycleCount = 0;
  int _busCount = 0;
  int _truckCount = 0;
  String _estimatedTime = "0 min";

  // Métodos para actualizar los contadores
  void updateCarCount(int count) {
    setState(() {
      _carCount = count;
      _updateEstimatedTime();
    });
  }

  void updateMotorcycleCount(int count) {
    setState(() {
      _motorcycleCount = count;
      _updateEstimatedTime();
    });
  }

  void updateBusCount(int count) {
    setState(() {
      _busCount = count;
      _updateEstimatedTime();
    });
  }

  void updateTruckCount(int count) {
    setState(() {
      _truckCount = count;
      _updateEstimatedTime();
    });
  }

  void resetCounters() {
    setState(() {
      _carCount = 0;
      _motorcycleCount = 0;
      _busCount = 0;
      _truckCount = 0;
      _updateEstimatedTime();
    });
  }

  void _updateEstimatedTime() {
    int totalVehicles = _carCount + _motorcycleCount + _busCount + _truckCount;
    int totalMinutes = totalVehicles * 2; // 2 minutos por vehículo
    setState(() {
      _estimatedTime = "$totalMinutes min";
    });
  }

  String getEstimatedTime() => _estimatedTime; // Getter para el tiempo estimado

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 150, // Ancho de la barra lateral
      decoration: BoxDecoration(
        color: Colors.black.withOpacity(0.6), // Fondo semitransparente
        borderRadius: const BorderRadius.only(
          topLeft: Radius.circular(15),
          bottomLeft: Radius.circular(15),
        ),
      ),
      padding: const EdgeInsets.all(10),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          _buildCounterItem(Icons.directions_car, "Autos", _carCount, Colors.blue),
          _buildCounterItem(Icons.motorcycle, "Motos", _motorcycleCount, Colors.orange),
          _buildCounterItem(Icons.directions_bus, "Buses", _busCount, Colors.red),
          _buildCounterItem(Icons.local_shipping, "Camiones", _truckCount, Colors.purple),
          const Divider(color: Colors.white70, thickness: 1, height: 20),
          _buildTimeEstimation(),
        ],
      ),
    );
  }

  Widget _buildCounterItem(IconData icon, String label, int count, Color color) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8.0),
      child: Column(
        children: [
          Icon(icon, color: color, size: 30),
          Text(
            label,
            style: TextStyle(color: color, fontSize: 14, fontWeight: FontWeight.bold),
          ),
          Text(
            '$count',
            style: const TextStyle(color: Colors.white, fontSize: 24, fontWeight: FontWeight.bold),
          ),
        ],
      ),
    );
  }

  Widget _buildTimeEstimation() {
    return Column(
      children: [
        const Icon(Icons.timer, color: Colors.white, size: 30),
        const Text(
          "Est. Espera",
          style: TextStyle(color: Colors.white, fontSize: 14, fontWeight: FontWeight.bold),
        ),
        Text(
          _estimatedTime,
          style: const TextStyle(color: Colors.white, fontSize: 24, fontWeight: FontWeight.bold),
        ),
      ],
    );
  }



  void updateEstimatedTime() {}
}
