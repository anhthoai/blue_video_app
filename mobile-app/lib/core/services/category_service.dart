import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../models/category_model.dart';
import 'api_service.dart';

class CategoryService {
  final ApiService _apiService = ApiService();

  // Get all categories
  Future<List<CategoryModel>> getCategories() async {
    try {
      final categoriesData = await _apiService.getCategories();
      return categoriesData.map((categoryData) {
        return CategoryModel.fromJson(categoryData);
      }).toList();
    } catch (e) {
      print('Error getting categories: $e');
      return [];
    }
  }
}

// Provider
final categoryServiceProvider = Provider<CategoryService>((ref) {
  return CategoryService();
});

// Categories list provider
final categoriesProvider = FutureProvider<List<CategoryModel>>((ref) async {
  final categoryService = ref.watch(categoryServiceProvider);
  return await categoryService.getCategories();
});
