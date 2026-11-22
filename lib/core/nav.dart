import 'package:flutter/material.dart';

import '../data/models/models.dart';
import '../features/details/details_page.dart';
import '../features/discover/catalog_list_page.dart';
import 'utils/ui.dart';

void openDetails(BuildContext context, MediaItem item) {
  Navigator.of(context).push(appRoute<void>(DetailsPage(item: item)));
}

void openCatalogList(BuildContext context, {required String title, required CatalogQuery query}) {
  Navigator.of(context).push(appRoute<void>(CatalogListPage(title: title, query: query)));
}
