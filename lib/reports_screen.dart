import 'package:flutter/material.dart';
import 'package:intl/intl.dart'; // Para formatear la fecha/hora
import 'report_manager.dart';

class ReportsScreen extends StatefulWidget {
  const ReportsScreen({Key? key}) : super(key: key);

  @override
  State<ReportsScreen> createState() => _ReportsScreenState();
}

class _ReportsScreenState extends State<ReportsScreen> {
  @override
  Widget build(BuildContext context) {
    final List<Report> reports = ReportManager.reports;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Reportes de Detección'),
        backgroundColor: Colors.blueAccent,
      ),
      body: reports.isEmpty
          ? const Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.info_outline, size: 60, color: Colors.grey),
                  SizedBox(height: 10),
                  Text(
                    'No hay reportes guardados aún.',
                    style: TextStyle(fontSize: 18, color: Colors.grey),
                    textAlign: TextAlign.center,
                  ),
                  Text(
                    'Inicia la detección y guarda un reporte.',
                    style: TextStyle(fontSize: 16, color: Colors.grey),
                    textAlign: TextAlign.center,
                  ),
                ],
              ),
            )
          : ListView.builder(
              padding: const EdgeInsets.all(16.0),
              itemCount: reports.length,
              itemBuilder: (context, index) {
                final report = reports[index];
                return Card(
                  margin: const EdgeInsets.only(bottom: 12.0),
                  elevation: 4,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(15),
                  ),
                  child: Padding(
                    padding: const EdgeInsets.all(16.0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Reporte del ${DateFormat('dd/MM/yyyy HH:mm').format(report.timestamp)}',
                          style: const TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 18,
                            color: Colors.blueAccent,
                          ),
                        ),
                        const Divider(height: 15, thickness: 1),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            _buildCountText('Carros:', report.carCount),
                            _buildCountText('Motos:', report.motorcycleCount),
                          ],
                        ),
                        const SizedBox(height: 8),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            _buildCountText('Buses:', report.busCount),
                            _buildCountText('Camiones:', report.truckCount),
                          ],
                        ),
                        const SizedBox(height: 15),
                        Text(
                          'Tiempo estimado de espera: ${report.estimatedTime}',
                          style: const TextStyle(
                            fontSize: 17,
                            fontWeight: FontWeight.bold,
                            color: Colors.green,
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
    );
  }

  Widget _buildCountText(String label, int count) {
    return Expanded(
      child: Text(
        '$label $count',
        style: const TextStyle(fontSize: 16, color: Colors.black87),
      ),
    );
  }
}