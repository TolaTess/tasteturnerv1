import 'dart:convert';
import 'package:flutter/material.dart' show debugPrint;
import 'package:http/http.dart' as http;
import 'package:cloud_functions/cloud_functions.dart';
import '../data_models/ingredient_data.dart';

class FoodApiService {
  static const String baseUrl = 'https://world.openfoodfacts.org/api/v2';

  /// Search for food products
  /// Uses cloud function proxy for server-side control
  Future<Map<String, dynamic>> searchProducts({
    String query = '',
    int page = 1,
    int pageSize = 20,
    String? categories,
    String? brands,
  }) async {
    try {
      // Use cloud function proxy
      final callable = FirebaseFunctions.instance.httpsCallable('searchFoodProducts');
      final result = await callable.call({
        'query': query,
        'page': page,
        'pageSize': pageSize,
        'categories': categories,
        'brands': brands,
      }).timeout(const Duration(seconds: 30));

      // Safely convert result.data to Map<String, dynamic>
      if (result.data is! Map) {
        throw Exception('Invalid response format: result.data is not a Map');
      }
      final resultData = Map<String, dynamic>.from(result.data as Map);

      if (resultData['success'] == true && resultData['data'] != null) {
        // Safely convert nested data map
        final dataRaw = resultData['data'];
        if (dataRaw is! Map) {
          throw Exception('Invalid data format: expected Map');
        }
        final dataMap = Map<String, dynamic>.from(dataRaw);
        
        // Also safely convert nested products list if it exists
        if (dataMap.containsKey('products') && dataMap['products'] is List) {
          final productsList = dataMap['products'] as List;
          dataMap['products'] = productsList.map((product) {
            if (product is Map) {
              return Map<String, dynamic>.from(product);
            }
            return product;
          }).toList();
        }
        
        return dataMap;
      } else {
        throw Exception('Failed to search products: Invalid response');
      }
    } catch (e) {
      debugPrint('Error searching products via cloud function: $e');
      // Fallback to direct API call if cloud function fails
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
      } catch (fallbackError) {
        debugPrint('Fallback API call also failed: $fallbackError');
        return {'count': 0, 'products': []};
      }
    }
  }

  /// Get detailed product information by barcode
  /// Uses cloud function proxy for server-side control
  Future<Map<String, dynamic>> getProduct(String barcode) async {
    try {
      // Use cloud function proxy
      final callable = FirebaseFunctions.instance.httpsCallable('getFoodProduct');
      final result = await callable.call({
        'barcode': barcode,
      }).timeout(const Duration(seconds: 30));

      // Safely convert result.data to Map<String, dynamic>
      if (result.data is! Map) {
        throw Exception('Invalid response format: result.data is not a Map');
      }
      final resultData = Map<String, dynamic>.from(result.data as Map);

      if (resultData['success'] == true && resultData['data'] != null) {
        // Safely convert nested data map
        final dataRaw = resultData['data'];
        if (dataRaw is! Map) {
          throw Exception('Invalid data format: expected Map');
        }
        final dataMap = Map<String, dynamic>.from(dataRaw);
        
        // Also safely convert nested product map if it exists
        if (dataMap.containsKey('product') && dataMap['product'] is Map) {
          dataMap['product'] = Map<String, dynamic>.from(dataMap['product'] as Map);
        }
        
        return dataMap;
      } else {
        throw Exception('Failed to get product: Invalid response');
      }
    } catch (e) {
      debugPrint('Error getting product via cloud function: $e');
      // Fallback to direct API call if cloud function fails
      try {
        final response = await http.get(
          Uri.parse('$baseUrl/product/$barcode'),
        );

        if (response.statusCode == 200) {
          return json.decode(response.body);
        } else {
          throw Exception('Failed to get product: ${response.statusCode}');
        }
      } catch (fallbackError) {
        debugPrint('Fallback API call also failed: $fallbackError');
        return {'status': 0, 'product': null};
      }
    }
  }

  /// Convert API response to an IngredientData object
  Map<String, dynamic> _convertToIngredientData(Map<String, dynamic> product) {
    // Safely convert nutriments map
    final nutrimentsRaw = product['nutriments'];
    final nutriments = nutrimentsRaw is Map
        ? Map<String, dynamic>.from(nutrimentsRaw)
        : <String, dynamic>{};

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
        final productsRaw = response['products'];
        if (productsRaw is! List) {
          return [];
        }
        final products = productsRaw;
        return products
            .map((product) {
              // Safely convert product map
              if (product is! Map) {
                return null;
              }
              final productMap = Map<String, dynamic>.from(product);
              return IngredientData.fromJson(_convertToIngredientData(productMap));
            })
            .where((ingredient) => ingredient != null)
            .cast<IngredientData>()
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
        // Safely convert product map
        final productRaw = response['product'];
        if (productRaw is! Map) {
          return null;
        }
        final productMap = Map<String, dynamic>.from(productRaw);
        return IngredientData.fromJson(_convertToIngredientData(productMap));
      }
      return null;
    } catch (e) {
      debugPrint('Error getting ingredient info: $e');
      return null;
    }
  }
}
