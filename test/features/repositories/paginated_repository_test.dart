import 'dart:math';

import 'package:flutter_test/flutter_test.dart';
import 'package:vit_gpt_flutter_api/features/repositories/paginated_repository.dart';

class _MockRepository with PaginatedRepository<int> {
  final _random = Random();

  @override
  int get chunkSize => 5;

  @override
  Future<int?> count() async => 50;

  @override
  Future<Iterable<int>> fetch({
    int? limit,
    int? skip,
  }) async {
    double milli = (_random.nextDouble() * 200) + 10;
    await Future.delayed(Duration(milliseconds: milli.toInt()));
    return [
      skip ?? 0,
    ];
  }

  @override
  int get maxConcurrency => 3;
}

void main() {
  test('paginated repository ...', () async {
    var instance = _MockRepository();
    var begin = DateTime.now();
    var itemsExpected = [0, 5, 10, 15, 20, 25, 30, 35, 40, 45];
    var quickList = await instance.fetchAll();
    expect(quickList.length, 10);
    expect(quickList.every((x) => itemsExpected.contains(x)), true);
    var allElapsed = DateTime.now().difference(begin).inMilliseconds;
    begin = DateTime.now();
    var orderedList = await instance.fetchInOrder();
    expect(orderedList.length, 10);
    expect(orderedList.every((x) => itemsExpected.contains(x)), true);
    var inOrderElapsed = DateTime.now().difference(begin).inMilliseconds;

    expect(allElapsed < inOrderElapsed, true,
        reason:
            'If the time to get all items in order is faster then get all as soon as possible, then someting is wrong');
  });
}
