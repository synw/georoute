import 'package:georoute/georoute.dart';

import 'conf.dart' as conf;
import 'read.dart';
import 'write.dart';

Future<void> main(List<String> args) async {
  var isWrite = false;
  if (args.isNotEmpty) {
    if (args[0] == "-w") {
      isWrite = true;
    } else {
      print("Wrong argument ${args[0]}");
      return;
    }
  }
  final t = Stopwatch()..start();
  final idb = InfluxDbRouter(
      address: conf.influxdbAddr,
      token: conf.influxDbToken,
      bucket: conf.influxdbBucket,
      org: conf.influxdbOrg,
      batchInterval: 100);
  if (isWrite) {
    print("Running in write mode");
    final n = await writeData(idb);
    print("Wrote $n datapoints");
  } else {
    print("Running in read mode");
    await readData(idb);
  }
  t.stop();
  print("Finished in ${t.elapsed}");
}
