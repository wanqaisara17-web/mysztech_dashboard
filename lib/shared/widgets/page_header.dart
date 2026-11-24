import 'package:flutter/material.dart';

class PageHeader extends StatelessWidget {
  const PageHeader({super.key, required this.subtitle});

  final String subtitle;

  @override
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (context, constraints) {
      final compact = constraints.maxWidth < 380;
      final iconSize = compact ? 40.0 : 46.0;
      return Padding(
        padding: EdgeInsets.fromLTRB(
          compact ? 12 : 20,
          16,
          compact ? 8 : 16,
          18,
        ),
        child: Row(
          children: [
            Container(
              width: iconSize,
              height: iconSize,
              decoration: BoxDecoration(
                color: const Color(0xFF17834B),
                borderRadius: BorderRadius.circular(15),
              ),
              child: const Icon(Icons.storefront_outlined, color: Colors.white),
            ),
            SizedBox(width: compact ? 8 : 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Mysztech Store Assistant',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: Theme.of(context).textTheme.titleMedium
                        ?.copyWith(fontWeight: FontWeight.w800),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    subtitle,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: Theme.of(context).textTheme.bodySmall
                        ?.copyWith(color: const Color(0xFF69756E)),
                  ),
                ],
              ),
            ),
            IconButton(
              padding: compact ? EdgeInsets.zero : null,
              constraints: compact
                  ? const BoxConstraints.tightFor(width: 38, height: 38)
                  : null,
              onPressed: () {},
              tooltip: 'Profile',
              icon: const CircleAvatar(
                radius: 17,
                backgroundColor: Color(0xFFE8F4EC),
                child: Icon(
                  Icons.person_outline,
                  size: 19,
                  color: Color(0xFF17834B),
                ),
              ),
            ),
          ],
        ),
      );
    },
  );
}
