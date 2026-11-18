import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import '../../../core/models/labslot_models.dart';
import '../../../core/providers/labslot_controller.dart';
import '../../../core/theme/app_theme.dart';

class AdminAccreditationReportsTab extends ConsumerStatefulWidget {
  const AdminAccreditationReportsTab({super.key});

  @override
  ConsumerState<AdminAccreditationReportsTab> createState() =>
      _AdminAccreditationReportsTabState();
}

class _AdminAccreditationReportsTabState
    extends ConsumerState<AdminAccreditationReportsTab> {
  String _selectedRoomFilter = 'ALL';
  final DateTime _startDate = DateTime.now().subtract(const Duration(days: 30));
  final DateTime _endDate = DateTime.now();

  Future<void> _exportPdfReport(AccreditationReport report) async {
    final dateFmt = DateFormat('MMM d, yyyy');
    final doc = pw.Document();

    doc.addPage(
      pw.Page(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.all(32),
        build: (pw.Context context) {
          return pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              pw.Text(
                'LabSlot — CHED / PACUCOA Laboratory Utilization & Audit Report',
                style: pw.TextStyle(
                  fontSize: 16,
                  fontWeight: pw.FontWeight.bold,
                ),
              ),
              pw.SizedBox(height: 6),
              pw.Text(
                'Scope: ${report.scopeTitle}',
                style: const pw.TextStyle(fontSize: 12),
              ),
              pw.Text(
                'Audit Period: ${dateFmt.format(report.startDate)} to ${dateFmt.format(report.endDate)}',
                style: const pw.TextStyle(fontSize: 11),
              ),
              pw.Divider(height: 24),
              pw.Text(
                '1. Core Institutional Utilization Metrics',
                style: pw.TextStyle(
                  fontSize: 13,
                  fontWeight: pw.FontWeight.bold,
                ),
              ),
              pw.SizedBox(height: 8),
              pw.TableHelper.fromTextArray(
                headers: const ['Compliance Metric', 'Recorded Value'],
                data: [
                  [
                    'Completed Student Workstation Sessions',
                    '${report.totalSessionsCompleted}',
                  ],
                  [
                    'Total Student Seated Hours',
                    '${report.totalSeatedHours} hrs',
                  ],
                  [
                    'Laboratory Utilization Rate',
                    '${report.utilizationRatePercent.toStringAsFixed(1)}%',
                  ],
                  [
                    'Expired Ghost-Slots Auto-Released (10-Min Rule)',
                    '${report.totalNoShowsAutoReleased}',
                  ],
                  [
                    'Defective PC Tickets (Resolved / Total)',
                    '${report.totalDefectsResolved} / ${report.totalDefectsReported}',
                  ],
                  [
                    'Mean Time to Repair (MTTR)',
                    '${report.averageRepairTurnaroundHours.toStringAsFixed(1)} hrs',
                  ],
                ],
              ),
              pw.SizedBox(height: 20),
              pw.Text(
                '2. Coursework Software Demand Breakdown',
                style: pw.TextStyle(
                  fontSize: 13,
                  fontWeight: pw.FontWeight.bold,
                ),
              ),
              pw.SizedBox(height: 8),
              pw.TableHelper.fromTextArray(
                headers: const ['Coursework Software / IDE', 'Sessions Logged'],
                data: [
                  for (final entry in report.softwareDemandCounts.entries)
                    [entry.key, '${entry.value}'],
                ],
              ),
            ],
          );
        },
      ),
    );

    await Printing.layoutPdf(
      onLayout: (PdfPageFormat format) async => doc.save(),
      name: 'LabSlot_Accreditation_Report.pdf',
    );
  }

  void _showCsvExportDialog(
    BuildContext context,
    AccreditationReport report,
  ) {
    final rows = <List<dynamic>>[
      ['Metric / Category', 'Item', 'Value'],
      ['Summary', 'Scope', report.scopeTitle],
      ['Summary', 'Completed Sessions', report.totalSessionsCompleted],
      ['Summary', 'Total Seated Hours', report.totalSeatedHours],
      [
        'Summary',
        'Utilization Rate (%)',
        report.utilizationRatePercent.toStringAsFixed(2),
      ],
      [
        'Summary',
        'No-Show Auto-Released',
        report.totalNoShowsAutoReleased,
      ],
      [
        'Summary',
        'Average Repair Turnaround (Hrs)',
        report.averageRepairTurnaroundHours.toStringAsFixed(2),
      ],
      for (final e in report.softwareDemandCounts.entries)
        ['Coursework Software Demand', e.key, e.value],
      for (final r in report.roomSessionBreakdown.entries)
        ['Room Seated Hours', r.key, r.value],
    ];

    final csvString = rows
        .map(
          (row) => row
              .map((cell) => '"${cell.toString().replaceAll('"', '""')}"')
              .join(','),
        )
        .join('\n');

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('CHED / PACUCOA Compliance CSV Export'),
        content: SingleChildScrollView(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 540),
            child: SelectableText(
              csvString,
              style: const TextStyle(fontFamily: 'monospace', fontSize: 12),
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text('Close'),
          ),
          ElevatedButton.icon(
            onPressed: () {
              Clipboard.setData(ClipboardData(text: csvString));
              Navigator.of(ctx).pop();
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text('CSV audit data copied to clipboard!'),
                  backgroundColor: AppTheme.availableGreen,
                ),
              );
            },
            icon: const Icon(Icons.copy_rounded, size: 18),
            label: const Text('Copy CSV to Clipboard'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(labSlotProvider);
    final controller = ref.read(labSlotProvider.notifier);
    final dateFmt = DateFormat('MMM d, yyyy');

    final report = controller.generateAccreditationReport(
      roomId: _selectedRoomFilter,
      startDate: _startDate,
      endDate: _endDate,
    );
    final isPhone = MediaQuery.sizeOf(context).width < 600;

    return SingleChildScrollView(
      padding: EdgeInsets.all(isPhone ? 14 : 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header & Filter Controls
          Card(
            child: Padding(
              padding: const EdgeInsets.all(18),
              child: Wrap(
                spacing: 16,
                runSpacing: 12,
                alignment: WrapAlignment.spaceBetween,
                crossAxisAlignment: WrapCrossAlignment.center,
                children: [
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Generate Accreditation & Utilization Reports (CHED / PACUCOA / PAASCU)',
                        style: TextStyle(
                          fontSize: 16.5,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      Text(
                        'Audit Period: ${dateFmt.format(_startDate)} – ${dateFmt.format(_endDate)}',
                        style: const TextStyle(
                          fontSize: 12.5,
                          color: Color(0xFF64748B),
                        ),
                      ),
                    ],
                  ),
                  Wrap(
                    spacing: 10,
                    runSpacing: 10,
                    crossAxisAlignment: WrapCrossAlignment.center,
                    children: [
                      ConstrainedBox(
                        constraints: BoxConstraints(
                          maxWidth: isPhone ? double.infinity : 240,
                        ),
                        child: DropdownButtonFormField<String>(
                          initialValue: _selectedRoomFilter,
                          isExpanded: true,
                          decoration: const InputDecoration(
                            labelText: 'Laboratory Scope',
                          ),
                          items: [
                            const DropdownMenuItem(
                              value: 'ALL',
                              child: Text('All Campus Laboratories'),
                            ),
                            for (final r in state.rooms)
                              DropdownMenuItem(
                                value: r.id,
                                child: Text(r.code),
                              ),
                          ],
                          onChanged: (v) {
                            if (v != null) {
                              setState(() => _selectedRoomFilter = v);
                            }
                          },
                        ),
                      ),
                      ElevatedButton.icon(
                        key: const Key('export-pdf-report-button'),
                        onPressed: () => _exportPdfReport(report),
                        icon: const Icon(Icons.picture_as_pdf_rounded),
                        label: const Text('Export PDF Report'),
                      ),
                      OutlinedButton.icon(
                        key: const Key('export-csv-report-button'),
                        onPressed: () => _showCsvExportDialog(context, report),
                        icon: const Icon(Icons.table_chart_outlined),
                        label: const Text('Export CSV'),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),

          const SizedBox(height: 18),

          // KPI Metric Cards
          Wrap(
            spacing: 14,
            runSpacing: 14,
            children: [
              _kpiCard(
                isPhone: isPhone,
                title: 'Completed Sessions',
                value: '${report.totalSessionsCompleted}',
                subtitle: '${report.totalSeatedHours} Total Seated Hours',
                icon: Icons.check_circle_outline,
                color: AppTheme.availableGreen,
              ),
              _kpiCard(
                isPhone: isPhone,
                title: 'Lab Utilization Rate',
                value:
                    '${report.utilizationRatePercent.toStringAsFixed(1)}%',
                subtitle: 'Accreditation Compliance Benchmark',
                icon: Icons.insights_rounded,
                color: AppTheme.primaryBlue,
              ),
              _kpiCard(
                isPhone: isPhone,
                title: 'Mean Time to Repair (MTTR)',
                value:
                    '${report.averageRepairTurnaroundHours.toStringAsFixed(1)} hrs',
                subtitle:
                    '${report.totalDefectsResolved}/${report.totalDefectsReported} Tickets Resolved',
                icon: Icons.build_circle_outlined,
                color: const Color(0xFF7C3AED),
              ),
              _kpiCard(
                isPhone: isPhone,
                title: 'Ghost-Slots Auto-Released',
                value: '${report.totalNoShowsAutoReleased}',
                subtitle: '10-Min Grace Period Enforcement',
                icon: Icons.timer_off_outlined,
                color: AppTheme.warningAmber,
              ),
            ],
          ),

          const SizedBox(height: 20),

          // Software Demand & Laboratory Breakdown
          Wrap(
            spacing: 18,
            runSpacing: 18,
            children: [
              ConstrainedBox(
                constraints: BoxConstraints(
                  maxWidth: isPhone ? double.infinity : 460,
                ),
                child: Card(
                  child: Padding(
                    padding: EdgeInsets.all(isPhone ? 14 : 18),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Coursework Software Demand Breakdown',
                          style: TextStyle(
                            fontWeight: FontWeight.w800,
                            fontSize: 15,
                          ),
                        ),
                        const SizedBox(height: 12),
                        for (final entry
                            in report.softwareDemandCounts.entries)
                          Padding(
                            padding: const EdgeInsets.only(bottom: 10),
                            child: Row(
                              children: [
                                Expanded(
                                  flex: 3,
                                  child: Text(
                                    entry.key,
                                    overflow: TextOverflow.ellipsis,
                                    style: const TextStyle(
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 8),
                                Expanded(
                                  flex: 4,
                                  child: LinearProgressIndicator(
                                    value: (entry.value /
                                            (report.totalSessionsCompleted == 0
                                                ? 1
                                                : report.totalSessionsCompleted))
                                        .clamp(0.1, 1.0),
                                    minHeight: 8,
                                    borderRadius: BorderRadius.circular(4),
                                  ),
                                ),
                                const SizedBox(width: 10),
                                Text(
                                  '${entry.value} sessions',
                                  style: const TextStyle(
                                    fontSize: 12,
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                              ],
                            ),
                          ),
                      ],
                    ),
                  ),
                ),
              ),
              ConstrainedBox(
                constraints: BoxConstraints(
                  maxWidth: isPhone ? double.infinity : 460,
                ),
                child: Card(
                  child: Padding(
                    padding: EdgeInsets.all(isPhone ? 14 : 18),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Seated Hours by Laboratory Room',
                          style: TextStyle(
                            fontWeight: FontWeight.w800,
                            fontSize: 15,
                          ),
                        ),
                        const SizedBox(height: 12),
                        for (final entry
                            in report.roomSessionBreakdown.entries)
                          Padding(
                            padding: const EdgeInsets.only(bottom: 10),
                            child: Row(
                              mainAxisAlignment:
                                  MainAxisAlignment.spaceBetween,
                              children: [
                                Expanded(
                                  child: Text(
                                    entry.key,
                                    overflow: TextOverflow.ellipsis,
                                    style: const TextStyle(
                                      fontWeight: FontWeight.w700,
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 8),
                                Text(
                                  '${entry.value} seated hrs logged',
                                  style: const TextStyle(
                                    color: Color(0xFF475569),
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ],
                            ),
                          ),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _kpiCard({
    required bool isPhone,
    required String title,
    required String value,
    required String subtitle,
    required IconData icon,
    required Color color,
  }) {
    return ConstrainedBox(
      constraints: BoxConstraints(maxWidth: isPhone ? double.infinity : 225),
      child: Card(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Expanded(
                    child: Text(
                      title,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: Color(0xFF64748B),
                      ),
                    ),
                  ),
                  Icon(icon, color: color, size: 20),
                ],
              ),
              const SizedBox(height: 8),
              Text(
                value,
                style: TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.w800,
                  color: color,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                subtitle,
                style: const TextStyle(fontSize: 11.5, color: Color(0xFF475569)),
              ),
            ],
          ),
        ),
      ),
    );
  }
}