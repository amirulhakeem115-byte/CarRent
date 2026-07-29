DateTime getTomorrowStart({DateTime? now}) {
  final baseNow = now ?? DateTime.now();
  return DateTime(
    baseNow.year,
    baseNow.month,
    baseNow.day,
  ).add(const Duration(days: 1));
}

DateTime getDefaultPickupDate({DateTime? prefilledPickupDate, DateTime? now}) {
  final tomorrowStart = getTomorrowStart(now: now);

  if (prefilledPickupDate != null &&
      prefilledPickupDate.isAfter(tomorrowStart)) {
    return prefilledPickupDate;
  }

  return tomorrowStart;
}

bool isPickupDateAllowed(DateTime pickupDate, {DateTime? now}) {
  final tomorrowStart = getTomorrowStart(now: now);
  final normalizedPickup = DateTime(
    pickupDate.year,
    pickupDate.month,
    pickupDate.day,
  );

  return normalizedPickup.isAfter(tomorrowStart) ||
      normalizedPickup.isAtSameMomentAs(tomorrowStart);
}
