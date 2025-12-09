enum UserRole {
  entrepreneur,
  customer,
}

extension UserRoleX on UserRole {
  String get asString {
    switch (this) {
      case UserRole.customer:
        return 'customer';
      case UserRole.entrepreneur:
        return 'entrepreneur';
    }
  }

  static UserRole fromString(String? value) {
    switch (value) {
      case 'customer':
        return UserRole.customer;
      case 'entrepreneur':
      default:
        return UserRole.entrepreneur;
    }
  }
}
