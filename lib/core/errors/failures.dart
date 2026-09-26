class AuthFailure extends Failure {
  const AuthFailure(super.message);
}

/// The email belongs to an existing account (Supabase `email_exists`). A guest
/// converting to this email must sign into that account instead. Subclasses
/// [AuthFailure] so existing `is AuthFailure` handling still applies.
class EmailAlreadyInUseFailure extends AuthFailure {
  const EmailAlreadyInUseFailure(super.message);
}

class PermissionFailure extends Failure {
  const PermissionFailure(super.message);
}
