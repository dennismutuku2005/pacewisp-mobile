import 'package:flutter/material.dart';
import '../services/api_service.dart';
import '../theme/colors.dart';
import '../components/badge.dart';

class SystemLogsScreen extends StatefulWidget {
  const SystemLogsScreen({super.key});

  @override
  State<SystemLogsScreen> createState() => _SystemLogsScreenState();
}

class _SystemLogsScreenState extends State<SystemLogsScreen> {
  final ApiService _apiService = ApiService();
  List<dynamic> _logs = [];
  bool _isLoading = true;
  String _search = '';

  @override
  void initState() {
    super.initState();
    _fetchLogs();
  }

  Future<void> _fetchLogs() async {
    setState(() => _isLoading = true);
    final res = await _apiService.getLogs(search: _search);
    if (mounted) {
      setState(() {
        _logs = res?['data'] ?? [];
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        _buildHeader(),
        _buildSearchBox(),
        Expanded(
          child: _isLoading 
            ? const Center(child: CircularProgressIndicator(color: PaceColors.purple))
            : RefreshIndicator(
                onRefresh: _fetchLogs,
                color: PaceColors.purple,
                child: ListView.separated(
                  padding: const EdgeInsets.all(16),
                  itemCount: _logs.length,
                  separatorBuilder: (_, __) => const Divider(color: PaceColors.border, height: 1),
                  itemBuilder: (context, index) => _buildLogItem(_logs[index]),
                ),
              ),
        ),
      ],
    );
  }

  Widget _buildHeader() {
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 20, 16, 8),
      child: const Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'SYSTEM LOGS',
            style: TextStyle(color: PaceColors.purple, fontSize: 20, fontWeight: FontWeight.bold, letterSpacing: -0.5),
          ),
          Text(
            'ACTIVITY TRACKING & AUDITS',
            style: TextStyle(color: PaceColors.adminDim, fontSize: 10, fontWeight: FontWeight.bold, letterSpacing: 1.5),
          ),
        ],
      ),
    );
  }

  Widget _buildSearchBox() {
    return Padding(
      padding: const EdgeInsets.all(16.0),
      child: Container(
        decoration: BoxDecoration(
          color: PaceColors.bgSubtle,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: PaceColors.border),
        ),
        child: TextField(
          onChanged: (val) {
            setState(() => _search = val);
            _fetchLogs();
          },
          style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold),
          decoration: const InputDecoration(
            hintText: 'Search logs...',
            hintStyle: TextStyle(color: PaceColors.adminDim, fontSize: 12),
            prefixIcon: Icon(Icons.search, color: PaceColors.adminDim, size: 20),
            border: InputBorder.none,
            contentPadding: EdgeInsets.symmetric(vertical: 12),
          ),
        ),
      ),
    );
  }

  Widget _buildLogItem(dynamic log) {
    bool isFailed = (log['status'] ?? '').toString().toLowerCase() == 'failed';
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 12.0),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(color: PaceColors.bgSubtle, borderRadius: BorderRadius.circular(8)),
            child: Icon(
              isFailed ? Icons.error_outline : Icons.check_circle_outline,
              color: isFailed ? Colors.redAccent : Colors.green,
              size: 16,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      log['user']?.toUpperCase() ?? 'SYSTEM',
                      style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: PaceColors.purple),
                    ),
                    Text(
                      log['time'] ?? '',
                      style: const TextStyle(fontSize: 9, color: PaceColors.adminDim),
                    ),
                  ],
                ),
                const SizedBox(height: 2),
                Text(
                  log['description'] ?? '',
                  style: const TextStyle(fontSize: 12, color: PaceColors.adminLabel, fontWeight: FontWeight.w500),
                ),
                const SizedBox(height: 4),
                Row(
                  children: [
                    PaceBadge(
                      label: log['action'] ?? 'AUDIT',
                      variant: BadgeVariant.secondary,
                    ),
                    const SizedBox(width: 8),
                    Text(
                      log['ip'] ?? '0.0.0.0',
                      style: const TextStyle(fontSize: 9, color: PaceColors.adminDim, fontFamily: 'monospace'),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
