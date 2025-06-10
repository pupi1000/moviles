class Report {
  final int carCount;
  final int motorcycleCount;
  final int busCount;
  final int truckCount;
  final String estimatedTime; // Tiempo estimado en minutos
  final DateTime timestamp;

  Report({
    required this.carCount,
    required this.motorcycleCount,
    required this.busCount,
    required this.truckCount,
    required this.timestamp,
    required this.estimatedTime, // Tiempo calculado
  });
}

class ReportManager {
  static final List<Report> _reports = [];

  static List<Report> get reports => _reports;

  static void addReport({
    required int carCount,
    required int motorcycleCount,
    required int busCount,
    required int truckCount,
    required DateTime timestamp,
  }) {
    // Calculamos el tiempo estimado en minutos, sumando 2 minutos por vehículo
    int totalVehicles = carCount + motorcycleCount + busCount + truckCount;

    // Cada vehículo suma 2 minutos
    int totalMinutes = totalVehicles * 2;

    // Solo mostramos el tiempo en minutos
    String estimatedTime = "$totalMinutes min";  // Mostrar solo minutos, sin segundos

    // Añadimos el reporte calculando el tiempo estimado
    _reports.add(
      Report(
        carCount: carCount,
        motorcycleCount: motorcycleCount,
        busCount: busCount,
        truckCount: truckCount,
        estimatedTime: estimatedTime, // Pasamos solo los minutos
        timestamp: timestamp,
      ),
    );
  }
}

