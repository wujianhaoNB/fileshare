import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../providers/ai_providers.dart';
import '../../../services/personal_development_service.dart';

class PersonalDashboard extends ConsumerWidget {
  const PersonalDashboard({super.key});
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final pd = ref.watch(personalDevelopmentProvider);
    final theme = Theme.of(context);
    final dims = pd.dimensions;
    if (dims.isEmpty) return const SizedBox.shrink();

    final score = pd.overallScore;

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        // Score header
        Container(
          padding: const EdgeInsets.all(24),
          decoration: BoxDecoration(
            gradient: const LinearGradient(colors: [Color(0xFF7C5CFC), Color(0xFF00CEC9)]),
            borderRadius: BorderRadius.circular(24),
          ),
          child: Row(children: [
            Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              const Text('综合评分', style: TextStyle(color: Colors.white70, fontSize: 13)),
              const SizedBox(height: 6),
              Text(score.toStringAsFixed(1), style: const TextStyle(color: Colors.white, fontSize: 40, fontWeight: FontWeight.w800)),
              const SizedBox(height: 4),
              Text('${_gradeLabel(score)} · ${dims.where((d) => d.score >= 60).length}/${dims.length} 项达标', style: const TextStyle(color: Colors.white60, fontSize: 12)),
            ]),
            const Spacer(),
            SizedBox(width: 100, height: 100, child: CustomPaint(painter: _RadarPainter(dims, const Color(0xFFFFFFFF)))),
          ]),
        ),
        const SizedBox(height: 24),
        Text('能力维度', style: theme.textTheme.titleSmall?.copyWith(color: const Color(0xFF7C5CFC), fontWeight: FontWeight.w700)),
        const SizedBox(height: 10),
        ...dims.map((d) => _DimensionTile(dim: d, pd: pd)),
        const SizedBox(height: 24),
        // Plans
        if (pd.plans.isNotEmpty) ...[
          Text('成长计划', style: theme.textTheme.titleSmall?.copyWith(color: const Color(0xFF7C5CFC), fontWeight: FontWeight.w700)),
          const SizedBox(height: 10),
          ...pd.plans.where((p) => p.progress < 1.0).map((p) => _PlanCard(plan: p)),
        ],
        const SizedBox(height: 80),
      ]),
    );
  }

  String _gradeLabel(double s) {
    if (s >= 90) return '卓越';
    if (s >= 75) return '优秀';
    if (s >= 60) return '良好';
    if (s >= 40) return '一般';
    return '待提升';
  }
}

class _DimensionTile extends StatefulWidget {
  final ProfileDimension dim;
  final PersonalDevelopmentService pd;
  const _DimensionTile({required this.dim, required this.pd});
  @override State<_DimensionTile> createState() => _DimensionTileState();
}
class _DimensionTileState extends State<_DimensionTile> {
  @override Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final d = widget.dim;
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(color: theme.colorScheme.surfaceContainerHighest, borderRadius: BorderRadius.circular(14)),
      child: Row(children: [
        Container(width: 40, height: 40, decoration: BoxDecoration(borderRadius: BorderRadius.circular(10), color: _dimColor(d.category).withValues(alpha: 0.12)), child: Icon(_dimIcon(d.category), color: _dimColor(d.category), size: 20)),
        const SizedBox(width: 12),
        Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children: [Text(d.name, style: theme.textTheme.bodyLarge?.copyWith(fontWeight: FontWeight.w600)), const Spacer(), Text('${d.score}', style: TextStyle(color: _dimColor(d.category), fontWeight: FontWeight.w700, fontSize: 18))]),
          const SizedBox(height: 6),
          ClipRRect(borderRadius: BorderRadius.circular(4), child: LinearProgressIndicator(value: d.score / 100, backgroundColor: theme.dividerColor, color: _dimColor(d.category), minHeight: 6)),
          const SizedBox(height: 4),
          Text('权重 ${d.weight} · ${widget.pd.getTrend(d.id)}', style: theme.textTheme.bodySmall),
        ])),
        const SizedBox(width: 8),
        // +/- buttons
        Column(children: [
          InkWell(onTap: () { widget.pd.updateScore(d.id, (d.score + 5).clamp(0, 100)); setState(() {}); }, child: const Icon(Icons.add_circle_outline, size: 18, color: Color(0xFF7C5CFC))),
          InkWell(onTap: () { widget.pd.updateScore(d.id, (d.score - 5).clamp(0, 100)); setState(() {}); }, child: const Icon(Icons.remove_circle_outline, size: 18, color: Color(0xFF8B8A9A))),
        ]),
      ]),
    );
  }

  Color _dimColor(String cat) {
    switch (cat) {
      case 'physical': return Colors.green;
      case 'career': return const Color(0xFF7C5CFC);
      case 'knowledge': return Colors.blue;
      case 'social': return Colors.orange;
      case 'mental': return Colors.teal;
      case 'financial': return Colors.amber;
      case 'lifestyle': return Colors.pink;
      default: return Colors.grey;
    }
  }
  IconData _dimIcon(String cat) {
    switch (cat) {
      case 'physical': return Icons.fitness_center_rounded;
      case 'career': return Icons.work_rounded;
      case 'knowledge': return Icons.school_rounded;
      case 'social': return Icons.people_rounded;
      case 'mental': return Icons.psychology_rounded;
      case 'financial': return Icons.savings_rounded;
      case 'lifestyle': return Icons.local_cafe_rounded;
      default: return Icons.star_rounded;
    }
  }
}

class _PlanCard extends StatelessWidget {
  final DevelopmentPlan plan;
  const _PlanCard({required this.plan});
  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final done = plan.steps.where((s) => s.completed).length;
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(color: theme.colorScheme.surfaceContainerHighest, borderRadius: BorderRadius.circular(14)),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(plan.title, style: theme.textTheme.titleMedium),
        const SizedBox(height: 4),
        Text(plan.description, style: theme.textTheme.bodySmall, maxLines: 2),
        const SizedBox(height: 8),
        ClipRRect(borderRadius: BorderRadius.circular(4), child: LinearProgressIndicator(value: plan.progress, minHeight: 6, backgroundColor: theme.dividerColor)),
        const SizedBox(height: 4),
        Text('$done/${plan.steps.length} 步完成', style: theme.textTheme.bodySmall),
      ]),
    );
  }
}

/// Radar chart painter for 8 dimensions.
class _RadarPainter extends CustomPainter {
  final List<ProfileDimension> dims;
  final Color color;
  _RadarPainter(this.dims, this.color);
  @override void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = min(size.width, size.height) / 2 - 8;
    final n = dims.length;
    final paint = Paint()..color = color.withValues(alpha: 0.15)..style = PaintingStyle.fill;
    final line = Paint()..color = color.withValues(alpha: 0.6)..style = PaintingStyle.stroke..strokeWidth = 1.5;
    final grid = Paint()..color = color.withValues(alpha: 0.15)..style = PaintingStyle.stroke..strokeWidth = 0.5;

    // Grid
    for (var r = 1; r <= 3; r++) {
      final path = Path();
      for (var i = 0; i < n; i++) {
        final angle = -pi / 2 + 2 * pi * i / n;
        final x = center.dx + radius * r / 3 * cos(angle);
        final y = center.dy + radius * r / 3 * sin(angle);
        if (i == 0) path.moveTo(x, y); else path.lineTo(x, y);
      }
      path.close(); canvas.drawPath(path, grid);
    }

    // Data fill
    final dataPath = Path();
    for (var i = 0; i < n; i++) {
      final angle = -pi / 2 + 2 * pi * i / n;
      final r = radius * dims[i].score / 100;
      final x = center.dx + r * cos(angle);
      final y = center.dy + r * sin(angle);
      if (i == 0) dataPath.moveTo(x, y); else dataPath.lineTo(x, y);
    }
    dataPath.close(); canvas.drawPath(dataPath, paint); canvas.drawPath(dataPath, line);

    // Dots
    final dot = Paint()..color = color..style = PaintingStyle.fill;
    for (var i = 0; i < n; i++) {
      final angle = -pi / 2 + 2 * pi * i / n;
      final r = radius * dims[i].score / 100;
      canvas.drawCircle(Offset(center.dx + r * cos(angle), center.dy + r * sin(angle)), 3, dot);
    }
  }
  @override bool shouldRepaint(covariant CustomPainter old) => true;
}
