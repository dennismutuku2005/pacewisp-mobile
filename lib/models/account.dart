class PaceAccount {
  final String subdomain;
  final String domain;
  final String accountName;
  final String token;
  final String lastLogin;

  PaceAccount({
    required this.subdomain,
    required this.domain,
    required this.accountName,
    required this.token,
    required this.lastLogin,
  });

  Map<String, dynamic> toJson() => {
    'subdomain': subdomain,
    'domain': domain,
    'accountName': accountName,
    'token': token,
    'lastLogin': lastLogin,
  };

  factory PaceAccount.fromJson(Map<String, dynamic> json) => PaceAccount(
    subdomain: json['subdomain'],
    domain: json['domain'] ?? 'pacewisp.co.ke',
    accountName: json['accountName'],
    token: json['token'],
    lastLogin: json['lastLogin'],
  );
}
