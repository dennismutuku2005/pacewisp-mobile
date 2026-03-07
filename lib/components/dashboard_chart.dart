import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
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

    return LineChart(
      LineChartData(
        gridData: FlGridData(
          show: true,
          drawVerticalLine: false,
          horizontalInterval: 5000,
          getDrawingHorizontalLine: (value) {
            return FlLine(
              color: PaceColors.getBorder(Theme.of(context).brightness == Brightness.dark).withOpacity(0.5),
              strokeWidth: 1,
              dashArray: [5, 5],
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
                    padding: const EdgeInsets.only(top: 12.0),
                    child: Text(
                      chartData[index]['day']?.toString().toUpperCase() ?? '',
                      style: GoogleFonts.figtree(
                        color: PaceColors.getDimText(Theme.of(context).brightness == Brightness.dark),
                        fontWeight: FontWeight.bold,
                        fontSize: 8,
                        letterSpacing: 1,
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
                if (value == 0) return const Text('');
                String label = value >= 1000 ? '${(value / 1000).toStringAsFixed(0)}k' : value.toStringAsFixed(0);
                return Text(
                  label,
                  style: GoogleFonts.figtree(
                    color: PaceColors.getDimText(Theme.of(context).brightness == Brightness.dark),
                    fontWeight: FontWeight.bold,
                    fontSize: 8,
                  ),
                );
              },
              reservedSize: 28,
            ),
          ),
        ),
        borderData: FlBorderData(show: false),
        lineTouchData: LineTouchData(
          touchTooltipData: LineTouchTooltipData(
            getTooltipColor: (_) => PaceColors.getCard(Theme.of(context).brightness == Brightness.dark).withOpacity(0.9),
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
                colors: [
                  PaceColors.purple.withOpacity(0.15),
                  PaceColors.purple.withOpacity(0.0),
                ],
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
                colors: [
                  const Color(0xFF22C55E).withOpacity(0.1),
                  const Color(0xFF22C55E).withOpacity(0.0),
                ],
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
