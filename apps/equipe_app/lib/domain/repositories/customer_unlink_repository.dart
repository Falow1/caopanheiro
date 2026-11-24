import '../models.dart';

abstract interface class CustomerUnlinkRepository {
  Future<Customer> unlinkCustomerAccount(String customerId);
}
