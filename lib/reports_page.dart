import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:intl/intl.dart';

import 'complaint_provider.dart';
import 'models.dart';
import 'utils/responsive.dart';
import 'complaints/complaint_card.dart';

class ReportsPage extends StatefulWidget {
  const ReportsPage({super.key});

  @override
  State<ReportsPage> createState() => _ReportsPageState();
}

class _ReportsPageState extends State<ReportsPage> {

  Map<String, int> _getComplaintCountsByStatus(List<CityComplaint> complaints) {
    Map<String, int> counts = {'New': 0, 'In Progress': 0, 'Resolved': 0, 'Closed': 0};
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
     var sortedEntries = counts.entries.toList()..sort((a, b) => b.value.compareTo(a.value));
     return Map.fromEntries(sortedEntries);
  }

  Widget _buildKPIs(List<CityComplaint> complaints) {
    int openComplaints = complaints.where((c) => c.status != 'Resolved' && c.status != 'Closed').length;
    
    return Wrap(
      spacing: 16.0,
      runSpacing: 16.0,
      alignment: WrapAlignment.spaceEvenly,
      children: [
        _buildKPICard('Open Complaints', openComplaints.toString()),
        _buildKPICard('Total Complaints', complaints.length.toString()),
      ],
    );
  }

  Widget _buildKPICard(String title, String value) {
    final bool isTablet = Responsive.isTablet(context);
    final double cardWidth = isTablet ? 180 : (MediaQuery.of(context).size.width / 2) - 24;

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
    final List<Color> colors = [Colors.orange, Colors.blue, Colors.green, Colors.grey];
    int i = 0;

    statusCounts.forEach((status, count) {
        if (count > 0) {
             sections.add(PieChartSectionData(
                color: colors[i % colors.length],
                value: count.toDouble(),
                title: '$count',
                radius: 60,
                titleStyle: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: Colors.white),
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
              ),
            )
          : const Center(child: Text('No data')),
      legend: _buildLegend(statusCounts, colors),
    );
  }

  Widget _buildPriorityChart(List<CityComplaint> complaints) {
     final priorityCounts = _getComplaintCountsByPriority(complaints);
     final List<BarChartGroupData> barGroups = [];
     final List<Color> colors = [Colors.red, Colors.orange, Colors.amber, Colors.blue];
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
                 maxY: maxY * 1.2,
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
                 gridData: FlGridData(show: true, drawVerticalLine: false),
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
                height: 200,
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

      return Wrap(
        spacing: 16.0,
        runSpacing: 8.0,
        children: legendItems,
     );
   }

  @override
  Widget build(BuildContext context) {
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
              onPressed: isLoading ? null : () => provider.refreshComplaints(),
             tooltip: 'Refresh Data',
           ),
        ],
      ),
       body: isLoading && complaints.isEmpty
          ? const Center(child: CircularProgressIndicator())
          : errorMessage != null
              ? Center(child: Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Text(errorMessage, style: const TextStyle(color: Colors.red), textAlign: TextAlign.center,)
                ))
              : complaints.isEmpty
                  ? Center(
                       child: Column(
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
                   : RefreshIndicator(
                       onRefresh: () => provider.refreshComplaints(),
                      child: ListView(
                        padding: const EdgeInsets.all(16.0),
                        children: [
                            _buildKPIs(complaints),
                           const SizedBox(height: 24),
                            _buildStatusChart(complaints),
                            const SizedBox(height: 24),
                            _buildPriorityChart(complaints),
                        ],
                      ),
                    ),
    );
  }
} 