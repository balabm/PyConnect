import 'package:flutter/material.dart';

/// Star rating row with optional numeric value.
class RatingStars extends StatelessWidget {
  const RatingStars({
    super.key,
    required this.rating,
    this.reviewCount,
    this.size = 14,
    this.color = const Color(0xFFE9C46A),
  });

  final double rating;
  final int? reviewCount;
  final double size;
  final Color color;

  @override
  Widget build(BuildContext context) {
    final fullStars = rating.floor();
    final hasHalf = (rating - fullStars) >= 0.25 && (rating - fullStars) < 0.75;
    final roundedUp = (rating - fullStars) >= 0.75;

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        for (int i = 0; i < 5; i++)
          Icon(
            i < fullStars || (i == fullStars && roundedUp)
                ? Icons.star
                : (i == fullStars && hasHalf)
                    ? Icons.star_half
                    : Icons.star_border,
            size: size,
            color: color,
          ),
        const SizedBox(width: 4),
        Text(
          reviewCount != null
              ? '${rating.toStringAsFixed(1)} ($reviewCount)'
              : rating.toStringAsFixed(1),
          style: TextStyle(
            fontSize: size - 2,
            fontWeight: FontWeight.w500,
            color: Colors.grey.shade700,
          ),
        ),
      ],
    );
  }
}
