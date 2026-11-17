part of 'earnings_bloc.dart';

enum EarningsStatus { loading, error, loaded }

/// Immutable snapshot of the earnings screen.
class EarningsState {
  final EarningsStatus status;
  final List<Earning> earnings;

  /// Id of the earning whose detail is loading (blocks double taps).
  final String? openingId;

  /// One-time signal: the UI should open this detail, then send
  /// [EarningDetailOpened] to clear it.
  final EarningDetail? detailToOpen;

  /// Goes up by one each time a detail fails to load (UI shows a SnackBar).
  final int detailFailures;

  const EarningsState({
    this.status = EarningsStatus.loading,
    this.earnings = const [],
    this.openingId,
    this.detailToOpen,
    this.detailFailures = 0,
  });

  EarningsState copyWith({
    EarningsStatus? status,
    List<Earning>? earnings,
    String? openingId,
    bool clearOpeningId = false,
    EarningDetail? detailToOpen,
    bool clearDetailToOpen = false,
    int? detailFailures,
  }) {
    return EarningsState(
      status: status ?? this.status,
      earnings: earnings ?? this.earnings,
      openingId: clearOpeningId ? null : (openingId ?? this.openingId),
      detailToOpen:
          clearDetailToOpen ? null : (detailToOpen ?? this.detailToOpen),
      detailFailures: detailFailures ?? this.detailFailures,
    );
  }
}
