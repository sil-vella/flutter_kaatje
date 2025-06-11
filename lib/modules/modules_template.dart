import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../core/00_base/module_base.dart';
import '../../core/managers/module_manager.dart';
import '../../core/managers/services_manager.dart';
import '../../tools/logging/logger.dart';

/// Template for creating new modules
/// 
/// Usage:
/// 1. Copy this file to your new module directory
/// 2. Rename the class to your module name
/// 3. Implement required methods
/// 4. Add your module-specific functionality
class TemplateModule extends ModuleBase {
  static final Logger _log = Logger();
  late ModuleManager _moduleManager;
  late ServicesManager _servicesManager;

  /// Constructor with module key
  TemplateModule() : super("template_module") {
    _log.info('✅ TemplateModule initialized.');
  }

  /// Initialize module with context
  @override
  void initialize(BuildContext context) {
    _initDependencies(context);
    _log.info('✅ TemplateModule initialized with context.');
  }

  /// Initialize dependencies using Provider
  void _initDependencies(BuildContext context) {
    _moduleManager = Provider.of<ModuleManager>(context, listen: false);
    _servicesManager = Provider.of<ServicesManager>(context, listen: false);
  }

  /// Cleanup resources when module is disposed
  @override
  void dispose() {
    _log.info('🗑 TemplateModule disposed.');
    super.dispose();
  }

  // Add your module-specific methods below
}