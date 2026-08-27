import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../features/auth/application/auth_controller.dart';
import '../features/auth/presentation/otp_verify_screen.dart';
import '../features/auth/presentation/phone_entry_screen.dart';
import '../features/admin/presentation/admin_shell.dart';
import '../features/admin/presentation/admin_dashboard_screen.dart';
import '../features/admin/presentation/admin_users_screen.dart';
import '../features/admin/presentation/admin_drivers_screen.dart';
import '../features/admin/presentation/admin_vendors_screen.dart';
import '../features/admin/presentation/admin_live_rides_screen.dart';
import '../features/admin/presentation/live_ops_screen.dart';
import '../features/admin/presentation/kyc_approval_screen.dart';
import '../features/admin/presentation/admin_sos_screen.dart';
import '../features/admin/presentation/admin_tickets_screen.dart';
import '../features/admin/presentation/admin_logs_screen.dart';
import '../features/admin/presentation/admin_finance_screen.dart';
import '../features/admin/presentation/admin_withdrawals_screen.dart';
import '../features/admin/presentation/admin_finance_management_screen.dart';
import '../features/admin/presentation/admin_risk_screen.dart';
import '../features/admin/data/admin_api.dart';
import '../features/support/data/support_api.dart';
import '../features/kyc/presentation/kyc_review_screen.dart';
import '../features/disputes/presentation/ticket_detail_screen.dart';

final adminRouterProvider = Provider<GoRouter>((ref) {
  return GoRouter(
    initialLocation: '/',
    refreshListenable: _AdminAuthRefreshListenable(ref),
    redirect: (context, state) {
      final session = ref.read(authControllerProvider).valueOrNull;
      final authenticated = session?.isAuthenticated ?? false;
      final isAdmin = session?.role == 'Admin';
      final path = state.matchedLocation;

      if (!authenticated && path != '/auth' && !path.startsWith('/auth')) {
        return '/auth';
      }

      // If authenticated but not an Admin, force re-login (stale token from
      // another app flavor).
      if (authenticated && !isAdmin && path != '/auth' && !path.startsWith('/auth')) {
        return '/auth';
      }

      if (authenticated && isAdmin && (path == '/auth' || path.startsWith('/auth'))) {
        return '/';
      }

      return null;
    },
    routes: [
      GoRoute(
        path: '/auth',
        builder: (_, _) => const PhoneEntryScreen(),
        routes: [
          GoRoute(
            path: 'otp',
            builder: (_, _) => const OtpVerifyScreen(),
          ),
        ],
      ),
      // ShellRoute wraps all admin sections with the navigation rail.
      ShellRoute(
        builder: (context, state, child) => AdminShell(child: child),
        routes: [
          GoRoute(
            path: '/',
            builder: (_, _) => const AdminDashboardScreen(),
          ),
          GoRoute(
            path: '/live-map',
            builder: (_, _) => const LiveOpsScreen(),
          ),
          GoRoute(
            path: '/kyc',
            builder: (_, _) => const KycApprovalScreen(),
          ),
          GoRoute(
            path: '/kyc/:id',
            builder: (_, state) => KycReviewScreen(
              driver: state.extra as AdminDriver,
            ),
          ),
          GoRoute(
            path: '/disputes',
            builder: (_, _) => const AdminTicketsScreen(),
          ),
          GoRoute(
            path: '/disputes/:id',
            builder: (_, state) => TicketDetailScreen(
              ticket: state.extra as DisputeTicketDetail,
            ),
          ),
          GoRoute(
            path: '/users',
            builder: (_, _) => const AdminUsersScreen(),
          ),
          GoRoute(
            path: '/drivers',
            builder: (_, _) => const AdminDriversScreen(),
          ),
          GoRoute(
            path: '/vendors',
            builder: (_, _) => const AdminVendorsScreen(),
          ),
          GoRoute(
            path: '/rides',
            builder: (_, _) => const AdminLiveRidesScreen(),
          ),
          GoRoute(
            path: '/sos',
            builder: (_, _) => const AdminSosScreen(),
          ),
          GoRoute(
            path: '/tickets',
            builder: (_, _) => const AdminTicketsScreen(),
          ),
          GoRoute(
            path: '/logs',
            builder: (_, _) => const AdminLogsScreen(),
          ),
          GoRoute(
            path: '/finance',
            builder: (_, _) => const AdminFinanceScreen(),
          ),
          GoRoute(
            path: '/withdrawals',
            builder: (_, _) => const AdminWithdrawalsScreen(),
          ),
          GoRoute(
            path: '/finance-management',
            builder: (_, _) => const AdminFinanceManagementScreen(),
          ),
          GoRoute(
            path: '/risk',
            builder: (_, _) => const AdminRiskScreen(),
          ),
        ],
      ),
    ],
  );
});

class _AdminAuthRefreshListenable extends ChangeNotifier {
  _AdminAuthRefreshListenable(Ref ref) {
    ref.listen(authControllerProvider, (_, _) => notifyListeners());
  }
}
