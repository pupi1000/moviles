// lib/report_manager.dart
import 'package:flutter/foundation.dart'; // Para @required, aunque ahora es más común usar null safety

class Report {
  final int carCount;
  final int motorcycleCount;
  final int busCount;
  final int truckCount;
  final String estimatedTime;
  final DateTime timestamp;

  Report({
    required this.carCount,
    required this.motorcycleCount,
    required this.busCount,
    required this.truckCount,
    required this.estimatedTime,
    required this.timestamp,
  });
}

class ReportManager { // No necesita extender ChangeNotifier si no hay listeners directos
  static final List<Report> _reports = []; // Lista para almacenar los reportes

  static List<Report> get reports => _reports;

  static void addReport({
    required int carCount,
    required int motorcycleCount,
    required int busCount,
    required int truckCount,
    required String estimatedTime,
    required DateTime timestamp,
  }) {
    _reports.add(
      Report(
        carCount: carCount,
        motorcycleCount: motorcycleCount,
        busCount: busCount,
        truckCount: truckCount,
        estimatedTime: estimatedTime,
        timestamp: timestamp,
      ),
    );
    // En una aplicación real, aquí notificarías a los listeners si no fuera un static manager
    // o guardarías en persistencia.
  }
}