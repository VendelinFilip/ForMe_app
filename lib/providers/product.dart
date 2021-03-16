import 'package:ForMe_app/providers/products_provider.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/foundation.dart';
import 'package:provider/provider.dart';

class Product with ChangeNotifier {
  final String id;
  final String title;
  final String description;
  final double price;
  final String imageUrl;
  bool isFavorite;

  Product({
    @required this.id,
    @required this.title,
    @required this.description,
    @required this.price,
    @required this.imageUrl,
    this.isFavorite = false,
  });

  void toggleFavoriteStatus(BuildContext context) async {
    isFavorite = !isFavorite;
    notifyListeners();
    await Provider.of<ProductsProvider>(context, listen: false)
        .toggleHttpFavorite(id, !isFavorite);
  }
}
