// Pega aquí el código completo de la clase `SideBarWidget` que te di antes.
import 'package:flutter/material.dart';

class SideBarWidget extends StatefulWidget {
  const SideBarWidget({Key? key}) : super(key: key);

  // Usamos un GlobalKey para acceder a los métodos del estado desde fuera
  static final GlobalKey<_SideBarWidgetState> sideBarKey = GlobalKey<_SideBarWidgetState>();

  @override
  _SideBarWidgetState createState() => _SideBarWidgetState();
}

class _SideBarWidgetState extends State<SideBarWidget> {
  int carCount = 0;
  int truckCount = 0;
  int busCount = 0;
  int motorcycleCount = 0;
  String estimatedTime = "min: 0.00";

  // Métodos para ser llamados desde CameraScreen
  void resetCounters() {
    setState(() {
      carCount = 0;
      truckCount = 0;
      busCount = 0;
      motorcycleCount = 0;
      updateTextViews(); // Llama a la actualización después de reiniciar
      updateEstimatedTime(); // Llama a la actualización después de reiniciar
    });
  }

  void updateTextViews() {
    // En un StatefulWidget, setState ya reconstruirá el widget
    // No necesitas lógica extra aquí aparte de llamar a setState si los valores
    // cambian directamente en el estado.
    // Aquí no hace nada porque los cambios ya se hacen en los incrementos.
  }

  void incrementCarCount() {
    setState(() {
      carCount++;
    });
  }

  void incrementTruckCount() {
    setState(() {
      truckCount++;
    });
  }

  void incrementBusCount() {
    setState(() {
      busCount++;
    });
  }

  void incrementMotorcycleCount() {
    setState(() {
      motorcycleCount++;
    });
  }

  void updateEstimatedTime() {
    double carTime = 200.0;
    double motorcycleTime = 120.0;
    double busTime = 470.0;
    double truckTime = 570.0;

    double totalSeconds =
        (carCount * carTime) +
        (motorcycleCount * motorcycleTime) +
        (busCount * busTime) +
        (truckCount * truckTime);

    double totalMinutes = totalSeconds / 60.0;
    setState(() {
      estimatedTime = "min: ${totalMinutes.toStringAsFixed(2)}";
    });
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 150,
      color: Colors.black.withOpacity(0.5),
      padding: const EdgeInsets.all(8.0),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          _buildVehicleCounter("assets/images/car.png", "Coche", carCount),
          _buildVehicleCounter("assets/images/motorcycle.png", "Moto", motorcycleCount),
          _buildVehicleCounter("assets/images/bus.png", "Bus", busCount),
          _buildVehicleCounter("assets/images/truck.png", "Camión", truckCount),
          const SizedBox(height: 20),
          Text(
            estimatedTime,
            style: const TextStyle(fontSize: 16, color: Colors.white),
          ),
        ],
      ),
    );
  }

  Widget _buildVehicleCounter(String imagePath, String label, int count) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8.0),
      child: Column(
        children: [
          Image.asset(imagePath, width: 40, height: 40),
          Text(
            label,
            style: const TextStyle(color: Colors.white),
          ),
          Text(
            count.toString(),
            style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Colors.white),
          ),
        ],
      ),
    );
  }
}