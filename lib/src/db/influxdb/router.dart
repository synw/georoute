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
      this.batchInterval = 300,
      this.org = "org"});

  /// The Influxdb database address
  final String address;

  /// The Influxdb org
  final String org;

  /// The Influxdb token
  final String token;

  /// The Influxdb bucket to write into
  final String bucket;

  /// The interval to post batch data in milliseconds
  final int batchInterval;

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

  /// Run a read query
  Future<List<GeoPoint>> select(
      {@required String start,
      String stop,
      String measurement = "location",
      bool verbose = false}) async {
    var q = 'from(bucket:"$bucket") |> range(start: $start';
    if (stop != null) {
      q += ', stop: $stop';
    }
    q += ')';
    q += ' |> filter(fn: (r) => r._measurement == "$measurement")';
    //q += ' |> filter(fn: (r) => r._field == "latitude" '
    //    'or r._field == "longitude")';
    q += ' |> group(columns: ["_time"])';
    // post to api
    final dynamic resp = await _postQuery(q, verbose: true);
    // process result
    final raw = resp.toString().split("\n");
    final lines = <int, GeoPoint>{};
    raw.forEach((line) {
      if (line.isNotEmpty) {
        if (!line.startsWith(
                ",result,table,_start,_stop,_time,_value,_field,_measurement") &&
            (line.length > 2)) {
          //line.replaceAll("\n", "");
          //lines.add(line);
          final l = line.split(",");
          final table = int.tryParse(l[2]);
          final value = l[6];
          final field = l[7];
          final timestamp = DateTime.parse(l[5]).millisecondsSinceEpoch;
          final name = l[9];
          /*print("table $table");
          print("field $field");
          print("valie $value");
          print("name $name");
          print("ts $timestamp");*/
          GeoPoint gp;
          if (!lines.containsKey(table)) {
            if (field == "latitude") {
              gp = GeoPoint(
                  name: name,
                  latitude: double.parse(value),
                  longitude: 0,
                  timestamp: timestamp);
            } else {
              gp = GeoPoint(
                  name: name,
                  latitude: 0,
                  longitude: double.parse(value),
                  timestamp: timestamp);
            }
          } else {
            final _gp = lines[table];
            if (field == "latitude") {
              gp = GeoPoint(
                  name: _gp.name ?? name,
                  latitude: double.parse(value),
                  longitude: _gp.longitude,
                  timestamp: _gp.timestamp ?? timestamp);
            } else {
              gp = GeoPoint(
                  name: _gp.name ?? name,
                  latitude: _gp.latitude,
                  longitude: double.parse(value),
                  timestamp: _gp.timestamp ?? timestamp);
            }
          }
          lines[table] = gp;
        }
      }
      //print("RAW LINE: $line");
    });
    /* for (final k in lines.keys) {
      final line = lines[k];
      print("$k $line");
    }*/
    return lines.values.toList();
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
    if (geoPoint.timestamp != null) {
      line += " ${geoPoint.timestamp * 1000}";
    }
    return "$line";
  }

  /// Stop the write queue if started
  void stopQueue() {
    if (_isQueueRunning) {
      _queueTimer.cancel();
    }
  }

  /// Dispose the class when finished using
  void dispose() => stopQueue();

  Future<dynamic> _postQuery(String data, {@required bool verbose}) async {
    if (verbose) {
      print(data);
    }
    dynamic resp;
    try {
      final addr = "$address/api/v2/query";
      final response = await _dio.post<dynamic>(addr,
          options: Options(
            headers: <String, dynamic>{"Authorization": "Token $token"},
            contentType: "application/vnd.flux",
          ),
          queryParameters: <String, dynamic>{"org": org, "bucket": bucket},
          data: data);
      if (response.statusCode == 200) {
        resp = response.data;
      } else {
        throw Exception("Wrong status code: ${response.statusCode}");
      }
    } on DioError catch (e) {
      if (e.response != null) {
        print(e.response.data);
        print(e.response.headers);
        print(e.response.request);
      } else {
        print(e.request);
        print(e.message);
      }
    } catch (e) {
      rethrow;
    }
    return resp;
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

  Future<void> _runWriteQueue(
      {@required String measurement, @required bool verbose}) async {
    _queueTimer =
        Timer.periodic(Duration(milliseconds: batchInterval), (t) async {
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
