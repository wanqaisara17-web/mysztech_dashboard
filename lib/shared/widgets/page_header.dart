import 'package:flutter/material.dart';

class PageHeader extends StatelessWidget {
  const PageHeader({super.key, required this.subtitle});

  final String subtitle;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.fromLTRB(20, 16, 16, 18),
    child: Row(
      children: [
        Container(
          width: 46,
          height: 46,
          decoration: BoxDecoration(
            color: const Color(0xFF17834B),
            borderRadius: BorderRadius.circular(15),
          ),
          child: const Icon(Icons.storefront_outlined, color: Colors.white),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Mysztech Store Assistant',
                style: Theme.of(context).textTheme.titleMedium
                    ?.copyWith(fontWeight: FontWeight.w800),
              ),
              const SizedBox(height: 2),
              Text(
                subtitle,
                style: Theme.of(context).textTheme.bodySmall
                    ?.copyWith(color: const Color(0xFF69756E)),
              ),
            ],
          ),
        ),
        IconButton(
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
}
