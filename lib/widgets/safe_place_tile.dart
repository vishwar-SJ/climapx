import 'package:flutter/material.dart';
import '../../models/safe_place_model.dart';

/// Safe Place Tile - Shows nearby emergency resources
class SafePlaceTile extends StatelessWidget {
  final SafePlace place;
  final VoidCallback? onNavigate;
  final VoidCallback? onCall;

  const SafePlaceTile({
    super.key,
    required this.place,
    this.onNavigate,
    this.onCall,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 0, vertical: 4),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Row(
          children: [
            // Type Icon
            Container(
              width: 48,
              height: 48,
              decoration: BoxDecoration(
                color: _getTypeColor().withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Center(
                child: Text(
                  place.typeIcon,
                  style: const TextStyle(fontSize: 24),
                ),
              ),
            ),
            const SizedBox(width: 12),
            // Place Info
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    place.name,
                    style: const TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w700,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 2),
                  Text(
                    place.address,
                    style: TextStyle(
                      fontSize: 12,
                      color: Colors.grey.shade600,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                        decoration: BoxDecoration(
                          color: _getTypeColor().withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Text(
                          place.typeLabel,
                          style: TextStyle(
                            fontSize: 10,
                            color: _getTypeColor(),
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                      if (place.rating != null && place.rating! > 0) ...[
                        const SizedBox(width: 8),
                        Icon(Icons.star, size: 14, color: Colors.amber.shade700),
                        const SizedBox(width: 2),
                        Text(
                          place.rating!.toStringAsFixed(1),
                          style: TextStyle(
                            fontSize: 12,
                            color: Colors.grey.shade700,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                      if (place.isOpen) ...[
                        const SizedBox(width: 8),
                        Container(
                          width: 6,
                          height: 6,
                          decoration: const BoxDecoration(
                            color: Colors.green,
                            shape: BoxShape.circle,
                          ),
                        ),
                        const SizedBox(width: 4),
                        const Text(
                          'Open',
                          style: TextStyle(fontSize: 11, color: Colors.green),
                        ),
                      ],
                    ],
                  ),
                ],
              ),
            ),
            // Actions
            Column(
              children: [
                IconButton(
                  onPressed: onNavigate,
                  icon: const Icon(Icons.directions, color: Colors.blue),
                  iconSize: 22,
                  tooltip: 'Navigate',
                ),
                if (place.phoneNumber != null)
                  IconButton(
                    onPressed: onCall,
                    icon: const Icon(Icons.phone, color: Colors.green),
                    iconSize: 22,
                    tooltip: 'Call',
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Color _getTypeColor() {
    switch (place.type) {
      case SafePlaceType.hospital:
        return Colors.red;
      case SafePlaceType.shelter:
        return Colors.indigo;
      case SafePlaceType.fireStation:
        return Colors.orange;
      case SafePlaceType.policeStation:
        return Colors.blue;
      case SafePlaceType.pharmacy:
        return Colors.green;
      case SafePlaceType.reliefCenter:
        return Colors.teal;
      case SafePlaceType.waterSource:
        return Colors.cyan;
      case SafePlaceType.foodDistribution:
        return Colors.brown;
    }
  }
}
