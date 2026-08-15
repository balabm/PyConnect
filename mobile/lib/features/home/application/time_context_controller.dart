import 'dart:async';
import 'package:flutter_riverpod/flutter_riverpod.dart';

enum TimeContextState {
  morningArrival,
  afternoonHeat,
  eveningNightlife,
}

class TimeContextNotifier extends StateNotifier<TimeContextState> {
  Timer? _timer;

  TimeContextNotifier() : super(_evaluate()) {
    _timer = Timer.periodic(const Duration(minutes: 1), (_) {
      state = _evaluate();
    });
  }

  static TimeContextState _evaluate() {
    final now = DateTime.now().toUtc().add(const Duration(minutes: 330));
    final hour = now.hour;

    if (hour >= 6 && hour < 12) {
      return TimeContextState.morningArrival;
    } else if (hour >= 12 && hour < 17) {
      return TimeContextState.afternoonHeat;
    } else {
      return TimeContextState.eveningNightlife;
    }
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }
}

final timeContextProvider =
    StateNotifierProvider<TimeContextNotifier, TimeContextState>(
  (ref) => TimeContextNotifier(),
);
