import 'package:flutter/material.dart';

/// A stable name -> icon registry.
///
/// Categories, payment methods and goals persist an *icon key* (a short
/// string), never a raw code point. That keeps Flutter's icon tree-shaking
/// working, keeps JSON backups readable and portable, and means a future
/// Material icon renumbering cannot scramble a user's categories.
class AppIcons {
  AppIcons._();

  static const IconData fallback = Icons.category_rounded;

  static const Map<String, IconData> catalog = <String, IconData>{
    // Everyday spending
    'restaurant': Icons.restaurant_rounded,
    'fastfood': Icons.fastfood_rounded,
    'coffee': Icons.local_cafe_rounded,
    'groceries': Icons.local_grocery_store_rounded,
    'shopping': Icons.shopping_bag_rounded,
    'cart': Icons.shopping_cart_rounded,
    'transport': Icons.directions_bus_rounded,
    'car': Icons.directions_car_rounded,
    'fuel': Icons.local_gas_station_rounded,
    'flight': Icons.flight_takeoff_rounded,
    'train': Icons.train_rounded,
    'home': Icons.home_rounded,
    'rent': Icons.house_rounded,
    'bills': Icons.receipt_long_rounded,
    'utilities': Icons.bolt_rounded,
    'water': Icons.water_drop_rounded,
    'phone': Icons.smartphone_rounded,
    'internet': Icons.wifi_rounded,
    'entertainment': Icons.movie_rounded,
    'music': Icons.headphones_rounded,
    'games': Icons.sports_esports_rounded,
    'sports': Icons.fitness_center_rounded,
    'health': Icons.favorite_rounded,
    'medical': Icons.local_hospital_rounded,
    'education': Icons.school_rounded,
    'books': Icons.menu_book_rounded,
    'pets': Icons.pets_rounded,
    'gift': Icons.card_giftcard_rounded,
    'family': Icons.family_restroom_rounded,
    'beauty': Icons.spa_rounded,
    'laundry': Icons.local_laundry_service_rounded,
    'subscriptions': Icons.subscriptions_rounded,
    'emi': Icons.credit_score_rounded,
    'insurance': Icons.shield_rounded,
    'tax': Icons.gavel_rounded,
    'charity': Icons.volunteer_activism_rounded,
    'travel': Icons.luggage_rounded,
    'tools': Icons.build_rounded,

    // Earning
    'salary': Icons.payments_rounded,
    'business': Icons.storefront_rounded,
    'freelance': Icons.laptop_mac_rounded,
    'bonus': Icons.emoji_events_rounded,
    'interest': Icons.percent_rounded,
    'investment': Icons.trending_up_rounded,
    'dividend': Icons.pie_chart_rounded,
    'refund': Icons.assignment_return_rounded,
    'rental_income': Icons.apartment_rounded,

    // Saving & goals
    'savings': Icons.savings_rounded,
    'piggy': Icons.account_balance_wallet_rounded,
    'emergency': Icons.health_and_safety_rounded,
    'retirement': Icons.beach_access_rounded,
    'goal': Icons.flag_rounded,
    'laptop': Icons.laptop_chromebook_rounded,
    'vehicle': Icons.two_wheeler_rounded,
    'wedding': Icons.celebration_rounded,
    'vacation': Icons.holiday_village_rounded,
    'gold': Icons.diamond_rounded,

    // Accounts & payment methods
    'cash': Icons.payments_outlined,
    'bank': Icons.account_balance_rounded,
    'credit_card': Icons.credit_card_rounded,
    'debit_card': Icons.credit_card_outlined,
    'upi': Icons.qr_code_rounded,
    'wallet': Icons.account_balance_wallet_outlined,

    // Generic
    'category': Icons.category_rounded,
    'star': Icons.star_rounded,
    'more': Icons.more_horiz_rounded,
    'transfer': Icons.swap_horiz_rounded,
  };

  /// Never throws - an unknown key (e.g. from a hand-edited backup) degrades
  /// to a neutral icon instead of crashing the list it appears in.
  static IconData resolve(String? key) => catalog[key] ?? fallback;

  static List<String> get keys => catalog.keys.toList(growable: false);
}

/// The palette users pick from when creating a category or goal.
class AppPalette {
  AppPalette._();

  static const List<int> swatches = <int>[
    0xFF10B981, // emerald
    0xFF14B8A6, // teal
    0xFF06B6D4, // cyan
    0xFF3B82F6, // blue
    0xFF6366F1, // indigo
    0xFF8B5CF6, // violet
    0xFFA855F7, // purple
    0xFFEC4899, // pink
    0xFFF43F5E, // rose
    0xFFEF4444, // red
    0xFFF97316, // orange
    0xFFF59E0B, // amber
    0xFFEAB308, // yellow
    0xFF84CC16, // lime
    0xFF22C55E, // green
    0xFF64748B, // slate
  ];

  static int at(int index) => swatches[index % swatches.length];
}
