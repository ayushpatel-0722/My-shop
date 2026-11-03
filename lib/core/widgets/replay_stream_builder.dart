import 'package:flutter/widgets.dart';

import '../cache/shared_streams.dart';

/// A [StreamBuilder] that starts from the stream's last known value when it
/// has one, so a screen opened a second time (or a different screen asking for
/// data another one already loaded) draws immediately instead of flashing its
/// loader. With any other stream it behaves exactly like [StreamBuilder].
class ReplayStreamBuilder<T> extends StreamBuilder<T> {
  // ignore: use_super_parameters
  ReplayStreamBuilder({
    super.key,
    required Stream<T>? stream,
    required super.builder,
    T? initialData,
  }) : super(
         stream: stream,
         initialData:
             initialData ?? (stream is ReplayStream<T> ? stream.latest : null),
       );
}
