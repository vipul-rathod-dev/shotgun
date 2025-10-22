import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

class InventoryController extends ChangeNotifier {
  final _productsCollection = FirebaseFirestore.instance.collection('products');

  final int _limit = 10;
  List<DocumentSnapshot> products = [];
  bool isLoading = false;
  bool hasMore = true;
  DocumentSnapshot? lastDocument;

  String searchTerm = '';
  List<String> moldingSuppliers = [];
  List<String> drummingSuppliers = [];

  Future<void> loadSuppliers() async {
    final snapshot = await FirebaseFirestore.instance.collection('suppliers').get();

    moldingSuppliers = snapshot.docs
        .where((doc) => doc['role'] == 'Molding')
        .map((doc) => doc['name'].toString())
        .toList();

    drummingSuppliers = snapshot.docs
        .where((doc) => doc['role'] == 'Drumming')
        .map((doc) => doc['name'].toString())
        .toList();

    notifyListeners();
  }

  Future<void> fetchProducts({bool clearPrevious = false}) async {
    if (isLoading) return;

    isLoading = true;
    notifyListeners();

    if (clearPrevious) {
      products = [];
      lastDocument = null;
      hasMore = true;
    }

    Query query = _productsCollection.orderBy('name');

    // Pagination support
    if (lastDocument != null && !clearPrevious) {
      query = query.startAfterDocument(lastDocument!);
    }

    final snapshot = await query.get();

    

    if (snapshot.docs.length < _limit) hasMore = false;
    if (snapshot.docs.isNotEmpty) {
      lastDocument = snapshot.docs.last;
      products.addAll(snapshot.docs);
    }

    // ✅ Apply substring (contains) search locally
    if (searchTerm.isNotEmpty) {
      final lowerTerm = searchTerm.toLowerCase();
      products = products.where((doc) {
        final data = doc.data() as Map<String, dynamic>;
        final name = (data['name'] ?? '').toString().toLowerCase();
        return name.contains(lowerTerm);
      }).toList();
    }

    isLoading = false;
    notifyListeners();
  }


  // Future<void> fetchProducts({bool clearPrevious = false}) async {
  //   if (isLoading) return;

  //   isLoading = true;
  //   notifyListeners();

  //   Query query = _productsCollection.orderBy('name').limit(_limit);

  //   if (searchTerm.isNotEmpty) {
  //     final endTerm = '$searchTerm\uf8ff';
  //     query = _productsCollection
  //         .orderBy('name')
  //         .where('name', isGreaterThanOrEqualTo: searchTerm)
  //         .where('name', isLessThanOrEqualTo: endTerm)
  //         .limit(_limit);
  //   }

  //   if (lastDocument != null && !clearPrevious) {
  //     query = query.startAfterDocument(lastDocument!);
  //   }

  //   final snapshot = await query.get();

  //   if (clearPrevious) {
  //     products = [];
  //     lastDocument = null;
  //     hasMore = true;
  //   }

  //   if (snapshot.docs.length < _limit) hasMore = false;
  //   if (snapshot.docs.isNotEmpty) {
  //     lastDocument = snapshot.docs.last;
  //     products.addAll(snapshot.docs);
  //   }

  //   isLoading = false;
  //   notifyListeners();
  // }

  Future<void> deleteProduct(String id) async {
    await _productsCollection.doc(id).delete();
    products.removeWhere((doc) => doc.id == id);
    notifyListeners();
  }

  Timer? _debounce;

  void onSearchChanged(String query) {
    if (_debounce?.isActive ?? false) _debounce!.cancel();
    _debounce = Timer(const Duration(milliseconds: 400), () {
      searchTerm = query.trim();
      fetchProducts(clearPrevious: true);
    });
  }


  // void search(String value) {
  //   searchTerm = value.trim();
  //   lastDocument = null;
  //   products.clear();
  //   hasMore = true;
  //   fetchProducts(clearPrevious: true);
  // }
}
