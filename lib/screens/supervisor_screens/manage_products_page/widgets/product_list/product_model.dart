class ProductModel {
  final String id;
  final String displayName;
  final double price;
  final int stock;
  final int minimumStock;
  final String category;

  // Raw / Other
  final String type;

  // Finished / Other
  final String productCode;

  // Finished
  final String modelGender;

  ProductModel({
    required this.id,
    required this.displayName,
    required this.price,
    this.stock = 0,
    this.minimumStock = 0,
    required this.category,
    this.type = '',
    this.productCode = '',
    this.modelGender = '',
  });

  factory ProductModel.fromMap(
    Map<String, dynamic> map,
  ) {
    return ProductModel(
      id: map['id']?.toString() ?? '',
      displayName: map['displayName']?.toString() ?? '',
      price: _parsePrice(map['price']),
      stock: _parseInt(map['stock']),
      minimumStock: _parseInt(map['minimumStock']),
      category: map['category']?.toString() ?? '',
      type: map['type']?.toString() ?? '',
      productCode: map['productCode']?.toString() ?? '',
      modelGender: map['modelGender']?.toString() ?? '',
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'displayName': displayName,
      'price': price,
      'stock': stock,
      'minimumStock': minimumStock,
      'category': category,
      'type': type,
      'productCode': productCode,
      'modelGender': modelGender,
    };
  }

  static double _parsePrice(dynamic value) {
    if (value == null) return 0;

    if (value is num) {
      return value.toDouble();
    }

    return double.tryParse(
          value.toString().trim(),
        ) ??
        0;
  }

  static int _parseInt(dynamic value) {
    if (value == null) return 0;

    if (value is num) {
      return value.toInt();
    }

    return int.tryParse(
          value.toString().trim(),
        ) ??
        0;
  }

  ProductModel copyWith({
    String? displayName,
    double? price,
    int? stock,
    int? minimumStock,
    String? type,
    String? productCode,
    String? modelGender,
  }) {
    return ProductModel(
      id: id,
      displayName: displayName ?? this.displayName,
      price: price ?? this.price,
      stock: stock ?? this.stock,
      minimumStock: minimumStock ?? this.minimumStock,
      category: category,
      type: type ?? this.type,
      productCode: productCode ?? this.productCode,
      modelGender: modelGender ?? this.modelGender,
    );
  }
}