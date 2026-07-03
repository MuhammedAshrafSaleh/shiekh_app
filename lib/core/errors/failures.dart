// lib/core/errors/failures.dart
import 'package:equatable/equatable.dart';

abstract class Failure extends Equatable {
  final String message;
  const Failure(this.message);

  @override
  List<Object?> get props => [message];
}

class ServerFailure extends Failure {
  const ServerFailure(super.message);
}

class NetworkFailure extends Failure {
  const NetworkFailure(super.message);
}

class AuthFailure extends Failure {
  const AuthFailure(super.message);
}

class PermissionFailure extends Failure {
  const PermissionFailure(super.message);
}

class ValidationFailure extends Failure {
  const ValidationFailure(super.message);
}

class EnrollmentRequiredFailure extends Failure {
  const EnrollmentRequiredFailure(
      [super.message = 'يجب التسجيل في الكتاب أولاً']);
}

class AttemptsExhaustedFailure extends Failure {
  const AttemptsExhaustedFailure(
      [super.message = 'لقد استنفدت جميع محاولاتك المسموحة']);
}

class NotEnrolledFailure extends Failure {
  const NotEnrolledFailure([super.message = 'غير مسجّل في هذا الكتاب']);
}

class DeleteRestrictedFailure extends Failure {
  const DeleteRestrictedFailure([super.message = 'لا يمكن الحذف لوجود بيانات مرتبطة']);
}
