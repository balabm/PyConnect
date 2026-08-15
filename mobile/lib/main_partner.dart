import 'package:flutter/material.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'app.dart';
import 'core/config/app_flavor.dart';
import 'core/widgets/error_boundary.dart';

/// Entry point for the PondyConnect Partner (Service Owner POS) app.
/// Covers all vendor categories: Restaurant, Cafe, Pizzeria, PubClub,
/// ScooterRental, TaxiOperator, LuggageCloak.
///
/// Build with:
///   flutter build apk --flavor partner --target lib/main_partner.dart \
///     --dart-define=APP_FLAVOR=partner
void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await dotenv.load(fileName: '.env');
  setupAppErrorWidget();
  runApp(const ProviderScope(
    child: PondyConnectApp(flavor: AppFlavor.partner),
  ));
}
