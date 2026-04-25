import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:lucide_icons/lucide_icons.dart';
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
      _showError('Failed to load SMS config');
    } finally {
      setState(() => _isLoading = false);
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
        _fetchInitialData();
      }
    } catch (e) {
      _showError('Failed to save config');
    }
  }

  Future<void> _clearConfig() async {
    final bool isDark = Provider.of<SettingsProvider>(context, listen: false).isDarkMode;
    
    final confirm = await showGeneralDialog<bool>(
      context: context,
      barrierDismissible: true,
      barrierLabel: '',
      barrierColor: Colors.black54,
      transitionDuration: const Duration(milliseconds: 200),
      pageBuilder: (c, a1, a2) => Center(
        child: Container(
          width: MediaQuery.of(context).size.width * 0.85,
          padding: const EdgeInsets.all(32),
          decoration: BoxDecoration(
            color: PaceColors.getCard(isDark),
            borderRadius: BorderRadius.circular(32),
            border: Border.all(color: PaceColors.getBorder(isDark), width: 1.2),
          ),
          child: Material(
            color: Colors.transparent,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 56, height: 56,
                  decoration: BoxDecoration(color: Colors.redAccent.withOpacity(0.08), shape: BoxShape.circle),
                  child: const Icon(LucideIcons.trash2, color: Colors.redAccent, size: 24),
                ),
                const SizedBox(height: 24),
                Text('DELETE CONFIG?', style: GoogleFonts.figtree(fontSize: 13, fontWeight: FontWeight.bold, color: PaceColors.purple, letterSpacing: 0.5)),
                const SizedBox(height: 12),
                Text('This action will clear all SMS gateway credentials. You will need to re-configure to enable broadcasting.', 
                  textAlign: TextAlign.center,
                  style: GoogleFonts.figtree(fontSize: 10, color: PaceColors.getDimText(isDark), height: 1.5, fontWeight: FontWeight.w500)),
                const SizedBox(height: 32),
                Row(
                  children: [
                    Expanded(
                      child: InkWell(
                        onTap: () => Navigator.pop(c, false),
                        borderRadius: BorderRadius.circular(12),
                        child: Container(
                          padding: const EdgeInsets.symmetric(vertical: 12),
                          alignment: Alignment.center,
                          child: Text('CANCEL', style: GoogleFonts.figtree(fontSize: 9, fontWeight: FontWeight.bold, color: PaceColors.getDimText(isDark), letterSpacing: 1)),
                        ),
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: InkWell(
                        onTap: () => Navigator.pop(c, true),
                        borderRadius: BorderRadius.circular(12),
                        child: Container(
                          padding: const EdgeInsets.symmetric(vertical: 12),
                          decoration: BoxDecoration(color: Colors.redAccent, borderRadius: BorderRadius.circular(12), boxShadow: [BoxShadow(color: Colors.redAccent.withOpacity(0.2), blurRadius: 10, offset: const Offset(0, 4))]),
                          alignment: Alignment.center,
                          child: Text('DELETE', style: GoogleFonts.figtree(fontSize: 9, fontWeight: FontWeight.bold, color: Colors.white, letterSpacing: 1)),
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );

    if (confirm != true) return;

    try {
      final res = await _api.saveSmsConfig({'apikey': '', 'partner_id': '', 'shortcode': ''});
      if (res != null && res['status'] == 'success') {
        _showSuccess('Configuration deleted');
        _fetchInitialData();
      }
    } catch (e) {
      _showError('Failed to delete config');
    }
  }

  void _showError(String msg) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg), backgroundColor: Colors.redAccent));
  }

  void _showSuccess(String msg) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg), backgroundColor: PaceColors.emerald));
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
            color: PaceColors.purple,
            child: SingleChildScrollView(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 24),
              physics: const AlwaysScrollableScrollPhysics(),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
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
                  const SizedBox(height: 32),
                  _buildSectionHeader('BROADCAST COMPOSER', 'NEW TRANSMISSION SEQUENCE', isDark),
                  _buildComposerWithLock(isDark, settings),
                  const SizedBox(height: 100),
                ],
              ),
            ),
          ),
    );
  }

  Widget _buildComposerWithLock(bool isDark, SettingsProvider settings) {
    if (_isConfigured) {
      return _buildComposer(isDark, settings);
    }

    return Stack(
      children: [
        Opacity(
          opacity: 0.4,
          child: ImageFiltered(
            imageFilter: ImageFilter.blur(sigmaX: 6, sigmaY: 6),
            child: AbsorbPointer(
              absorbing: true,
              child: _buildComposer(isDark, settings),
            ),
          ),
        ),
        Positioned.fill(
          child: Center(
            child: Container(
              padding: const EdgeInsets.all(24),
              margin: const EdgeInsets.symmetric(horizontal: 24),
              decoration: BoxDecoration(
                color: PaceColors.getCard(isDark),
                borderRadius: BorderRadius.circular(24),
                border: Border.all(color: PaceColors.purple.withOpacity(0.3), width: 1.2),
                boxShadow: [
                  BoxShadow(color: Colors.black.withOpacity(0.1), blurRadius: 40, spreadRadius: -10)
                ],
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    width: 48,
                    height: 48,
                    decoration: BoxDecoration(color: PaceColors.purple.withOpacity(0.1), shape: BoxShape.circle),
                    child: const Icon(LucideIcons.shieldAlert, color: PaceColors.purple, size: 24),
                  ),
                  const SizedBox(height: 20),
                  Text('SETUP REQUIRED', style: GoogleFonts.figtree(fontSize: 11, fontWeight: FontWeight.bold, color: PaceColors.purple, letterSpacing: 1)),
                  const SizedBox(height: 8),
                  Text(
                    'Your SMS gateway is not yet configured. Please set your credentials to enable broadcasting.',
                    textAlign: TextAlign.center,
                    style: GoogleFonts.figtree(fontSize: 10, color: PaceColors.getDimText(isDark), height: 1.5),
                  ),
                  const SizedBox(height: 24),
                  SizedBox(
                    width: double.infinity,
                    height: 44,
                    child: ElevatedButton(
                      onPressed: () => setState(() => _showConfig = true),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: PaceColors.purple,
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        elevation: 0,
                      ),
                      child: const Text('CONFIGURE NOW', style: TextStyle(fontSize: 10, fontWeight: FontWeight.w600, letterSpacing: 1)),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildSectionHeader(String title, String sub, bool isDark) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(title, style: GoogleFonts.figtree(color: PaceColors.purple, fontSize: 13, fontWeight: FontWeight.normal, letterSpacing: -0.2)),
        Text(sub, style: GoogleFonts.figtree(color: PaceColors.getDimText(isDark), fontSize: 8, fontWeight: FontWeight.w600, letterSpacing: 1.5)),
      ]),
    );
  }

  Widget _buildHeader(bool isDark) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('SMS CENTER', style: GoogleFonts.figtree(color: PaceColors.purple, fontSize: 20, fontWeight: FontWeight.normal, letterSpacing: -0.5)),
        Text('TRANSMISSION HUB', style: GoogleFonts.figtree(color: PaceColors.getDimText(isDark), fontSize: 10, fontWeight: FontWeight.w600, letterSpacing: 2)),
      ],
    );
  }

  Widget _buildStatsGrid(bool isDark) {
    return GridView.count(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      crossAxisCount: 2,
      crossAxisSpacing: 12,
      mainAxisSpacing: 12,
      childAspectRatio: 1.5,
      children: [
        _buildStatCard('TARGET AUDIENCE', _targetPhones.length.toString(), LucideIcons.users, PaceColors.purple, isDark),
        _buildStatCard('SENT CAMPAIGNS', 'ACTIVE', LucideIcons.shieldCheck, _isConfigured ? PaceColors.emerald : Colors.redAccent, isDark),
      ],
    );
  }

  Widget _buildStatCard(String label, String value, IconData icon, Color color, bool isDark) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: PaceColors.getCard(isDark),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: PaceColors.getBorder(isDark), width: 1.2),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(color: color.withOpacity(0.08), borderRadius: BorderRadius.circular(10)),
            child: Icon(icon, color: color, size: 16),
          ),
          const Spacer(),
          Text(value, style: GoogleFonts.figtree(fontSize: 16, fontWeight: FontWeight.normal, color: PaceColors.purple, letterSpacing: -0.5)),
          const SizedBox(height: 2),
          Text(label, style: GoogleFonts.figtree(fontSize: 8, fontWeight: FontWeight.w600, color: PaceColors.getDimText(isDark), letterSpacing: 1)),
        ],
      ),
    );
  }

  Widget _buildConfigToggle(bool isDark) {
    return InkWell(
      onTap: () => setState(() => _showConfig = !_showConfig),
      borderRadius: BorderRadius.circular(16),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        decoration: BoxDecoration(
          color: PaceColors.getCard(isDark),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: PaceColors.getBorder(isDark), width: 1.2),
        ),
        child: Row(
          children: [
            Stack(
              children: [
                Icon(LucideIcons.settings, size: 16, color: PaceColors.getDimText(isDark)),
                if (!_isConfigured)
                  Positioned(
                    right: 0,
                    top: 0,
                    child: Container(width: 6, height: 6, decoration: const BoxDecoration(color: Colors.redAccent, shape: BoxShape.circle, border: Border.fromBorderSide(BorderSide(color: Colors.white, width: 1)))),
                  ),
              ],
            ),
            const SizedBox(width: 12),
            Text('GATEWAY CONFIGURATION', style: GoogleFonts.figtree(fontSize: 11, fontWeight: FontWeight.w600, color: PaceColors.getPrimaryText(isDark))),
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
        color: PaceColors.getCard(isDark),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: PaceColors.purple.withOpacity(0.3), width: 1.2),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text('API CREDENTIALS', style: GoogleFonts.figtree(fontSize: 8, fontWeight: FontWeight.bold, color: PaceColors.purple, letterSpacing: 1)),
              IconButton(onPressed: _clearConfig, icon: const Icon(LucideIcons.trash2, size: 16, color: Colors.redAccent), padding: EdgeInsets.zero, constraints: const BoxConstraints()),
            ],
          ),
          const SizedBox(height: 20),
          _buildConfigInput('API KEY', _config['apikey'], (v) => _config['apikey'] = v, _obscureApiKey, isDark, true),
          const SizedBox(height: 16),
          _buildConfigInput('PARTNER ID', _config['partner_id'], (v) => _config['partner_id'] = v, false, isDark, false),
          const SizedBox(height: 16),
          _buildConfigInput('SENDER ID / SHORTCODE', _config['shortcode'], (v) => _config['shortcode'] = v, false, isDark, false),
          const SizedBox(height: 24),
          SizedBox(
            width: double.infinity,
            height: 48,
            child: ElevatedButton(
              onPressed: _saveConfig,
              style: ElevatedButton.styleFrom(
                backgroundColor: PaceColors.purple,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                elevation: 0,
              ),
              child: const Text('UPDATE CREDENTIALS', style: TextStyle(fontSize: 10, fontWeight: FontWeight.w600, letterSpacing: 1)),
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
        Text(label, style: GoogleFonts.figtree(fontSize: 8, fontWeight: FontWeight.w600, color: PaceColors.getDimText(isDark), letterSpacing: 1)),
        const SizedBox(height: 4),
        TextField(
          onChanged: onChanged,
          obscureText: obscure,
          autocorrect: false,
          enableSuggestions: false,
          controller: TextEditingController(text: safeValue)..selection = TextSelection.fromPosition(TextPosition(offset: safeValue.length)),
          style: GoogleFonts.figtree(color: PaceColors.getPrimaryText(isDark), fontSize: 13, fontWeight: FontWeight.w500),
          decoration: InputDecoration(
            isDense: true,
            hintText: 'Required',
            hintStyle: TextStyle(color: PaceColors.getDimText(isDark).withOpacity(0.3)),
            contentPadding: const EdgeInsets.symmetric(vertical: 12),
            enabledBorder: UnderlineInputBorder(borderSide: BorderSide(color: PaceColors.getBorder(isDark))),
            focusedBorder: const UnderlineInputBorder(borderSide: BorderSide(color: PaceColors.purple)),
            suffixIcon: hasToggle ? IconButton(
              icon: Icon(obscure ? LucideIcons.eye : LucideIcons.eyeOff, size: 16, color: PaceColors.getDimText(isDark)),
              onPressed: () => setState(() => _obscureApiKey = !_obscureApiKey),
              padding: EdgeInsets.zero,
              constraints: const BoxConstraints(),
            ) : null,
          ),
        ),
      ],
    );
  }

  Widget _buildComposer(bool isDark, SettingsProvider settings) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: PaceColors.getCard(isDark),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: PaceColors.getBorder(isDark), width: 1.2),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text('TARGET AUDIENCE', style: GoogleFonts.figtree(fontSize: 9, fontWeight: FontWeight.w600, color: PaceColors.getDimText(isDark), letterSpacing: 1.5)),
              PaceBadge(label: '${_targetPhones.length} SELECTED', variant: BadgeVariant.secondary),
            ],
          ),
          const SizedBox(height: 16),
          _buildFilterChips(isDark),
          if (_filter == 'range') ...[
            const SizedBox(height: 16),
            _buildDatePicker(isDark),
          ],
          const SizedBox(height: 16),
          SizedBox(
            width: double.infinity,
            height: 44,
            child: OutlinedButton.icon(
              onPressed: _isFetchingCustomers ? null : _fetchTargetCustomers,
              icon: _isFetchingCustomers ? const SizedBox(width: 12, height: 12, child: CircularProgressIndicator(strokeWidth: 2, color: PaceColors.purple)) : const Icon(LucideIcons.refreshCw, size: 14),
              label: const Text('IDENTIFY & SYNC AUDIENCE', style: TextStyle(fontSize: 10, fontWeight: FontWeight.w600, letterSpacing: 1)),
              style: OutlinedButton.styleFrom(
                foregroundColor: PaceColors.purple,
                side: BorderSide(color: PaceColors.purple.withOpacity(0.3), width: 1),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
            ),
          ),
          const SizedBox(height: 32),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text('MESSAGE BODY', style: GoogleFonts.figtree(fontSize: 9, fontWeight: FontWeight.w600, color: PaceColors.getDimText(isDark), letterSpacing: 1.5)),
              Text('${_messageController.text.length}/160', style: GoogleFonts.figtree(fontSize: 9, fontWeight: FontWeight.w600, color: PaceColors.getDimText(isDark))),
            ],
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _messageController,
            maxLines: 5,
            onChanged: (v) => setState(() {}),
            style: GoogleFonts.figtree(color: PaceColors.getPrimaryText(isDark), fontSize: 13, height: 1.5),
            decoration: InputDecoration(
              hintText: 'Type broadcast content...',
              hintStyle: TextStyle(color: PaceColors.getDimText(isDark).withOpacity(0.3)),
              filled: true,
              fillColor: PaceColors.getBackground(isDark).withOpacity(0.5),
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: BorderSide.none),
              contentPadding: const EdgeInsets.all(16),
            ),
          ),
          const SizedBox(height: 32),
          if (settings.hasPolicy('send_bulk_sms'))
            SizedBox(
              width: double.infinity,
              height: 54,
              child: ElevatedButton(
                onPressed: _isSending || _targetPhones.isEmpty ? null : _sendBroadcast,
                style: ElevatedButton.styleFrom(
                  backgroundColor: PaceColors.purple,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                  elevation: 4,
                  shadowColor: PaceColors.purple.withOpacity(0.3),
                ),
                child: _isSending 
                  ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                  : Text('EXECUTE SEND TO ${_targetPhones.length} CUSTOMERS', style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold, letterSpacing: 1)),
              ),
            ),
          const SizedBox(height: 24),
          _buildNotice(isDark),
        ],
      ),
    );
  }

  Widget _buildNotice(bool isDark) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(color: PaceColors.getSurface(isDark), borderRadius: BorderRadius.circular(16)),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(LucideIcons.info, size: 16, color: PaceColors.purple),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('TRANSMISSION POLICY', style: GoogleFonts.figtree(fontSize: 9, fontWeight: FontWeight.w700, color: PaceColors.purple, letterSpacing: 1)),
                const SizedBox(height: 4),
                Text('Ensure credits are available on TextSMS. Multi-segment messages consume multiple credits per recipient.', style: GoogleFonts.figtree(fontSize: 10, color: PaceColors.getDimText(isDark), height: 1.4)),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFilterChips(bool isDark) {
    return Row(
      children: [
        _buildChip('all', 'ALL', isDark),
        const SizedBox(width: 8),
        _buildChip('active', 'ACTIVE', isDark),
        const SizedBox(width: 8),
        _buildChip('range', 'RANGE', isDark),
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
            color: isSelected ? PaceColors.purple : Colors.transparent,
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: isSelected ? PaceColors.purple : PaceColors.getBorder(isDark)),
          ),
          alignment: Alignment.center,
          child: Text(label, style: GoogleFonts.figtree(fontSize: 8, fontWeight: FontWeight.w700, color: isSelected ? Colors.white : PaceColors.getDimText(isDark), letterSpacing: 0.5)),
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
              decoration: BoxDecoration(color: PaceColors.getBackground(isDark), borderRadius: BorderRadius.circular(10), border: Border.all(color: PaceColors.getBorder(isDark))),
              child: Row(children: [Icon(LucideIcons.calendar, size: 12, color: PaceColors.getDimText(isDark)), const SizedBox(width: 8), Text(_startDate == null ? 'START DATE' : DateFormat('MMM dd, yyyy').format(_startDate!), style: GoogleFonts.figtree(fontSize: 9, fontWeight: FontWeight.w600, color: PaceColors.getPrimaryText(isDark)))]),
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
              decoration: BoxDecoration(color: PaceColors.getBackground(isDark), borderRadius: BorderRadius.circular(10), border: Border.all(color: PaceColors.getBorder(isDark))),
              child: Row(children: [Icon(LucideIcons.calendar, size: 12, color: PaceColors.getDimText(isDark)), const SizedBox(width: 8), Text(_endDate == null ? 'END DATE' : DateFormat('MMM dd, yyyy').format(_endDate!), style: GoogleFonts.figtree(fontSize: 9, fontWeight: FontWeight.w600, color: PaceColors.getPrimaryText(isDark)))]),
            ),
          ),
        ),
      ],
    );
  }
}
