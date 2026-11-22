import 'package:flutter/material.dart';

import '../../data/models/models.dart';
import 'catalog_grid.dart';

/// صفحة "عرض الكل" لصف أو نوع أو ممثل معيّن.
class CatalogListPage extends StatelessWidget {
  const CatalogListPage({super.key, required this.title, required this.query});

  final String title;
  final CatalogQuery query;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        scrolledUnderElevation: 0,
        title: Text(title, style: const TextStyle(fontWeight: FontWeight.w700)),
      ),
      body: CatalogGrid(query: query),
    );
  }
}
