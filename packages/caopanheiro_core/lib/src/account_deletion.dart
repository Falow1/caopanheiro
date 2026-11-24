abstract interface class AccountDeletionRepository {
 Future<void> deleteOwnAccount(String password);
}
