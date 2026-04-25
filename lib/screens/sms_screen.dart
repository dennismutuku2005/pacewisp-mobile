import 'package:flutter/material.dart';
import 'package:lucide_icons/lucide_icons.dart';
import 'package:provider/provider.dart';
import '../providers/settings_provider.dart';
import '../services/api_service.dart';
import '../theme/colors.dart';
import '../components/Badge.dart'; // Assuming a Badge component exists or I'll use a container
import 'package:intl/intl.dart';

class SmsScreen extends StatefulWidget {
  const SmsScreen({super.key});

  @override
  State<SmsScreen> createState() => _SmsScreenState();
}

class _SmsScreenState extends State<SmsScreen> {
  final ApiService _api = ApiService();
  final TextEditingController _messageController = TextEditingController();
  
  bool _isLoading = false;
  bool _isFetchingCustomers = false;
  bool _isSending = false;
  bool _showConfig = false;

  Map<String, dynamic> _config = {'apikey': '', 'partner_id': '', 'shortcode': ''};
  List<String> _targetPhones = [];
  String _filter = 'all';
  DateTime? _startDate;
  DateTime? _endDate;

  @override
  void initState() {
    super.initState();
    _fetchInitialData();
  }

  Future<void> _fetchInitialData() async {
    setState(() => _isLoading = true);
    try {
      final res = await _api.getSmsConfig();
      if (res != null && res['status'] == 'success') {
        setState(() {
          _config = Map<String, dynamic>.from(res['data'] ?? {});
        });
      }
    } catch (e) {
      _showError('Failed to load SMS config');
    } finally {
      setState(() => _isLoading = false);
    }
  }

  Future<void> _fetchTargetCustomers() async {
    setState(() => _isFetchingCustomers = true);
    try {
      final res = await _api.getSmsTargetCustomers(
        filter: _filter,
        start: _startDate != null ? DateFormat('yyyy-MM-dd').format(_startDate!) : null,
        end: _endDate != null ? DateFormat('yyyy-MM-dd').format(_endDate!) : null,
      );

      if (res != null && res['status'] == 'success') {
        final List phones = res['data'] ?? [];
        setState(() {
          _targetPhones = phones.map((e) => e.toString()).toList();
        });
        _showSuccess('Identified ${_targetPhones.length} recipients');
      }
    } catch (e) {
      _showError('Failed to fetch customers');
    } finally {
      setState(() => _isFetchingCustomers = false);
    }
  }

  Future<void> _sendBroadcast() async {
    if (_targetPhones.isEmpty) {
      _showError('Please sync targeted numbers first');
      return;
    }
    if (_messageController.text.trim().isEmpty) {
      _showError('Please enter a message');
      return;
    }

    setState(() => _isSending = true);
    try {
      final res = await _api.sendBulkSms(_targetPhones, _messageController.text.trim());
      if (res != null && res['status'] == 'success') {
        _showSuccess('Broadcast initiated successfully');
        _messageController.clear();
      } else {
        _showError(res?['message'] ?? 'Failed to send SMS');
      }
    } catch (e) {
      _showError('System error during broadcast');
    } finally {
      setState(() => _isSending = false);
    }
  }

  Future<void> _saveConfig() async {
    try {
      final res = await _api.saveSmsConfig(_config);
      if (res != null && res['status'] == 'success') {
        _showSuccess('Gateway config saved');
        setState(() => _showConfig = false);
      }
    } catch (e) {
      _showError('Failed to save config');
    }
  }

  void _showError(String msg) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg), backgroundColor: Colors.redAccent));
  }

  void _showSuccess(String msg) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg), backgroundColor: Colors.emerald));
  }

  @override
  Widget build(BuildContext context) {
    final settings = Provider.of<SettingsProvider>(context);
    final isDark = settings.isDarkMode;

    return Scaffold(
      backgroundColor: PaceColors.getBackground(isDark),
      body: _isLoading 
        ? const Center(child: CircularProgressIndicator())
        : RefreshIndicator(
            onRefresh: _fetchInitialData,
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(20),
              physics: const AlwaysScrollableScrollPhysics(),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildHeader(isDark),
                  const SizedBox(height: 24),
                  _buildStatsGrid(isDark),
                  const SizedBox(height: 24),
                  if (settings.hasPolicy('manage_sms_config')) _buildConfigToggle(isDark),
                  if (_showConfig) ...[
                    const SizedBox(height: 16),
                    _buildConfigForm(isDark),
                  ],
                  const SizedBox(height: 24),
                  _buildComposer(isDark, settings),
                  const SizedBox(height: 100), // Space for bottom padding
                ],
              ),
            ),
          ),
    );
  }

  Widget _buildHeader(bool isDark) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.slate[900],
                borderRadius: BorderRadius.circular(16),
              ),
              child: const Icon(LucideIcons.send, color: Colors.white, size: 20),
            ),
            const SizedBox(width: 16),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('SMS Command', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: PaceColors.getPrimaryText(isDark))),
                Text('TRANSMISSION CENTER', style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: PaceColors.getDimText(isDark), letterSpacing: 1.2)),
              ],
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildStatsGrid(bool isDark) {
    return Row(
      children: [
        Expanded(child: _buildStatCard('Audience', _targetPhones.length.toString(), LucideIcons.users, Colors.indigo, isDark)),
        const SizedBox(width: 12),
        Expanded(child: _buildStatCard('Segments', ( (_messageController.text.length / 160).ceil() ).toString(), LucideIcons.zap, Colors.amber, isDark)),
      ],
    );
  }

  Widget _buildStatCard(String label, String value, IconData icon, Color color, bool isDark) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: PaceColors.getCard(isDark),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: PaceColors.getBorder(isDark).withOpacity(0.5)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: color, size: 20),
          const SizedBox(height: 12),
          Text(value, style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: PaceColors.getPrimaryText(isDark))),
          Text(label.toUpperCase(), style: TextStyle(fontSize: 9, fontWeight: FontWeight.bold, color: PaceColors.getDimText(isDark), letterSpacing: 1)),
        ],
      ),
    );
  }

  Widget _buildConfigToggle(bool isDark) {
    return InkWell(
      onTap: () => setState(() => _showConfig = !_showConfig),
      borderRadius: BorderRadius.circular(20),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
        decoration: BoxDecoration(
          color: PaceColors.getCard(isDark),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: PaceColors.getBorder(isDark).withOpacity(0.5)),
        ),
        child: Row(
          children: [
            Icon(LucideIcons.settings, size: 18, color: PaceColors.getSecondaryText(isDark)),
            const SizedBox(width: 12),
            Text('Gateway Configuration', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: PaceColors.getPrimaryText(isDark))),
            const Spacer(),
            Icon(_showConfig ? LucideIcons.chevronUp : LucideIcons.chevronDown, size: 16, color: PaceColors.getDimText(isDark)),
          ],
        ),
      ),
    );
  }

  Widget _buildConfigForm(bool isDark) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.slate[900],
        borderRadius: BorderRadius.circular(24),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildConfigInput('API KEY', _config['apikey'], (v) => _config['apikey'] = v, true),
          const SizedBox(height: 16),
          _buildConfigInput('PARTNER ID', _config['partner_id'], (v) => _config['partner_id'] = v, false),
          const SizedBox(height: 16),
          _buildConfigInput('SENDER ID', _config['shortcode'], (v) => _config['shortcode'] = v, false),
          const SizedBox(height: 20),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: _saveConfig,
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.indigo,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 16),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                elevation: 0,
              ),
              child: const Text('Update Credentials', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, letterSpacing: 0.5)),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildConfigInput(String label, String value, Function(String) onChanged, bool obscure) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: const TextStyle(fontSize: 9, fontWeight: FontWeight.bold, color: Colors.white54, letterSpacing: 1)),
        const SizedBox(height: 8),
        TextField(
          onChanged: onChanged,
          obscureText: obscure,
          style: const TextStyle(color: Colors.white, fontSize: 13),
          decoration: InputDecoration(
            isDense: true,
            hintText: 'Required',
            hintStyle: const TextStyle(color: Colors.white24),
            contentPadding: const EdgeInsets.symmetric(vertical: 12),
            enabledBorder: const UnderlineInputBorder(borderSide: BorderSide(color: Colors.white12)),
            focusedBorder: const UnderlineInputBorder(borderSide: BorderSide(color: Colors.indigo)),
          ),
        ),
      ],
    );
  }

  Widget _buildComposer(bool isDark, SettingsProvider settings) {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: PaceColors.getCard(isDark),
        borderRadius: BorderRadius.circular(32),
        border: Border.all(color: PaceColors.getBorder(isDark).withOpacity(0.5)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('TARGET AUDIENCE', style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: PaceColors.getDimText(isDark), letterSpacing: 1.5)),
          const SizedBox(height: 16),
          _buildFilterChips(isDark),
          if (_filter == 'range') ...[
            const SizedBox(height: 16),
            _buildDatePicker(isDark),
          ],
          const SizedBox(height: 16),
          SizedBox(
            width: double.infinity,
            child: OutlinedButton.icon(
              onPressed: _isFetchingCustomers ? null : _fetchTargetCustomers,
              icon: _isFetchingCustomers ? const SizedBox(width: 12, height: 12, child: CircularProgressIndicator(strokeWidth: 2)) : const Icon(LucideIcons.refreshCw, size: 14),
              label: const Text('SYNC TARGETS', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, letterSpacing: 1)),
              style: OutlinedButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: 14),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
              ),
            ),
          ),
          const SizedBox(height: 32),
          Row(
            mainAxisAlignment: MainAxisAlignment.between,
            children: [
              Text('MESSAGE BODY', style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: PaceColors.getDimText(isDark), letterSpacing: 1.5)),
              Text('${_messageController.text.length}/160', style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: PaceColors.getDimText(isDark))),
            ],
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _messageController,
            maxLines: 6,
            onChanged: (v) => setState(() {}),
            style: TextStyle(color: PaceColors.getPrimaryText(isDark), fontSize: 14),
            decoration: InputDecoration(
              hintText: 'Type broadcast content...',
              hintStyle: TextStyle(color: PaceColors.getDimText(isDark).withOpacity(0.5)),
              filled: true,
              fillColor: PaceColors.getBackground(isDark).withOpacity(0.5),
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(20), borderSide: BorderSide.none),
            ),
          ),
          const SizedBox(height: 32),
          if (settings.hasPolicy('send_bulk_sms'))
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: _isSending || _targetPhones.isEmpty ? null : _sendBroadcast,
                style: ElevatedButton.styleFrom(
                  backgroundColor: PaceColors.purple,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 18),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                  elevation: 8,
                  shadowColor: PaceColors.purple.withOpacity(0.4),
                ),
                child: _isSending 
                  ? const CircularProgressIndicator(color: Colors.white)
                  : Text('Send to ${_targetPhones.length} Customers'.toUpperCase(), style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, letterSpacing: 1.5)),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildFilterChips(bool isDark) {
    return Row(
      children: [
        _buildChip('all', 'All', isDark),
        const SizedBox(width: 8),
        _buildChip('active', 'Active', isDark),
        const SizedBox(width: 8),
        _buildChip('range', 'Range', isDark),
      ],
    );
  }

  Widget _buildChip(String id, String label, bool isDark) {
    bool isSelected = _filter == id;
    return Expanded(
      child: InkWell(
        onTap: () => setState(() => _filter = id),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 10),
          decoration: BoxDecoration(
            color: isSelected ? Colors.indigo : Colors.transparent,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: isSelected ? Colors.indigo : PaceColors.getBorder(isDark)),
          ),
          alignment: Alignment.center,
          child: Text(label, style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: isSelected ? Colors.white : PaceColors.getSecondaryText(isDark))),
        ),
      ),
    );
  }

  Widget _buildDatePicker(bool isDark) {
    return Row(
      children: [
        Expanded(
          child: InkWell(
            onTap: () async {
              final date = await showDatePicker(context: context, initialDate: DateTime.now(), firstDate: DateTime(2020), lastDate: DateTime.now());
              if (date != null) setState(() => _startDate = date);
            },
            child: Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(color: PaceColors.getBackground(isDark), borderRadius: BorderRadius.circular(12)),
              child: Text(_startDate == null ? 'Start Date' : DateFormat('MMM dd, yyyy').format(_startDate!), style: TextStyle(fontSize: 11, color: PaceColors.getPrimaryText(isDark))),
            ),
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: InkWell(
            onTap: () async {
              final date = await showDatePicker(context: context, initialDate: DateTime.now(), firstDate: DateTime(2020), lastDate: DateTime.now());
              if (date != null) setState(() => _endDate = date);
            },
            child: Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(color: PaceColors.getBackground(isDark), borderRadius: BorderRadius.circular(12)),
              child: Text(_endDate == null ? 'End Date' : DateFormat('MMM dd, yyyy').format(_endDate!), style: TextStyle(fontSize: 11, color: PaceColors.getPrimaryText(isDark))),
            ),
          ),
        ),
      ],
    );
  }
}
