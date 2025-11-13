import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';

class CollectionAnalytics extends StatefulWidget {
  const CollectionAnalytics({super.key});

  @override
  State<CollectionAnalytics> createState() => _CollectionAnalyticsState();
}

class _CollectionAnalyticsState extends State<CollectionAnalytics>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  // Analytics data
  List<CollectionData> _collectionData = [];
  List<WasteTypeData> _wasteTypeData = [];
  List<PointsData> _pointsDistribution = [];
  List<PointsByWasteType> _pointsByWasteType = [];

  // Statistics
  double _totalCollections = 0;
  double _todayCollections = 0;
  int _totalPointsDistributed = 0;
  int _activeUsers = 0;

  // Time filters
  String _timeFilter = 'week';

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _loadAnalyticsData();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _loadAnalyticsData() async {
    await _loadCollectionData();
    await _loadWasteTypeData();
    await _loadPointsData();
    await _loadStatistics();
  }

  Future<void> _loadCollectionData() async {
    try {
      DateTime startDate = _getStartDate();

      final collections =
          await _firestore
              .collection("Collections")
              .where("collectionDate", isGreaterThanOrEqualTo: startDate)
              .where("status", isEqualTo: "completed")
              .get();

      // Group by date
      Map<String, double> dailyData = {};

      for (var doc in collections.docs) {
        var data = doc.data();
        Timestamp? timestamp = data['collectionDate'];
        if (timestamp != null) {
          DateTime date = timestamp.toDate();
          String dateKey = DateFormat('MMM dd').format(date);
          double quantity =
              (data['quantity (kg)'] ?? data['quantity'] ?? 0).toDouble();

          dailyData[dateKey] = (dailyData[dateKey] ?? 0) + quantity;
        }
      }

      // Convert to chart data
      List<CollectionData> chartData = [];
      dailyData.forEach((date, quantity) {
        chartData.add(CollectionData(date, quantity));
      });

      // Sort by date
      chartData.sort((a, b) => a.date.compareTo(b.date));

      setState(() {
        _collectionData = chartData;
      });
    } catch (e) {
      print("Error loading collection data: $e");
    }
  }

  Future<void> _loadWasteTypeData() async {
    try {
      final collections =
          await _firestore
              .collection("Collections")
              .where("status", isEqualTo: "completed")
              .get();

      Map<String, double> wasteTypeQuantities = {};
      double total = 0;

      for (var doc in collections.docs) {
        var data = doc.data();
        String wasteType = data['wasteType'] ?? 'Unknown';
        double quantity =
            (data['quantity (kg)'] ?? data['quantity'] ?? 0).toDouble();

        wasteTypeQuantities[wasteType] =
            (wasteTypeQuantities[wasteType] ?? 0) + quantity;
        total += quantity;
      }

      // Convert to chart data
      List<WasteTypeData> chartData = [];
      wasteTypeQuantities.forEach((type, quantity) {
        double percentage = total > 0 ? (quantity / total) * 100 : 0;
        chartData.add(WasteTypeData(type, quantity, percentage));
      });

      setState(() {
        _wasteTypeData = chartData;
      });
    } catch (e) {
      print("Error loading waste type data: $e");
    }
  }

  Future<void> _loadPointsData() async {
    try {
      // Load points distribution from users
      final users = await _firestore.collection("users").get();

      List<PointsData> pointsData = [];
      List<PointsByWasteType> pointsByType = [];

      Map<String, int> wasteTypePoints = {};

      for (var userDoc in users.docs) {
        var userData = userDoc.data();
        String userName =
            userData['name'] ?? userData['Name'] ?? 'Unknown User';
        int points =
            int.tryParse(userData['Points']?.toString() ?? '0') ??
            userData['coins'] ??
            0;

        if (points > 0) {
          pointsData.add(PointsData(userName, points));
        }
      }

      // Load points by waste type from submissions
      final submissions =
          await _firestore.collection("GarbageSubmissions").get();

      for (var doc in submissions.docs) {
        var data = doc.data();
        String wasteType = data['Type'] ?? 'Unknown';
        int points = int.tryParse(data['Points']?.toString() ?? '0') ?? 0;

        wasteTypePoints[wasteType] = (wasteTypePoints[wasteType] ?? 0) + points;
      }

      wasteTypePoints.forEach((type, points) {
        pointsByType.add(PointsByWasteType(type, points));
      });

      // Sort data
      pointsData.sort((a, b) => b.points.compareTo(a.points));
      pointsByType.sort((a, b) => b.points.compareTo(a.points));

      setState(() {
        _pointsDistribution = pointsData.take(10).toList(); // Top 10 users
        _pointsByWasteType = pointsByType;
      });
    } catch (e) {
      print("Error loading points data: $e");
    }
  }

  Future<void> _loadStatistics() async {
    try {
      // Total collections
      final totalCollections =
          await _firestore
              .collection("Collections")
              .where("status", isEqualTo: "completed")
              .get();

      double totalKg = 0;
      for (var doc in totalCollections.docs) {
        var data = doc.data();
        totalKg += (data['quantity (kg)'] ?? data['quantity'] ?? 0).toDouble();
      }

      // Today's collections
      DateTime today = DateTime.now();
      DateTime startOfDay = DateTime(today.year, today.month, today.day);

      final todayCollections =
          await _firestore
              .collection("Collections")
              .where("status", isEqualTo: "completed")
              .where("collectionDate", isGreaterThanOrEqualTo: startOfDay)
              .get();

      double todayKg = 0;
      for (var doc in todayCollections.docs) {
        var data = doc.data();
        todayKg += (data['quantity (kg)'] ?? data['quantity'] ?? 0).toDouble();
      }

      // Points and users
      final users = await _firestore.collection("users").get();
      int totalPoints = 0;
      int activeUsersCount = 0;

      for (var userDoc in users.docs) {
        var userData = userDoc.data();
        int points =
            int.tryParse(userData['Points']?.toString() ?? '0') ??
            userData['coins'] ??
            0;
        totalPoints += points;
        if (points > 0) activeUsersCount++;
      }

      setState(() {
        _totalCollections = totalKg;
        _todayCollections = todayKg;
        _totalPointsDistributed = totalPoints;
        _activeUsers = activeUsersCount;
      });
    } catch (e) {
      print("Error loading statistics: $e");
    }
  }

  DateTime _getStartDate() {
    switch (_timeFilter) {
      case 'week':
        return DateTime.now().subtract(const Duration(days: 7));
      case 'month':
        return DateTime.now().subtract(const Duration(days: 30));
      case 'year':
        return DateTime.now().subtract(const Duration(days: 365));
      default:
        return DateTime.now().subtract(const Duration(days: 7));
    }
  }

  Widget _buildCollectionAnalytics() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Time Filter
          _buildTimeFilter(),
          const SizedBox(height: 20),

          // Collection Trends Chart
          _buildCard(
            "Collection Trends",
            _collectionData.isNotEmpty
                ? SizedBox(
                  height: 200,
                  child: BarChart(
                    BarChartData(
                      alignment: BarChartAlignment.spaceAround,
                      maxY:
                          _collectionData
                              .map((e) => e.quantity)
                              .reduce((a, b) => a > b ? a : b) *
                          1.2,
                      barGroups:
                          _collectionData.asMap().entries.map((entry) {
                            int index = entry.key;
                            CollectionData data = entry.value;
                            return BarChartGroupData(
                              x: index,
                              barRods: [
                                BarChartRodData(
                                  toY: data.quantity,
                                  color: Colors.green,
                                  width: 16,
                                  borderRadius: BorderRadius.circular(4),
                                ),
                              ],
                            );
                          }).toList(),
                      titlesData: FlTitlesData(
                        bottomTitles: AxisTitles(
                          sideTitles: SideTitles(
                            showTitles: true,
                            getTitlesWidget: (value, meta) {
                              if (value.toInt() < _collectionData.length) {
                                return Padding(
                                  padding: const EdgeInsets.only(top: 8.0),
                                  child: Text(
                                    _collectionData[value.toInt()].date,
                                    style: const TextStyle(fontSize: 10),
                                  ),
                                );
                              }
                              return const Text('');
                            },
                          ),
                        ),
                        leftTitles: AxisTitles(
                          sideTitles: SideTitles(showTitles: true),
                        ),
                        topTitles: AxisTitles(
                          sideTitles: SideTitles(showTitles: false),
                        ),
                        rightTitles: AxisTitles(
                          sideTitles: SideTitles(showTitles: false),
                        ),
                      ),
                      gridData: FlGridData(show: true),
                      borderData: FlBorderData(show: false),
                    ),
                  ),
                )
                : const Center(child: Text("No collection data available")),
          ),

          const SizedBox(height: 20),

          // Waste Type Distribution
          _buildCard(
            "Waste Type Distribution",
            _wasteTypeData.isNotEmpty
                ? SizedBox(
                  height: 200,
                  child: PieChart(
                    PieChartData(
                      sections:
                          _wasteTypeData.asMap().entries.map((entry) {
                            int index = entry.key;
                            WasteTypeData data = entry.value;
                            final colors = [
                              Colors.green,
                              Colors.blue,
                              Colors.orange,
                              Colors.purple,
                              Colors.red,
                              Colors.yellow,
                            ];
                            return PieChartSectionData(
                              value: data.quantity,
                              color: colors[index % colors.length],
                              radius: 50,
                              title: '${data.percentage.toStringAsFixed(1)}%',
                              titleStyle: const TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.bold,
                                color: Colors.white,
                              ),
                            );
                          }).toList(),
                      sectionsSpace: 2,
                      centerSpaceRadius: 40,
                    ),
                  ),
                )
                : const Center(child: Text("No waste type data available")),
          ),

          const SizedBox(height: 20),

          // Waste Type Details
          if (_wasteTypeData.isNotEmpty) ...[
            _buildCard(
              "Waste Type Details",
              Column(
                children:
                    _wasteTypeData
                        .map(
                          (data) => _buildWasteTypeRow(
                            data.type,
                            data.quantity,
                            data.percentage,
                          ),
                        )
                        .toList(),
              ),
            ),
            const SizedBox(height: 20),
          ],

          // Key Statistics
          _buildCard(
            "Collection Statistics",
            Column(
              children: [
                _buildStatRow(
                  "Total Collected",
                  "${_totalCollections.toStringAsFixed(1)} kg",
                ),
                const Divider(),
                _buildStatRow(
                  "Today's Collection",
                  "${_todayCollections.toStringAsFixed(1)} kg",
                ),
                const Divider(),
                _buildStatRow(
                  "Average Daily",
                  "${(_totalCollections / 30).toStringAsFixed(1)} kg",
                ),
                const Divider(),
                _buildStatRow("Collection Efficiency", "85%"),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPointAnalytics() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Points Distribution Chart
          _buildCard(
            "Top Users by Points",
            _pointsDistribution.isNotEmpty
                ? SizedBox(
                  height: 200,
                  child: BarChart(
                    BarChartData(
                      alignment: BarChartAlignment.spaceAround,
                      maxY:
                          _pointsDistribution
                              .map((e) => e.points)
                              .reduce((a, b) => a > b ? a : b) *
                          1.2,
                      barGroups:
                          _pointsDistribution.asMap().entries.map((entry) {
                            int index = entry.key;
                            PointsData data = entry.value;
                            return BarChartGroupData(
                              x: index,
                              barRods: [
                                BarChartRodData(
                                  toY: data.points.toDouble(),
                                  color: Colors.blue,
                                  width: 16,
                                  borderRadius: BorderRadius.circular(4),
                                ),
                              ],
                            );
                          }).toList(),
                      titlesData: FlTitlesData(
                        bottomTitles: AxisTitles(
                          sideTitles: SideTitles(
                            showTitles: true,
                            getTitlesWidget: (value, meta) {
                              if (value.toInt() < _pointsDistribution.length) {
                                String userName =
                                    _pointsDistribution[value.toInt()].user;
                                return Padding(
                                  padding: const EdgeInsets.only(top: 8.0),
                                  child: Text(
                                    userName.length > 8
                                        ? '${userName.substring(0, 8)}...'
                                        : userName,
                                    style: const TextStyle(fontSize: 10),
                                  ),
                                );
                              }
                              return const Text('');
                            },
                          ),
                        ),
                        leftTitles: AxisTitles(
                          sideTitles: SideTitles(showTitles: true),
                        ),
                        topTitles: AxisTitles(
                          sideTitles: SideTitles(showTitles: false),
                        ),
                        rightTitles: AxisTitles(
                          sideTitles: SideTitles(showTitles: false),
                        ),
                      ),
                      gridData: FlGridData(show: true),
                      borderData: FlBorderData(show: false),
                    ),
                  ),
                )
                : const Center(child: Text("No points data available")),
          ),

          const SizedBox(height: 20),

          // Points by Waste Type
          _buildCard(
            "Points by Waste Type",
            _pointsByWasteType.isNotEmpty
                ? SizedBox(
                  height: 200,
                  child: PieChart(
                    PieChartData(
                      sections:
                          _pointsByWasteType.asMap().entries.map((entry) {
                            int index = entry.key;
                            PointsByWasteType data = entry.value;
                            final colors = [
                              Colors.green,
                              Colors.blue,
                              Colors.orange,
                              Colors.purple,
                              Colors.red,
                              Colors.yellow,
                            ];
                            return PieChartSectionData(
                              value: data.points.toDouble(),
                              color: colors[index % colors.length],
                              radius: 50,
                              title: data.points.toString(),
                              titleStyle: const TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.bold,
                                color: Colors.white,
                              ),
                            );
                          }).toList(),
                      sectionsSpace: 2,
                      centerSpaceRadius: 40,
                    ),
                  ),
                )
                : const Center(child: Text("No points by waste type data")),
          ),

          const SizedBox(height: 20),

          // Points Statistics
          _buildCard(
            "Points Statistics",
            Column(
              children: [
                _buildStatRow(
                  "Total Points Distributed",
                  _totalPointsDistributed.toString(),
                ),
                const Divider(),
                _buildStatRow(
                  "Active Users with Points",
                  _activeUsers.toString(),
                ),
                const Divider(),
                _buildStatRow(
                  "Average Points per User",
                  _activeUsers > 0
                      ? (_totalPointsDistributed / _activeUsers)
                          .toStringAsFixed(0)
                      : "0",
                ),
                const Divider(),
                _buildStatRow("Points Redemption Rate", "42%"),
              ],
            ),
          ),

          const SizedBox(height: 20),

          // Top Users List
          if (_pointsDistribution.isNotEmpty) ...[
            _buildCard(
              "Top Points Earners",
              Column(
                children:
                    _pointsDistribution
                        .take(5)
                        .map(
                          (user) => _buildUserPointsRow(user.user, user.points),
                        )
                        .toList(),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildTimeFilter() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
      children: [
        _buildFilterChip('Week', 'week'),
        _buildFilterChip('Month', 'month'),
        _buildFilterChip('Year', 'year'),
      ],
    );
  }

  Widget _buildFilterChip(String label, String value) {
    return FilterChip(
      label: Text(label),
      selected: _timeFilter == value,
      onSelected: (selected) {
        setState(() {
          _timeFilter = value;
        });
        _loadCollectionData();
      },
      selectedColor: Colors.green,
      checkmarkColor: Colors.white,
    );
  }

  Widget _buildCard(String title, Widget child) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      margin: const EdgeInsets.only(bottom: 16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.grey.withOpacity(0.1),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: const TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: Colors.green,
            ),
          ),
          const SizedBox(height: 12),
          child,
        ],
      ),
    );
  }

  Widget _buildStatRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: const TextStyle(fontSize: 16)),
          Text(
            value,
            style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
          ),
        ],
      ),
    );
  }

  Widget _buildWasteTypeRow(String type, double quantity, double percentage) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Expanded(
            flex: 2,
            child: Text(type, style: const TextStyle(fontSize: 14)),
          ),
          Expanded(
            flex: 2,
            child: Text(
              "${quantity.toStringAsFixed(1)} kg",
              style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w500),
            ),
          ),
          Expanded(
            flex: 1,
            child: Text(
              "${percentage.toStringAsFixed(1)}%",
              style: const TextStyle(fontSize: 14, color: Colors.green),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildUserPointsRow(String user, int points) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Expanded(
            child: Text(
              user,
              style: const TextStyle(fontSize: 14),
              overflow: TextOverflow.ellipsis,
            ),
          ),
          Text(
            "$points pts",
            style: const TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.bold,
              color: Colors.blue,
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[50],
      appBar: AppBar(
        title: const Text("Analytics Dashboard"),
        backgroundColor: Colors.green[700],
        foregroundColor: Colors.white,
        bottom: TabBar(
          controller: _tabController,
          tabs: const [
            Tab(text: "Collection Analytics"),
            Tab(text: "Point Analysis"),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [_buildCollectionAnalytics(), _buildPointAnalytics()],
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: _loadAnalyticsData,
        backgroundColor: Colors.green,
        child: const Icon(Icons.refresh, color: Colors.white),
      ),
    );
  }
}

// Data models for charts
class CollectionData {
  final String date;
  final double quantity;

  CollectionData(this.date, this.quantity);
}

class WasteTypeData {
  final String type;
  final double quantity;
  final double percentage;

  WasteTypeData(this.type, this.quantity, this.percentage);
}

class PointsData {
  final String user;
  final int points;

  PointsData(this.user, this.points);
}

class PointsByWasteType {
  final String type;
  final int points;

  PointsByWasteType(this.type, this.points);
}
