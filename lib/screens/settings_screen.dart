import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/settings_provider.dart';
import '../theme/colors.dart';
import 'login_screen.dart';
import '../services/lock_service.dart';

class SettingsScreen extends StatelessWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final settings = Provider.of<SettingsProvider>(context);
    final isDark = settings.isDarkMode;

    return SingleChildScrollView(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildHeader(isDark),
          const SizedBox(height: 24),
          
          _buildActiveAccountCard(settings, isDark),
          const SizedBox(height: 24),

          _buildSectionTitle('SWITCH INSTANCE', isDark),
          _buildSettingGroup(
            isDark,
            [
              ...settings.accounts.asMap().entries.map((entry) {
                final index = entry.key;
                final acc = entry.value;
                final isActive = settings.activeAccount?.subdomain == acc.subdomain && settings.activeAccount?.domain == acc.domain;
                
                return ListTile(
                  leading: Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(color: isActive ? PaceColors.purple : PaceColors.getSurface(isDark), borderRadius: BorderRadius.circular(8)),
                    child: Text(acc.subdomain[0].toUpperCase(), style: TextStyle(color: isActive ? Colors.white : PaceColors.purple, fontWeight: FontWeight.bold)),
                  ),
                  title: Text("${acc.subdomain}.${acc.domain}", style: TextStyle(fontSize: 14, fontWeight: FontWeight.w900, color: PaceColors.getPrimaryText(isDark), letterSpacing: 0.5)),
                  subtitle: Text(acc.accountName.toUpperCase(), style: TextStyle(fontSize: 10, color: PaceColors.getDimText(isDark), fontWeight: FontWeight.w900, letterSpacing: 1.5)),
                  trailing: isActive ? const Icon(Icons.check_circle_rounded, color: PaceColors.purple, size: 20) : null,
                  onTap: () => settings.switchAccount(index),
                );
              }),
              ListTile(
                leading: Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(color: PaceColors.purple.withOpacity(0.08), borderRadius: BorderRadius.circular(8)),
                  child: const Icon(Icons.add_link_rounded, color: PaceColors.purple, size: 20),
                ),
                title: const Text('ADD NEW INSTANCE', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w900, color: PaceColors.purple, letterSpacing: 1)),
                onTap: () {
                  Navigator.of(context).push(MaterialPageRoute(builder: (_) => const LoginScreen()));
                },
              ),
            ],
          ),
          
          const SizedBox(height: 24),
          _buildSectionTitle('APPEARANCE & SECURITY', isDark),
          _buildSettingGroup(
            isDark,
            [
              _buildSwitchTile(
                'DARK MODE', 
                'ADAPTIVE VISUAL INTERFACE', 
                Icons.dark_mode_rounded, 
                settings.isDarkMode, 
                (val) => settings.toggleDarkMode(), 
                isDark
              ),
              const Divider(height: 1),
              _buildSwitchTile(
                'SYSTEM APP LOCK', 
                'SECURE WITH BIOMETRICS', 
                Icons.lock_person_rounded, 
                settings.isAppLockEnabled, 
                (val) async {
                  final success = await LockService().authenticate();
                  if (success) {
                    settings.toggleAppLock(val);
                  }
                }, 
                isDark
              ),
            ],
          ),
          const SizedBox(height: 24),
          _buildSectionTitle('BUILD INFORMATION', isDark),
          _buildSettingGroup(
            isDark,
            [
              _buildReadOnlyTile('VERSION', '1.2.5 ENTERPRISE STABLE', Icons.info_outline_rounded, isDark),
              const Divider(height: 1),
              _buildReadOnlyTile('SYSTEM STATUS', 'CORE API ONLINE', Icons.bolt_rounded, isDark, valueColor: PaceColors.emerald),
            ],
          ),
          const SizedBox(height: 40),
          SizedBox(
            width: double.infinity,
            height: 56,
            child: TextButton.icon(
              onPressed: () {
                settings.logout();
                Navigator.of(context).pushAndRemoveUntil(
                  MaterialPageRoute(builder: (_) => const LoginScreen()),
                  (route) => false,
                );
              },
              icon: const Icon(Icons.logout_rounded, color: Colors.blueGrey, size: 18),
              label: const Text('SIGN OUT OF ALL SESSIONS', style: TextStyle(color: Colors.blueGrey, fontWeight: FontWeight.w900, letterSpacing: 1, fontSize: 13)),
              style: TextButton.styleFrom(
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(20), 
                  side: const BorderSide(color: Colors.blueGrey, width: 1)
                )
              ),
            ),
          ),
          const SizedBox(height: 80),
        ],
      ),
    );
  }

  Widget _buildHeader(bool isDark) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text('PREFERENCES', style: TextStyle(color: PaceColors.purple, fontSize: 18, fontWeight: FontWeight.w900, letterSpacing: -0.5)),
        Text('MANAGE CORE ACCOUNTS & SYSTEM BEHAVIOR', style: TextStyle(color: PaceColors.getDimText(isDark), fontSize: 9, fontWeight: FontWeight.w900, letterSpacing: 2)),
      ],
    );
  }

  Widget _buildActiveAccountCard(SettingsProvider settings, bool isDark) {
    final acc = settings.activeAccount;
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: PaceColors.purple,
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(color: PaceColors.purple.withOpacity(0.3), blurRadius: 20, offset: const Offset(0, 10))
        ]
      ),
      child: Row(
        children: [
          Container(
            width: 56, height: 56,
            decoration: BoxDecoration(color: Colors.white24, borderRadius: BorderRadius.circular(16)),
            child: Center(child: Text(acc?.subdomain[0].toUpperCase() ?? 'P', style: const TextStyle(color: Colors.white, fontSize: 24, fontWeight: FontWeight.w900))),
          ),
          const SizedBox(width: 20),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(acc?.accountName.toUpperCase() ?? 'GUEST USER', style: const TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.w900, letterSpacing: 1.5)),
                Text("${acc?.subdomain}.${acc?.domain}", style: TextStyle(color: Colors.white.withOpacity(0.7), fontSize: 11, fontWeight: FontWeight.w700, letterSpacing: 0.5)),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSectionTitle(String title, bool isDark) {
    return Padding(
      padding: const EdgeInsets.only(left: 4, bottom: 12),
      child: Text(title, style: TextStyle(color: PaceColors.getDimText(isDark), fontSize: 9, fontWeight: FontWeight.w900, letterSpacing: 2)),
    );
  }

  Widget _buildSettingGroup(bool isDark, List<Widget> children) {
    return Container(
      decoration: BoxDecoration(
        color: PaceColors.getCard(isDark),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: PaceColors.getBorder(isDark), width: 1.5),
      ),
      child: Column(children: children),
    );
  }

  Widget _buildSwitchTile(String title, String subtitle, IconData icon, bool value, Function(bool) onChanged, bool isDark) {
    return ListTile(
      leading: Icon(icon, color: PaceColors.purple, size: 20),
      title: Text(title, style: TextStyle(fontSize: 13, fontWeight: FontWeight.w900, color: PaceColors.getPrimaryText(isDark), letterSpacing: 0.5)),
      subtitle: Text(subtitle, style: TextStyle(fontSize: 9, color: PaceColors.getDimText(isDark), fontWeight: FontWeight.w900, letterSpacing: 1)),
      trailing: Switch(
        value: value,
        onChanged: onChanged,
        activeColor: PaceColors.purple,
        activeTrackColor: PaceColors.purple.withOpacity(0.2),
      ),
    );
  }

  Widget _buildReadOnlyTile(String label, String value, IconData icon, bool isDark, {Color? valueColor}) {
    return ListTile(
      leading: Icon(icon, color: PaceColors.purple, size: 20),
      title: Text(label, style: TextStyle(fontSize: 11, fontWeight: FontWeight.w900, color: PaceColors.getDimText(isDark), letterSpacing: 1)),
      trailing: Text(value, style: TextStyle(fontSize: 11, fontWeight: FontWeight.w900, color: valueColor ?? PaceColors.getPrimaryText(isDark), letterSpacing: 0.5)),
    );
  }
}
