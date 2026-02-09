enum UserRole {
  admin,
  staff,
  supervisor,
}

extension UserRoleX on UserRole {
  static UserRole fromString(String role) {
    switch (role.toLowerCase()) {
      case 'admin':
        return UserRole.admin;
      case 'staff':
        return UserRole.staff;
      case 'supervisor':
        return UserRole.supervisor;
      default:
        throw Exception('Unknown role: $role');
    }
  }
}
