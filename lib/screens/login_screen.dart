import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:lucide_icons/lucide_icons.dart';
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
  final List<String> _domains = [
    'pacewisp.co.ke', 
    'pace.com', 
  ];

  @override
  void dispose() {
    _subdomainController.dispose();
    _usernameController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _handleVerifyInstance() async {
    final subdomain = _subdomainController.text.trim();
    if (subdomain.isEmpty) {
      _showError('Please enter account name / subdomain');
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
        _showError('Instance unreachable. Check Account Name and Domain.');
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
          final userData = res['data']?['user'] ?? {};
          final type = userData['type']?.toString() ?? 'admin';
          final policies = List<String>.from(userData['policies'] ?? []);
          
          await settings.login(
            _subdomainController.text.trim(), 
            _selectedDomain, 
            username, 
            token,
            type: type,
            policies: policies,
          );
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
      _showError('Login service unavailable: $e');
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _showError(String msg) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(msg, style: GoogleFonts.figtree(color: Colors.white, fontWeight: FontWeight.w600)),
        backgroundColor: PaceColors.red,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
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
          padding: const EdgeInsets.symmetric(horizontal: 24.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const SizedBox(height: 48),
              _buildLogo(isDark),
              const SizedBox(height: 24),
              Text(
                _isReachable ? 'Account Credentials' : 'Connect to Instance',
                style: GoogleFonts.figtree(
                  color: PaceColors.purple,
                  fontSize: 22,
                  fontWeight: FontWeight.w700,
                  letterSpacing: -0.5,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 4),
              Text(
                _isReachable ? 'Sign in to access management dashboard' : 'Enter your WISP subdomain and domain to continue',
                style: GoogleFonts.figtree(
                  color: PaceColors.getDimText(isDark),
                  fontSize: 12,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 32),

              if (!_isReachable) ...[
                _buildTextField(
                  _subdomainController,
                  'Subdomain / Account Name',
                  LucideIcons.globe,
                  hint: 'e.g. cloud',
                  isDark: isDark,
                ),
                const SizedBox(height: 16),
                _buildLabel('Select Domain', isDark),
                _buildDomainDropdown(isDark),
                const SizedBox(height: 24),
                _buildButton(
                  onPressed: _handleVerifyInstance,
                  label: 'Verify Instance',
                  isLoading: _isLoading,
                  isDark: isDark,
                ),
              ] else ...[
                _buildInstanceInfo(isDark),
                const SizedBox(height: 20),
                _buildTextField(
                  _usernameController,
                  'Username',
                  LucideIcons.user,
                  hint: 'admin',
                  isDark: isDark,
                ),
                const SizedBox(height: 16),
                _buildTextField(
                  _passwordController,
                  'Password',
                  LucideIcons.lock,
                  obscure: !_showPassword,
                  isDark: isDark,
                  suffix: IconButton(
                    icon: Icon(_showPassword ? LucideIcons.eyeOff : LucideIcons.eye, color: PaceColors.getDimText(isDark), size: 18),
                    onPressed: () => setState(() => _showPassword = !_showPassword),
                  ),
                ),
                const SizedBox(height: 24),
                _buildButton(
                  onPressed: _handleLogin,
                  label: 'Sign In',
                  isLoading: _isLoading,
                  isDark: isDark,
                ),
                const SizedBox(height: 8),
                TextButton(
                  onPressed: () => setState(() => _isReachable = false),
                  child: Text(
                    'Change Instance',
                    style: GoogleFonts.figtree(color: PaceColors.purple, fontWeight: FontWeight.w600, fontSize: 13),
                  ),
                ),
              ],
              
              if (settings.accounts.isNotEmpty && !_isReachable) ...[
                const SizedBox(height: 36),
                Row(
                  children: [
                    const Expanded(child: Divider()),
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 12),
                      child: Text(
                        'SAVED ACCOUNTS',
                        style: GoogleFonts.figtree(color: PaceColors.getDimText(isDark), fontSize: 10, fontWeight: FontWeight.w700, letterSpacing: 1),
                      ),
                    ),
                    const Expanded(child: Divider()),
                  ],
                ),
                const SizedBox(height: 16),
                _buildRecentAccounts(settings, isDark),
              ],
              
              const SizedBox(height: 36),
              Center(
                child: Column(
                  children: [
                    Text(
                      'Pace Management Portal',
                      style: GoogleFonts.figtree(color: PaceColors.getDimText(isDark), fontSize: 10, fontWeight: FontWeight.w600),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      'Version ${settings.appVersion}',
                      style: GoogleFonts.figtree(color: PaceColors.getDimText(isDark).withOpacity(0.6), fontSize: 9),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 24),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildLogo(bool isDark) {
    return Center(
      child: Image.asset(
        'assets/images/logo.png',
        height: 52,
        errorBuilder: (_, __, ___) => Image.asset(
          'assets/images/logoc.png',
          height: 52,
          errorBuilder: (ctx, _, __) => const Icon(LucideIcons.wifi, color: PaceColors.purple, size: 36),
        ),
      ),
    );
  }

  Widget _buildTextField(
    TextEditingController controller,
    String label,
    IconData icon, {
    bool obscure = false,
    Widget? suffix,
    String? hint,
    required bool isDark,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildLabel(label, isDark),
        TextField(
          controller: controller,
          obscureText: obscure,
          style: GoogleFonts.figtree(fontSize: 14, fontWeight: FontWeight.w600, color: PaceColors.getPrimaryText(isDark)),
          decoration: InputDecoration(
            hintText: hint,
            hintStyle: GoogleFonts.figtree(color: PaceColors.getDimText(isDark), fontSize: 13),
            prefixIcon: Icon(icon, color: PaceColors.purple, size: 18),
            suffixIcon: suffix,
            filled: true,
            fillColor: PaceColors.getCard(isDark),
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: BorderSide(color: PaceColors.getBorder(isDark))),
            enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: BorderSide(color: PaceColors.getBorder(isDark))),
            focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: const BorderSide(color: PaceColors.purple, width: 1.5)),
            contentPadding: const EdgeInsets.symmetric(vertical: 14, horizontal: 16),
          ),
        ),
      ],
    );
  }

  Widget _buildLabel(String text, bool isDark) {
    return Padding(
      padding: const EdgeInsets.only(left: 2, bottom: 6),
      child: Text(
        text,
        style: GoogleFonts.figtree(color: PaceColors.getSecondaryText(isDark), fontSize: 11, fontWeight: FontWeight.w600),
      ),
    );
  }

  Widget _buildDomainDropdown(bool isDark) {
    return Container(
      height: 48,
      padding: const EdgeInsets.symmetric(horizontal: 14),
      decoration: BoxDecoration(
        color: PaceColors.getCard(isDark),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: PaceColors.getBorder(isDark)),
      ),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<String>(
          value: _selectedDomain,
          isExpanded: true,
          dropdownColor: PaceColors.getCard(isDark),
          style: GoogleFonts.figtree(fontSize: 13, fontWeight: FontWeight.w600, color: PaceColors.getPrimaryText(isDark)),
          items: _domains.map((d) => DropdownMenuItem(value: d, child: Text(d))).toList(),
          onChanged: (val) => setState(() => _selectedDomain = val!),
        ),
      ),
    );
  }

  Widget _buildButton({
    required VoidCallback onPressed,
    required String label,
    required bool isLoading,
    required bool isDark,
  }) {
    return SizedBox(
      height: 48,
      child: ElevatedButton(
        onPressed: isLoading ? null : onPressed,
        style: ElevatedButton.styleFrom(
          backgroundColor: PaceColors.purple,
          foregroundColor: Colors.white,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
          elevation: 0,
        ),
        child: isLoading
            ? const SizedBox(height: 20, width: 20, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
            : Text(label, style: GoogleFonts.figtree(fontWeight: FontWeight.w700, fontSize: 13)),
      ),
    );
  }

  Widget _buildInstanceInfo(bool isDark) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: PaceColors.purple.withOpacity(0.06),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: PaceColors.purple.withOpacity(0.2)),
      ),
      child: Row(
        children: [
          const Icon(LucideIcons.checkCircle2, color: PaceColors.green, size: 18),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Connected Instance', style: GoogleFonts.figtree(color: PaceColors.getDimText(isDark), fontSize: 9, fontWeight: FontWeight.w600)),
                Text('${_subdomainController.text}.${_selectedDomain}', style: GoogleFonts.figtree(color: PaceColors.purple, fontWeight: FontWeight.w700, fontSize: 12)),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildRecentAccounts(SettingsProvider settings, bool isDark) {
    return Column(
      children: List.generate(settings.accounts.length, (index) {
        final acc = settings.accounts[index];
        return Container(
          margin: const EdgeInsets.only(bottom: 8),
          decoration: BoxDecoration(
            color: PaceColors.getCard(isDark),
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: PaceColors.getBorder(isDark)),
          ),
          child: ListTile(
            dense: true,
            onTap: () {
              settings.switchAccount(index);
              Navigator.of(context).pushReplacement(MaterialPageRoute(builder: (_) => const MainScaffold()));
            },
            leading: Container(
              padding: const EdgeInsets.all(6),
              decoration: BoxDecoration(color: PaceColors.purple.withOpacity(0.08), borderRadius: BorderRadius.circular(6)),
              child: const Icon(LucideIcons.globe, size: 16, color: PaceColors.purple),
            ),
            title: Text(
              acc.accountName,
              style: GoogleFonts.figtree(fontSize: 13, fontWeight: FontWeight.w700, color: PaceColors.getPrimaryText(isDark)),
            ),
            subtitle: Text(
              "${acc.subdomain}.${acc.domain}",
              style: GoogleFonts.figtree(fontSize: 11, color: PaceColors.getDimText(isDark)),
            ),
            trailing: const Icon(LucideIcons.chevronRight, size: 16, color: Colors.grey),
          ),
        );
      }),
    );
  }
}
