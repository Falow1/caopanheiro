abstract interface class TutorTransportRepository {
  Future<Map<String, dynamic>> transportPolicy();
  Future<List<Map<String, dynamic>>> searchTransportAddress(String query);
  Future<Map<String, dynamic>> quoteTransport(
    bool pickup,
    bool returnTrip,
    Map<String, dynamic> location,
  );
  Future<Map<String, dynamic>> trackTransport(String appointmentId);
}
