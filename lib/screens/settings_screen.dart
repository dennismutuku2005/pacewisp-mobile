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

    return Column(
      children: [
        _buildHeader(isDark),
        Expanded(
          child: SingleChildScrollView(
            physics: const AlwaysScrollableScrollPhysics(),
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildActiveAccountCard(settings, isDark),
          const SizedBox(height: 32),

          _buildSectionTitle('SWITCH INSTANCE', isDark),
          _buildSettingGroup(
            isDark,
            [
              ...settings.accounts.asMap().entries.map((entry) {
                final index = entry.key;
                final acc = entry.value;
                final isActive = settings.activeAccount?.subdomain == acc.subdomain && settings.activeAccount?.domain == acc.domain;
                
                return ListTile(
                  contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                  title: Text("${acc.subdomain}.${acc.domain}", style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: PaceColors.getPrimaryText(isDark), letterSpacing: 0.5)),
                  subtitle: Text(acc.accountName.toUpperCase(), style: TextStyle(fontSize: 10, color: PaceColors.getDimText(isDark), fontWeight: FontWeight.bold, letterSpacing: 1.5)),
                  trailing: isActive ? const Icon(Icons.check_circle_rounded, color: PaceColors.purple, size: 22) : null,
                  onTap: () => settings.switchAccount(index),
                );
              }),
              ListTile(
                contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                leading: Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(color: PaceColors.purple.withOpacity(0.08), borderRadius: BorderRadius.circular(10)),
                  child: const Icon(Icons.add_link_rounded, color: PaceColors.purple, size: 20),
                ),
                title: Text('ADD NEW INSTANCE', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: PaceColors.purple, letterSpacing: 1)),
                onTap: () {
                  Navigator.of(context).push(MaterialPageRoute(builder: (_) => const LoginScreen()));
                },
              ),
            ],
          ),
          
          const SizedBox(height: 32),
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
                isDark,
                Colors.amber
              ),
              const Divider(height: 1, indent: 56),
              _buildSwitchTile(
                'SYSTEM APP LOCK', 
                'SECURE WITH BIOMETRICS', 
                Icons.fingerprint_rounded, 
                settings.isAppLockEnabled, 
                (val) async {
                  if (val) {
                    final success = await LockService().authenticate();
                    if (success) {
                      settings.toggleAppLock(true);
                    }
                  } else {
                    final success = await LockService().authenticate();
                    if (success) {
                      settings.toggleAppLock(false);
                    }
                  }
                }, 
                isDark,
                PaceColors.emerald
              ),
            ],
          ),
          const SizedBox(height: 32),
          _buildSectionTitle('BUILD INFORMATION', isDark),
          _buildSettingGroup(
            isDark,
            [
              _buildReadOnlyTile('VERSION', '1.2.6 ENTERPRISE STABLE', isDark),
              const Divider(height: 1),
              _buildReadOnlyTile('SYSTEM STATUS', 'CORE API ONLINE', isDark, valueColor: PaceColors.emerald),
            ],
          ),
          const SizedBox(height: 40),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12),
            child: SizedBox(
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
                icon: const Icon(Icons.logout_rounded, color: Colors.redAccent, size: 20),
                label: Text('SIGN OUT OF ALL SESSIONS', style: TextStyle(color: Colors.redAccent, fontWeight: FontWeight.bold, letterSpacing: 1, fontSize: 13)),
                style: TextButton.styleFrom(
                  backgroundColor: Colors.redAccent.withOpacity(0.05),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16), 
                    side: BorderSide(color: Colors.redAccent.withOpacity(0.2), width: 1.5)
                  )
                ),
              ),
            ),
          ),
          const SizedBox(height: 80),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildHeader(bool isDark) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(16, 20, 16, 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text('PREFERENCES', style: TextStyle(color: PaceColors.purple, fontSize: 18, fontWeight: FontWeight.normal, letterSpacing: -0.5)),
              const Icon(Icons.settings_rounded, color: PaceColors.purple, size: 24),
            ],
          ),
          const SizedBox(height: 4),
          Text('MANAGE CORE ACCOUNTS & SYSTEM BEHAVIOR', style: TextStyle(color: PaceColors.getDimText(isDark), fontSize: 9, fontWeight: FontWeight.bold, letterSpacing: 1.2)),
        ],
      ),
    );
  }

  Widget _buildActiveAccountCard(SettingsProvider settings, bool isDark) {
    final acc = settings.activeAccount;
    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(color: PaceColors.purple.withOpacity(isDark ? 0.2 : 0.4), blurRadius: 24, offset: const Offset(0, 12))
        ],
        image: const DecorationImage(
          image: AssetImage('assets/images/sidebar.png'),
          fit: BoxFit.cover,
          alignment: Alignment.centerRight,
        ),
      ),
      child: Container(
        padding: const EdgeInsets.all(24),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(24),
          gradient: LinearGradient(
            colors: [PaceColors.purple.withOpacity(0.95), PaceColors.purple.withOpacity(0.5)],
            begin: Alignment.bottomLeft,
            end: Alignment.topRight,
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('ACTIVE INSTANCE', style: TextStyle(color: Colors.white.withOpacity(0.7), fontSize: 9, fontWeight: FontWeight.bold, letterSpacing: 2)),
            const SizedBox(height: 12),
            Text(acc?.accountName.toUpperCase() ?? 'GUEST USER', style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold, letterSpacing: 1.5)),
            const SizedBox(height: 4),
            Text("${acc?.subdomain}.${acc?.domain}", style: TextStyle(color: Colors.white.withOpacity(0.8), fontSize: 13, fontWeight: FontWeight.w600, letterSpacing: 0.5)),
          ],
        ),
      ),
    );
  }

  Widget _buildSectionTitle(String title, bool isDark) {
    return Padding(
      padding: const EdgeInsets.only(left: 4, bottom: 12),
      child: Text(title, style: TextStyle(color: PaceColors.getDimText(isDark), fontSize: 10, fontWeight: FontWeight.bold, letterSpacing: 2)),
    );
  }

  Widget _buildSettingGroup(bool isDark, List<Widget> children) {
    return Container(
      decoration: BoxDecoration(
        color: PaceColors.getSurface(isDark),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: PaceColors.getBorder(isDark), width: 1.5),
      ),
      child: Column(children: children),
    );
  }

  Widget _buildSwitchTile(String title, String subtitle, IconData icon, bool value, Function(bool) onChanged, bool isDark, Color iconColor) {
    return ListTile(
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      leading: Container(
        padding: const EdgeInsets.all(10),
        decoration: BoxDecoration(color: iconColor.withOpacity(0.1), borderRadius: BorderRadius.circular(10)),
        child: Icon(icon, color: iconColor, size: 20),
      ),
      title: Text(title, style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: PaceColors.getPrimaryText(isDark), letterSpacing: 0.5)),
      subtitle: Text(subtitle, style: TextStyle(fontSize: 9, color: PaceColors.getDimText(isDark), fontWeight: FontWeight.bold, letterSpacing: 1)),
      trailing: Switch(
        value: value,
        onChanged: onChanged,
        activeColor: Colors.white,
        activeTrackColor: PaceColors.emerald,
        inactiveThumbColor: isDark ? Colors.grey[400] : Colors.grey[600],
        inactiveTrackColor: isDark ? Colors.grey[800] : Colors.grey[300],
      ),
    );
  }

  Widget _buildReadOnlyTile(String label, String value, bool isDark, {Color? valueColor}) {
    return ListTile(
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      title: Text(label, style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: PaceColors.getDimText(isDark), letterSpacing: 1)),
      trailing: Text(value, style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: valueColor ?? PaceColors.getPrimaryText(isDark), letterSpacing: 0.5)),
    );
  }
}

