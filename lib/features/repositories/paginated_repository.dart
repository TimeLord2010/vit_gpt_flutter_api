import 'dart:async';

mixin PaginatedRepository<T> {
  /// The number of parallel jobs to run at any given time.
  int get maxConcurrency;

  /// The size of the result of [fetch].
  int get chunkSize;

  Future<Iterable<T>> fetch({
    int? limit,
    int? skip,
  });

  /// Counts the number of items.
  ///
  /// Used in [fetchAll].
  Future<int?> count();

  Stream<Iterable<T>> streamInOrder() async* {
    assert(maxConcurrency > 0);
    assert(chunkSize > 0);

    var count = await this.count();
    if (count == null) {
      Iterable<T> found = await fetch();
      yield found;
      return;
    }

    // Creating the functions that will be run in batch.
    var jobCount = (count / chunkSize).ceil();
    var jobs = <Future<Iterable<T>> Function()>[];
    for (int i = 0; i < jobCount; i++) {
      Future<Iterable<T>> func() async {
        var result = await fetch(
          limit: chunkSize,
          skip: i * chunkSize,
        );
        return result;
      }

      jobs.add(func);
    }

    while (jobs.isNotEmpty) {
      var futures = <Future<Iterable<T>>>[];
      for (int i = 0; i < maxConcurrency && i < jobs.length; i++) {
        var future = jobs.removeAt(0)();
        futures.add(future);
      }
      var fetched = await Future.wait(futures);
      var flat = fetched.expand((x) => x);
      yield flat;
    }
  }

  /// The items are not garanted to be streamed in the same order they are
  /// originally.
  Stream<Iterable<T>> streamAll() async* {
    assert(maxConcurrency > 0);
    assert(chunkSize > 0);

    var count = await this.count();
    if (count == null) {
      Iterable<T> found = await fetch();
      yield found;
      return;
    }

    // Creating the functions that will be run in batch.
    var jobCount = (count / chunkSize).ceil();
    var jobs = <Stream<Iterable<T>> Function()>[];
    for (int i = 0; i < jobCount; i++) {
      Stream<Iterable<T>> func() async* {
        var result = await fetch(
          limit: chunkSize,
          skip: i * chunkSize,
        );
        yield result;

        if (jobs.isEmpty) {
          return;
        }
        var next = jobs.removeAt(0)();
        yield* next;
      }

      jobs.add(func);
    }

    final controller = StreamController<Iterable<T>>();
    int activeJobs = 0;

    void startNextJob() {
      if (jobs.isEmpty) return;
      if (activeJobs >= maxConcurrency) return;
      activeJobs++;
      final stream = jobs.removeAt(0)();

      stream.listen(
        controller.add,
        onDone: () {
          activeJobs--;
          startNextJob();
          if (activeJobs == 0) {
            controller.close();
          }
        },
        onError: controller.addError,
        cancelOnError: false,
      );
    }

    for (var i = 0; i < maxConcurrency && jobs.isNotEmpty; i++) {
      startNextJob();
    }

    yield* controller.stream;
  }

  /// Fetches all items in parallel.
  ///
  /// If [count] returned null, then [fetch] is run syncronously until no items
  /// are found.
  Future<Iterable<T>> fetchAll() async {
    Stream<Iterable<T>> stream = streamAll();
    List<Iterable<T>> listOfLists = await stream.toList();
    Iterable<T> iterable = listOfLists.expand((x) => x);
    return iterable;
  }

  Future<Iterable<T>> fetchInOrder() async {
    Stream<Iterable<T>> stream = streamInOrder();
    List<Iterable<T>> listOfLists = await stream.toList();
    Iterable<T> iterable = listOfLists.expand((x) => x);
    return iterable;
  }
}
