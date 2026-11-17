import 'package:flutter/material.dart';

import 'earnings/earnings_screen.dart';

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
            children: [
              ListTile(
                title: const Text('Part 1 - Earnings screen (rewritten)'),
                onTap: () => Navigator.of(context).push(MaterialPageRoute(
                  builder: (_) => const EarningsScreen(userId: 'demo-user'),
                )),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
