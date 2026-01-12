class CartItem {
  final String id;
  final String name;
  final int price;
  final int buyPrice;
  int qty;

  CartItem({
    required this.id,
    required this.name,
    required this.price,
    this.buyPrice = 0,
    this.qty = 1,
  });

  int get subtotal => price * qty;
  int get cogs => buyPrice * qty;
  int get grossProfit => (price - buyPrice) * qty;
}
