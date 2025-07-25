import 'package:flutter/material.dart';
import 'package:remocall_flutter/utils/theme.dart';

class CustomButton extends StatelessWidget {
  final String text;
  final VoidCallback? onPressed;
  final bool isLoading;
  final bool isGradient;
  final bool isOutlined;
  final IconData? icon;
  final double? width;
  final EdgeInsetsGeometry? padding;

  const CustomButton({
    super.key,
    required this.text,
    required this.onPressed,
    this.isLoading = false,
    this.isGradient = false,
    this.isOutlined = false,
    this.icon,
    this.width,
    this.padding,
  });

  @override
  Widget build(BuildContext context) {
    final isDarkMode = Theme.of(context).brightness == Brightness.dark;
    
    final buttonChild = Row(
      mainAxisAlignment: MainAxisAlignment.center,
      mainAxisSize: MainAxisSize.min,
      children: [
        if (isLoading)
          const SizedBox(
            width: 20,
            height: 20,
            child: CircularProgressIndicator(
              strokeWidth: 2,
              valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
            ),
          )
        else ...[
          if (icon != null) ...[
            Icon(icon, size: 20),
            const SizedBox(width: 8),
          ],
          Flexible(
            child: Text(
              text,
              style: AppTheme.bodyLarge.copyWith(
                fontWeight: FontWeight.w600,
                color: isOutlined 
                  ? (isDarkMode ? AppTheme.primaryLight : AppTheme.primaryColor)
                  : Colors.white,
              ),
              overflow: TextOverflow.ellipsis,
              maxLines: 1,
            ),
          ),
        ],
      ],
    );

    if (isGradient && !isOutlined) {
      return Container(
        width: width ?? double.infinity,
        height: 56,
        decoration: BoxDecoration(
          gradient: onPressed != null
              ? (isDarkMode 
                  ? LinearGradient(
                      colors: [AppTheme.primaryLight, AppTheme.primaryLight.withOpacity(0.7)],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    )
                  : AppTheme.primaryGradient)
              : LinearGradient(
                  colors: isDarkMode 
                    ? [Colors.grey[700]!, Colors.grey[800]!]
                    : [Colors.grey[400]!, Colors.grey[500]!],
                ),
          borderRadius: BorderRadius.circular(12),
          boxShadow: onPressed != null
              ? [
                  BoxShadow(
                    color: (isDarkMode ? AppTheme.primaryLight : AppTheme.primaryColor).withOpacity(0.3),
                    blurRadius: 12,
                    offset: const Offset(0, 4),
                  ),
                ]
              : null,
        ),
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            onTap: isLoading ? null : onPressed,
            borderRadius: BorderRadius.circular(12),
            child: Padding(
              padding: padding ??
                  const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
              child: buttonChild,
            ),
          ),
        ),
      );
    }

    if (isOutlined) {
      return SizedBox(
        width: width ?? double.infinity,
        height: 56,
        child: OutlinedButton(
          onPressed: isLoading ? null : onPressed,
          style: OutlinedButton.styleFrom(
            side: BorderSide(
              color: onPressed != null
                  ? (isDarkMode ? AppTheme.primaryLight : AppTheme.primaryColor)
                  : (isDarkMode ? Colors.grey[600]! : Colors.grey[400]!),
              width: 2,
            ),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
            padding: padding ??
                const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
          ),
          child: buttonChild,
        ),
      );
    }

    return SizedBox(
      width: width ?? double.infinity,
      height: 56,
      child: ElevatedButton(
        onPressed: isLoading ? null : onPressed,
        style: ElevatedButton.styleFrom(
          backgroundColor: isDarkMode ? AppTheme.primaryLight : AppTheme.primaryColor,
          foregroundColor: Colors.white,
          disabledBackgroundColor: isDarkMode ? Colors.grey[700] : Colors.grey[400],
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          elevation: 0,
          padding: padding ??
              const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
        ),
        child: buttonChild,
      ),
    );
  }
}