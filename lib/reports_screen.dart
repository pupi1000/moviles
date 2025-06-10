import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'report_manager.dart';

class ReportsScreen extends StatefulWidget {
  const ReportsScreen({Key? key}) : super(key: key);

  @override
  _ReportsScreenState createState() => _ReportsScreenState();
}

class _ReportsScreenState extends State<ReportsScreen> {
  @override
  Widget build(BuildContext context) {
    final List<Report> reports = List.from(ReportManager.reports);

    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'Reportes de Detección',
          style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
        ),
        backgroundColor: Colors.teal,
        foregroundColor: Colors.white,
        centerTitle: true,
      ),
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [Color.fromARGB(255, 0, 126, 255), Color.fromARGB(255, 255, 118, 87)],
          ),
        ),
        child: reports.isEmpty
            ? const Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.info_outline, size: 80, color: Colors.white),
                    SizedBox(height: 20),
                    Text(
                      'Aún no hay reportes guardados.',
                      style: TextStyle(fontSize: 22, color: Colors.white),
                    ),
                    SizedBox(height: 10),
                    Text(
                      'Inicia la detección desde la pantalla principal y guarda un reporte.',
                      style: TextStyle(fontSize: 18, color: Colors.white70),
                    ),
                  ],
                ),
              )
            : SingleChildScrollView(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  children: [
                    for (var report in reports)
                      Card(
                        margin: const EdgeInsets.only(bottom: 15.0),
                        elevation: 6,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: Padding(
                          padding: const EdgeInsets.all(20.0),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              // Fecha del reporte
                              Text(
                                'Reporte del ${DateFormat('dd/MM/yyyy HH:mm').format(report.timestamp)}',
                                style: const TextStyle(
                                  fontWeight: FontWeight.bold,
                                  fontSize: 19,
                                  color: Colors.deepPurple,
                                ),
                              ),
                              const Divider(height: 20, thickness: 1.5, color: Colors.blueGrey),
                              
                              // Detalles de los vehículos
                              _buildReportDetailRow('Carros:', report.carCount, Icons.car_rental),
                              _buildReportDetailRow('Motos:', report.motorcycleCount, Icons.two_wheeler),
                              _buildReportDetailRow('Buses:', report.busCount, Icons.directions_bus),
                              _buildReportDetailRow('Camiones:', report.truckCount, Icons.local_shipping),
                              
                              const SizedBox(height: 20),
                              
                              // Tiempo estimado
                              Align(
                                alignment: Alignment.centerRight,
                                child: Chip(
                                  label: Text(
                                    'Tiempo estimado de espera: ${report.estimatedTime}',
                                    style: const TextStyle(fontSize: 17, fontWeight: FontWeight.bold, color: Colors.white),
                                  ),
                                  backgroundColor: Colors.green.shade600,
                                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                                  elevation: 3,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                  ],
                ),
              ),
      ),
    );
  }

  // Función auxiliar para construir las filas de detalle del reporte.
  Widget _buildReportDetailRow(String label, int count, IconData icon) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4.0),
      child: Row(
        children: [
          Icon(icon, color: Colors.blueGrey, size: 22),
          const SizedBox(width: 10),
          Text(
            '$label $count',
            style: const TextStyle(fontSize: 17, color: Colors.black87),
          ),
        ],
      ),
    );
  }
}
