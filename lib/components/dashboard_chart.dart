import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../theme/colors.dart';

enum ChartType { bar, line }

class DashboardChart extends StatelessWidget {
  final List<dynamic> chartData;
  final ChartType type;

  const DashboardChart({super.key, required this.chartData, this.type = ChartType.bar});

  @override
  Widget build(BuildContext context) {
    if (chartData.isEmpty) {
      return const Center(child: Text('No data available'));
    }

    final isDark = Theme.of(context).brightness == Brightness.dark;

    if (type == ChartType.bar) {
      return _buildBarChart(isDark);
    } else {
      return _buildLineChart(isDark);
    }
  }

  Widget _buildBarChart(bool isDark) {
    return BarChart(
      BarChartData(
        alignment: BarChartAlignment.spaceAround,
        maxY: _getMaxY(),
        barTouchData: BarTouchData(
          enabled: true,
          touchTooltipData: BarTouchTooltipData(
            getTooltipColor: (_) => PaceColors.purple.withOpacity(0.9),
            getTooltipItem: (group, groupIndex, rod, rodIndex) {
              return BarTooltipItem(
                'KSH ${rod.toY.toInt()}',
                GoogleFonts.figtree(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                  fontSize: 10,
                ),
              );
            },
          ),
        ),
        titlesData: _getTitlesData(isDark),
        gridData: _getGridData(isDark),
        borderData: FlBorderData(show: false),
        barGroups: List.generate(chartData.length, (i) {
          final amount = double.tryParse(chartData[i]['amount'].toString()) ?? 0;
          return BarChartGroupData(
            x: i,
            barRods: [
              BarChartRodData(
                toY: amount,
                color: PaceColors.purple,
                width: 12,
                borderRadius: const BorderRadius.vertical(top: Radius.circular(4)),
                backDrawRodData: BackgroundBarChartRodData(
                  show: true,
                  toY: _getMaxY(),
                  color: PaceColors.purple.withOpacity(0.05),
                ),
              ),
            ],
          );
        }),
      ),
    );
  }

  Widget _buildLineChart(bool isDark) {
    List<FlSpot> revenueSpots = [];
    List<FlSpot> entrySpots = [];
    
    for (int i = 0; i < chartData.length; i++) {
       final amount = double.tryParse(chartData[i]['amount'].toString()) ?? 0;
       final entries = double.tryParse(chartData[i]['entries'].toString()) ?? 0;
       revenueSpots.add(FlSpot(i.toDouble(), amount));
       entrySpots.add(FlSpot(i.toDouble(), entries));
    }

    return LineChart(
      LineChartData(
        gridData: _getGridData(isDark),
        titlesData: _getTitlesData(isDark),
        borderData: FlBorderData(show: false),
        lineTouchData: LineTouchData(
          touchTooltipData: LineTouchTooltipData(
            getTooltipColor: (_) => PaceColors.getCard(isDark).withOpacity(0.95),
            getTooltipItems: (touchedSpots) {
              return touchedSpots.map((spot) {
                final isRevenue = spot.barIndex == 0;
                return LineTooltipItem(
                  isRevenue ? 'REVENUE: KSH ${spot.y.toInt()}' : 'ENTRIES: ${spot.y.toInt()}',
                  GoogleFonts.figtree(
                    color: isRevenue ? PaceColors.purple : const Color(0xFF22C55E),
                    fontWeight: FontWeight.bold,
                    fontSize: 10,
                  ),
                );
              }).toList();
            },
          ),
        ),
        lineBarsData: [
          // Revenue Line (Purple)
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
                colors: [PaceColors.purple.withOpacity(0.15), PaceColors.purple.withOpacity(0.0)],
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
              ),
            ),
          ),
          // Entries Line (Green)
          LineChartBarData(
            spots: entrySpots,
            isCurved: true,
            color: const Color(0xFF22C55E),
            barWidth: 2,
            isStrokeCapRound: true,
            dotData: const FlDotData(show: false),
            belowBarData: BarAreaData(
              show: true,
              gradient: LinearGradient(
                colors: [const Color(0xFF22C55E).withOpacity(0.1), const Color(0xFF22C55E).withOpacity(0.0)],
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
              ),
            ),
          ),
        ],
      ),
    );
  }

  FlTitlesData _getTitlesData(bool isDark) {
    return FlTitlesData(
      show: true,
      bottomTitles: AxisTitles(
        sideTitles: SideTitles(
          showTitles: true,
          getTitlesWidget: (value, meta) {
            int index = value.toInt();
            if (index >= 0 && index < chartData.length) {
              return Padding(
                padding: const EdgeInsets.only(top: 8.0),
                child: Text(
                  chartData[index]['day']?.toString().split(' ')[0].toUpperCase() ?? '',
                  style: GoogleFonts.figtree(
                    color: PaceColors.getDimText(isDark),
                    fontWeight: FontWeight.bold,
                    fontSize: 8,
                    letterSpacing: 1,
                  ),
                ),
              );
            }
            return const SizedBox();
          },
          reservedSize: 22,
        ),
      ),
      leftTitles: AxisTitles(
        sideTitles: SideTitles(
          showTitles: true,
          getTitlesWidget: (value, meta) {
             if (value == 0) return const SizedBox();
             String label = value >= 1000 ? '${(value / 1000).toStringAsFixed(0)}k' : value.toStringAsFixed(0);
             return Text(label, style: GoogleFonts.figtree(color: PaceColors.getDimText(isDark), fontWeight: FontWeight.bold, fontSize: 8));
          },
          reservedSize: 28,
        ),
      ),
      rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
      topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
    );
  }

  FlGridData _getGridData(bool isDark) {
     return FlGridData(
      show: true,
      drawVerticalLine: false,
      horizontalInterval: _getInterval(),
      getDrawingHorizontalLine: (value) => FlLine(
        color: PaceColors.getBorder(isDark).withOpacity(0.5),
        strokeWidth: 1,
        dashArray: [4, 4],
      ),
    );
  }

  double _getMaxY() {
    double max = 1000;
    for (var d in chartData) {
      double val = double.tryParse(d['amount'].toString()) ?? 0;
      double entries = double.tryParse(d['entries'].toString()) ?? 0;
      if (val > max) max = val;
      if (entries > max) max = entries;
    }
    return max * 1.2;
  }

  double _getInterval() {
    double max = _getMaxY();
    if (max <= 5000) return 1000;
    if (max <= 20000) return 5000;
    return 10000;
  }
}
