import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/settings_provider.dart';
import '../theme/colors.dart';
import 'login_screen.dart';

class SettingsScreen extends StatelessWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final settings = Provider.of<SettingsProvider>(context);
    final isDark = settings.isDarkMode;

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildHeader(isDark),
          const SizedBox(height: 24),
          
          _buildSettingGroup(
            'Switch Account',
            isDark,
            [
              ...settings.accounts.asMap().entries.map((entry) {
                final index = entry.key;
                final acc = entry.value;
                final isActive = settings.activeAccount?.subdomain == acc.subdomain && settings.activeAccount?.domain == acc.domain;
                
                return ListTile(
                  leading: CircleAvatar(
                    backgroundColor: isActive ? PaceColors.purple : PaceColors.getSurface(isDark),
                    child: Text(acc.subdomain[0].toUpperCase(), style: TextStyle(color: isActive ? Colors.white : PaceColors.purple, fontWeight: FontWeight.bold)),
                  ),
                  title: Text("${acc.subdomain}.${acc.domain}", style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: PaceColors.getPrimaryText(isDark))),
                  subtitle: Text(acc.accountName, style: TextStyle(fontSize: 11, color: PaceColors.getSecondaryText(isDark))),
                  trailing: isActive ? const Icon(Icons.check_circle, color: PaceColors.purple) : null,
                  onTap: () => settings.switchAccount(index),
                );
              }),
              ListTile(
                leading: CircleAvatar(backgroundColor: PaceColors.getSurface(isDark), child: const Icon(Icons.add, color: PaceColors.purple)),
                title: const Text('Add New Account', style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: PaceColors.purple)),
                onTap: () {
                  Navigator.of(context).push(MaterialPageRoute(builder: (_) => const LoginScreen()));
                },
              ),
            ],
          ),
          
          const SizedBox(height: 24),
          _buildSettingGroup(
            'Appearance & Security',
            isDark,
            [
              ListTile(
                title: Text('Dark Mode', style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: PaceColors.getPrimaryText(isDark))),
                subtitle: Text('Switch between light and dark themes', style: TextStyle(fontSize: 11, color: PaceColors.getSecondaryText(isDark))),
                trailing: Switch(
                  value: settings.isDarkMode,
                  onChanged: (val) => settings.toggleDarkMode(),
                  activeColor: PaceColors.purple,
                ),
              ),
              const Divider(height: 1),
              ListTile(
                title: Text('App Lock', style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: PaceColors.getPrimaryText(isDark))),
                subtitle: Text('Secure access with a 4-digit pin', style: TextStyle(fontSize: 11, color: PaceColors.getSecondaryText(isDark))),
                trailing: Switch(
                  value: settings.isAppLockEnabled,
                  onChanged: (val) {
                    if (val) {
                      _showPinSetup(context, settings);
                    } else {
                      settings.toggleAppLock(null);
                    }
                  },
                  activeColor: PaceColors.purple,
                ),
              ),
            ],
          ),
          const SizedBox(height: 24),
          _buildSettingGroup(
            'Account Details',
            isDark,
            [
              _buildReadOnlyTile('Login Username', settings.activeAccount?.accountName ?? 'N/A', isDark),
              _buildReadOnlyTile('Account Domain', "${settings.activeAccount?.subdomain}.${settings.activeAccount?.domain}", isDark),
              _buildReadOnlyTile('App Version', '1.0.0 Stable Build', isDark),
            ],
          ),
          const SizedBox(height: 32),
          SizedBox(
            width: double.infinity,
            child: TextButton.icon(
              onPressed: () {
                settings.logout();
                Navigator.of(context).pushAndRemoveUntil(
                  MaterialPageRoute(builder: (_) => const LoginScreen()),
                  (route) => false,
                );
              },
              icon: const Icon(Icons.logout, color: Colors.blueGrey),
              label: const Text('SIGN OUT', style: TextStyle(color: Colors.blueGrey, fontWeight: FontWeight.bold, letterSpacing: 1)),
              style: TextButton.styleFrom(
                padding: const EdgeInsets.all(16), 
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16), 
                  side: const BorderSide(color: Colors.blueGrey, width: 0.5)
                )
              ),
            ),
          ),
          const SizedBox(height: 80),
        ],
      ),
    );
  }

  void _showPinSetup(BuildContext context, SettingsProvider settings) {
    String pin = '';
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Set Security Pin'),
        content: TextField(
          obscureText: true,
          keyboardType: TextInputType.number,
          maxLength: 4,
          decoration: const InputDecoration(hintText: 'Enter 4-digit PIN'),
          onChanged: (val) => pin = val,
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('CANCEL')),
          TextButton(
            onPressed: () {
              if (pin.length == 4) {
                settings.toggleAppLock(pin);
                Navigator.pop(ctx);
              }
            },
            child: const Text('SET PIN'),
          ),
        ],
      ),
    );
  }

  Widget _buildHeader(bool isDark) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'SETTINGS',
          style: TextStyle(color: PaceColors.purple, fontSize: 20, fontWeight: FontWeight.bold, letterSpacing: -0.5),
        ),
        Text(
          'MANAGE YOUR ACCOUNTS & PREFERENCES',
          style: TextStyle(color: PaceColors.getDimText(isDark), fontSize: 10, fontWeight: FontWeight.bold, letterSpacing: 1.5),
        ),
      ],
    );
  }

  Widget _buildSettingGroup(String title, bool isDark, List<Widget> children) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          child: Text(title.toUpperCase(), style: const TextStyle(color: PaceColors.purple, fontSize: 10, fontWeight: FontWeight.bold, letterSpacing: 1)),
        ),
        Container(
          decoration: BoxDecoration(
            color: PaceColors.getCard(isDark),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: PaceColors.getBorder(isDark)),
          ),
          child: Column(children: children),
        ),
      ],
    );
  }

  Widget _buildReadOnlyTile(String label, String value, bool isDark) {
    return ListTile(
      title: Text(label, style: TextStyle(fontSize: 13, color: PaceColors.getSecondaryText(isDark), fontWeight: FontWeight.bold)),
      subtitle: Text(value, style: TextStyle(fontSize: 11, color: PaceColors.getDimText(isDark))),
    );
  }
}
