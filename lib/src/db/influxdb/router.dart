import 'dart:async';

import 'package:geopoint/geopoint.dart';
import 'package:dio/dio.dart';
import 'package:meta/meta.dart';
import 'package:pedantic/pedantic.dart';

final _dio = Dio();

/// A router for Influxdb
class InfluxDbRouter {
  /// Main constructor
  InfluxDbRouter(
      {@required this.address,
      @required this.token,
      @required this.bucket,
      this.org = "org"});

  /// The Influxdb database address
  final String address;

  /// The Influxdb org
  final String org;

  /// The Influxdb token
  final String token;

  /// The Influxdb bucket to write into
  final String bucket;

  final _writeQueue = <String>[];
  var _isQueueRunning = false;
  Timer _queueTimer;

  /// Push a [GeoPoint] into the write queue
  Future<void> push(GeoPoint geoPoint,
      {String measurement = "location", bool verbose = false}) async {
    if (!_isQueueRunning) {
      unawaited(_runWriteQueue(measurement: measurement, verbose: verbose));
      _isQueueRunning = true;
    }
    final data = lineProtocolFromGeoPoint(geoPoint);
    _writeQueue.add(data);
  }

  /// Write a single [GeoPoint] to the database
  Future<void> write(GeoPoint geoPoint,
      {String measurement = "location", bool verbose = false}) async {
    final data = lineProtocolFromGeoPoint(geoPoint);
    await _writeData(data, measurement: measurement, verbose: verbose);
  }

  Future<void> _writeData(String data,
      {@required String measurement, @required bool verbose}) async {
    if (verbose) {
      print(data);
    }
    try {
      final addr = "$address/api/v2/write";
      //print("Post to $addr");
      await _dio.post<dynamic>(addr,
          options: Options(
            headers: <String, dynamic>{"Authorization": "Token $token"},
            contentType: "text/plain; charset=utf-8",
          ),
          queryParameters: <String, dynamic>{"org": org, "bucket": bucket},
          data: data);
      //print("RESP: ${resp.statusCode} \n$resp");
    } on DioError catch (e) {
      // The request was made and the server responded with a status code
      // that falls out of the range of 2xx and is also not 304.
      if (e.response != null) {
        print(e.response.data);
        print(e.response.headers);
        print(e.response.request);
      } else {
        // Something happened in setting up or sending the request that triggered an Error
        print(e.request);
        print(e.message);
      }
    } catch (e) {
      rethrow;
    }
  }

  /// Convert a [GeoPoint] to an Influxdb line protocol string
  String lineProtocolFromGeoPoint(GeoPoint geoPoint,
      {String measurement = "location"}) {
    var line = "$measurement,";
    final tags = <String, dynamic>{};
    if (geoPoint.name != null) {
      tags["name"] = geoPoint.name;
    }
    if (geoPoint.altitude != null) {
      tags["altitude"] = geoPoint.altitude;
    }
    if (geoPoint.speed != null) {
      tags["speed"] = geoPoint.speed;
    }
    if (geoPoint.heading != null) {
      tags["heading"] = geoPoint.heading;
    }
    final taglines = <String>[];
    for (final tag in tags.keys) {
      taglines.add("$tag=${tags[tag]}");
    }
    line += taglines.join(",");
    line += " latitude=${geoPoint.latitude},longitude=${geoPoint.longitude}";
    return line;
  }

  /// Stop the write queue if started
  void stopQueue() {
    if (_isQueueRunning) {
      _queueTimer.cancel();
    }
  }

  /// Dispose the class when finished using
  void dispose() => stopQueue();

  Future<void> _runWriteQueue(
      {@required String measurement, @required bool verbose}) async {
    _queueTimer = Timer.periodic(const Duration(milliseconds: 300), (t) async {
      if (_writeQueue.isNotEmpty) {
        if (verbose) {
          print("Queue: writing ${_writeQueue.length} datapoints");
        }
        await _writeData(_writeQueue.join("\n"),
            measurement: measurement, verbose: verbose);
        _writeQueue.clear();
      }
    });
  }
}
