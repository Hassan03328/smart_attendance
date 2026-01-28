class Validators {
  /// Detect role from email domain
  static String? getRoleFromEmail(String email) {
    final e = email.trim().toLowerCase();

    // Lecturer
    if (e.endsWith('@arabou.edu.sa')) {
      return 'lecturer';
    }

    // Student
    if (e.endsWith('@aou.edu.sa')) {
      return 'student';
    }

    return null;
  }

  /// Password rules
  static bool isValidPassword(String password) {
    if (password.length < 8 || password.length > 24) return false;
    if (!RegExp(r'[A-Z]').hasMatch(password)) return false;
    if (!RegExp(r'[a-z]').hasMatch(password)) return false;
    if (!RegExp(r'\d').hasMatch(password)) return false;
    if (!RegExp(r'[!@#\$&*~]').hasMatch(password)) return false;
    return true;
  }
}
