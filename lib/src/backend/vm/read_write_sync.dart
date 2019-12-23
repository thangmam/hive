import 'dart:async';

class ReadWriteSync {
  Future readTask;

  Future writeTask;

  Future<T> syncRead<T>(Future<T> Function() task) async {
    final previousTask = readTask;
    final completer = Completer();

    readTask = completer.future;
    if (previousTask != null) {
      await previousTask;
    }

    final result = await task();
    completer.complete();
    return result;
  }

  Future<T> syncWrite<T>(Future<T> Function() task) async {
    final previousTask = writeTask;
    final completer = Completer();

    writeTask = completer.future;
    if (previousTask != null) {
      await previousTask;
    }

    final result = await task();
    completer.complete();
    return result;
  }

  Future<T> syncReadWrite<T>(Future<T> Function() task) async {
    final previousReadTask = readTask;
    final completer = Completer();
    final future = completer.future;

    readTask = future;
    if (previousReadTask != null) {
      await previousReadTask;
    }

    final previousWriteTask = writeTask;
    writeTask = future;
    if (previousWriteTask != null) {
      await previousWriteTask;
    }

    final result = await task();
    completer.complete();
    return result;
  }
}
