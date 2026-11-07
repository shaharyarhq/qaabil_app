/// Only the member fields explicitly returned by the API.
class Member {
  const Member({
    required this.id,
    required this.name,
    required this.email,
    this.fullName,
    this.school,
  });

  final int id;
  final String name;
  final String email;
  final String? fullName;
  final String? school;

  factory Member.fromJson(Map<String, dynamic> json) => Member(
    id: json['id'] as int,
    name: json['name'] as String,
    email: json['email'] as String,
    fullName: json['full_name'] as String?,
    school: json['school'] as String?,
  );
}
