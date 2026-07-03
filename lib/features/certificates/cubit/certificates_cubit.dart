// lib/features/certificates/cubit/certificates_cubit.dart
import 'package:flutter_bloc/flutter_bloc.dart';

import '../data/certificate_repository.dart';
import 'certificates_state.dart';

class CertificatesCubit extends Cubit<CertificatesState> {
  final CertificateRepository _repo;

  CertificatesCubit(this._repo) : super(CertificatesInitial());

  Future<void> loadCertificates() async {
    emit(CertificatesLoading());
    final result = await _repo.getCertificates();
    result.fold(
      (f) => emit(CertificatesError(f.message)),
      (certs) => certs.isEmpty
          ? emit(CertificatesEmpty())
          : emit(CertificatesLoaded(certs)),
    );
  }
}
