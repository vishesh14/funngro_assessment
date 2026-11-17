// Stand-ins for the app's real types, so the rewritten screen runs on its own.
// In the real app these already exist; only earnings_screen.dart is the answer.
import 'dart:async';
import 'dart:math';

import 'package:flutter/material.dart';

class Earning {
  final String id;
  final num amount;
  final String title;
  final DateTime date;

  const Earning({
    required this.id,
    required this.amount,
    required this.title,
    required this.date,
  });
}

class EarningDetail {
  final String id;
  final String description;
  const EarningDetail({required this.id, required this.description});
}

class WalletUpdate {
  final String id;
  final num amount;
  const WalletUpdate({required this.id, required this.amount});

  Earning toEarning() => Earning(
        id: id,
        amount: amount,
        title: 'New earning',
        date: DateTime.now(),
      );
}

/// Fake backend: 3,000 earnings, ~800ms latency, a wallet update every 5s.
class FakeEarningsApi {
  final _rng = Random();
  int _nextId = 100000;

  Future<List<Earning>> fetchEarnings(String userId) async {
    await Future.delayed(const Duration(milliseconds: 800));
    return List.generate(
      3000,
      (i) => Earning(
        id: 'e$i',
        amount: 50 + _rng.nextInt(2000),
        title: 'Project payout #$i',
        date: DateTime.now().subtract(Duration(days: i)),
      ),
    );
  }

  Stream<WalletUpdate> walletUpdates(String userId) {
    return Stream.periodic(
      const Duration(seconds: 5),
      (_) => WalletUpdate(id: 'e${_nextId++}', amount: 100 + _rng.nextInt(500)),
    );
  }

  Future<EarningDetail> fetchDetail(String id) async {
    await Future.delayed(const Duration(milliseconds: 600));
    if (_rng.nextInt(5) == 0) throw Exception('detail failed');
    return EarningDetail(id: id, description: 'Details for $id');
  }
}

final api = FakeEarningsApi();

class EarningTile extends StatelessWidget {
  final Earning earning;
  final String subtitle;
  final VoidCallback? onTap;

  const EarningTile({
    super.key,
    required this.earning,
    required this.subtitle,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return ListTile(
      title: Text(earning.title),
      subtitle: Text(subtitle),
      onTap: onTap,
    );
  }
}

class DetailScreen extends StatelessWidget {
  final EarningDetail detail;
  const DetailScreen({super.key, required this.detail});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Earning detail')),
      body: Center(child: Text(detail.description)),
    );
  }
}
