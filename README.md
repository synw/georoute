# Georoute

Route geospatial data to various backends and protocols. Available routes:

- [x] Influxdb
- [ ] Websockets
- [ ] Postgresql

The geospatial data format used is [GeoPoint](https://github.com/synw/geopoint#geopoint-1)

## Influxdb

Initialize the route:

   ```dart
   const String influxdbAddr = "http://localhost:9999";
   const String influxdbBucket = "my_bucket";
   const String influxdbOrg = "my_org";
   const String influxDbToken = "my_write_token";

   final idb = InfluxDbRouter(
      address: influxdbAddr,
      token: influxDbToken,
      bucket: influxdbBucket,
      org: influxdbOrg);
   ```

### Write a single datapoint

   ```dart
   final geoPoint = GeoPoint(
      name: "my_point",
      latitude: -10.38533807,
      longitude: -36.88378926,
      timestamp: DateTime.now().millisecondsSinceEpoch);
   // make a post request to the Influxdb's api
   idb.write(geoPoint);
   ```

Note: only the latitude, longitude, name, speed, heading and altitude properties
of the geopoint will be recorded. The latitude and longitude are recorded as fields, and the rest are tags. Example of line protocol data sent:

   ```
   location,name=4661 latitude=-10.38580945,longitude=-36.88917801 1585834948038
   ```

### Batch write

A write queue is available for heavy write loads. It will write batched data every 500 milliseconds into the database

   ```dart
   idb.push(geoPoint);
   ```

### Convert a geopoint to line protocol

   ```dart
   final String data = idb.lineProtocolFromGeoPoint(geoPoint);
   ```

### Run the example

Add a `conf.dart` file in `example/bin` with your credentials:

   ```dart
   const String influxdbAddr = "http://localhost:9999";
   const String influxdbBucket = "my_bucket";
   const String influxdbOrg = "my_org";
   const String influxDbToken = "my_write_token";
   ```

Run:

   ```bash
   cd example
   dart bin/influxdb.dart
   ```