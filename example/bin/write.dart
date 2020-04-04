import 'dart:async';

import 'package:geopoint/geopoint.dart';
import 'package:georoute/georoute.dart';
import 'package:pedantic/pedantic.dart';

import 'mock_data.dart';

Future<int> writeData(InfluxDbRouter idb) async {
  var i = 0;
  var n = 0;
  while (i < 30) {
    final trackController = StreamController<GeoPoint>();
    trackController.stream.listen((GeoPoint geoPoint) {
      // add a point to the write queue
      idb.push(geoPoint, verbose: true);
      n++;
    });
    unawaited(mockTrack(n: i, timeInterval: 100, sink: trackController.sink)
        .then((_) {
      trackController.close();
    }));
    ++i;
  }
  return n;
}
