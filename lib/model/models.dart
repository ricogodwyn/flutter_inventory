class Invoice {
  final int id;
  final String invoiceStr;

  Invoice({required this.id, required this.invoiceStr});

  factory Invoice.fromJson(Map<String, dynamic> json) {
    return Invoice(
      id: json['id'],
      invoiceStr: json['invoice_str'],
    );
  }

  @override
  String toString() => invoiceStr; // Important for auto-complete display
}

class SoldItem {
  final int id;
  final String itemTag;
  final String itemSn;
  final String itemType;

  SoldItem({
    required this.id,
    required this.itemTag,
    required this.itemSn,
    required this.itemType,
  });

  factory SoldItem.fromJson(Map<String, dynamic> json) {
    return SoldItem(
      id: json['id'] ?? 0, // Use a default value if id can be null
      itemTag: json['item_tag'] ?? '',
      itemSn: json['item_sn'] ?? '',
      itemType: json['item_type'] ?? '',
    );
  }
}
