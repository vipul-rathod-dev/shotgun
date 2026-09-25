class ProductModel {
  final String id;
  final String displayName;
  final double price;
  final String category;

  // Raw
  final String type;

  // Finished
  final String productCode;
  final String modelGender;

  ProductModel({
    required this.id,
    required this.displayName,
    required this.price,
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
          value.toString(),
        ) ??
        0;
  }

  ProductModel copyWith({
    String? displayName,
    double? price,
    String? type,
    String? productCode,
    String? modelGender,
  }) {
    return ProductModel(
      id: id,
      displayName: displayName ?? this.displayName,
      price: price ?? this.price,
      category: category,
      type: type ?? this.type,
      productCode: productCode ?? this.productCode,
      modelGender: modelGender ?? this.modelGender,
    );
  }
}