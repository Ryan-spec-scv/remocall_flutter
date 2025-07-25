import 'package:flutter/material.dart';
import 'package:remocall_flutter/models/transaction_model.dart';
import 'package:remocall_flutter/screens/transactions/transaction_detail_screen.dart';
import 'package:remocall_flutter/utils/theme.dart';
import 'package:remocall_flutter/utils/datetime_utils.dart';
import 'package:intl/intl.dart';

class TransactionListItem extends StatelessWidget {
  final TransactionModel transaction;
  final NumberFormat currencyFormatter = NumberFormat.currency(locale: 'ko_KR', symbol: '');

  TransactionListItem({
    super.key,
    required this.transaction,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    
    return InkWell(
      onTap: () {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => TransactionDetailScreen(transaction: transaction),
          ),
        );
      },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        decoration: BoxDecoration(
          border: Border(
            bottom: BorderSide(
              color: Theme.of(context).brightness == Brightness.dark
                  ? Colors.grey[800]!
                  : Colors.grey[200]!,
              width: 1,
            ),
          ),
        ),
        child: LayoutBuilder(
        builder: (context, constraints) {
          final totalWidth = constraints.maxWidth;
          return Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              // QR주소
              SizedBox(
                width: totalWidth * 0.2,
                child: Text(
                  transaction.description.isNotEmpty ? transaction.description : 'QR결제',
                  style: TextStyle(
                    fontSize: 12,
                  ),
                  overflow: TextOverflow.ellipsis,
                  maxLines: 1,
                  textAlign: TextAlign.center,
                ),
              ),
              
              // 입금자
              SizedBox(
                width: totalWidth * 0.2,
                child: Text(
                  transaction.sender ?? '알 수 없음',
                  style: TextStyle(
                    fontSize: 13,
                  ),
                  overflow: TextOverflow.ellipsis,
                  maxLines: 1,
                  textAlign: TextAlign.center,
                ),
              ),
              
              // 금액
              SizedBox(
                width: totalWidth * 0.4,
                child: Text(
                  currencyFormatter.format(transaction.amount),
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.bold,
                  ),
                  textAlign: TextAlign.center,
                ),
              ),
              
              // 날짜
              SizedBox(
                width: totalWidth * 0.2,
                child: FittedBox(
                  fit: BoxFit.scaleDown,
                  alignment: Alignment.centerRight,
                  child: Text(
                    DateTimeUtils.getKSTShortDateTimeString(transaction.createdAt),
                    style: TextStyle(
                      fontSize: 11,
                      color: Theme.of(context).textTheme.bodySmall!.color!.withOpacity(0.7),
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.visible,
                  ),
                ),
              ),
            ],
          );
        },
      ),
      ),
    );
  }
}