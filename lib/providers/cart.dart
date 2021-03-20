import 'dart:convert';

import 'package:ForMe_app/models/http_exception.dart';
import 'package:ForMe_app/providers/orders.dart';
import 'package:flutter/cupertino.dart';
import 'package:http/http.dart' as http;
import 'package:provider/provider.dart';

class CartItem {
  final String id;
  final String title;
  final int quantity;
  final double price;

  CartItem({
    @required this.id,
    @required this.title,
    @required this.quantity,
    @required this.price,
  });
}

class Cart with ChangeNotifier {
  final String authToken;
  final String userId;
  Map<String, CartItem> _items;

  Cart(this.authToken, this.userId, this._items);

  Map<String, CartItem> get items {
    return {..._items};
  }

  int get itemCount {
    return _items.length;
  }

  double get totalAmount {
    var total = 0.0;
    _items.forEach((key, cartItem) {
      total += cartItem.price * cartItem.quantity;
    });
    return total;
  }

  Future<void> orderEverything(BuildContext context, Cart cart) async {
    final _previousItems = _items;

    await Provider.of<Orders>(context, listen: false).addOrder(
      cart.items.values.toList(),
      cart.totalAmount,
    );

    final cartUrl =
        'https://forme-afb88-default-rtdb.firebaseio.com/cart/$userId.json?auth=$authToken';
    final response = await http.delete(cartUrl);

    if (response.statusCode >= 400) {
      _items = _previousItems;
      notifyListeners();
      throw HttpException("Could not delete cartItems.");
    }
  }

  Future<void> fetchAndSetCartItems() async {
    final url =
        'https://forme-afb88-default-rtdb.firebaseio.com/cart/$userId.json?auth=$authToken';
    try {
      final response = await http.get(url);
      final extractedData = json.decode(response.body) as Map<String, dynamic>;
      final Map<String, CartItem> loadedCartItems = {};
      extractedData.forEach((productId, productData) {
        loadedCartItems.putIfAbsent(
          productId,
          () => CartItem(
            id: productId,
            title: productData['title'],
            price: productData['price'],
            quantity: productData['quantity'],
          ),
        );
      });
      _items = loadedCartItems;
      notifyListeners();
    } catch (error) {
      print(error);
      throw error;
    }
  }

  Future<void> addItem(
    String productId,
    double price,
    String title,
  ) async {
    if (_items.containsKey(productId)) {
      final url =
          'https://forme-afb88-default-rtdb.firebaseio.com/cart/$userId/$productId.json?auth=$authToken';

      final existingCartQuantityItem = await http.get(url);
      final previousQuantity =
          json.decode(existingCartQuantityItem.body)['quantity'];
      final response = await http.patch(
        url,
        body: json.encode({
          'quantity': previousQuantity + 1,
        }),
      );
      _items.update(
          productId,
          (existingCartItem) => CartItem(
                id: existingCartItem.id,
                title: existingCartItem.title,
                price: existingCartItem.price,
                quantity: existingCartItem.quantity + 1,
              ));
      if (response.statusCode >= 400) {
        _items.removeWhere((key, value) => value.id == productId);
        notifyListeners();
        throw HttpException("Could not add product to cart status");
      }
    } else {
      final url =
          'https://forme-afb88-default-rtdb.firebaseio.com/cart/$userId/$productId.json?auth=$authToken';
      try {
        final response = await http.patch(
          url,
          body: json.encode({
            'title': title,
            'price': price,
            'quantity': 1,
          }),
        );
        _items.putIfAbsent(
          productId,
          () => CartItem(
            id: json.decode(response.body)['name'],
            title: title,
            price: price,
            quantity: 1,
          ),
        );
        notifyListeners();
        if (response.statusCode >= 400) {
          _items.removeWhere((key, value) => value.id == productId);
          notifyListeners();
          throw HttpException("Could not add product to cart status");
        }
      } catch (error) {
        print(error);
        throw error;
      }
    }
    notifyListeners();
  }

  Future<void> removeSingleItem(String productId) async {
    if (!_items.containsKey(productId)) {
      return;
    }
    if (_items[productId].quantity > 1) {
      final url =
          'https://forme-afb88-default-rtdb.firebaseio.com/cart/$userId/$productId.json?auth=$authToken';
      final response = await http.patch(
        url,
        body: json.encode({
          'quantity': _items[productId].quantity - 1,
        }),
      );
      _items.update(
        productId,
        (existingCartItem) => CartItem(
          id: existingCartItem.id,
          title: existingCartItem.title,
          price: existingCartItem.price,
          quantity: existingCartItem.quantity - 1,
        ),
      );
      if (response.statusCode >= 400) {
        _items.update(
          productId,
          (existingCartItem) => CartItem(
            id: existingCartItem.id,
            title: existingCartItem.title,
            price: existingCartItem.price,
            quantity: existingCartItem.quantity + 1,
          ),
        );
        notifyListeners();
        throw HttpException("Could not delete product from cart status");
      }
    } else {
      final existingCartItem = _items[productId];
      final url =
          'https://forme-afb88-default-rtdb.firebaseio.com/cart/$userId/$productId.json?auth=$authToken';
      final response = await http.delete(url);
      _items.remove(productId);
      if (response.statusCode >= 400) {
        _items.putIfAbsent(productId, () => existingCartItem);
        notifyListeners();
        throw HttpException("Could not delete product from cart status");
      }
    }
    notifyListeners();
  }

  void clearCart() {
    _items = {};
    notifyListeners();
  }
}
