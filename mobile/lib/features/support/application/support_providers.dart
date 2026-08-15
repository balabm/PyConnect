import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/providers.dart';
import '../data/support_api.dart';

final supportTicketsProvider =
    FutureProvider<List<SupportTicketModel>>((ref) async {
  final api = ref.watch(supportApiProvider);
  return api.getTickets();
});

final sosCreationProvider =
    FutureProvider.family<CriticalTicketModel, SosRequest>((ref, request) async {
  final api = ref.watch(supportApiProvider);
  return api.createSos(request);
});
