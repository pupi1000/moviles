import 'package:flutter/material.dart'; // Solo necesario si se usa Material/Widgets
import 'package:intl/intl.dart'; // Importar para formato de fecha/hora

// Clase Report para estructurar la información de cada detección
class Report {
  final int carCount;
  final int motorcycleCount;
  final int busCount;
  final int truckCount;
  final String estimatedTime; // Tiempo estimado en formato de minutos (ej. "10 min")
  final DateTime timestamp; // Fecha y hora exacta de la detección

  Report({
    required this.carCount,
    required this.motorcycleCount,
    required this.busCount,
    required this.truckCount,
    required this.timestamp,
    required this.estimatedTime, // Se requiere que el tiempo ya venga calculado y formateado
  });
}

// Clase ReportManager para gestionar la adición y recuperación de reportes
class ReportManager {
  // Lista estática para almacenar todos los reportes. Permite acceso global.
  static final List<Report> _reports = [];

  // Getter para acceder a la lista de reportes (solo lectura)
  static List<Report> get reports => _reports;

  // Método para añadir un nuevo reporte a la lista
  static void addReport({
    required int carCount,
    required int motorcycleCount,
    required int busCount,
    required int truckCount,
    required DateTime timestamp,
  }) {
    // Calcula el tiempo estimado en minutos
    int totalVehicles = carCount + motorcycleCount + busCount + truckCount;

    // Cada vehículo suma 2 minutos al tiempo de espera estimado
    int totalMinutes = totalVehicles * 2;

    // Formatea el tiempo estimado para mostrar solo minutos
    String estimatedTime = "$totalMinutes min"; // Ejemplo: "10 min"

    // Añade el nuevo reporte a la lista, con el tiempo estimado calculado
    _reports.add(
      Report(
        carCount: carCount,
        motorcycleCount: motorcycleCount,
        busCount: busCount,
        truckCount: truckCount,
        estimatedTime: estimatedTime, // Pasa el tiempo ya formateado
        timestamp: timestamp,
      ),
    );
  }
}
