import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'screens/chat/chat_screen.dart';
import 'screens/dashboard/dashboard_screen.dart';
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
            child: ChatScreen(),
          ),
        ),
        GoRoute(
          path: '/dashboard',
          pageBuilder: (context, state) => const NoTransitionPage(
            child: DashboardScreen(),
          ),
        ),
        GoRoute(
          path: '/devices',
          pageBuilder: (context, state) => const NoTransitionPage(
            child: HomeScreen(),
          ),
        ),
        GoRoute(
          path: '/tools',
          pageBuilder: (context, state) => const NoTransitionPage(
            child: _ToolsTab(),
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
    // Standalone routes (full screen, no bottom nav)
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

/// Tools tab — provides quick access to file transfer and other tools.
class _ToolsTab extends StatelessWidget {
  const _ToolsTab();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('工具')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          _ToolCard(
            icon: Icons.swap_horiz,
            title: '文件快传',
            subtitle: '发送和接收文件',
            onTap: () => context.go('/devices'),
          ),
          const SizedBox(height: 12),
          _ToolCard(
            icon: Icons.qr_code_scanner,
            title: '扫码配对',
            subtitle: '扫描二维码配对设备',
            onTap: () => context.push('/qr-scan'),
          ),
          const SizedBox(height: 12),
          _ToolCard(
            icon: Icons.history,
            title: '传输历史',
            subtitle: '查看过去的文件传输记录',
            onTap: () => context.push('/history'),
          ),
          const SizedBox(height: 12),
          _ToolCard(
            icon: Icons.auto_awesome,
            title: 'AI 能力进化',
            subtitle: '查看 AI 学习的工具和能力',
            onTap: () {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('进化日志将在 Phase 1 上线')),
              );
            },
          ),
        ],
      ),
    );
  }
}

class _ToolCard extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback onTap;

  const _ToolCard({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      child: ListTile(
        leading: CircleAvatar(
          backgroundColor: Theme.of(context).colorScheme.primaryContainer,
          child: Icon(icon, color: Theme.of(context).colorScheme.onPrimaryContainer),
        ),
        title: Text(title),
        subtitle: Text(subtitle),
        trailing: const Icon(Icons.chevron_right),
        onTap: onTap,
      ),
    );
  }
}

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
            icon: Icon(Icons.chat_outlined),
            selectedIcon: Icon(Icons.chat),
            label: 'AI 助手',
          ),
          NavigationDestination(
            icon: Icon(Icons.dashboard_outlined),
            selectedIcon: Icon(Icons.dashboard),
            label: '仪表盘',
          ),
          NavigationDestination(
            icon: Icon(Icons.apps_outlined),
            selectedIcon: Icon(Icons.apps),
            label: '工具',
          ),
          NavigationDestination(
            icon: Icon(Icons.settings_outlined),
            selectedIcon: Icon(Icons.settings),
            label: '设置',
          ),
        ],
      ),
    );
  }

  int _calculateSelectedIndex(BuildContext context) {
    final location = GoRouterState.of(context).uri.toString();
    if (location.startsWith('/dashboard')) return 1;
    if (location.startsWith('/tools') || location.startsWith('/devices')) return 2;
    if (location.startsWith('/settings')) return 3;
    return 0;
  }

  void _onItemTapped(int index, BuildContext context) {
    switch (index) {
      case 0: context.go('/');
      case 1: context.go('/dashboard');
      case 2: context.go('/tools');
      case 3: context.go('/settings');
    }
  }
}
