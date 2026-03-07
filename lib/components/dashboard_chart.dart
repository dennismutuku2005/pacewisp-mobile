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
    final maxY = _getMaxY();

    return Container(
      padding: const EdgeInsets.only(right: 16, top: 12), // Add padding to prevent cut lines at edges
      child: type == ChartType.bar 
        ? _buildBarChart(isDark, maxY) 
        : _buildLineChart(isDark, maxY),
    );
  }

  Widget _buildBarChart(bool isDark, double maxY) {
    return BarChart(
      BarChartData(
        alignment: BarChartAlignment.spaceAround,
        maxY: maxY,
        minY: 0,
        barTouchData: BarTouchData(
          enabled: true,
          touchTooltipData: BarTouchTooltipData(
            getTooltipColor: (_) => PaceColors.getCard(isDark).withOpacity(0.95),
            getTooltipItem: (group, groupIndex, rod, rodIndex) {
              final isRevenue = rodIndex == 0;
              return BarTooltipItem(
                isRevenue ? 'REV: KSH ${rod.toY.toInt()}' : 'ENT: ${rod.toY.toInt()}',
                GoogleFonts.figtree(
                  color: isRevenue ? PaceColors.purple : const Color(0xFF22C55E),
                  fontWeight: FontWeight.w900,
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
          final entries = double.tryParse(chartData[i]['entries'].toString()) ?? 0;
          
          return BarChartGroupData(
            x: i,
            barsSpace: 4,
            barRods: [
              BarChartRodData(
                toY: amount,
                color: PaceColors.purple,
                width: 8,
                borderRadius: const BorderRadius.vertical(top: Radius.circular(3)),
                backDrawRodData: BackgroundBarChartRodData(show: true, toY: maxY, color: PaceColors.purple.withOpacity(0.02)),
              ),
              BarChartRodData(
                toY: entries,
                color: const Color(0xFF22C55E),
                width: 8,
                borderRadius: const BorderRadius.vertical(top: Radius.circular(3)),
                backDrawRodData: BackgroundBarChartRodData(show: true, toY: maxY, color: const Color(0xFF22C55E).withOpacity(0.02)),
              ),
            ],
          );
        }),
      ),
    );
  }

  Widget _buildLineChart(bool isDark, double maxY) {
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
        maxY: maxY,
        minY: 0,
        gridData: _getGridData(isDark),
        titlesData: _getTitlesData(isDark),
        borderData: FlBorderData(show: false),
        lineTouchData: LineTouchData(
          touchTooltipData: LineTouchTooltipData(
            getTooltipColor: (_) => PaceColors.getCard(isDark).withOpacity(0.95),
            fitInsideHorizontally: true,
            fitInsideVertically: true,
            getTooltipItems: (touchedSpots) {
              return touchedSpots.map<LineTooltipItem>((spot) {
                final isRevenue = spot.barIndex == 0;
                return LineTooltipItem(
                  isRevenue ? 'REVENUE: KSH ${spot.y.toInt()}' : 'ENTRIES: ${spot.y.toInt()}',
                  GoogleFonts.figtree(
                    color: isRevenue ? PaceColors.purple : const Color(0xFF22C55E),
                    fontWeight: FontWeight.w900,
                    fontSize: 10,
                  ),
                );
              }).toList();
            },
          ),
        ),
        lineBarsData: [
          LineChartBarData(
            spots: revenueSpots,
            isCurved: true,
            curveSmoothness: 0.35,
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
          LineChartBarData(
            spots: entrySpots,
            isCurved: true,
            curveSmoothness: 0.35,
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
              // Only show every 2nd or 3rd label if there are too many items to avoid overlap
              if (chartData.length > 7 && index % 2 != 0) return const SizedBox();
              
              return Padding(
                padding: const EdgeInsets.only(top: 8.0),
                child: Text(
                  chartData[index]['day']?.toString().split(' ')[0].toUpperCase() ?? '',
                  style: GoogleFonts.figtree(
                    color: PaceColors.getDimText(isDark),
                    fontWeight: FontWeight.w900,
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
             return Text(label, style: GoogleFonts.figtree(color: PaceColors.getDimText(isDark), fontWeight: FontWeight.w900, fontSize: 8));
          },
          reservedSize: 32,
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
      horizontalInterval: (_getMaxY() / 4).clamp(1.0, double.infinity),
      getDrawingHorizontalLine: (value) => FlLine(
        color: PaceColors.getBorder(isDark).withOpacity(0.5),
        strokeWidth: 1,
        dashArray: [4, 4],
      ),
    );
  }

  double _getMaxY() {
    double max = 10;
    for (var d in chartData) {
      double val = double.tryParse(d['amount'].toString()) ?? 0;
      double entries = double.tryParse(d['entries'].toString()) ?? 0;
      if (val > max) max = val;
      if (entries > max) max = entries;
    }
    // Dynamically scale maxY to ensure lines are never cut off at the top
    return max * 1.25; 
  }
}
