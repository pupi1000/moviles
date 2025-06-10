import 'package:flutter_riverpod/flutter_riverpod.dart';

// Define un estado para los contadores de vehículos
class VehicleCounts {
  final int cars;
  final int motorcycles;
  final int buses;
  final int trucks;
  final String estimatedTime;

  VehicleCounts({
    this.cars = 0,
    this.motorcycles = 0,
    this.buses = 0,
    this.trucks = 0,
    this.estimatedTime = "0 min",
  });

  // Método copyWith para crear una nueva instancia con valores actualizados
  VehicleCounts copyWith({
    int? cars,
    int? motorcycles,
    int? buses,
    int? trucks,
    String? estimatedTime,
  }) {
    return VehicleCounts(
      cars: cars ?? this.cars,
      motorcycles: motorcycles ?? this.motorcycles,
      buses: buses ?? this.buses,
      trucks: trucks ?? this.trucks,
      estimatedTime: estimatedTime ?? this.estimatedTime,
    );
  }
}

// Un StateNotifier para gestionar el estado de los contadores de vehículos
class VehicleCountNotifier extends StateNotifier<VehicleCounts> {
  VehicleCountNotifier() : super(VehicleCounts());

  void updateCounts({
    int? cars,
    int? motorcycles,
    int? buses,
    int? trucks,
  }) {
    final newCars = cars ?? state.cars;
    final newMotorcycles = motorcycles ?? state.motorcycles;
    final newBuses = buses ?? state.buses;
    final newTrucks = trucks ?? state.trucks;

    final totalVehicles = newCars + newMotorcycles + newBuses + newTrucks;
    final estimatedMinutes = totalVehicles * 2; // 2 minutos por vehículo

    state = state.copyWith(
      cars: newCars,
      motorcycles: newMotorcycles,
      buses: newBuses,
      trucks: newTrucks,
      estimatedTime: "$estimatedMinutes min",
    );
  }

  void resetCounts() {
    state = VehicleCounts(); // Vuelve al estado inicial
  }
}

// El provider que expone el StateNotifier
final vehicleCountProvider = StateNotifierProvider<VehicleCountNotifier, VehicleCounts>(
  (ref) => VehicleCountNotifier(),
);
