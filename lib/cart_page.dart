import 'package:flutter/material.dart';

import 'main.dart';

class CartPage extends StatefulWidget {
  const CartPage({super.key});

  @override
  State<CartPage> createState() => _CartPageState();
}

class _CartPageState extends State<CartPage> {
  List<Map<String, dynamic>> _items = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  double _price(Map<String, dynamic> item) =>
      ((item['foods']['price']) as num).toDouble();

  double get _total =>
      _items.fold(0, (s, e) => s + _price(e) * (e['quantity'] as int));

  // ---------- READ ----------
  Future<void> _load() async {
    try {
      final data = await supabase
          .from('cart_items')
          .select('id, quantity, foods(id, name, emoji, price)')
          .order('id');
      if (!mounted) return;
      setState(() => _items = List<Map<String, dynamic>>.from(data));
    } catch (e) {
      if (mounted) showMsg(context, 'Could not load cart: $e', error: true);
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  // ---------- UPDATE quantity ----------
  Future<void> _changeQty(Map<String, dynamic> item, int delta) async {
    final newQty = (item['quantity'] as int) + delta;
    if (newQty < 1) return _remove(item);
    try {
      await supabase
          .from('cart_items')
          .update({'quantity': newQty})
          .eq('id', item['id']);
      _load();
    } catch (e) {
      if (mounted) showMsg(context, 'Update failed: $e', error: true);
    }
  }

  // ---------- DELETE one ----------
  Future<void> _remove(Map<String, dynamic> item) async {
    try {
      await supabase.from('cart_items').delete().eq('id', item['id']);
      if (mounted) showMsg(context, 'Removed from cart');
      _load();
    } catch (e) {
      if (mounted) showMsg(context, 'Delete failed: $e', error: true);
    }
  }

  // ---------- Place order (clears cart) ----------
  Future<void> _placeOrder() async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Place order?'),
        content: Text('Total: ৳${_total.toStringAsFixed(2)}'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(minimumSize: const Size(110, 42)),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Confirm'),
          ),
        ],
      ),
    );
    if (ok != true) return;
    try {
      await supabase
          .from('cart_items')
          .delete()
          .eq('user_id', supabase.auth.currentUser!.id);
      if (!mounted) return;
      showMsg(context, 'Order placed! Your food is on the way 🚀');
      _load();
    } catch (e) {
      if (mounted) showMsg(context, 'Order failed: $e', error: true);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text(
          '🛒 My Cart',
          style: TextStyle(fontWeight: FontWeight.w800),
        ),
        backgroundColor: Colors.white,
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _items.isEmpty
          ? const Center(
              child: Text(
                'Your cart is empty 🍃\nGo add something tasty!',
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 16),
              ),
            )
          : Column(
              children: [
                Expanded(
                  child: ListView.builder(
                    padding: const EdgeInsets.all(14),
                    itemCount: _items.length,
                    itemBuilder: (_, i) => _cartTile(_items[i]),
                  ),
                ),
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: const BoxDecoration(
                    color: Colors.white,
                    boxShadow: [
                      BoxShadow(blurRadius: 10, color: Colors.black12),
                    ],
                  ),
                  child: SafeArea(
                    top: false,
                    child: Row(
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text(
                                'Total',
                                style: TextStyle(color: Colors.black54),
                              ),
                              Text(
                                '৳${_total.toStringAsFixed(2)}',
                                style: const TextStyle(
                                  fontSize: 22,
                                  fontWeight: FontWeight.w800,
                                ),
                              ),
                            ],
                          ),
                        ),
                        SizedBox(
                          width: 170,
                          child: ElevatedButton(
                            onPressed: _placeOrder,
                            child: const Text(
                              'Place order',
                              style: TextStyle(fontWeight: FontWeight.w700),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
    );
  }

  Widget _cartTile(Map<String, dynamic> item) {
    final food = item['foods'] as Map<String, dynamic>;
    final qty = item['quantity'] as int;
    return Dismissible(
      key: ValueKey(item['id']),
      direction: DismissDirection.endToStart,
      background: Container(
        alignment: Alignment.centerRight,
        padding: const EdgeInsets.only(right: 20),
        margin: const EdgeInsets.only(bottom: 12),
        decoration: BoxDecoration(
          color: Colors.red.shade400,
          borderRadius: BorderRadius.circular(16),
        ),
        child: const Icon(Icons.delete, color: Colors.white),
      ),
      onDismissed: (_) => _remove(item),
      child: Card(
        margin: const EdgeInsets.only(bottom: 12),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Row(
            children: [
              Text(food['emoji'], style: const TextStyle(fontSize: 36)),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      food['name'],
                      style: const TextStyle(
                        fontWeight: FontWeight.w700,
                        fontSize: 16,
                      ),
                    ),
                    Text(
                      '৳${_price(item).toStringAsFixed(2)} each',
                      style: const TextStyle(
                        color: Colors.black54,
                        fontSize: 12,
                      ),
                    ),
                    Text(
                      '৳${(_price(item) * qty).toStringAsFixed(2)}',
                      style: const TextStyle(
                        color: Color(0xFFE4561F),
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ],
                ),
              ),
              IconButton(
                onPressed: () => _changeQty(item, -1),
                icon: const Icon(Icons.remove_circle_outline),
              ),
              Text(
                '$qty',
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                ),
              ),
              IconButton(
                onPressed: () => _changeQty(item, 1),
                icon: const Icon(Icons.add_circle, color: Color(0xFFFF6B35)),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
