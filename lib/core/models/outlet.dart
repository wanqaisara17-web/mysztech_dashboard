class Outlet {
  const Outlet({required this.id, required this.name});

  final String id;
  final String name;

  factory Outlet.fromJson(Map<String, dynamic> json) => Outlet(
    id: json['id']?.toString() ?? '',
    name: json['name']?.toString() ?? '',
  );
}

Map<String, String> outletNamesById(Iterable<Outlet> outlets) => {
  for (final outlet in outlets)
    if (outlet.id.isNotEmpty && outlet.name.isNotEmpty) outlet.id: outlet.name,
};

String outletLabel(Map<String, String> names, String? id) {
  if (id == null || id.isEmpty) return 'Outlet unavailable';
  final name = names[id];
  return name?.isNotEmpty == true ? name! : 'Outlet $id';
}
