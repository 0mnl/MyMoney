import 'package:flutter/material.dart';

/// Единая реакция на функцию, закрытую флагом из `FeatureFlags`.
///
/// Намеренно ничего не блокирует и никуда не ведёт: короткое исчезающее
/// сообщение и всё. Пользователь понимает, что функция существует и появится,
/// а не что приложение сломалось.
///
/// Одна точка на все такие места — чтобы формулировка и поведение не
/// разъезжались по экранам.
void showUnderDevelopment(BuildContext context, String feature) {
  final messenger = ScaffoldMessenger.maybeOf(context);
  if (messenger == null) return;

  messenger
    // Без этого при быстрых повторных тапах сообщения выстраиваются в
    // очередь и последнее висит ещё несколько секунд после ухода с экрана.
    ..hideCurrentSnackBar()
    ..showSnackBar(
      SnackBar(
        content: Text('$feature — в разработке'),
        duration: const Duration(milliseconds: 1800),
        behavior: SnackBarBehavior.floating,
        margin: const EdgeInsets.all(16),
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.all(Radius.circular(12)),
        ),
      ),
    );
}
