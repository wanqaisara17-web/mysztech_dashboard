import 'package:flutter/material.dart';

import '../../../core/local/local_workspace.dart';
import '../../../core/models/local_product.dart';

class LocalProductFormScreen extends StatefulWidget {
  const LocalProductFormScreen({
    super.key,
    required this.workspace,
    this.product,
  });

  final LocalWorkspace workspace;
  final LocalProduct? product;

  @override
  State<LocalProductFormScreen> createState() => _LocalProductFormScreenState();
}

class _LocalProductFormScreenState extends State<LocalProductFormScreen> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _name;
  late final TextEditingController _sku;
  late final TextEditingController _barcode;
  late final TextEditingController _category;
  late final TextEditingController _price;
  late final TextEditingController _quantity;
  late final TextEditingController _threshold;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    final product = widget.product;
    _name = TextEditingController(text: product?.name ?? '');
    _sku = TextEditingController(text: product?.sku ?? '');
    _barcode = TextEditingController(text: product?.barcode ?? '');
    _category = TextEditingController(text: product?.category ?? '');
    _price = TextEditingController(text: product?.price?.toString() ?? '');
    _quantity = TextEditingController(
      text: product?.quantity?.toString() ?? '',
    );
    _threshold = TextEditingController(
      text: product?.lowStockThreshold?.toString() ?? '',
    );
  }

  @override
  void dispose() {
    _name.dispose();
    _sku.dispose();
    _barcode.dispose();
    _category.dispose();
    _price.dispose();
    _quantity.dispose();
    _threshold.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _saving = true);
    final product = LocalProduct(
      id:
          widget.product?.id ??
          DateTime.now().microsecondsSinceEpoch.toString(),
      name: _name.text.trim(),
      sku: _optional(_sku.text),
      barcode: _optional(_barcode.text),
      category: _optional(_category.text),
      price: _optionalNumber(_price.text),
      quantity: _optionalNumber(_quantity.text),
      lowStockThreshold: _optionalNumber(_threshold.text),
    );
    await widget.workspace.saveProduct(product);
    if (mounted) Navigator.of(context).pop();
  }

  Future<void> _delete() async {
    final shouldDelete = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete local item?'),
        content: const Text(
          'This removes the item and its local stock note from this device. It does not affect the POS.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
    if (shouldDelete == true && mounted) {
      await widget.workspace.deleteProduct(widget.product!.id);
      if (mounted) Navigator.of(context).pop();
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(
      title: Text(
        widget.product == null ? 'Add local item' : 'Edit local item',
      ),
    ),
    body: Form(
      key: _formKey,
      child: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          Card(
            child: Padding(
              padding: const EdgeInsets.all(14),
              child: Text(
                widget.workspace.persistentStorageAvailable
                    ? 'LOCAL ONLY · Saved on this device. This item and its stock notes are not sent to the POS.'
                    : 'LOCAL ONLY · Kept for this app session on this platform. This item and its stock notes are not sent to the POS.',
              ),
            ),
          ),
          const SizedBox(height: 14),
          TextFormField(
            controller: _name,
            textCapitalization: TextCapitalization.words,
            decoration: const InputDecoration(
              labelText: 'Item name *',
              border: OutlineInputBorder(),
            ),
            validator: (value) => value == null || value.trim().isEmpty
                ? 'Enter an item name.'
                : null,
          ),
          const SizedBox(height: 12),
          TextFormField(
            controller: _sku,
            decoration: const InputDecoration(
              labelText: 'SKU (optional)',
              border: OutlineInputBorder(),
            ),
          ),
          const SizedBox(height: 12),
          TextFormField(
            controller: _barcode,
            keyboardType: TextInputType.number,
            decoration: const InputDecoration(
              labelText: 'Barcode (optional)',
              border: OutlineInputBorder(),
            ),
          ),
          const SizedBox(height: 12),
          TextFormField(
            controller: _category,
            textCapitalization: TextCapitalization.words,
            decoration: const InputDecoration(
              labelText: 'Category (optional)',
              border: OutlineInputBorder(),
            ),
          ),
          const SizedBox(height: 12),
          _numberField(_price, 'Price (optional)'),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(child: _numberField(_quantity, 'On hand (optional)')),
              const SizedBox(width: 12),
              Expanded(
                child: _numberField(_threshold, 'Low-stock level (optional)'),
              ),
            ],
          ),
          const SizedBox(height: 20),
          FilledButton.icon(
            onPressed: _saving ? null : _save,
            icon: _saving
                ? const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(Icons.save_outlined),
            label: Text(_saving ? 'Saving…' : 'Save on this device'),
          ),
          if (widget.product != null) ...[
            const SizedBox(height: 8),
            TextButton.icon(
              onPressed: _saving ? null : _delete,
              icon: const Icon(Icons.delete_outline),
              label: const Text('Delete local item'),
            ),
          ],
        ],
      ),
    ),
  );

  Widget _numberField(TextEditingController controller, String label) =>
      TextFormField(
        controller: controller,
        keyboardType: const TextInputType.numberWithOptions(
          decimal: true,
          signed: false,
        ),
        decoration: InputDecoration(
          labelText: label,
          border: const OutlineInputBorder(),
        ),
        validator: (value) {
          if (value == null || value.trim().isEmpty) return null;
          return num.tryParse(value.trim()) == null
              ? 'Enter a valid number.'
              : null;
        },
      );

  String? _optional(String value) => value.trim().isEmpty ? null : value.trim();

  num? _optionalNumber(String value) =>
      value.trim().isEmpty ? null : num.tryParse(value.trim());
}
