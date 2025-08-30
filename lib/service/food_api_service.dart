import 'dart:convert';
import 'package:flutter/material.dart' show debugPrint;
import 'package:http/http.dart' as http;
import '../data_models/ingredient_data.dart';

class FoodApiService {
  static const String baseUrl = 'https://world.openfoodfacts.org/api/v2';

  /// Search for food products
  Future<Map<String, dynamic>> searchProducts({
    String query = '',
    int page = 1,
    int pageSize = 20,
    String? categories,
    String? brands,
  }) async {
    try {
      final queryParams = {
        'categories_tags_en': query,
        'page': page.toString(),
        'page_size': pageSize.toString(),
        'fields':
            'code,product_name,brands,categories,nutriments,image_url,ingredients_text,serving_size',
        'sort_by': 'ecoscore_score',
      };

      if (categories != null) queryParams['categories_tags'] = categories;
      if (brands != null) queryParams['brands_tags'] = brands;

      final response = await http.get(
        Uri.parse('$baseUrl/search').replace(queryParameters: queryParams),
      );

      if (response.statusCode == 200) {
        return json.decode(response.body);
      } else {
        throw Exception('Failed to search products: ${response.statusCode}');
      }
    } catch (e) {
      debugPrint('Error searching products: $e');
      return {'count': 0, 'products': []};
    }
  }

  /// Get detailed product information by barcode
  Future<Map<String, dynamic>> getProduct(String barcode) async {
    try {
      final response = await http.get(
        Uri.parse('$baseUrl/product/$barcode'),
      );

      if (response.statusCode == 200) {
        return json.decode(response.body);
      } else {
        throw Exception('Failed to get product: ${response.statusCode}');
      }
    } catch (e) {
      debugPrint('Error getting product: $e');
      return {'status': 0, 'product': null};
    }
  }

  /// Convert API response to an IngredientData object
  Map<String, dynamic> _convertToIngredientData(Map<String, dynamic> product) {
    final nutriments = product['nutriments'] ?? {};

    return {
      'name': product['product_name'] ?? 'Unknown',
      'image': product['image_url'] ?? '',
      'servingSize': product['serving_size'] ?? '',
      'ingredients': product['ingredients_text'] ?? '',
      'macros': {
        'calories': nutriments['energy-kcal_100g']?.toString() ?? '0',
        'protein': nutriments['proteins_100g']?.toString() ?? '0',
        'carbs': nutriments['carbohydrates_100g']?.toString() ?? '0',
        'fat': nutriments['fat_100g']?.toString() ?? '0',
        'fiber': nutriments['fiber_100g']?.toString() ?? '0',
      },
      'features': {
        'brand': product['brands'] ?? '',
        'categories': product['categories'] ?? '',
      },
      'code': product['code'] ?? '',
    };
  }

  /// Search for ingredients
  Future<List<IngredientData>> searchIngredients(String query) async {
    try {
      final response = await searchProducts(
        query: query,
        pageSize: 10,
      );

      if (response['count'] > 0) {
        final products = response['products'] as List<dynamic>;
        return products
            .map((product) =>
                IngredientData.fromJson(_convertToIngredientData(product)))
            .toList();
      }
      return [];
    } catch (e) {
      debugPrint('Error searching ingredients: $e');
      return [];
    }
  }

  /// Get nutritional information for a specific ingredient
  Future<IngredientData?> getIngredientInfo(String barcode) async {
    try {
      final response = await getProduct(barcode);

      if (response['status'] == 1 && response['product'] != null) {
        return IngredientData.fromJson(
            _convertToIngredientData(response['product']));
      }
      return null;
    } catch (e) {
      debugPrint('Error getting ingredient info: $e');
      return null;
    }
  }
}
