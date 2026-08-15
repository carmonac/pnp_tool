import 'dart:io';

import 'package:pnp_cli/src/cli.dart' as cli;

Future<void> main(List<String> arguments) async {
  exitCode = await cli.run(arguments);
}
