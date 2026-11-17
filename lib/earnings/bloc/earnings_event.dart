part of 'earnings_bloc.dart';

sealed class EarningsEvent {
  const EarningsEvent();
}

/// Screen opened: subscribe to wallet updates, then load the list.
final class EarningsStarted extends EarningsEvent {
  const EarningsStarted();
}

/// The user tapped Retry on the error view.
final class EarningsRetryRequested extends EarningsEvent {
  const EarningsRetryRequested();
}

/// The user tapped a row and wants its detail screen.
final class EarningTapped extends EarningsEvent {
  final Earning earning;
  const EarningTapped(this.earning);
}

/// The UI has navigated to the detail screen; clear the one-time signal.
final class EarningDetailOpened extends EarningsEvent {
  const EarningDetailOpened();
}

/// Internal: a live wallet update arrived. Private, so only the bloc sends it.
final class _WalletUpdateReceived extends EarningsEvent {
  final Earning earning;
  const _WalletUpdateReceived(this.earning);
}
