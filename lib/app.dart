import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'core/constants/app_theme.dart';
import 'core/logger/app_logger.dart';
import 'ui/app_router.dart';

class FileShareApp extends ConsumerStatefulWidget {
  const FileShareApp({super.key});

  @override
  ConsumerState<FileShareApp> createState() => _FileShareAppState();
}

class _FileShareAppState extends ConsumerState<FileShareApp> {
  @override
  void initState() {
    super.initState();
    AppLogger().info('FileShare app started');
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp.router(
      debugShowCheckedModeBanner: false,
      title: '文件快传',
      theme: AppTheme.light,
      darkTheme: AppTheme.dark,
      themeMode: ThemeMode.system,
      routerConfig: appRouter,
    );
  }
}
