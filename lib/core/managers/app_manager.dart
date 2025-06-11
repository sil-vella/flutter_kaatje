import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:go_router/go_router.dart';
import '../../tools/logging/logger.dart';
import 'hooks_manager.dart';
import 'module_manager.dart';
import '../00_base/module_base.dart';

class AppManager extends ChangeNotifier {
  static final Logger _log = Logger();
  static final AppManager _instance = AppManager._internal();
  static late BuildContext globalContext;

  bool _isInitialized = false;
  bool get isInitialized => _isInitialized;

  factory AppManager() => _instance;
  AppManager._internal();

  final HooksManager _hooksManager = HooksManager(); // ✅ Ensure Singleton HooksManager

  Future<void> _initializeModules(BuildContext context) async {
    _log.info('Initializing modules...');

    final moduleManager = Provider.of<ModuleManager>(context, listen: false);
    
    // Initialize all registered modules
    for (var moduleGroup in moduleManager.modules.values) {
      for (var module in moduleGroup.values) {
        _log.info('Initializing module: ${module.moduleKey}');
        module.initialize(context);
      }
    }

    _isInitialized = true;
    notifyListeners();
    _log.info('All modules initialized successfully.');
  }

  Future<void> initializeApp(BuildContext context) async {
    if (!_isInitialized) {
      Future.delayed(Duration.zero, () {
        // ✅ Use GoRouter instead of NavigationContainer
        if (Navigator.canPop(context)) {
          context.go('/'); // ✅ Navigate to Home using GoRouter
        }
      });
      await _initializeModules(context); // Now awaited
      _isInitialized = true;
    }
  }
}
