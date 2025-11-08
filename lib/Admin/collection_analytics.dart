import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';

class CollectionAnalytics extends StatelessWidget {
  const CollectionAnalytics({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[50],
      appBar: AppBar(
        title: const Text(
          "Collection Analytics",
          style: TextStyle(color: Colors.white),
        ),
        centerTitle: false,
        backgroundColor: Colors.green[700],
        elevation: 0,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              "Overview",
              style: TextStyle(
                fontSize: 22,
                fontWeight: FontWeight.bold,
                color: Colors.green[800],
              ),
            ),
            const SizedBox(height: 20),

            // Weekly Collections Chart
            _buildCard(
              "Weekly Collections",
              SizedBox(
                height: 200,
                child: BarChart(
                  BarChartData(
                    gridData: FlGridData(show: false),
                    borderData: FlBorderData(show: false),
                    titlesData: FlTitlesData(
                      leftTitles: AxisTitles(
                        sideTitles: SideTitles(showTitles: false),
                      ),
                      topTitles: AxisTitles(
                        sideTitles: SideTitles(showTitles: false),
                      ),
                      rightTitles: AxisTitles(
                        sideTitles: SideTitles(showTitles: false),
                      ),
                      bottomTitles: AxisTitles(
                        sideTitles: SideTitles(
                          showTitles: true,
                          getTitlesWidget: (value, meta) {
                            switch (value.toInt()) {
                              case 0:
                                return const Text("Mon");
                              case 1:
                                return const Text("Tue");
                              case 2:
                                return const Text("Wed");
                              case 3:
                                return const Text("Thu");
                              case 4:
                                return const Text("Fri");
                              case 5:
                                return const Text("Sat");
                              case 6:
                                return const Text("Sun");
                              default:
                                return const Text("");
                            }
                          },
                        ),
                      ),
                    ),
                    barGroups: [
                      BarChartGroupData(
                        x: 0,
                        barRods: [
                          BarChartRodData(toY: 120, color: Colors.green),
                        ],
                      ),
                      BarChartGroupData(
                        x: 1,
                        barRods: [
                          BarChartRodData(toY: 150, color: Colors.green),
                        ],
                      ),
                      BarChartGroupData(
                        x: 2,
                        barRods: [
                          BarChartRodData(toY: 100, color: Colors.green),
                        ],
                      ),
                      BarChartGroupData(
                        x: 3,
                        barRods: [
                          BarChartRodData(toY: 180, color: Colors.green),
                        ],
                      ),
                      BarChartGroupData(
                        x: 4,
                        barRods: [
                          BarChartRodData(toY: 140, color: Colors.green),
                        ],
                      ),
                      BarChartGroupData(
                        x: 5,
                        barRods: [
                          BarChartRodData(toY: 200, color: Colors.green),
                        ],
                      ),
                      BarChartGroupData(
                        x: 6,
                        barRods: [
                          BarChartRodData(toY: 170, color: Colors.green),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            ),

            const SizedBox(height: 20),

            // Pie chart: waste type distribution
            _buildCard(
              "Waste Type Distribution",
              SizedBox(
                height: 200,
                child: PieChart(
                  PieChartData(
                    centerSpaceRadius: 40,
                    sections: [
                      PieChartSectionData(
                        value: 40,
                        title: "Organic",
                        color: Colors.green,
                        radius: 50,
                      ),
                      PieChartSectionData(
                        value: 25,
                        title: "Plastic",
                        color: Colors.orange,
                        radius: 50,
                      ),
                      PieChartSectionData(
                        value: 20,
                        title: "Paper",
                        color: Colors.blue,
                        radius: 50,
                      ),
                      PieChartSectionData(
                        value: 15,
                        title: "Metal",
                        color: Colors.purple,
                        radius: 50,
                      ),
                    ],
                  ),
                ),
              ),
            ),

            const SizedBox(height: 20),

            // Key Statistics
            _buildCard(
              "Key Statistics",
              Column(
                children: const [
                  _StatRow("Average per Day", "152"),
                  Divider(),
                  _StatRow("This Month", "3,245"),
                  Divider(),
                  _StatRow("Recycling Rate", "68%"),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCard(String title, Widget child) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.green.withOpacity(0.1),
            blurRadius: 8,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: Colors.green[800],
            ),
          ),
          const SizedBox(height: 15),
          child,
        ],
      ),
    );
  }
}

class _StatRow extends StatelessWidget {
  final String label;
  final String value;
  const _StatRow(this.label, this.value);

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(label, style: TextStyle(fontSize: 16, color: Colors.grey[800])),
        Text(
          value,
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.bold,
            color: Colors.green[700],
          ),
        ),
      ],
    );
  }
}
