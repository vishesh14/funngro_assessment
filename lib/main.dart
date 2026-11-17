import 'package:flutter/material.dart';


void main() => runApp(const App());

class App extends StatelessWidget {
  const App({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Funngro assessment',
      home: Builder(
        builder: (context) => Scaffold(
          appBar: AppBar(title: const Text('Funngro assessment')),
          body: ListView(
            children: const [],
          ),
        ),
      ),
    );
  }
}
