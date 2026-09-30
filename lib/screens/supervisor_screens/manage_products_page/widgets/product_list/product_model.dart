class ProductModel {
  final String id;
  final String displayName;
  final double price;
  final int stock;
  final int minimumStock;
  final String category;
  final String type;
  final String productCode;
  final String modelGender;

  /// Shared identity for Raw variants belonging to the same model.
  final String modelId;
  final String modelName;

  // Mold configuration.
  // Each cavity maps to one model and its Black/Clear/PC variants.
  final int cavityCount;
  final List<Map<String, dynamic>> cavities;

  const ProductModel({
    required this.id,
    required this.displayName,
    required this.price,
    this.stock = 0,
    this.minimumStock = 0,
    required this.category,
    this.type = '',
    this.productCode = '',
    this.modelGender = '',
    this.modelId = '',
    this.modelName = '',
    this.cavityCount = 0,
    this.cavities = const [],
  });

  factory ProductModel.fromMap(Map<String, dynamic> map) {
    final rawCavities = map['cavities'];

    final cavities = rawCavities is List
        ? rawCavities
            .whereType<Map>()
            .map((item) => Map<String, dynamic>.from(item))
            .toList()
        : <Map<String, dynamic>>[];

    return ProductModel(
      id: map['id']?.toString() ?? '',
      displayName: map['displayName']?.toString() ??
          map['name']?.toString() ??
          '',
      price: _toDouble(map['price']),
      stock: _toInt(map['stock']),
      minimumStock: _toInt(map['minimumStock']),
      category: map['category']?.toString() ?? '',
      type: map['type']?.toString() ?? '',
      productCode: map['productCode']?.toString() ?? '',
      modelGender: map['modelGender']?.toString() ?? '',
      modelId: map['modelId']?.toString() ?? '',
      modelName: map['modelName']?.toString() ?? '',
      cavityCount: _toInt(map['cavityCount']),
      cavities: cavities,
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
      'modelId': modelId,
      'modelName': modelName,
      'cavityCount': cavityCount,
      'cavities': cavities,
    };
  }

  ProductModel copyWith({
    String? displayName,
    double? price,
    int? stock,
    int? minimumStock,
    String? type,
    String? productCode,
    String? modelGender,
    String? modelId,
    String? modelName,
    int? cavityCount,
    List<Map<String, dynamic>>? cavities,
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
      modelId: modelId ?? this.modelId,
      modelName: modelName ?? this.modelName,
      cavityCount: cavityCount ?? this.cavityCount,
      cavities: cavities ?? this.cavities,
    );
  }

  static int _toInt(dynamic value) {
    if (value is num) return value.toInt();
    return int.tryParse(value?.toString().trim() ?? '') ?? 0;
  }

  static double _toDouble(dynamic value) {
    if (value is num) return value.toDouble();
    return double.tryParse(value?.toString().trim() ?? '') ?? 0;
  }
}