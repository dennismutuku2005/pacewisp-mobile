import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/settings_provider.dart';
import '../services/api_service.dart';
import '../theme/colors.dart';
import 'main_scaffold.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _subdomainController = TextEditingController();
  final _usernameController = TextEditingController();
  final _passwordController = TextEditingController();
  final ApiService _apiService = ApiService();
  
  bool _isLoading = false;
  bool _showPassword = false;
  bool _isReachable = false;
  
  String _selectedDomain = 'pacewisp.co.ke';
  final List<String> _domains = ['pacewisp.co.ke', 'pace.com', 'wispportal.online'];

  Future<void> _handleVerifyInstance() async {
    final subdomain = _subdomainController.text.trim();
    if (subdomain.isEmpty) {
      _showError('Please enter account name');
      return;
    }

    setState(() => _isLoading = true);
    
    try {
      final settings = Provider.of<SettingsProvider>(context, listen: false);
      await settings.setTemporaryConfig(subdomain, _selectedDomain);

      final reachable = await _apiService.pingInstance();
      
      if (!mounted) return;
      setState(() => _isLoading = false);

      if (reachable) {
        setState(() => _isReachable = true);
      } else {
        _showError('Account not found or unreachable. Check your entry.');
      }
    } catch (e) {
      if (mounted) setState(() => _isLoading = false);
      _showError('Connection error: Instance not found');
    }
  }

  Future<void> _handleLogin() async {
    final username = _usernameController.text.trim();
    final password = _passwordController.text;

    if (username.isEmpty || password.isEmpty) {
      _showError('Username and password are required');
      return;
    }

    setState(() => _isLoading = true);
    
    try {
      final settings = Provider.of<SettingsProvider>(context, listen: false);
      final res = await _apiService.login(username, password);
      
      if (!mounted) return;

      if (res != null && (res['status'] == 'success' || res['status'] == 200)) {
        final token = res['data']?['token'] ?? res['token'];
        if (token != null) {
          await settings.login(_subdomainController.text.trim(), _selectedDomain, username, token);
          if (mounted) {
            Navigator.of(context).pushReplacement(MaterialPageRoute(builder: (_) => const MainScaffold()));
          }
        } else {
          _showError('Authentication failed: Missing token');
        }
      } else {
        _showError(res?['message'] ?? 'Login failed. Invalid credentials.');
      }
    } catch (e) {
      _showError('Login service unavailable');
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _showError(String msg) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(msg, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w500)),
        backgroundColor: Colors.redAccent,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final settings = Provider.of<SettingsProvider>(context);
    final isDark = settings.isDarkMode;
    
    return Scaffold(
      backgroundColor: PaceColors.getBackground(isDark),
      body: SafeArea(
        child: SingleChildScrollView(
          physics: const BouncingScrollPhysics(),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const SizedBox(height: 50),
                _buildLogo(isDark),
                const SizedBox(height: 32),
                Text(
                  _isReachable ? 'ACCESS YOUR ACCOUNT' : 'CONNECT TO INSTANCE',
                  style: TextStyle(color: PaceColors.getSecondaryText(isDark), fontSize: 10, fontWeight: FontWeight.bold, letterSpacing: 2),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 8),
                Text(
                  _isReachable ? 'Enter your credentials' : 'Enter your account details',
                  style: TextStyle(color: PaceColors.getPrimaryText(isDark), fontSize: 20, fontWeight: FontWeight.bold, letterSpacing: -0.5),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 40),

                if (!_isReachable) ...[
                  _buildTextField(_subdomainController, 'ACCOUNT NAME', Icons.business, hint: 'e.g. cloud', isDark: isDark),
                  const SizedBox(height: 20),
                  _buildLabel('SELECT DOMAIN', isDark),
                  _buildDomainDropdown(isDark),
                  const SizedBox(height: 32),
                  _buildButton(
                    onPressed: _handleVerifyInstance,
                    label: 'VERIFY ACCOUNT',
                    isLoading: _isLoading,
                  ),
                ] else ...[
                  _buildInstanceInfo(isDark),
                  const SizedBox(height: 24),
                  _buildTextField(_usernameController, 'USERNAME', Icons.person_outline, isDark: isDark),
                  const SizedBox(height: 16),
                  _buildTextField(
                    _passwordController, 
                    'PASSWORD', 
                    Icons.lock_outline, 
                    obscure: !_showPassword,
                    isDark: isDark,
                    suffix: IconButton(
                      icon: Icon(_showPassword ? Icons.visibility_off : Icons.visibility, color: PaceColors.getDimText(isDark), size: 20),
                      onPressed: () => setState(() => _showPassword = !_showPassword),
                    )
                  ),
                  const SizedBox(height: 32),
                  _buildButton(
                    onPressed: _handleLogin,
                    label: 'SIGN IN',
                    isLoading: _isLoading,
                  ),
                  TextButton(
                    onPressed: () => setState(() => _isReachable = false),
                    child: Text('Change Account', style: TextStyle(color: PaceColors.getSecondaryText(isDark), fontWeight: FontWeight.bold)),
                  ),
                ],
                
                if (settings.accounts.isNotEmpty && !_isReachable) ...[
                  const SizedBox(height: 40),
                  Text(
                    'SAVED ACCOUNTS',
                    style: TextStyle(color: PaceColors.getDimText(isDark), fontSize: 10, fontWeight: FontWeight.bold, letterSpacing: 1),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 16),
                  _buildRecentAccounts(settings, isDark),
                ],
                
                const SizedBox(height: 40),
                Center(
                  child: Text(
                    'PaceWISP v1.0 • SECURE',
                    style: TextStyle(color: PaceColors.getDimText(isDark), fontSize: 8, fontWeight: FontWeight.bold, letterSpacing: 1),
                  ),
                ),
                const SizedBox(height: 24),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildLogo(bool isDark) {
    return Center(
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: isDark ? PaceColors.purple.withOpacity(0.1) : PaceColors.purple.withOpacity(0.05),
          shape: BoxShape.circle,
        ),
        child: Image.asset(
          'assets/images/logoc.png',
          height: 60,
          errorBuilder: (_, __, ___) => const Icon(Icons.wifi, color: PaceColors.purple, size: 48),
        ),
      ),
    );
  }

  Widget _buildTextField(TextEditingController controller, String label, IconData icon, {bool obscure = false, Widget? suffix, String? hint, required bool isDark}) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildLabel(label, isDark),
        TextField(
          controller: controller,
          obscureText: obscure,
          style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: PaceColors.getPrimaryText(isDark)),
          decoration: InputDecoration(
            hintText: hint,
            hintStyle: TextStyle(color: PaceColors.getDimText(isDark), fontSize: 13),
            prefixIcon: Icon(icon, color: PaceColors.purple, size: 20),
            suffixIcon: suffix,
            filled: true,
            fillColor: PaceColors.getCard(isDark),
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: BorderSide.none),
            enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: BorderSide(color: PaceColors.getBorder(isDark), width: 1)),
            focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: const BorderSide(color: PaceColors.purple, width: 2)),
            contentPadding: const EdgeInsets.symmetric(vertical: 18, horizontal: 20),
          ),
        ),
      ],
    );
  }

  Widget _buildLabel(String text, bool isDark) {
    return Padding(
      padding: const EdgeInsets.only(left: 4, bottom: 8),
      child: Text(text, style: TextStyle(color: PaceColors.getSecondaryText(isDark), fontSize: 9, fontWeight: FontWeight.bold, letterSpacing: 1)),
    );
  }

  Widget _buildDomainDropdown(bool isDark) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      decoration: BoxDecoration(
        color: PaceColors.getCard(isDark),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: PaceColors.getBorder(isDark), width: 1),
      ),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<String>(
          value: _selectedDomain,
          isExpanded: true,
          dropdownColor: PaceColors.getCard(isDark),
          style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: PaceColors.getPrimaryText(isDark)),
          items: _domains.map((d) => DropdownMenuItem(value: d, child: Text(d))).toList(),
          onChanged: (val) => setState(() => _selectedDomain = val!),
        ),
      ),
    );
  }

  Widget _buildButton({required VoidCallback onPressed, required String label, required bool isLoading}) {
    return SizedBox(
      height: 56,
      child: ElevatedButton(
        onPressed: isLoading ? null : onPressed,
        style: ElevatedButton.styleFrom(
          backgroundColor: PaceColors.purple,
          foregroundColor: Colors.white,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          elevation: 0,
        ),
        child: isLoading
            ? const SizedBox(height: 24, width: 24, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
            : Text(label, style: const TextStyle(fontWeight: FontWeight.bold, letterSpacing: 1, fontSize: 16)),
      ),
    );
  }

  Widget _buildInstanceInfo(bool isDark) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: PaceColors.purple.withOpacity(0.05),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: PaceColors.purple.withOpacity(0.2)),
      ),
      child: Row(
        children: [
          const Icon(Icons.check_circle, color: PaceColors.emerald, size: 20),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('CONNECTED TO', style: TextStyle(color: PaceColors.getDimText(isDark), fontSize: 8, fontWeight: FontWeight.bold)),
                Text('${_subdomainController.text}.${_selectedDomain}', style: TextStyle(color: PaceColors.getPrimaryText(isDark), fontWeight: FontWeight.bold)),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildRecentAccounts(SettingsProvider settings, bool isDark) {
    return SizedBox(
      height: 60,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        itemCount: settings.accounts.length,
        separatorBuilder: (_, __) => const SizedBox(width: 12),
        itemBuilder: (context, index) {
          final acc = settings.accounts[index];
          return GestureDetector(
            onTap: () {
              setState(() {
                _subdomainController.text = acc.subdomain;
                _selectedDomain = acc.domain;
                _usernameController.text = acc.accountName;
                _isReachable = false;
              });
            },
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              decoration: BoxDecoration(
                color: PaceColors.getCard(isDark),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: PaceColors.getBorder(isDark)),
              ),
              child: Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(acc.subdomain, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: PaceColors.purple)),
                    Text(acc.domain, style: TextStyle(fontSize: 9, color: PaceColors.getDimText(isDark))),
                  ],
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}
