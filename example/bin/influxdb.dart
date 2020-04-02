import 'dart:async';

import 'package:georoute/georoute.dart';
import 'package:geopoint/geopoint.dart';
import 'package:pedantic/pedantic.dart';

import 'conf.dart' as conf;
import 'mock_data.dart';

Future<void> main() async {
  final t = Stopwatch()..start();
  final idb = InfluxDbRouter(
      address: conf.influxdbAddr,
      token: conf.influxDbToken,
      bucket: conf.influxdbBucket,
      org: conf.influxdbOrg);
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
        .then((_) => trackController.close()));
    ++i;
  }
  t.stop();
  print("Wrote $n datapoints in ${t.elapsed}");
}
