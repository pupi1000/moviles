import 'package:flutter_riverpod/flutter_riverpod.dart';

final vehicleCountProvider = StateNotifierProvider<VehicleCountNotifier, VehicleCount>((ref) {
  return VehicleCountNotifier();
});

class VehicleCount {
  final int carCount;
  final int motorcycleCount;
  final int busCount;
  final int truckCount;

  VehicleCount({
    required this.carCount,
    required this.motorcycleCount,
    required this.busCount,
    required this.truckCount,
  });

  VehicleCount copyWith({
    int? carCount,
    int? motorcycleCount,
    int? busCount,
    int? truckCount,
  }) {
    return VehicleCount(
      carCount: carCount ?? this.carCount,
      motorcycleCount: motorcycleCount ?? this.motorcycleCount,
      busCount: busCount ?? this.busCount,
      truckCount: truckCount ?? this.truckCount,
    );
  }
}

class VehicleCountNotifier extends StateNotifier<VehicleCount> {
  VehicleCountNotifier() : super(VehicleCount(carCount: 0, motorcycleCount: 0, busCount: 0, truckCount: 0));

  void incrementCarCount() {
    state = state.copyWith(carCount: state.carCount + 1);
  }

  void incrementMotorcycleCount() {
    state = state.copyWith(motorcycleCount: state.motorcycleCount + 1);
  }

  void incrementBusCount() {
    state = state.copyWith(busCount: state.busCount + 1);
  }

  void incrementTruckCount() {
    state = state.copyWith(truckCount: state.truckCount + 1);
  }
}
