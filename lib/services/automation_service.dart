import 'dart:async';
import '../core/logger/app_logger.dart';
import 'primitives/primitive_registry.dart';

/// Trigger for an automation rule.
class AutomationTrigger {
  final String type; // 'time', 'interval', 'event', 'condition'
  final Map<String, dynamic> config;
  const AutomationTrigger({required this.type, required this.config});
}

/// Action that an automation performs.
class AutomationAction {
  final String type; // 'notify', 'execute_tool', 'http_call', 'run_primitive'
  final Map<String, dynamic> config;
  const AutomationAction({required this.type, required this.config});
}

/// User-defined or AI-generated automation rule.
class AutomationRule {
  final String id;
  String name;
  String? description;
  final AutomationTrigger trigger;
  final AutomationAction action;
  bool isEnabled;
  DateTime? lastTriggeredAt;
  final DateTime createdAt;

  AutomationRule({
    required this.id, required this.name, this.description,
    required this.trigger, required this.action,
    this.isEnabled = true, this.lastTriggeredAt,
    DateTime? createdAt,
  }) : createdAt = createdAt ?? DateTime.now();

  Map<String, dynamic> toJson() => {
    'id': id, 'name': name, 'description': description,
    'trigger': {'type': trigger.type, 'config': trigger.config},
    'action': {'type': action.type, 'config': action.config},
    'is_enabled': isEnabled, 'last_triggered_at': lastTriggeredAt?.toIso8601String(),
  };
}

/// Manages automation rules — evaluates triggers and executes actions.
class AutomationService {
  final AppLogger _logger = AppLogger();
  final PrimitiveRegistry _primitives;
  final List<AutomationRule> _rules = [];
  final _controller = StreamController<List<AutomationRule>>.broadcast();

  Timer? _evalTimer;
  final _completionCallbacks = <String, void Function(Map<String, dynamic> result)>{};

  AutomationService({required PrimitiveRegistry primitives}) : _primitives = primitives;

  Stream<List<AutomationRule>> get rules => _controller.stream;
  List<AutomationRule> get allRules => List.unmodifiable(_rules);

  /// Register a completion callback (for automations that wait on async results).
  void onComplete(String ruleId, void Function(Map<String, dynamic> result) cb) {
    _completionCallbacks[ruleId] = cb;
  }

  void addRule(AutomationRule rule) {
    _rules.add(rule);
    _controller.add(allRules);
  }

  void removeRule(String id) {
    _rules.removeWhere((r) => r.id == id);
    _controller.add(allRules);
  }

  void toggleRule(String id, bool enabled) {
    final rule = _rules.firstWhere((r) => r.id == id);
    rule.isEnabled = enabled;
    _controller.add(allRules);
  }

  /// Start periodic trigger evaluation.
  void start() {
    _evalTimer = Timer.periodic(const Duration(seconds: 10), (_) => evaluateTriggers());
    _logger.info('Automation engine started');
  }

  /// Evaluate all enabled triggers.
  Future<void> evaluateTriggers() async {
    final now = DateTime.now();
    for (final rule in _rules.where((r) => r.isEnabled)) {
      if (_shouldTrigger(rule, now)) {
        await _executeAction(rule);
        rule.lastTriggeredAt = now;
        _controller.add(allRules);
      }
    }
  }

  bool _shouldTrigger(AutomationRule rule, DateTime now) {
    switch (rule.trigger.type) {
      case 'interval':
        final minutes = rule.trigger.config['minutes'] as int? ?? 60;
        if (rule.lastTriggeredAt == null) return true;
        return now.difference(rule.lastTriggeredAt!).inMinutes >= minutes;
      case 'time':
        final timeStr = rule.trigger.config['at'] as String?; // 'HH:MM'
        if (timeStr == null) return false;
        final parts = timeStr.split(':');
        final triggerTime = DateTime(now.year, now.month, now.day, int.parse(parts[0]), int.parse(parts[1]));
        if (rule.lastTriggeredAt != null && rule.lastTriggeredAt!.day == now.day) return false; // already fired today
        return now.hour == triggerTime.hour && now.minute == triggerTime.minute;
      default:
        return false;
    }
  }

  Future<void> _executeAction(AutomationRule rule) async {
    try {
      switch (rule.action.type) {
        case 'notify':
          _logger.info('Automation "${rule.name}" triggered notification: ${rule.action.config['title']}');
          break;
        case 'run_primitive':
          final primName = rule.action.config['primitive'] as String;
          final args = rule.action.config['args'] as Map<String, dynamic>? ?? {};
          final prim = _primitives.get(primName);
          if (prim != null) {
            final result = await prim.execute(args);
            _completionCallbacks[rule.id]?.call(result.toJson());
          }
          break;
      }
    } catch (e) {
      _logger.error('Automation action failed: ${rule.name}', e);
    }
  }

  void stop() {
    _evalTimer?.cancel();
    _controller.close();
  }
}
