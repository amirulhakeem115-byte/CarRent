DateTime getTomorrowStart({DateTime? now}) {
  final baseNow = now ?? DateTime.now();
  return DateTime(
    baseNow.year,
    baseNow.month,
    baseNow.day,
  ).add(const Duration(days: 1));
}

DateTime getDefaultPickupDate({DateTime? prefilledPickupDate, DateTime? now}) {
  final baseNow = now ?? DateTime.now();
  final todayStart = DateTime(baseNow.year, baseNow.month, baseNow.day);

  if (prefilledPickupDate != null &&
      (prefilledPickupDate.isAfter(todayStart) ||
          prefilledPickupDate.isAtSameMomentAs(todayStart))) {
    return prefilledPickupDate;
  }

  return todayStart;
}

bool isPickupDateAllowed(DateTime pickupDate, {DateTime? now}) {
  final baseNow = now ?? DateTime.now();
  final todayStart = DateTime(baseNow.year, baseNow.month, baseNow.day);
  final normalizedPickup = DateTime(
    pickupDate.year,
    pickupDate.month,
    pickupDate.day,
  );

  return normalizedPickup.isAfter(todayStart) ||
      normalizedPickup.isAtSameMomentAs(todayStart);
}
