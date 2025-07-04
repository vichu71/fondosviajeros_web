import 'dart:math';
import 'package:flutter/material.dart';

import '../model/base_model.dart';
import 'package:fondosviajeros_web/model/model.dart' as model;

class ApiPaginatedDataTableController {
  late void Function() refresh;
}

class ColumnDefinition<T extends model.BaseModel> {
  final String title;
  final String? fieldName;
  final bool isNumeric;
  final Widget Function(BuildContext context, T item) cellBuilder;

  ColumnDefinition({
    this.fieldName,
    required this.title,
    this.isNumeric = false,
    required this.cellBuilder,
  });
}

class ApiPaginatedDataTable<T extends model.BaseModel> extends StatefulWidget {
  final String title;
  final ApiPaginatedDataTableController controller;
  final Future<model.Page<T>> Function(int page, int size) api;
  final List<ColumnDefinition<T>> columnDefinitions;
  final double height;

  const ApiPaginatedDataTable({
    Key? key,
    required this.title,
    required this.controller,
    required this.api,
    required this.columnDefinitions,
    this.height = kMinInteractiveDimension,
  }) : super(key: key);

  @override
  _ApiPaginatedDataTableState<T> createState() =>
      _ApiPaginatedDataTableState<T>();
}

class _ApiPaginatedDataTableState<T extends model.BaseModel>
    extends State<ApiPaginatedDataTable<T>> {
  List<T> items = [];
  int pageIndex = 0;
  int size = 10;
  int totalItems = 0;
  bool isLoading = false;

  @override
  void initState() {
    super.initState();
    widget.controller.refresh = loadPage;
    loadPage();
  }

  Future<void> loadPage() async {
    setState(() => isLoading = true);

    try {
      final model.Page<T> page = await widget.api(pageIndex, size);
      setState(() {
        items = page.content; // Sobrescribe los elementos con la nueva página
        totalItems = page.totalElements;
      });
    } catch (error) {
      print('Error: $error');
    } finally {
      setState(() => isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    // Calcular el rango de elementos mostrados
    int firstItemIndex = pageIndex * size + 1;
    int lastItemIndex = min((pageIndex + 1) * size, totalItems);

    return isLoading
        ? Center(child: CircularProgressIndicator())
        : SingleChildScrollView(
      child: PaginatedDataTable(
        header: Text('${widget.title} ($firstItemIndex-$lastItemIndex of $totalItems)'),
        rowsPerPage: size,
       // availableRowsPerPage: [5, 10, 20],
        onRowsPerPageChanged: (value) {
          if (value != null) {
            setState(() {
              size = value;
              pageIndex = 0;
              loadPage();
            });
          }
        },
        onPageChanged: (firstRowIndex) {
          int newPageIndex = firstRowIndex ~/ size;
          if (newPageIndex != pageIndex) {
            setState(() {
              pageIndex = newPageIndex;
              loadPage();
            });
          }
        },
        columns: widget.columnDefinitions
            .map((column) => DataColumn(label: Text(column.title)))
            .toList(),
        source: _DataSource(
          context: context,
          items: items,
          columns: widget.columnDefinitions,
          totalItems: totalItems,
        ),
      ),
    );
  }
}

class _DataSource<T extends model.BaseModel> extends DataTableSource {
  final BuildContext context;
  final List<T> items;
  final List<ColumnDefinition<T>> columns;
  final int totalItems;

  _DataSource({
    required this.context,
    required this.items,
    required this.columns,
    required this.totalItems,
  });

  @override
  DataRow getRow(int index) {
    if (index >= items.length) {
      return DataRow(
        cells: List<DataCell>.generate(
          columns.length,
              (index) => DataCell(Container()),
        ),
      );
    }

    final T item = items[index];
    return DataRow(
      cells: columns.map((column) => DataCell(column.cellBuilder(context, item))).toList(),
    );
  }

  @override
  bool get isRowCountApproximate => false;

  @override
  int get rowCount => totalItems;

  @override
  int get selectedRowCount => 0;
}
