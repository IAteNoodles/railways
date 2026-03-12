import 'package:flutter/material.dart';

import '../config/routes.dart';
import '../models/category.dart';

void openCategory(BuildContext context, Category category) {
  final hasSubheads = (category.subheadCount ?? 0) > 0;

  if (hasSubheads) {
    Navigator.pushNamed(context, AppRoutes.subheads, arguments: {
      'categoryId': category.id,
      'categoryName': category.name,
      'subheadCount': category.subheadCount,
      'drawingCount': category.drawingCount,
    });
    return;
  }

  Navigator.pushNamed(context, AppRoutes.results, arguments: category.name);
}