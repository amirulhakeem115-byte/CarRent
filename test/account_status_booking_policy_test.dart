import 'package:flutter_test/flutter_test.dart';
import 'package:carrent_system/services/booking_service.dart';

void main() {
  group('BookingService account-status action policy', () {
    test('defers account-action cancellation for active rentals', () {
      expect(BookingService.shouldDeferAccountStatusAction('active'), isTrue);
      expect(BookingService.shouldDeferAccountStatusAction('ongoing'), isTrue);
      expect(BookingService.shouldDeferAccountStatusAction('overdue'), isTrue);
      expect(
        BookingService.shouldDeferAccountStatusAction('return requested'),
        isTrue,
      );
    });

    test('cancels immediately for bookings not yet handed out', () {
      expect(BookingService.shouldDeferAccountStatusAction('pending'), isFalse);
      expect(
        BookingService.shouldDeferAccountStatusAction('approved'),
        isFalse,
      );
      expect(
        BookingService.shouldDeferAccountStatusAction('confirmed'),
        isFalse,
      );
      expect(
        BookingService.shouldDeferAccountStatusAction('waiting for payment'),
        isFalse,
      );
    });

    test('treats disabled and suspended users as restricted', () {
      expect(BookingService.isAccountRestricted('disabled'), isTrue);
      expect(BookingService.isAccountRestricted('suspended'), isTrue);
      expect(BookingService.isAccountRestricted('active'), isFalse);
      expect(BookingService.isAccountRestricted(''), isFalse);
    });

    test('does not auto-cancel bookings when an account is suspended', () {
      expect(
        BookingService.shouldAutoCancelBookingsOnStatusChange('suspended'),
        isFalse,
      );
      expect(
        BookingService.shouldAutoCancelBookingsOnStatusChange('disabled'),
        isFalse,
      );
      expect(
        BookingService.shouldAutoCancelBookingsOnStatusChange('active'),
        isTrue,
      );
    });
  });
}
