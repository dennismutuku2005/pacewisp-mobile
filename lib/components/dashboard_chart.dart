import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import '../theme/colors.dart';

class DashboardChart extends StatelessWidget {
  final List<dynamic> chartData;

  const DashboardChart({super.key, required this.chartData});

  @override
  Widget build(BuildContext context) {
    if (chartData.isEmpty) {
      return const Center(child: Text('No data available'));
    }

    // Convert list to FlSpot
    List<FlSpot> revenueSpots = [];
    List<FlSpot> entrySpots = [];
    
    for (int i = 0; i < chartData.length; i++) {
      final amount = double.tryParse(chartData[i]['amount'].toString()) ?? 0;
      final entries = double.tryParse(chartData[i]['entries'].toString()) ?? 0;
      revenueSpots.add(FlSpot(i.toDouble(), amount));
      entrySpots.add(FlSpot(i.toDouble(), entries));
    }

    return AspectRatio(
      aspectRatio: 1.7,
      child: LineChart(
        LineChartData(
          gridData: FlGridData(
            show: true,
            drawVerticalLine: false,
            horizontalInterval: 1000,
            getDrawingHorizontalLine: (value) {
              return FlLine(
                color: PaceColors.border,
                strokeWidth: 1,
              );
            },
          ),
          titlesData: FlTitlesData(
            show: true,
            rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
            topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
            bottomTitles: AxisTitles(
              sideTitles: SideTitles(
                showTitles: true,
                getTitlesWidget: (value, meta) {
                  int index = value.toInt();
                  if (index >= 0 && index < chartData.length) {
                    return Padding(
                      padding: const EdgeInsets.only(top: 8.0),
                      child: Text(
                        chartData[index]['day'] ?? '',
                        style: const TextStyle(
                          color: PaceColors.adminDim,
                          fontWeight: FontWeight.bold,
                          fontSize: 10,
                        ),
                      ),
                    );
                  }
                  return const Text('');
                },
              ),
            ),
            leftTitles: AxisTitles(
              sideTitles: SideTitles(
                showTitles: true,
                getTitlesWidget: (value, meta) {
                  return Text(
                    value >= 1000 ? '${(value / 1000).toStringAsFixed(0)}k' : value.toStringAsFixed(0),
                    style: const TextStyle(
                      color: PaceColors.adminDim,
                      fontWeight: FontWeight.bold,
                      fontSize: 10,
                    ),
                  );
                },
                reservedSize: 30,
              ),
            ),
          ),
          borderData: FlBorderData(show: false),
          lineBarsData: [
            // Revenue Line
            LineChartBarData(
              spots: revenueSpots,
              isCurved: true,
              color: PaceColors.purple,
              barWidth: 3,
              isStrokeCapRound: true,
              dotData: const FlDotData(show: false),
              belowBarData: BarAreaData(
                show: true,
                gradient: LinearGradient(
                  colors: [
                    PaceColors.purple.withOpacity(0.2),
                    PaceColors.purple.withOpacity(0.0),
                  ],
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                ),
              ),
            ),
            // Entries Line
            LineChartBarData(
              spots: entrySpots,
              isCurved: true,
              color: PaceColors.green,
              barWidth: 2,
              isStrokeCapRound: true,
              dotData: const FlDotData(show: false),
              belowBarData: BarAreaData(
                show: true,
                gradient: LinearGradient(
                  colors: [
                    PaceColors.green.withOpacity(0.1),
                    PaceColors.green.withOpacity(0.0),
                  ],
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
