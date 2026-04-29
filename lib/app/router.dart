// lib/app/router.dart
import 'package:go_router/go_router.dart';
import '../ui/screens/topology_editor_screen.dart';
import '../ui/screens/topology_list_screen.dart';
import '../ui/screens/auth_screen.dart';
import '../ui/screens/device_config_screen.dart';
import '../ui/screens/statistics_screen.dart';
import '../ui/screens/pentest_screen.dart';
import '../ui/screens/syslog_screen.dart';
import '../ui/screens/scenario_screen.dart';
import '../ui/screens/scenario_play_screen.dart';
import '../ui/screens/protocol_viz_screen.dart';

final appRouter = GoRouter(
  initialLocation: '/',
  routes: [
    GoRoute(
      path: '/',
      builder: (context, state) => const TopologyEditorScreen(),
    ),
    GoRoute(
      path: '/auth',
      builder: (context, state) => const AuthScreen(),
    ),
    GoRoute(
      path: '/config/:deviceId',
      builder: (context, state) {
        final deviceId = state.pathParameters['deviceId']!;
        return DeviceConfigScreen(deviceId: deviceId);
      },
    ),
    GoRoute(
      path: '/stats',
      builder: (context, state) => const StatisticsScreen(),
    ),
    GoRoute(
      path: '/topologies',
      builder: (context, state) => const TopologyListScreen(),
    ),
    GoRoute(
      path: '/pentest',
      builder: (context, state) => const PentestScreen(),
    ),
    GoRoute(
      path: '/syslog',
      builder: (context, state) => const SyslogScreen(),
    ),
    GoRoute(
      path: '/scenarios',
      builder: (_, __) => const ScenarioScreen(),
    ),
    GoRoute(
      path: '/scenario/:id',
      builder: (_, s) =>
          ScenarioPlayScreen(id: s.pathParameters['id']!),
    ),
    GoRoute(
      path: '/protocol-viz',
      builder: (_, __) => const ProtocolVizScreen(),
    ),
  ],
);
