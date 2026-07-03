// lib/features/certificates/cubit/certificates_state.dart
import 'package:equatable/equatable.dart';

import '../../../models/certificate_entity.dart';

abstract class CertificatesState extends Equatable {
  const CertificatesState();

  @override
  List<Object?> get props => [];
}

class CertificatesInitial extends CertificatesState {}

class CertificatesLoading extends CertificatesState {}

class CertificatesLoaded extends CertificatesState {
  final List<CertificateEntity> certificates;

  const CertificatesLoaded(this.certificates);

  @override
  List<Object?> get props => [certificates];
}

class CertificatesEmpty extends CertificatesState {}

class CertificatesError extends CertificatesState {
  final String message;
  const CertificatesError(this.message);

  @override
  List<Object?> get props => [message];
}
