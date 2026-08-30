import 'package:flutter/material.dart';

import '../../core/theme/app_colors.dart';
import '../../models/enums.dart';
import '../add_transaction/add_transaction_screen.dart';

/// The prominent central action of the navigation bar.
class AddButton extends StatelessWidget {
  const AddButton({super.key, this.type});

  final TransactionType? type;

  @override
  Widget build(BuildContext context) {
    final palette = context.finance;

    return Semantics(
      button: true,
      label: 'Add a transaction',
      excludeSemantics: true,
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: () => openAddTransaction(context, type: type),
          customBorder: const CircleBorder(),
          child: Container(
            width: 54,
            height: 54,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: palette.brandGradient,
              ),
              boxShadow: <BoxShadow>[
                BoxShadow(
                  color: palette.brandGradient.last.withValues(alpha: 0.45),
                  blurRadius: 18,
                  offset: const Offset(0, 6),
                ),
              ],
            ),
            child: const Icon(Icons.add_rounded, color: Colors.white, size: 28),
          ),
        ),
      ),
    );
  }
}

/// Opens the Add / Edit transaction screen.
Future<bool?> openAddTransaction(
  BuildContext context, {
  TransactionType? type,
  int? transactionId,
  int? goalId,
}) {
  return Navigator.of(context).push<bool>(
    MaterialPageRoute<bool>(
      fullscreenDialog: true,
      builder: (context) => AddTransactionScreen(
        initialType: type,
        transactionId: transactionId,
        initialGoalId: goalId,
      ),
    ),
  );
}
