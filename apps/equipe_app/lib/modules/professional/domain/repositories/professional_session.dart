import '../models.dart';

class ProfessionalCompany {
  const ProfessionalCompany(this.id, this.name, this.professional);
  final String id;
  final String name;
  final Professional professional;
}

abstract interface class ProfessionalSession {
  List<ProfessionalCompany> get companies;
  String? get selectedCompanyId;
  List<Appointment> get confirmedAppointments;
  bool get readOnly;
  DateTime? get updatedAt;
  String? get cacheWarning;
  Future<Professional?> restore();
  Future<Professional> selectCompany(String id);
  Future<void> signOut();
}

abstract interface class AttachedSession {
  bool get hasPendingCommands;
  Future<Professional> attachCompany(String id);
  void detachView();
}
