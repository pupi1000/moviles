import 'package:flutter/material.dart';
import 'package:intl/intl.dart'; // Necesario para formatear fechas
import 'report_manager.dart'; // Importa la clase que gestiona los reportes

class ReportsScreen extends StatefulWidget {
  const ReportsScreen({Key? key}) : super(key: key);

  @override
  _ReportsScreenState createState() => _ReportsScreenState();
}

class _ReportsScreenState extends State<ReportsScreen> {
  @override
  Widget build(BuildContext context) {
    // Obtiene una copia de la lista de reportes para evitar modificaciones concurrentes
    final List<Report> reports = List.from(ReportManager.reports);

    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'Reportes de Detección',
          style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
        ),
        backgroundColor: Colors.teal, // Color de la barra de la aplicación
        foregroundColor: Colors.white, // Color del texto de la barra de la aplicación
        centerTitle: true, // Centra el título
      ),
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient( // Fondo con gradiente para un aspecto profesional
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [Color.fromARGB(255, 0, 126, 255), Color.fromARGB(255, 255, 118, 87)], // Colores del gradiente
          ),
        ),
        // Muestra un mensaje si no hay reportes, de lo contrario, muestra la lista
        child: reports.isEmpty
            ? const Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.info_outline, size: 80, color: Colors.white), // Icono informativo
                    SizedBox(height: 20),
                    Text(
                      'Aún no hay reportes guardados.',
                      style: TextStyle(fontSize: 22, color: Colors.white, fontWeight: FontWeight.w500),
                      textAlign: TextAlign.center,
                    ),
                    SizedBox(height: 10),
                    Text(
                      'Realiza una detección para empezar a verlos aquí.',
                      style: TextStyle(fontSize: 16, color: Colors.white70),
                      textAlign: TextAlign.center,
                    ),
                  ],
                ),
              )
            : ListView.builder(
                padding: const EdgeInsets.all(16.0), // Espaciado alrededor de la lista
                itemCount: reports.length, // Número de reportes a mostrar
                itemBuilder: (context, index) {
                  final report = reports[index]; // Obtiene el reporte actual
                  return Card(
                    margin: const EdgeInsets.only(bottom: 16.0), // Margen inferior entre tarjetas
                    elevation: 8, // Sombra de la tarjeta
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(15), // Bordes redondeados
                    ),
                    color: Colors.white.withOpacity(0.95), // Fondo ligeramente transparente para que se vea el gradiente
                    child: Padding(
                      padding: const EdgeInsets.all(20.0), // Relleno dentro de la tarjeta
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start, // Alinea el contenido a la izquierda
                        children: [
                          Text(
                            'Reporte #${index + 1}', // Título del reporte (ej. Reporte #1)
                            style: TextStyle(
                              fontSize: 22,
                              fontWeight: FontWeight.bold,
                              color: Colors.blueGrey[800],
                            ),
                          ),
                          const Divider(height: 20, thickness: 1.5, color: Colors.black12), // Separador
                          // Fila para mostrar la fecha y hora de la detección
                          _buildReportDetailRow(
                            Icons.access_time,
                            'Fecha y Hora:',
                            DateFormat('dd/MM/yyyy HH:mm:ss').format(report.timestamp),
                            Colors.deepPurple,
                          ),
                          // Fila para mostrar el tiempo estimado de espera
                          _buildReportDetailRow(
                            Icons.timer_outlined,
                            'Tiempo Estimado:',
                            report.estimatedTime, // Ya está en formato "X min"
                            Colors.orange,
                          ),
                          const SizedBox(height: 10),
                          // Utiliza Wrap para los chips de vehículos, permitiendo que se ajusten a la pantalla
                          Wrap(
                            spacing: 8.0, // Espacio horizontal entre chips
                            runSpacing: 8.0, // Espacio vertical entre líneas de chips
                            children: [
                              _buildVehicleChip('Autos', report.carCount, Colors.blue),
                              _buildVehicleChip('Motos', report.motorcycleCount, Colors.green),
                              _buildVehicleChip('Buses', report.busCount, Colors.red),
                              _buildVehicleChip('Camiones', report.truckCount, Colors.purple),
                            ],
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

  // Helper para construir una fila de detalle de reporte (icono, etiqueta, valor)
  Widget _buildReportDetailRow(IconData icon, String label, String value, Color color) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4.0),
      child: Row(
        children: [
          Icon(icon, color: color, size: 24), // Icono del detalle
          const SizedBox(width: 10),
          Text(
            label,
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.grey[700]),
          ),
          const SizedBox(width: 5),
          Expanded( // Permite que el valor ocupe el espacio restante
            child: Text(
              value,
              style: TextStyle(fontSize: 18, color: Colors.grey[800]),
              textAlign: TextAlign.end, // Alinea el valor a la derecha
            ),
          ),
        ],
      ),
    );
  }

  // Helper para construir un "chip" para cada tipo de vehículo
  Widget _buildVehicleChip(String label, int count, Color color) {
    return Chip(
      avatar: CircleAvatar(
        backgroundColor: Colors.white,
        child: Text('$count', style: TextStyle(color: color, fontWeight: FontWeight.bold)),
      ),
      label: Text(
        label,
        style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w600),
      ),
      backgroundColor: color,
      elevation: 4, // Sombra del chip
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(20), // Bordes redondeados del chip
      ),
    );
  }
}
