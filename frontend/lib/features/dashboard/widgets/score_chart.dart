import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:convora/core/models/models.dart';

class ScoreLineChart extends StatelessWidget {
  final List<TimelinePoint> timeline;
  final int maxScore;

  const ScoreLineChart({
    super.key,
    required this.timeline,
    required this.maxScore,
  });

  Color _getDiscColor(String disc) {
    switch (disc.toUpperCase()) {
      case 'D':
        return Colors.red.shade300;
      case 'I':
        return Colors.orange.shade300;
      case 'S':
        return Colors.green.shade300;
      case 'C':
        return Colors.blue.shade300;
      default:
        return Colors.grey.shade300;
    }
  }

  @override
  Widget build(BuildContext context) {
    if (timeline.isEmpty) {
      return Container(
        height: 300,
        decoration: BoxDecoration(
          border: Border.all(color: Colors.grey.shade300),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.trending_up, size: 48, color: Colors.grey.shade400),
              const SizedBox(height: 16),
              Text(
                'No training sessions yet',
                style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                      color: Colors.grey.shade600,
                    ),
              ),
              const SizedBox(height: 8),
              Text(
                'Complete a session to see your progression',
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: Colors.grey.shade500,
                    ),
              ),
            ],
          ),
        ),
      );
    }

    // Convert timeline points to FlSpots
    final spots = List.generate(
      timeline.length,
      (index) => FlSpot(index.toDouble(), timeline[index].score.toDouble()),
    );

    // Determine Y-axis max (score range)
    final yMax = (maxScore.toDouble() * 1.1).ceil();

    return SizedBox(
      height: 300,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: LineChart(
          LineChartData(
            gridData: FlGridData(
              show: true,
              drawVerticalLine: false,
              horizontalInterval: ((yMax / 5).ceil().toDouble()),
              getDrawingHorizontalLine: (value) => FlLine(
                color: Colors.grey.shade200,
                strokeWidth: 1,
              ),
            ),
            titlesData: FlTitlesData(
              bottomTitles: AxisTitles(
                sideTitles: SideTitles(
                  showTitles: true,
                  reservedSize: 30,
                  getTitlesWidget: (value, meta) {
                    final index = value.toInt();
                    if (index < 0 || index >= timeline.length) {
                      return const Text('');
                    }
                    // Show every 5th label to avoid crowding
                    if (index % 5 != 0 && index != timeline.length - 1) {
                      return const Text('');
                    }
                    return Text(
                      '${index + 1}',
                      style: const TextStyle(fontSize: 10),
                    );
                  },
                ),
              ),
              leftTitles: AxisTitles(
                sideTitles: SideTitles(
                  showTitles: true,
                  reservedSize: 35,
                  getTitlesWidget: (value, meta) {
                    return Text(
                      '${value.toInt()}',
                      style: const TextStyle(fontSize: 10),
                      textAlign: TextAlign.right,
                    );
                  },
                ),
              ),
              topTitles: const AxisTitles(
                sideTitles: SideTitles(showTitles: false),
              ),
              rightTitles: const AxisTitles(
                sideTitles: SideTitles(showTitles: false),
              ),
            ),
            borderData: FlBorderData(
              show: true,
              border: Border(
                bottom: BorderSide(color: Colors.grey.shade300),
                left: BorderSide(color: Colors.grey.shade300),
              ),
            ),
            minX: 0,
            maxX: (timeline.length - 1).toDouble(),
            minY: 0,
            maxY: yMax,
            lineBarsData: [
              LineChartBarData(
                spots: spots,
                isCurved: true,
                color: Colors.teal,
                barWidth: 3,
                isStrokeCapRound: true,
                dotData: FlDotData(
                  show: true,
                  getDotPainter: (spot, percent, barData, index) {
                    final discType = timeline[index.toInt()].discType;
                    return FlDotCirclePainter(
                      radius: 5,
                      color: _getDiscColor(discType),
                      strokeWidth: 2,
                      strokeColor: Colors.white,
                    );
                  },
                ),
                belowBarData: BarAreaData(
                  show: true,
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [
                      Colors.teal.withValues(alpha: 0.3),
                      Colors.teal.withValues(alpha: 0),
                    ],
                  ),
                ),
              ),
            ],
            lineTouchData: LineTouchData(
              handleBuiltInTouches: true,
              touchTooltipData: LineTouchTooltipData(
                getTooltipItems: (List<LineBarSpot> touchedBarSpots) {
                  return touchedBarSpots.map((barSpot) {
                    final index = barSpot.x.toInt();
                    if (index < 0 || index >= timeline.length) {
                      return const LineTooltipItem('', TextStyle());
                    }
                    final point = timeline[index];
                    return LineTooltipItem(
                      '${point.scenarioTitle}\nScore: ${point.score.toInt()}',
                      const TextStyle(color: Colors.white, fontSize: 12),
                    );
                  }).toList();
                },
              ),
            ),
          ),
        ),
      ),
    );
  }
}
