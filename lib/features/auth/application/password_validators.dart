String? validateNewPassword(String? value) {
  final password = value ?? '';
  if (password.isEmpty) {
    return 'Password is required.';
  }
  if (password.length < 6) {
    return 'Password must be at least 6 characters.';
  }
  return null;
}

String? validateConfirmPassword(String? value, String newPassword) {
  final confirm = value ?? '';
  if (confirm.isEmpty) {
    return 'Please confirm your new password.';
  }
  if (confirm != newPassword) {
    return 'Passwords do not match.';
  }
  return null;
}