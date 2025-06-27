import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:intl/intl.dart'; // For date formatting

import 'complaint_provider.dart';
import 'models.dart';
import 'utils/responsive.dart'; // Assuming you have this for responsive layout

class ReportsPage extends StatefulWidget {
  const ReportsPage({super.key});

  @override
  State<ReportsPage> createState() => _ReportsPageState();
}

class _ReportsPageState extends State<ReportsPage> {
  @override
  void initState() {
    super.initState();
  }

  // --- Data Processing Methods (Now take complaints list as argument) ---

  Map<String, int> _getComplaintCountsByStatus(List<CityComplaint> complaints) {
    Map<String, int> counts = {'New': 0, 'In Progress': 0, 'Resolved': 0, 'Closed': 0}; // Initialize with expected statuses
    for (var complaint in complaints) {
      counts.update(complaint.status, (value) => value + 1, ifAbsent: () => 1);
    }
    return counts;
  }

   Map<String, int> _getComplaintCountsByPriority(List<CityComplaint> complaints) {
    Map<String, int> counts = {'Critical': 0, 'High': 0, 'Medium': 0, 'Low': 0};
    for (var complaint in complaints) {
      counts.update(complaint.priority, (value) => value + 1, ifAbsent: () => 1);
    }
    // Ensure order for chart
    return {
      'Critical': counts['Critical']!,
      'High': counts['High']!,
      'Medium': counts['Medium']!,
      'Low': counts['Low']!,
    };
  }

  Map<String, int> _getComplaintCountsByDirectorate(List<CityComplaint> complaints) {
    Map<String, int> counts = {};
    for (var complaint in complaints) {
       counts.update(complaint.directorate ?? 'Unknown', (value) => value + 1, ifAbsent: () => 1);
    }
    // Sort by count descending for display
     var sortedEntries = counts.entries.toList()..sort((a, b) => b.value.compareTo(a.value));
     return Map.fromEntries(sortedEntries);
  }

  Map<String, int> _getComplaintCountsByIssueType(List<CityComplaint> complaints) {
     Map<String, int> counts = {};
     for (var complaint in complaints) {
       counts.update(complaint.issueType, (value) => value + 1, ifAbsent: () => 1);
     }
      // Sort by count descending
     var sortedEntries = counts.entries.toList()..sort((a, b) => b.value.compareTo(a.value));
     return Map.fromEntries(sortedEntries);
  }

  Map<DateTime, int> _getComplaintsSubmittedOverTime(List<CityComplaint> complaints, {int days = 30}) {
     Map<DateTime, int> counts = {};
     DateTime now = DateTime.now();
     DateTime startDate = DateTime(now.year, now.month, now.day).subtract(Duration(days: days - 1)); // Start of the period (day only)

     for (var complaint in complaints) {
         if (complaint.dateSubmitted != null && !complaint.dateSubmitted!.isBefore(startDate)) {
             DateTime day = DateTime(complaint.dateSubmitted!.year, complaint.dateSubmitted!.month, complaint.dateSubmitted!.day);
             counts.update(day, (value) => value + 1, ifAbsent: () => 1);
         }
     }

      // Ensure all days in the range are present, even if count is 0
      Map<DateTime, int> completeCounts = {};
      for (int i = 0; i < days; i++) {
          DateTime currentDay = startDate.add(Duration(days: i));
          completeCounts[currentDay] = counts[currentDay] ?? 0;
      }

      return completeCounts; // Already sorted by date due to iteration
  }


  // --- UI Building Methods (Take complaints list as argument) ---

  Widget _buildKPIs(List<CityComplaint> complaints) {
    int openComplaints = complaints.where((c) => c.status != 'Resolved' && c.status != 'Closed').length;
    int resolvedToday = complaints.where((c) {
        DateTime now = DateTime.now();
        DateTime today = DateTime(now.year, now.month, now.day);
        return c.status == 'Resolved' && c.closedTime != null 
               && c.closedTime!.isAfter(today) && c.closedTime!.isBefore(today.add(const Duration(days: 1)));
    }).length;
    // Warning: The closedTime field might need proper DateTime parsing or this 'resolvedToday' KPI will be inaccurate.


    return Wrap( // Use Wrap for responsive layout of KPIs
      spacing: 16.0, // Horizontal space between cards
      runSpacing: 16.0, // Vertical space between rows
      alignment: WrapAlignment.spaceEvenly,
      children: [
        _buildKPICard('Open Complaints', openComplaints.toString()),
        _buildKPICard('Total Complaints', complaints.length.toString()),
        // _buildKPICard('Resolved Today', resolvedToday.toString()), // Commented out due to closedTime uncertainty
      ],
    );
  }

  Widget _buildKPICard(String title, String value) {
    final bool isTablet = Responsive.isTablet(context);
    final double cardWidth = isTablet ? 180 : (MediaQuery.of(context).size.width / 2) - 24; // Roughly half screen width on mobile

    return SizedBox(
      width: cardWidth,
      child: Card(
         elevation: 2.0,
         shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
         child: Padding(
           padding: const EdgeInsets.all(16.0),
           child: Column(
             mainAxisAlignment: MainAxisAlignment.center,
             children: [
               Text(
                 value,
                 style: TextStyle(
                    fontSize: isTablet ? 32 : 28,
                    fontWeight: FontWeight.bold,
                    color: Theme.of(context).primaryColor
                 ),
               ),
               const SizedBox(height: 8),
               Text(
                 title,
                 textAlign: TextAlign.center,
                 style: TextStyle(fontSize: isTablet ? 16 : 14, color: Colors.grey[700]),
               ),
             ],
           ),
         ),
      ),
    );
  }


  Widget _buildStatusChart(List<CityComplaint> complaints) {
    final statusCounts = _getComplaintCountsByStatus(complaints);
    final List<PieChartSectionData> sections = [];
    final List<Color> colors = [Colors.orange, Colors.blue, Colors.green, Colors.grey]; // New, In Progress, Resolved, Closed
    int i = 0;

    statusCounts.forEach((status, count) {
        if (count > 0) { // Only show sections with data
             sections.add(PieChartSectionData(
                color: colors[i % colors.length],
                value: count.toDouble(),
                title: '$count', // Show count on slice
                radius: 60,
                titleStyle: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: Colors.white),
                // Use titlePositionPercentageOffset to position title inside/outside
             ));
        }
        i++;
    });

    return _buildChartCard(
      title: 'Complaints by Status',
      chart: sections.isNotEmpty
          ? PieChart(
              PieChartData(
                sections: sections,
                centerSpaceRadius: 40,
                sectionsSpace: 2,
                // pieTouchData: PieTouchData(touchCallback: (event, response) { ... }), // Optional interaction
              ),
            )
          : const Center(child: Text('No data')),
      legend: _buildLegend(statusCounts, colors),
    );
  }

  Widget _buildPriorityChart(List<CityComplaint> complaints) {
     final priorityCounts = _getComplaintCountsByPriority(complaints);
     final List<BarChartGroupData> barGroups = [];
     final List<Color> colors = [Colors.red, Colors.orange, Colors.amber, Colors.blue]; // Critical, High, Medium, Low
     int i = 0;
     double maxY = 0;

     priorityCounts.forEach((priority, count) {
         if(count.toDouble() > maxY) maxY = count.toDouble();
         barGroups.add(
            BarChartGroupData(
               x: i,
               barRods: [
                  BarChartRodData(
                     toY: count.toDouble(),
                     color: colors[i % colors.length],
                     width: 16,
                     borderRadius: BorderRadius.circular(4)
                  )
               ]
            )
         );
         i++;
     });

     return _buildChartCard(
       title: 'Complaints by Priority',
       chart: barGroups.isNotEmpty
           ? BarChart(
               BarChartData(
                 barGroups: barGroups,
                 maxY: maxY * 1.2, // Add some padding to max Y
                 titlesData: FlTitlesData(
                    show: true,
                    bottomTitles: AxisTitles(
                       sideTitles: SideTitles(
                          showTitles: true,
                          getTitlesWidget: (double value, TitleMeta meta) {
                            final titles = priorityCounts.keys.toList();
                            final index = value.toInt();
                            if (index >= 0 && index < titles.length) {
                               return SideTitleWidget(axisSide: meta.axisSide, space: 4.0, child: Text(titles[index], style: const TextStyle(fontSize: 10)));
                            }
                            return Container();
                          },
                          reservedSize: 30,
                       ),
                    ),
                   leftTitles: AxisTitles(sideTitles: SideTitles(showTitles: true, reservedSize: 30)),
                   topTitles: AxisTitles(sideTitles: SideTitles(showTitles: false)),
                   rightTitles: AxisTitles(sideTitles: SideTitles(showTitles: false)),
                 ),
                 borderData: FlBorderData(show: false),
                 gridData: FlGridData(show: true, drawVerticalLine: false, horizontalInterval: maxY > 10 ? (maxY/5).roundToDouble() : 1), // Adjust grid lines
                 barTouchData: BarTouchData( // Optional: Tooltips
                      touchTooltipData: BarTouchTooltipData(
                          getTooltipColor: (group) => Colors.blueGrey,
                          getTooltipItem: (group, groupIndex, rod, rodIndex) {
                            String priority = priorityCounts.keys.elementAt(group.x);
                            return BarTooltipItem(
                              '$priority\n',
                              const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 14),
                              children: <TextSpan>[
                                TextSpan(
                                  text: (rod.toY).toInt().toString(),
                                  style: const TextStyle(color: Colors.yellow, fontSize: 12, fontWeight: FontWeight.w500),
                                ),
                              ],
                            );
                          },
                        ),
                   ),
               ),
             )
           : const Center(child: Text('No data')),
     );
  }

   Widget _buildDirectorateChart(List<CityComplaint> complaints) {
      final directorateCounts = _getComplaintCountsByDirectorate(complaints);
      final List<BarChartGroupData> barGroups = [];
      int i = 0;
      double maxY = 0;

      directorateCounts.forEach((directorate, count) {
         if(count.toDouble() > maxY) maxY = count.toDouble();
          barGroups.add(
             BarChartGroupData(
                x: i,
                barRods: [
                   BarChartRodData(toY: count.toDouble(), color: Colors.teal[300], width: 16, borderRadius: BorderRadius.circular(4))
                ]
             )
          );
          i++;
      });

      return _buildChartCard(
        title: 'Complaints by Directorate',
        chart: barGroups.isNotEmpty
            ? BarChart(
                BarChartData(
                  barGroups: barGroups,
                  maxY: maxY * 1.2,
                  titlesData: FlTitlesData(
                     show: true,
                     bottomTitles: AxisTitles(
                        sideTitles: SideTitles(
                           showTitles: true,
                           getTitlesWidget: (double value, TitleMeta meta) {
                             final titles = directorateCounts.keys.toList();
                             final index = value.toInt();
                             if (index >= 0 && index < titles.length) {
                                String shortTitle = titles[index].length > 10 ? '${titles[index].substring(0, 8)}...' : titles[index]; // Shorten long names
                                return SideTitleWidget(axisSide: meta.axisSide, space: 4.0, child: Text(shortTitle, style: const TextStyle(fontSize: 10)));
                             }
                             return Container();
                           },
                           reservedSize: 30,
                           interval: 1, // Show every label
                        ),
                     ),
                    leftTitles: AxisTitles(sideTitles: SideTitles(showTitles: true, reservedSize: 30)),
                    topTitles: AxisTitles(sideTitles: SideTitles(showTitles: false)),
                    rightTitles: AxisTitles(sideTitles: SideTitles(showTitles: false)),
                  ),
                  borderData: FlBorderData(show: false),
                  gridData: FlGridData(show: true, drawVerticalLine: false, horizontalInterval: maxY > 10 ? (maxY/5).roundToDouble() : 1),
                  barTouchData: BarTouchData(
                     touchTooltipData: BarTouchTooltipData(
                         getTooltipColor: (group) => Colors.blueGrey,
                         getTooltipItem: (group, groupIndex, rod, rodIndex) {
                           String directorate = directorateCounts.keys.elementAt(group.x);
                           return BarTooltipItem(
                             '$directorate\n',
                             const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 14),
                             children: <TextSpan>[ TextSpan(text: (rod.toY).toInt().toString(), style: const TextStyle(color: Colors.yellow, fontSize: 12, fontWeight: FontWeight.w500)) ],
                           );
                         },
                       ),
                  ),
                ),
              )
            : const Center(child: Text('No data')),
      );
   }

  Widget _buildChartCard({required String title, required Widget chart, Widget? legend}) {
    return Card(
      elevation: 2.0,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(title, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
            const SizedBox(height: 20),
            SizedBox(
               height: 200, // Fixed height for chart area
               child: chart
            ),
             if (legend != null) ...[
               const SizedBox(height: 16),
               legend,
             ]
          ],
        ),
      ),
    );
  }

   Widget _buildLegend(Map<String, int> data, List<Color> colors) {
     int i = 0;
     List<Widget> legendItems = [];
     data.forEach((key, value) {
       if (value > 0) {
         legendItems.add(
           Padding(
             padding: const EdgeInsets.only(bottom: 4.0),
             child: Row(
               mainAxisSize: MainAxisSize.min,
               children: [
                 Container(width: 12, height: 12, color: colors[i % colors.length]),
                 const SizedBox(width: 8),
                 Text('$key ($value)'),
               ],
             ),
           ),
         );
       }
       i++;
     });

     return Wrap( // Wrap legend items if they don't fit horizontally
        spacing: 16.0,
        runSpacing: 8.0,
        children: legendItems,
     );
   }

  // --- Main Build Method ---
  @override
  Widget build(BuildContext context) {
    // Get the provider instance and watch for changes
    final provider = context.watch<ComplaintProvider>();
    final complaints = provider.complaints;
    final isLoading = provider.isLoading;
    final errorMessage = provider.errorMessage;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Reports Dashboard'),
        actions: [
           IconButton(
             icon: const Icon(Icons.refresh),
             onPressed: isLoading ? null : () => provider.refreshComplaints(), // Call provider's refresh
             tooltip: 'Refresh Data',
           ),
        ],
      ),
      body: isLoading
          ? const Center(child: CircularProgressIndicator())
          : errorMessage != null
              ? Center(child: Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Text(errorMessage, style: const TextStyle(color: Colors.red), textAlign: TextAlign.center,)
                ))
              : complaints.isEmpty
                  ? Center(
                      child: Column( // Add refresh button when no data
                           mainAxisSize: MainAxisSize.min,
                           children: [
                              const Text('No complaint data available.'),
                              const SizedBox(height: 16),
                              ElevatedButton.icon(
                                 icon: const Icon(Icons.refresh),
                                 label: const Text('Tap to Refresh'),
                                 onPressed: isLoading ? null : () => provider.refreshComplaints(),
                               )
                           ],
                       ))
                  : RefreshIndicator( // Add pull-to-refresh
                      onRefresh: () => provider.refreshComplaints(), // Call provider's refresh
                      child: ListView(
                        padding: const EdgeInsets.all(16.0),
                        children: [
                           _buildKPIs(complaints), // Pass complaints list
                           const SizedBox(height: 24),
                           _buildStatusChart(complaints), // Pass complaints list
                           const SizedBox(height: 24),
                           _buildPriorityChart(complaints), // Pass complaints list
                            const SizedBox(height: 24),
                           _buildDirectorateChart(complaints), // Pass complaints list
                           // Add more charts here (e.g., Issue Type, Complaints over time)
                           // Consider adding filters (e.g., DateRangePicker) in the AppBar or as a separate section
                        ],
                      ),
                    ),
    );
  }
} 