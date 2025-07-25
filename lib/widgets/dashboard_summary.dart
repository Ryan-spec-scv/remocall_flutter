import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:intl/intl.dart';
import 'package:remocall_flutter/utils/theme.dart';

class DashboardSummary extends StatelessWidget {
  final Map<String, dynamic>? dashboardData;
  
  const DashboardSummary({
    super.key,
    required this.dashboardData,
  });

  @override
  Widget build(BuildContext context) {
    print('===== DashboardSummary.build() =====');
    print('dashboardData: $dashboardData');
    print('dashboardData is null: ${dashboardData == null}');
    
    if (dashboardData == null) {
      print('Returning loading placeholder because dashboardData is null');
      print('=====================================');
      // 데이터가 없을 때도 UI 구조를 유지하여 깜빡임 방지
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Center(
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 40),
              child: CircularProgressIndicator(
                color: AppTheme.primaryColor,
              ),
            ),
          ),
        ],
      );
    }
    print('dashboardData is not null, proceeding to render');
    print('=====================================');
    
    final currencyFormatter = NumberFormat.currency(locale: 'ko_KR', symbol: '₩');
    final numberFormatter = NumberFormat('#,###');
    
    // 대시보드 데이터 추출 (안전한 타입 변환)
    final todayStatsData = dashboardData!['today_stats'];
    final todayStats = todayStatsData != null ? Map<String, dynamic>.from(todayStatsData) : <String, dynamic>{};
    
    // 대시보드 데이터에서 추가 정보 추출
    final unsettledFee = dashboardData!['unsettled_fee'] ?? <String, dynamic>{};
    final shopInfo = dashboardData!['shop'] ?? <String, dynamic>{};
    
    // API 데이터 로그 출력
    print('===== 오늘의 요약 API 데이터 =====');
    print('today_stats: $todayStats');
    print('unsettled_fee: $unsettledFee');
    print('shop: $shopInfo');
    print('================================');
    
    // 실제 API 데이터 사용
    final totalStatsData = dashboardData!['total_stats'];
    final totalStats = totalStatsData != null ? Map<String, dynamic>.from(totalStatsData) : <String, dynamic>{};
    
    final monthlyStatsData = dashboardData!['monthly_stats'];
    final monthlyStats = monthlyStatsData != null ? Map<String, dynamic>.from(monthlyStatsData) : <String, dynamic>{};
    
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // 전체 통계 카드 (한줄)
        _buildFullWidthStatCard(
          amount: currencyFormatter.format(totalStats['amount'] ?? 0),
          transactions: '${numberFormatter.format(totalStats['count'] ?? 0)}건',
          fee: currencyFormatter.format(totalStats['fee'] ?? 0),
          icon: Icons.assessment,
          color: AppTheme.primaryColor,
        ).animate().fadeIn(delay: 500.ms).slideY(begin: 0.1, end: 0),
        
        const SizedBox(height: 12),
        
        // 이번달 & 오늘 통계 카드들 (두개)
        Row(
          children: [
            Expanded(
              child: _buildCompactStatCard(
                title: '이번달',
                amount: currencyFormatter.format(monthlyStats['amount'] ?? 0),
                transactions: '${numberFormatter.format(monthlyStats['count'] ?? 0)}건',
                fee: currencyFormatter.format(monthlyStats['fee'] ?? 0),
                icon: Icons.calendar_month,
                color: Colors.blue,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _buildCompactStatCard(
                title: '오늘',
                amount: currencyFormatter.format(todayStats['amount'] ?? 0),
                transactions: '${numberFormatter.format(todayStats['count'] ?? 0)}건',
                fee: currencyFormatter.format(todayStats['fee'] ?? 0),
                icon: Icons.today,
                color: Colors.green,
              ),
            ),
          ],
        ).animate().fadeIn(delay: 600.ms).slideY(begin: 0.1, end: 0),
        
        const SizedBox(height: 24),
      ],
    );
  }
  
  Widget _buildFullWidthStatCard({
    required String amount,
    required String transactions,
    required String fee,
    required IconData icon,
    required Color color,
  }) {
    return Builder(
      builder: (context) => Container(
        width: double.infinity,
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [
              color.withOpacity(0.8),
              color,
            ],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
              color: color.withOpacity(0.3),
              blurRadius: 20,
              offset: const Offset(0, 10),
            ),
          ],
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
          children: [
            _buildStatItem('총 입금', amount, Colors.white),
            _buildStatItem('총 거래건수', transactions, Colors.white),
          ],
        ),
      ),
    );
  }
  
  Widget _buildCompactStatCard({
    required String title,
    required String amount,
    required String transactions,
    required String fee,
    required IconData icon,
    required Color color,
  }) {
    return Builder(
      builder: (context) => Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Theme.of(context).cardTheme.color,
          borderRadius: BorderRadius.circular(12),
          boxShadow: [
            BoxShadow(
              color: Theme.of(context).brightness == Brightness.dark
                  ? Colors.black.withOpacity(0.3)
                  : Colors.grey.withOpacity(0.1),
              blurRadius: 10,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: color.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Icon(
                    icon,
                    size: 16,
                    color: color,
                  ),
                ),
                const SizedBox(width: 8),
                Text(
                  title,
                  style: AppTheme.bodySmall.copyWith(
                    color: Theme.of(context).brightness == Brightness.dark
                        ? Colors.grey[400]
                        : Colors.grey[600],
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            _buildCompactStatItem('입금', amount),
            const SizedBox(height: 8),
            _buildCompactStatItem('거래', transactions),
            const SizedBox(height: 8),
            _buildCompactStatItem('수수료', fee),
          ],
        ),
      ),
    );
  }
  
  Widget _buildStatItem(String label, String value, Color textColor) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Text(
          label,
          style: AppTheme.bodySmall.copyWith(
            color: textColor.withOpacity(0.7),
            fontSize: 13,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          value,
          style: AppTheme.bodyMedium.copyWith(
            color: textColor,
            fontWeight: FontWeight.w700,
            fontSize: 16,
          ),
        ),
      ],
    );
  }
  
  Widget _buildCompactStatItem(String label, String value) {
    return Builder(
      builder: (context) => Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: AppTheme.bodySmall.copyWith(
              color: Theme.of(context).brightness == Brightness.dark
                  ? Colors.grey[500]
                  : Colors.grey[600],
              fontSize: 12,
            ),
          ),
          Text(
            value,
            style: AppTheme.bodySmall.copyWith(
              fontWeight: FontWeight.w600,
              fontSize: 12,
            ),
          ),
        ],
      ),
    );
  }
}