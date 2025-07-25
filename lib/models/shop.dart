import 'package:remocall_flutter/utils/datetime_utils.dart';

class Shop {
  final int id;
  final String name;
  final String code;
  final String type;
  final bool isActive;
  final DateTime? createdAt;
  
  // 정산 관련 정보
  final String? pricingPlan;
  final String? pricingPlanName;
  final double? feeRate;
  final int? settlementDay;
  final double? monthlyFlatFeeAmount;
  
  // 잔액 정보
  final double currentCreditBalance;
  final double overdraftAmount;
  final double? monthlyPrepaidAmount;
  
  // 도메인 정보
  final Map<String, dynamic>? domain;

  Shop({
    required this.id,
    required this.name,
    required this.code,
    required this.type,
    required this.isActive,
    this.createdAt,
    this.pricingPlan,
    this.pricingPlanName,
    this.feeRate,
    this.settlementDay,
    this.monthlyFlatFeeAmount,
    required this.currentCreditBalance,
    required this.overdraftAmount,
    this.monthlyPrepaidAmount,
    this.domain,
  });

  factory Shop.fromJson(Map<String, dynamic> json) {
    return Shop(
      id: json['id'],
      name: json['name'],
      code: json['code'],
      type: json['type'] ?? 'shop',
      isActive: json['is_active'] ?? true,
      createdAt: json['created_at'] != null ? DateTimeUtils.parseToKST(json['created_at']) : null,
      pricingPlan: json['pricing_plan'],
      pricingPlanName: json['pricing_plan_name'],
      feeRate: _parseDouble(json['fee_rate']),
      settlementDay: json['settlement_day'],
      monthlyFlatFeeAmount: _parseDouble(json['monthly_flat_fee_amount']),
      currentCreditBalance: _parseDouble(json['current_credit_balance']) ?? 0.0,
      overdraftAmount: _parseDouble(json['overdraft_amount']) ?? 0.0,
      monthlyPrepaidAmount: _parseDouble(json['monthly_prepaid_amount']),
      domain: json['domain'],
    );
  }
  
  static double? _parseDouble(dynamic value) {
    if (value == null) return null;
    if (value is double) return value;
    if (value is int) return value.toDouble();
    if (value is String) {
      return double.tryParse(value);
    }
    return null;
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'code': code,
      'type': type,
      'is_active': isActive,
      'created_at': createdAt?.toIso8601String(),
      'pricing_plan': pricingPlan,
      'pricing_plan_name': pricingPlanName,
      'fee_rate': feeRate,
      'settlement_day': settlementDay,
      'monthly_flat_fee_amount': monthlyFlatFeeAmount,
      'current_credit_balance': currentCreditBalance,
      'overdraft_amount': overdraftAmount,
      'monthly_prepaid_amount': monthlyPrepaidAmount,
      'domain': domain,
    };
  }
}