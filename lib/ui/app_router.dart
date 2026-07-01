import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'screens/home_screen.dart';
import 'screens/file_picker_screen.dart';
import 'screens/transfer_progress_screen.dart';
import 'screens/history_screen.dart';
import 'screens/settings_screen.dart';
import 'screens/qr_display_screen.dart';
import 'screens/qr_scanner_screen.dart';
import 'screens/pairing_confirm_screen.dart';
import '../network/pairing/pairing_handler.dart';

final GlobalKey<NavigatorState> _rootNavigatorKey = GlobalKey<NavigatorState>();

final appRouter = GoRouter(
  navigatorKey: _rootNavigatorKey,
  initialLocation: '/',
  routes: [
    ShellRoute(
      builder: (context, state, child) {
        return ScaffoldWithNavBar(child: child);
      },
      routes: [
        GoRoute(
          path: '/',
          pageBuilder: (context, state) => const NoTransitionPage(
            child: HomeScreen(),
          ),
        ),
        GoRoute(
          path: '/transfers',
          pageBuilder: (context, state) => const NoTransitionPage(
            child: TransferProgressScreen(),
          ),
        ),
        GoRoute(
          path: '/history',
          pageBuilder: (context, state) => const NoTransitionPage(
            child: HistoryScreen(),
          ),
        ),
        GoRoute(
          path: '/settings',
          pageBuilder: (context, state) => const NoTransitionPage(
            child: SettingsScreen(),
          ),
        ),
      ],
    ),
    GoRoute(
      path: '/send',
      builder: (context, state) {
        final deviceJson = state.extra as Map<String, dynamic>?;
        return FilePickerScreen(
          peerName: deviceJson?['name'] as String? ?? 'Unknown',
          peerAddress: deviceJson?['ip'] as String? ?? '',
          peerPort: deviceJson?['port'] as int? ?? 9876,
          peerId: deviceJson?['id'] as String?,
        );
      },
    ),
    GoRoute(
      path: '/qr-display',
      builder: (context, state) => const QrDisplayScreen(),
    ),
    GoRoute(
      path: '/qr-scan',
      builder: (context, state) => const QrScannerScreen(),
    ),
    GoRoute(
      path: '/pairing-confirm',
      builder: (context, state) {
        final payload = (state.extra as Map<String, dynamic>?)?['payload'] as QrPairingPayload?;
        if (payload == null) {
          return const HomeScreen();
        }
        return PairingConfirmScreen(payload: payload);
      },
    ),
  ],
);

/// Bottom navigation bar wrapper.
class ScaffoldWithNavBar extends StatelessWidget {
  final Widget child;

  const ScaffoldWithNavBar({super.key, required this.child});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: child,
      bottomNavigationBar: NavigationBar(
        selectedIndex: _calculateSelectedIndex(context),
        onDestinationSelected: (index) => _onItemTapped(index, context),
        destinations: const [
          NavigationDestination(
            icon: Icon(Icons.devices_outlined),
            selectedIcon: Icon(Icons.devices),
            label: 'Devices',
          ),
          NavigationDestination(
            icon: Icon(Icons.swap_horiz_outlined),
            selectedIcon: Icon(Icons.swap_horiz),
            label: 'Transfers',
          ),
          NavigationDestination(
            icon: Icon(Icons.history_outlined),
            selectedIcon: Icon(Icons.history),
            label: 'History',
          ),
          NavigationDestination(
            icon: Icon(Icons.settings_outlined),
            selectedIcon: Icon(Icons.settings),
            label: 'Settings',
          ),
        ],
      ),
    );
  }

  int _calculateSelectedIndex(BuildContext context) {
    final location = GoRouterState.of(context).uri.toString();
    if (location.startsWith('/transfer')) return 1;
    if (location.startsWith('/history')) return 2;
    if (location.startsWith('/settings')) return 3;
    return 0;
  }

  void _onItemTapped(int index, BuildContext context) {
    switch (index) {
      case 0:
        context.go('/');
      case 1:
        context.go('/transfers');
      case 2:
        context.go('/history');
      case 3:
        context.go('/settings');
    }
  }
}
