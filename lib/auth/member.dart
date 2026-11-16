/// Only the member fields explicitly returned by the API.
class Member {
  const Member({
    required this.id,
    required this.name,
    required this.email,
    this.fullName,
    this.school,
    this.avatarUrl,
  });

  final int id;
  final String name;
  final String email;
  final String? fullName;
  final String? school;
  final Uri? avatarUrl;

  factory Member.fromJson(Map<String, dynamic> json, {Uri? origin}) {
    final avatar = json['avatar_url'];
    final uri = avatar is String && avatar.isNotEmpty
        ? Uri.tryParse(avatar)
        : null;
    final resolved = uri == null ? null : origin?.resolveUri(uri) ?? uri;
    return Member(
      id: json['id'] as int,
      name: json['name'] as String,
      email: json['email'] as String,
      fullName: json['full_name'] as String?,
      school: json['school'] as String?,
      avatarUrl:
          resolved != null &&
              resolved.hasAuthority &&
              resolved.userInfo.isEmpty &&
              (resolved.scheme == 'https' ||
                  (resolved.scheme == 'http' &&
                      resolved.origin == origin?.origin))
          ? resolved
          : null,
    );
  }
}
