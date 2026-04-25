class PaceAccount {
  final String subdomain;
  final String domain;
  final String accountName;
  final String token;
  final String lastLogin;
  final String type;
  final String? phone;
  final List<String> policies;

  PaceAccount({
    required this.subdomain,
    required this.domain,
    required this.accountName,
    required this.token,
    required this.lastLogin,
    this.type = 'admin',
    this.phone,
    this.policies = const [],
  });

  Map<String, dynamic> toJson() => {
    'subdomain': subdomain,
    'domain': domain,
    'accountName': accountName,
    'token': token,
    'lastLogin': lastLogin,
    'type': type,
    'phone': phone,
    'policies': policies,
  };

  factory PaceAccount.fromJson(Map<String, dynamic> json) => PaceAccount(
    subdomain: json['subdomain'],
    domain: json['domain'] ?? 'pacewisp.co.ke',
    accountName: json['accountName'],
    token: json['token'],
    lastLogin: json['lastLogin'],
    type: json['type'] ?? 'admin',
    phone: json['phone'],
    policies: List<String>.from(json['policies'] ?? []),
  );

  PaceAccount copyWith({
    String? subdomain,
    String? domain,
    String? accountName,
    String? token,
    String? lastLogin,
    String? type,
    String? phone,
    List<String>? policies,
  }) => PaceAccount(
    subdomain: subdomain ?? this.subdomain,
    domain: domain ?? this.domain,
    accountName: accountName ?? this.accountName,
    token: token ?? this.token,
    lastLogin: lastLogin ?? this.lastLogin,
    type: type ?? this.type,
    phone: phone ?? this.phone,
    policies: policies ?? this.policies,
  );
}
