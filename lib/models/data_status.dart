class DataStatus {
  const DataStatus({
    this.lastUpdated,
    this.offlineCache = false,
  });

  final DateTime? lastUpdated;
  final bool offlineCache;

  DataStatus copyWith({
    DateTime? lastUpdated,
    bool? offlineCache,
  }) {
    return DataStatus(
      lastUpdated: lastUpdated ?? this.lastUpdated,
      offlineCache: offlineCache ?? this.offlineCache,
    );
  }
}
