import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../core/models/item.dart';

class LocalLabelScreen extends StatefulWidget {
  const LocalLabelScreen({super.key, this.item});

  final PosItem? item;

  @override
  State<LocalLabelScreen> createState() => _LocalLabelScreenState();
}

class _LocalLabelScreenState extends State<LocalLabelScreen> {
  late final TextEditingController _name;
  late final TextEditingController _sku;
  late final TextEditingController _price;

  @override
  void initState() {
    super.initState();
    _name = TextEditingController(text: widget.item?.name ?? '');
    _sku = TextEditingController(
      text: widget.item?.sku ?? widget.item?.barcode ?? '',
    );
    _price = TextEditingController(text: widget.item?.price?.toString() ?? '');
  }

  @override
  void dispose() {
    _name.dispose();
    _sku.dispose();
    _price.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final labelText = [
      _name.text.trim(),
      if (_sku.text.trim().isNotEmpty) 'SKU / Barcode: ${_sku.text.trim()}',
      if (_price.text.trim().isNotEmpty) 'Price: ${_price.text.trim()}',
    ].where((part) => part.isNotEmpty).join('\n');

    return Scaffold(
      appBar: AppBar(title: const Text('Local label preview')),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          Text(
            widget.item == null
                ? 'Enter item information manually. This preview is local and is not saved to the POS.'
                : 'Preview based on the item record. This label is not sent to the POS or a printer.',
          ),
          const SizedBox(height: 16),
          TextField(
            controller: _name,
            decoration: const InputDecoration(
              labelText: 'Item name',
              border: OutlineInputBorder(),
            ),
            onChanged: (_) => setState(() {}),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _sku,
            decoration: const InputDecoration(
              labelText: 'SKU or barcode (optional)',
              border: OutlineInputBorder(),
            ),
            onChanged: (_) => setState(() {}),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _price,
            decoration: const InputDecoration(
              labelText: 'Price (optional)',
              border: OutlineInputBorder(),
            ),
            onChanged: (_) => setState(() {}),
          ),
          const SizedBox(height: 20),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(22),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'LABEL PREVIEW',
                    style: TextStyle(
                      fontSize: 11,
                      letterSpacing: 1.2,
                      color: Color(0xFF69756E),
                    ),
                  ),
                  const SizedBox(height: 12),
                  Text(
                    _name.text.isEmpty ? 'Item name' : _name.text,
                    style: Theme.of(context).textTheme.titleLarge
                        ?.copyWith(fontWeight: FontWeight.w700),
                  ),
                  if (_sku.text.isNotEmpty) Text('SKU / Barcode: ${_sku.text}'),
                  if (_price.text.isNotEmpty)
                    Text(
                      'Price: ${_price.text}',
                      style: const TextStyle(fontWeight: FontWeight.w600),
                    ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 12),
          FilledButton.icon(
            onPressed: labelText.isEmpty
                ? null
                : () async {
                    await Clipboard.setData(ClipboardData(text: labelText));
                    if (context.mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('Label text copied')),
                      );
                    }
                  },
            icon: const Icon(Icons.copy),
            label: const Text('Copy label text'),
          ),
        ],
      ),
    );
  }
}
