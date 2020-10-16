import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';

import 'HomePage.dart';

Future<void> main() async {
  await DotEnv().load('.env');
  runApp(new EngagementApplication());
}

class EngagementApplication extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return MaterialApp(home: HomePage());
  }
}
