import 'dart:async';

import 'package:georoute/georoute.dart';

Future<void> readData(InfluxDbRouter idb) async {
  try {
    final geoPoints = await idb.select(start: "-15y", verbose: true);
    //geoPoints.forEach((gp) => print("$gp ts: ${gp.timestamp} ${gp.name}"));
    //geoPoints.forEach((gp) => print("$gp"));
    geoPoints.forEach((gp) => print(gp.details()));
  } catch (e) {
    rethrow;
  }
}
