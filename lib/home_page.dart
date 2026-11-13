import 'dart:math';

import 'package:flutter/material.dart';

import 'cart_page.dart';
import 'main.dart';

const List<String> kCategories = [
  'Breakfast',
  'Lunch',
  'Dinner',
  'Dessert',
  'Snack',
  'Drinks',
];

class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  List<Map<String, dynamic>> _foods = [];
  int _cartCount = 0;
  bool _loading = true;
  String _search = '';
  String _category = 'All';

  String get _uid => supabase.auth.currentUser!.id;

  @override
  void initState() {
    super.initState();
    _load();
  }

  // ---------- READ ----------
  Future<void> _load() async {
    setState(() => _loading = true);
    try {
      final foods = await supabase
          .from('foods')
          .select()
          .order('id', ascending: false);
      final cart = await supabase.from('cart_items').select('quantity');
      if (!mounted) return;
      setState(() {
        _foods = List<Map<String, dynamic>>.from(foods);
        _cartCount = (cart as List).fold<int>(
          0,
          (s, e) => s + (e['quantity'] as int),
        );
      });
    } catch (e) {
      if (mounted) showMsg(context, 'Could not load foods: $e', error: true);
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  List<Map<String, dynamic>> get _filtered {
    final q = _search.toLowerCase();
    return _foods.where((f) {
      final okCat = _category == 'All' || f['category'] == _category;
      final okSearch =
          q.isEmpty ||
          (f['name'] as String).toLowerCase().contains(q) ||
          (f['description'] as String).toLowerCase().contains(q);
      return okCat && okSearch;
    }).toList();
  }

  // ---------- CART: add ----------
  Future<void> _addToCart(Map<String, dynamic> food) async {
    try {
      final existing = await supabase
          .from('cart_items')
          .select()
          .eq('food_id', food['id'])
          .maybeSingle();
      if (existing == null) {
        await supabase.from('cart_items').insert({'food_id': food['id']});
      } else {
        await supabase
            .from('cart_items')
            .update({'quantity': (existing['quantity'] as int) + 1})
            .eq('id', existing['id']);
      }
      if (!mounted) return;
      showMsg(context, '${food['name']} added to cart 🛒');
      _load();
    } catch (e) {
      if (mounted) showMsg(context, 'Could not add to cart: $e', error: true);
    }
  }

  // ---------- CREATE / UPDATE ----------
  Future<void> _openFoodDialog([Map<String, dynamic>? food]) async {
    final result = await showDialog<Map<String, dynamic>>(
      context: context,
      builder: (_) => _FoodDialog(food: food),
    );
    if (result == null) return;
    try {
      if (food == null) {
        await supabase.from('foods').insert(result);
        if (mounted) showMsg(context, 'Food added 🎉');
      } else {
        await supabase.from('foods').update(result).eq('id', food['id']);
        if (mounted) showMsg(context, 'Food updated ✅');
      }
      _load();
    } catch (e) {
      if (mounted) showMsg(context, 'Save failed: $e', error: true);
    }
  }

  // ---------- DELETE ----------
  Future<void> _delete(Map<String, dynamic> food) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete food?'),
        content: Text('Remove "${food['name']}" permanently?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Delete', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
    if (ok != true) return;
    try {
      await supabase.from('foods').delete().eq('id', food['id']);
      if (mounted) showMsg(context, 'Food deleted');
      _load();
    } catch (e) {
      if (mounted) showMsg(context, 'Delete failed: $e', error: true);
    }
  }

  // ---------- UNIQUE FEATURE: Surprise me ----------
  void _surprise() {
    final list = _filtered.isNotEmpty ? _filtered : _foods;
    if (list.isEmpty) return;
    final pick = list[Random().nextInt(list.length)];
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text(
          '🎲 Tonight you should eat…',
          textAlign: TextAlign.center,
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(pick['emoji'], style: const TextStyle(fontSize: 64)),
            const SizedBox(height: 8),
            Text(
              pick['name'],
              style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w800),
            ),
            Text('৳${pick['price']}  •  ${pick['category']}'),
            const SizedBox(height: 6),
            Text(pick['description'], textAlign: TextAlign.center),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Nah'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(minimumSize: const Size(120, 42)),
            onPressed: () {
              Navigator.pop(ctx);
              _addToCart(pick);
            },
            child: const Text('Add to cart'),
          ),
        ],
      ),
    );
  }

  Future<void> _openCart() async {
    await Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => const CartPage()),
    );
    _load(); // refresh badge after returning
  }

  @override
  Widget build(BuildContext context) {
    final list = _filtered;
    final user = supabase.auth.currentUser;
    return Scaffold(
      appBar: AppBar(
        title: const Text(
          '🍽️ Foodie',
          style: TextStyle(fontWeight: FontWeight.w800),
        ),
        backgroundColor: Colors.white,
        actions: [
          IconButton(
            tooltip: 'Surprise me',
            icon: const Icon(Icons.casino_outlined),
            onPressed: _surprise,
          ),
          IconButton(
            tooltip: 'Cart',
            onPressed: _openCart,
            icon: Badge(
              isLabelVisible: _cartCount > 0,
              label: Text('$_cartCount'),
              child: const Icon(Icons.shopping_cart_outlined),
            ),
          ),
          PopupMenuButton<String>(
            icon: const Icon(Icons.account_circle_outlined),
            onSelected: (v) async {
              if (v == 'logout') await supabase.auth.signOut();
            },
            itemBuilder: (_) => [
              PopupMenuItem(enabled: false, child: Text(user?.email ?? '')),
              const PopupMenuItem(value: 'logout', child: Text('Logout')),
            ],
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        backgroundColor: const Color(0xFFFF6B35),
        foregroundColor: Colors.white,
        onPressed: () => _openFoodDialog(),
        icon: const Icon(Icons.add),
        label: const Text('Add food'),
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(14, 12, 14, 6),
            child: TextField(
              decoration: const InputDecoration(
                hintText: 'Search food…',
                prefixIcon: Icon(Icons.search),
              ),
              onChanged: (v) => setState(() => _search = v),
            ),
          ),
          SizedBox(
            height: 48,
            child: ListView(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 10),
              children: ['All', ...kCategories]
                  .map(
                    (c) => Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 4),
                      child: ChoiceChip(
                        label: Text(c),
                        selected: _category == c,
                        selectedColor: const Color(0xFFFFD2B8),
                        onSelected: (_) => setState(() => _category = c),
                      ),
                    ),
                  )
                  .toList(),
            ),
          ),
          Expanded(
            child: _loading
                ? const Center(child: CircularProgressIndicator())
                : RefreshIndicator(
                    onRefresh: _load,
                    child: list.isEmpty
                        ? ListView(
                            children: const [
                              SizedBox(height: 120),
                              Center(child: Text('No food found 🍃')),
                            ],
                          )
                        : ListView.builder(
                            padding: const EdgeInsets.fromLTRB(14, 6, 14, 90),
                            itemCount: list.length,
                            itemBuilder: (_, i) => _foodCard(list[i]),
                          ),
                  ),
          ),
        ],
      ),
    );
  }

  Widget _foodCard(Map<String, dynamic> f) {
    final mine = f['owner_id'] == _uid;
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      elevation: 1.5,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Row(
          children: [
            Container(
              width: 64,
              height: 64,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: const Color(0xFFFFE9DB),
                borderRadius: BorderRadius.circular(14),
              ),
              child: Text(f['emoji'], style: const TextStyle(fontSize: 34)),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    f['name'],
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  Text(
                    f['category'],
                    style: const TextStyle(color: Colors.black54, fontSize: 12),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    f['description'],
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(fontSize: 12.5),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    '৳${f['price']}',
                    style: const TextStyle(
                      fontWeight: FontWeight.w800,
                      color: Color(0xFFE4561F),
                      fontSize: 16,
                    ),
                  ),
                ],
              ),
            ),
            Column(
              children: [
                IconButton.filled(
                  style: IconButton.styleFrom(
                    backgroundColor: const Color(0xFFFF6B35),
                  ),
                  tooltip: 'Add to cart',
                  onPressed: () => _addToCart(f),
                  icon: const Icon(Icons.add_shopping_cart, size: 20),
                ),
                if (mine)
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      InkWell(
                        onTap: () => _openFoodDialog(f),
                        child: const Padding(
                          padding: EdgeInsets.all(4),
                          child: Icon(
                            Icons.edit,
                            size: 20,
                            color: Colors.blueGrey,
                          ),
                        ),
                      ),
                      InkWell(
                        onTap: () => _delete(f),
                        child: const Padding(
                          padding: EdgeInsets.all(4),
                          child: Icon(
                            Icons.delete,
                            size: 20,
                            color: Colors.red,
                          ),
                        ),
                      ),
                    ],
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

/// Add / Edit food form (with validation)
class _FoodDialog extends StatefulWidget {
  final Map<String, dynamic>? food;
  const _FoodDialog({this.food});

  @override
  State<_FoodDialog> createState() => _FoodDialogState();
}

class _FoodDialogState extends State<_FoodDialog> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _name;
  late final TextEditingController _price;
  late final TextEditingController _emoji;
  late final TextEditingController _desc;
  late String _category;

  @override
  void initState() {
    super.initState();
    final f = widget.food;
    _name = TextEditingController(text: f?['name'] ?? '');
    _price = TextEditingController(text: f != null ? '${f['price']}' : '');
    _emoji = TextEditingController(text: f?['emoji'] ?? '🍽️');
    _desc = TextEditingController(text: f?['description'] ?? '');
    _category = f?['category'] ?? kCategories.first;
  }

  @override
  void dispose() {
    _name.dispose();
    _price.dispose();
    _emoji.dispose();
    _desc.dispose();
    super.dispose();
  }

  void _save() {
    if (!_formKey.currentState!.validate()) return;
    Navigator.pop(context, {
      'name': _name.text.trim(),
      'category': _category,
      'price': double.parse(_price.text.trim()),
      'emoji': _emoji.text.trim().isEmpty ? '🍽️' : _emoji.text.trim(),
      'description': _desc.text.trim(),
    });
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(widget.food == null ? 'Add food' : 'Edit food'),
      content: SingleChildScrollView(
        child: Form(
          key: _formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextFormField(
                controller: _name,
                decoration: const InputDecoration(labelText: 'Food name'),
                validator: (v) {
                  final t = v?.trim() ?? '';
                  if (t.length < 3 || t.length > 60)
                    return 'Name must be 3-60 characters';
                  return null;
                },
              ),
              const SizedBox(height: 10),
              DropdownButtonFormField<String>(
                value: _category,
                decoration: const InputDecoration(labelText: 'Category'),
                items: kCategories
                    .map((c) => DropdownMenuItem(value: c, child: Text(c)))
                    .toList(),
                onChanged: (v) => setState(() => _category = v!),
              ),
              const SizedBox(height: 10),
              TextFormField(
                controller: _price,
                keyboardType: const TextInputType.numberWithOptions(
                  decimal: true,
                ),
                decoration: const InputDecoration(labelText: 'Price (৳)'),
                validator: (v) {
                  final t = v?.trim() ?? '';
                  if (!Rx.price.hasMatch(t))
                    return 'Enter a valid price, e.g. 120 or 99.50';
                  if (double.parse(t) <= 0)
                    return 'Price must be greater than 0';
                  return null;
                },
              ),
              const SizedBox(height: 10),
              TextFormField(
                controller: _emoji,
                maxLength: 4,
                decoration: const InputDecoration(
                  labelText: 'Emoji',
                  counterText: '',
                ),
              ),
              const SizedBox(height: 10),
              TextFormField(
                controller: _desc,
                maxLines: 2,
                decoration: const InputDecoration(labelText: 'Description'),
                validator: (v) => (v == null || v.trim().length < 5)
                    ? 'Write at least 5 characters'
                    : null,
              ),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancel'),
        ),
        ElevatedButton(
          style: ElevatedButton.styleFrom(minimumSize: const Size(100, 42)),
          onPressed: _save,
          child: const Text('Save'),
        ),
      ],
    );
  }
}
