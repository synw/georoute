import 'dart:async';
import 'dart:io';

import 'package:geopoint/geopoint.dart';
import 'package:meta/meta.dart';

Future<void> mockTrack(
    {@required StreamSink<GeoPoint> sink,
    int n,
    int timeInterval = 1000}) async {
  n ??= 0;
  final name = "device_$n";
  final file = File("data/tracks/track_$n.csv");
  final data = file.readAsStringSync();
  final lines = data.split("\n");
  for (final strline in lines.sublist(1)) {
    if (strline == "") {
      continue;
    }
    final records = strline.split(",");
    final ts = DateTime.parse(records[4]).microsecondsSinceEpoch;
    final gp = GeoPoint(
      name: name,
      latitude: double.parse(records[1]),
      longitude: double.parse(records[2]),
      timestamp: ts,
    );
    sink.add(gp);
    await Future<dynamic>.delayed(Duration(milliseconds: timeInterval));
  }
}
