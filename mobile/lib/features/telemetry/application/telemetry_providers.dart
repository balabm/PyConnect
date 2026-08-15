import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/providers.dart';
import '../data/telemetry_api.dart';

final telemetryApiProvider = Provider<TelemetryApi>((ref) {
  return TelemetryApi(ref.watch(apiClientProvider));
});
