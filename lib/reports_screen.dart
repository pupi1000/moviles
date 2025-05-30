// lib/reports_screen.dart
import 'package:flutter/material.dart';
import 'package:intl/intl.dart'; // Necesario para formatear fechas
import 'report_manager.dart'; // Importa el manejador de reportes

class ReportsScreen extends StatefulWidget {
  const ReportsScreen({Key? key}) : super(key: key);

  @override
  State<ReportsScreen> createState() => _ReportsScreenState();
}

class _ReportsScreenState extends State<ReportsScreen> {
  @override
  Widget build(BuildContext context) {
    // Obtiene los reportes del ReportManager. Se usa List.from para crear una copia
    // y evitar problemas si la lista original es modificada en otro lugar.
    final List<Report> reports = List.from(ReportManager.reports);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Reportes de Detección'),
        backgroundColor: Colors.deepPurple, // Usar el mismo color de AppBar que en main.dart
        foregroundColor: Colors.white, // Color del texto e iconos en la AppBar
      ),
      body: Container(
        // Fondo con un gradiente suave para un diseño más agradable.
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [Color.fromARGB(255, 143, 182, 211), Color.fromARGB(255, 125, 185, 213)],
          ),
        ),
        child: reports.isEmpty
            ? const Center(
                // Mensaje cuando no hay reportes guardados.
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.info_outline, size: 80, color: Colors.grey), // Icono más grande
                    SizedBox(height: 20),
                    Text(
                      'Aún no hay reportes guardados.',
                      style: TextStyle(fontSize: 22, color: Colors.blueGrey, fontWeight: FontWeight.w600),
                      textAlign: TextAlign.center,
                    ),
                    SizedBox(height: 10),
                    Text(
                      'Inicia la detección desde la pantalla principal y guarda un reporte.',
                      style: TextStyle(fontSize: 18, color: Colors.grey),
                      textAlign: TextAlign.center,
                    ),
                  ],
                ),
              )
            : ListView.builder(
                padding: const EdgeInsets.all(16.0),
                itemCount: reports.length,
                itemBuilder: (context, index) {
                  // Muestra los reportes más recientes primero.
                  final report = reports[reports.length - 1 - index];
                  return Card(
                    margin: const EdgeInsets.only(bottom: 15.0),
                    elevation: 6, // Mayor elevación para un efecto 3D
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(20), // Bordes más redondeados
                    ),
                    child: Padding(
                      padding: const EdgeInsets.all(20.0),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Reporte del ${DateFormat('dd/MM/yyyy HH:mm').format(report.timestamp)}',
                            style: const TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 19,
                              color: Colors.deepPurple, // Color de título del reporte
                            ),
                          ),
                          const Divider(height: 20, thickness: 1.5, color: Colors.blueGrey), // Divisor más grueso
                          // Filas de detalle del reporte con iconos y texto mejorado.
                          _buildReportDetailRow('Carros:', report.carCount, Icons.car_rental),
                          _buildReportDetailRow('Motos:', report.motorcycleCount, Icons.two_wheeler),
                          _buildReportDetailRow('Buses:', report.busCount, Icons.directions_bus),
                          _buildReportDetailRow('Camiones:', report.truckCount, Icons.local_shipping),
                          const SizedBox(height: 20),
                          Align(
                            alignment: Alignment.centerRight,
                            child: Chip( // Usa un Chip para el tiempo estimado, más estético.
                              label: Text(
                                'Tiempo estimado de espera: ${report.estimatedTime}',
                                style: const TextStyle(
                                  fontSize: 17,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.white,
                                ),
                              ),
                              backgroundColor: Colors.green.shade600, // Fondo verde para el chip
                              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                              elevation: 3,
                            ),
                          ),
                        ],
                      ),
                    ),
                  );
                },
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
          Icon(icon, color: Colors.blueGrey, size: 22), // Icono del detalle
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