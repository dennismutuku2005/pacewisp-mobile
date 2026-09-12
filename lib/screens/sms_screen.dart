import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:provider/provider.dart';
import 'package:google_fonts/google_fonts.dart';
import '../providers/settings_provider.dart';
import '../services/api_service.dart';
import '../theme/colors.dart';
import '../components/badge.dart';
import '../components/skeleton.dart';
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
  bool _obscureApiKey = true;

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

  @override
  void dispose() {
    _messageController.dispose();
    super.dispose();
  }

  Future<void> _fetchInitialData() async {
    setState(() => _isLoading = true);
    try {
      final res = await _api.getSmsConfig();
      if (res != null && res['status'] == 'success') {
        setState(() {
          final data = res['data'] ?? {};
          _config = {
            'apikey': data['apikey']?.toString() ?? '',
            'partner_id': data['partner_id']?.toString() ?? '',
            'shortcode': data['shortcode']?.toString() ?? '',
          };
        });
      }
    } catch (e) {
      _showError('Failed to load SMS gateway settings');
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  bool get _isConfigured =>
      (_config['apikey']?.toString().isNotEmpty ?? false) &&
      (_config['partner_id']?.toString().isNotEmpty ?? false) &&
      (_config['shortcode']?.toString().isNotEmpty ?? false);

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
      _showError('Failed to sync audience numbers');
    } finally {
      if (mounted) setState(() => _isFetchingCustomers = false);
    }
  }

  Future<void> _sendBroadcast() async {
    if (_targetPhones.isEmpty) {
      _showError('Please sync targeted audience numbers first');
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
        _showError(res?['message'] ?? 'Failed to dispatch SMS');
      }
    } catch (e) {
      _showError('System error during broadcast execution');
    } finally {
      if (mounted) setState(() => _isSending = false);
    }
  }

  Future<void> _saveConfig() async {
    try {
      final res = await _api.saveSmsConfig(_config);
      if (res != null && res['status'] == 'success') {
        _showSuccess('Gateway configuration saved');
        setState(() => _showConfig = false);
        _fetchInitialData();
      }
    } catch (e) {
      _showError('Failed to save config');
    }
  }

  void _showError(String msg) {
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(msg, style: GoogleFonts.figtree()), backgroundColor: Colors.red.shade700),
      );
    }
  }

  void _showSuccess(String msg) {
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(msg, style: GoogleFonts.figtree()), backgroundColor: PaceColors.emerald),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final settings = Provider.of<SettingsProvider>(context);
    final isDark = settings.isDarkMode;

    return RefreshIndicator(
      onRefresh: _fetchInitialData,
      color: PaceColors.purple,
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 120),
        physics: const AlwaysScrollableScrollPhysics(),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _buildHeader(isDark),
            const SizedBox(height: 16),
            _buildStatsGrid(isDark),
            const SizedBox(height: 16),
            if (settings.hasPolicy('manage_sms_config')) _buildConfigToggle(isDark),
            if (_showConfig) ...[
              const SizedBox(height: 12),
              _buildConfigForm(isDark),
            ],
            const SizedBox(height: 20),
            _buildComposerSection(isDark, settings),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader(bool isDark) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'SMS Broadcast',
          style: GoogleFonts.figtree(
            color: PaceColors.getPrimaryText(isDark),
            fontSize: 20,
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 2),
        Text(
          'Dispatch promotional and maintenance notices to hotspot customers',
          style: GoogleFonts.figtree(
            color: PaceColors.getDimText(isDark),
            fontSize: 12,
          ),
        ),
      ],
    );
  }

  Widget _buildStatsGrid(bool isDark) {
    return Row(
      children: [
        Expanded(
          child: _buildStatCard('Target Audience', '${_targetPhones.length} Contacts', LucideIcons.users, PaceColors.purple, isDark),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: _buildStatCard('Gateway Status', _isConfigured ? 'Ready' : 'Not Set', LucideIcons.shieldCheck, _isConfigured ? PaceColors.emerald : Colors.red.shade600, isDark),
        ),
      ],
    );
  }

  Widget _buildStatCard(String label, String value, IconData icon, Color color, bool isDark) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: PaceColors.getCard(isDark),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: PaceColors.getBorder(isDark)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                label,
                style: GoogleFonts.figtree(fontSize: 12, fontWeight: FontWeight.w600, color: PaceColors.getDimText(isDark)),
              ),
              Container(
                padding: const EdgeInsets.all(6),
                decoration: BoxDecoration(color: color.withOpacity(0.1), borderRadius: BorderRadius.circular(8)),
                child: Icon(icon, color: color, size: 14),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            value,
            style: GoogleFonts.figtree(
              fontSize: 16,
              fontWeight: FontWeight.bold,
              color: PaceColors.getPrimaryText(isDark),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildConfigToggle(bool isDark) {
    return InkWell(
      onTap: () => setState(() => _showConfig = !_showConfig),
      borderRadius: BorderRadius.circular(14),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        decoration: BoxDecoration(
          color: PaceColors.getCard(isDark),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: PaceColors.getBorder(isDark)),
        ),
        child: Row(
          children: [
            Icon(LucideIcons.settings, size: 18, color: PaceColors.purple),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'SMS Gateway API Settings',
                    style: GoogleFonts.figtree(fontSize: 14, fontWeight: FontWeight.bold, color: PaceColors.getPrimaryText(isDark)),
                  ),
                  Text(
                    _isConfigured ? 'TextSMS gateway credentials active' : 'Configuration required to send messages',
                    style: GoogleFonts.figtree(fontSize: 12, color: PaceColors.getDimText(isDark)),
                  ),
                ],
              ),
            ),
            Icon(_showConfig ? LucideIcons.chevronUp : LucideIcons.chevronDown, size: 18, color: Colors.grey),
          ],
        ),
      ),
    );
  }

  Widget _buildConfigForm(bool isDark) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: PaceColors.getCard(isDark),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: PaceColors.getBorder(isDark)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'TextSMS Credentials',
            style: GoogleFonts.figtree(fontSize: 14, fontWeight: FontWeight.bold, color: PaceColors.getPrimaryText(isDark)),
          ),
          const SizedBox(height: 14),
          _buildConfigInput('API Key', _config['apikey'], (v) => _config['apikey'] = v, _obscureApiKey, isDark, true),
          const SizedBox(height: 12),
          _buildConfigInput('Partner ID', _config['partner_id'], (v) => _config['partner_id'] = v, false, isDark, false),
          const SizedBox(height: 12),
          _buildConfigInput('Sender ID / Shortcode', _config['shortcode'], (v) => _config['shortcode'] = v, false, isDark, false),
          const SizedBox(height: 18),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: _saveConfig,
              style: ElevatedButton.styleFrom(
                backgroundColor: PaceColors.purple,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 12),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                elevation: 0,
              ),
              child: Text('Save Gateway Credentials', style: GoogleFonts.figtree(fontSize: 13, fontWeight: FontWeight.w600)),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildConfigInput(String label, String? value, Function(String) onChanged, bool obscure, bool isDark, bool hasToggle) {
    final String safeValue = value ?? '';
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: GoogleFonts.figtree(fontSize: 12, fontWeight: FontWeight.w600, color: PaceColors.getDimText(isDark))),
        const SizedBox(height: 6),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 12),
          decoration: BoxDecoration(
            color: PaceColors.getSurface(isDark),
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: PaceColors.getBorder(isDark)),
          ),
          child: TextField(
            onChanged: onChanged,
            obscureText: obscure,
            controller: TextEditingController(text: safeValue)..selection = TextSelection.fromPosition(TextPosition(offset: safeValue.length)),
            style: GoogleFonts.figtree(color: PaceColors.getPrimaryText(isDark), fontSize: 13),
            decoration: InputDecoration(
              isDense: true,
              hintText: 'Enter $label',
              border: InputBorder.none,
              contentPadding: const EdgeInsets.symmetric(vertical: 12),
              suffixIcon: hasToggle
                  ? IconButton(
                      icon: Icon(obscure ? LucideIcons.eye : LucideIcons.eyeOff, size: 16, color: PaceColors.getDimText(isDark)),
                      onPressed: () => setState(() => _obscureApiKey = !_obscureApiKey),
                    )
                  : null,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildComposerSection(bool isDark, SettingsProvider settings) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: PaceColors.getCard(isDark),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: PaceColors.getBorder(isDark)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Target Audience Filter',
                style: GoogleFonts.figtree(fontSize: 14, fontWeight: FontWeight.bold, color: PaceColors.getPrimaryText(isDark)),
              ),
              PaceBadge(label: '${_targetPhones.length} Selected', variant: BadgeVariant.primary),
            ],
          ),
          const SizedBox(height: 12),
          _buildFilterChips(isDark),
          if (_filter == 'range') ...[
            const SizedBox(height: 12),
            _buildDatePicker(isDark),
          ],
          const SizedBox(height: 14),
          SizedBox(
            width: double.infinity,
            child: OutlinedButton.icon(
              onPressed: _isFetchingCustomers ? null : _fetchTargetCustomers,
              icon: _isFetchingCustomers
                  ? const SizedBox(width: 14, height: 14, child: CircularProgressIndicator(strokeWidth: 2, color: PaceColors.purple))
                  : const Icon(LucideIcons.users, size: 16),
              label: Text('Sync Target Audience', style: GoogleFonts.figtree(fontSize: 13, fontWeight: FontWeight.w600)),
              style: OutlinedButton.styleFrom(
                foregroundColor: PaceColors.purple,
                side: const BorderSide(color: PaceColors.purple),
                padding: const EdgeInsets.symmetric(vertical: 12),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
              ),
            ),
          ),
          const SizedBox(height: 20),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Message Content',
                style: GoogleFonts.figtree(fontSize: 14, fontWeight: FontWeight.bold, color: PaceColors.getPrimaryText(isDark)),
              ),
              Text(
                '${_messageController.text.length}/160',
                style: GoogleFonts.figtree(fontSize: 12, color: PaceColors.getDimText(isDark)),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: PaceColors.getSurface(isDark),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: PaceColors.getBorder(isDark)),
            ),
            child: TextField(
              controller: _messageController,
              maxLines: 4,
              onChanged: (v) => setState(() {}),
              style: GoogleFonts.figtree(color: PaceColors.getPrimaryText(isDark), fontSize: 14),
              decoration: InputDecoration(
                hintText: 'Type your broadcast SMS message here...',
                hintStyle: GoogleFonts.figtree(fontSize: 13, color: PaceColors.getDimText(isDark).withOpacity(0.6)),
                border: InputBorder.none,
                isDense: true,
              ),
            ),
          ),
          const SizedBox(height: 18),
          if (settings.hasPolicy('send_bulk_sms'))
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: _isSending || _targetPhones.isEmpty ? null : _sendBroadcast,
                style: ElevatedButton.styleFrom(
                  backgroundColor: PaceColors.purple,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  elevation: 0,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                ),
                child: _isSending
                    ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                    : Text(
                        'Send Broadcast to ${_targetPhones.length} Customers',
                        style: GoogleFonts.figtree(fontSize: 14, fontWeight: FontWeight.bold),
                      ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildFilterChips(bool isDark) {
    return Row(
      children: [
        _buildChip('all', 'All Customers', isDark),
        const SizedBox(width: 8),
        _buildChip('active', 'Active Users', isDark),
        const SizedBox(width: 8),
        _buildChip('range', 'Date Range', isDark),
      ],
    );
  }

  Widget _buildChip(String id, String label, bool isDark) {
    bool isSelected = _filter == id;
    return Expanded(
      child: InkWell(
        onTap: () => setState(() => _filter = id),
        borderRadius: BorderRadius.circular(8),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 8),
          decoration: BoxDecoration(
            color: isSelected ? PaceColors.purple : PaceColors.getSurface(isDark),
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: isSelected ? PaceColors.purple : PaceColors.getBorder(isDark)),
          ),
          alignment: Alignment.center,
          child: Text(
            label,
            style: GoogleFonts.figtree(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: isSelected ? Colors.white : PaceColors.getDimText(isDark),
            ),
          ),
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
            borderRadius: BorderRadius.circular(8),
            child: Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: PaceColors.getSurface(isDark),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: PaceColors.getBorder(isDark)),
              ),
              child: Row(
                children: [
                  Icon(LucideIcons.calendar, size: 14, color: PaceColors.getDimText(isDark)),
                  const SizedBox(width: 6),
                  Text(
                    _startDate == null ? 'Start Date' : DateFormat('MMM dd, yyyy').format(_startDate!),
                    style: GoogleFonts.figtree(fontSize: 12, color: PaceColors.getPrimaryText(isDark)),
                  ),
                ],
              ),
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
            borderRadius: BorderRadius.circular(8),
            child: Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: PaceColors.getSurface(isDark),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: PaceColors.getBorder(isDark)),
              ),
              child: Row(
                children: [
                  Icon(LucideIcons.calendar, size: 14, color: PaceColors.getDimText(isDark)),
                  const SizedBox(width: 6),
                  Text(
                    _endDate == null ? 'End Date' : DateFormat('MMM dd, yyyy').format(_endDate!),
                    style: GoogleFonts.figtree(fontSize: 12, color: PaceColors.getPrimaryText(isDark)),
                  ),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }
}
