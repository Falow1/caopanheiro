abstract interface class TransportBookingRepository {
  Future<Map<String, dynamic>> bookingPolicy();
  Future<List<Map<String, dynamic>>> searchBookingAddress(String query);
  Future<void> saveBookingPolicy(Map<String, dynamic> policy);
  Future<List<Map<String, dynamic>>> bookingRequests();
  Future<void> decideBookingRequest(Map<String, dynamic> input);
}
