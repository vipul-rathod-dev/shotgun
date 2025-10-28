// lib/models/product_model.dart
class ProductModel {
  final String id;
  final String displayName;
  final double price;
  final String category;

  ProductModel({
    required this.id,
    required this.displayName,
    required this.price,
    required this.category,
  });

  factory ProductModel.fromMap(Map<String, dynamic> map) {
    return ProductModel(
      id: map['id'] ?? '',
      displayName: map['displayName'] ?? '',
      price: (map['price'] ?? 0).toDouble(),
      category: map['category'] ?? '',
    );
  }

  Map<String, dynamic> toMap() => {
    'id': id,
    'displayName': displayName,
    'price': price,
    'category': category,
  };
}
