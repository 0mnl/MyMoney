import '../model/debt.dart';

/// График погашения долга (Bible v2 §7.7, §13).
///
/// Отдельный репозиторий, а не поле внутри `Debt`: позиций графика бывают
/// десятки, они меняются по одной (отметка «оплачено»), и тянуть весь долг
/// целиком ради одной галочки было бы расточительно.
abstract class DebtPaymentRepository {
  Future<void> create(DebtPayment payment);

  /// Массовая вставка — график обычно генерируется целиком.
  Future<void> createAll(List<DebtPayment> payments);

  Future<DebtPayment?> findById(String id);

  /// Позиции одного долга, отсортированные по дате платежа.
  Future<List<DebtPayment>> listByDebt(String debtId);

  Future<void> update(DebtPayment payment);
  Future<void> softDelete(String id);

  /// Мягко удаляет весь график долга — например, при перегенерации.
  Future<void> softDeleteByDebt(String debtId);

  Stream<List<DebtPayment>> watchByDebt(String debtId);
}
