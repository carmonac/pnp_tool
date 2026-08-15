import 'package:pnp_tool/pnp_tool.dart';

void main(List<String> arguments) async {
  if (arguments.length != 2) {
    print('Usage: pnp_tool <inputDir> <outputPath>');
    return;
  }

  final inputDir = arguments[0];
  final outputPath = arguments[1];

  await PnPGenerator.generatePdf(inputDir: inputDir, outputPath: outputPath);
}
