class AuthenticatedUser {
  const AuthenticatedUser({required this.name, this.email, this.accountId});

  final String name;
  final String? email;
  final String? accountId;

  String? get notificationAccountIdentity {
    final id = accountId?.trim();
    if (id != null && id.isNotEmpty) return id;
    final normalizedEmail = email?.trim().toLowerCase();
    return normalizedEmail == null || normalizedEmail.isEmpty
        ? null
        : normalizedEmail;
  }
}
