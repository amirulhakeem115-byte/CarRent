import 'package:flutter_test/flutter_test.dart';
import 'package:carrent_system/models/booking_model.dart';
import 'package:carrent_system/models/payment_model.dart';
import 'package:carrent_system/services/payment_restriction_service.dart';

void main() {
  group('PaymentRestrictionService Logic Tests', () {
    late PaymentRestrictionService service;

    setUp(() {
      service = PaymentRestrictionService();
    });

    test('Customer with clean booking history has no restriction', () {
      final booking = BookingModel(
        id: 'b1',
        vehicleId: 'v1',
        vehicleName: 'Toyota Vios',
        userId: 'u1',
        userName: 'John',
        userPhone: '12345678',
        pickUpDate: DateTime.now().subtract(const Duration(days: 5)),
        returnDate: DateTime.now().subtract(const Duration(days: 2)),
        totalPrice: 200.0,
        depositAmount: 50.0,
        finalAmount: 150.0,
        status: 'completed',
        createdAt: DateTime.now().subtract(const Duration(days: 5)),
      );

      final payment = PaymentModel(
        id: 'p1',
        bookingId: 'b1',
        userId: 'u1',
        amount: 150.0,
        depositAmount: 50.0,
        balanceAmount: 150.0,
        paymentMethod: 'Online Banking',
        paymentDate: DateTime.now().subtract(const Duration(days: 2)),
        status: 'Approved',
        paymentStatus: 'Approved',
      );

      service.evaluateRestrictionForData([booking], [payment]);

      expect(service.isRestricted, false);
      expect(service.totalOutstandingAmount, 0.0);
    });

    test('Customer with status Awaiting Final Payment is restricted', () {
      final booking = BookingModel(
        id: 'b_awaiting',
        vehicleId: 'v1',
        vehicleName: 'Honda Civic',
        userId: 'u1',
        userName: 'John',
        userPhone: '12345678',
        pickUpDate: DateTime.now().subtract(const Duration(days: 5)),
        returnDate: DateTime.now().subtract(const Duration(days: 1)),
        totalPrice: 400.0,
        depositAmount: 100.0,
        finalAmount: 300.0,
        status: 'Awaiting Final Payment',
        createdAt: DateTime.now().subtract(const Duration(days: 5)),
      );

      service.evaluateRestrictionForData([booking], []);

      expect(service.isRestricted, true);
      expect(service.totalOutstandingAmount, 300.0);
      expect(service.primaryOutstandingBooking?.id, 'b_awaiting');
    });

    test('Customer with overdue late fees is restricted', () {
      final booking = BookingModel(
        id: 'b_overdue',
        vehicleId: 'v2',
        vehicleName: 'Proton X50',
        userId: 'u1',
        userName: 'John',
        userPhone: '12345678',
        pickUpDate: DateTime.now().subtract(const Duration(days: 3)),
        returnDate: DateTime.now().subtract(const Duration(hours: 5)),
        totalPrice: 300.0,
        depositAmount: 50.0,
        lateFees: 100.0,
        status: 'Active',
        createdAt: DateTime.now().subtract(const Duration(days: 3)),
      );

      service.evaluateRestrictionForData([booking], []);

      expect(service.isRestricted, true);
      expect(service.totalOutstandingAmount, 100.0);
    });

    test('Customer with rejected payment is restricted', () {
      final booking = BookingModel(
        id: 'b_rejected',
        vehicleId: 'v3',
        vehicleName: 'Perodua Myvi',
        userId: 'u1',
        userName: 'John',
        userPhone: '12345678',
        pickUpDate: DateTime.now().subtract(const Duration(days: 2)),
        returnDate: DateTime.now().add(const Duration(days: 1)),
        totalPrice: 150.0,
        depositAmount: 50.0,
        status: 'Pending Payment',
        createdAt: DateTime.now().subtract(const Duration(days: 2)),
      );

      final rejectedPayment = PaymentModel(
        id: 'p_rej',
        bookingId: 'b_rejected',
        userId: 'u1',
        amount: 150.0,
        depositAmount: 50.0,
        balanceAmount: 100.0,
        paymentMethod: 'Bank Transfer',
        paymentDate: DateTime.now().subtract(const Duration(hours: 2)),
        status: 'Rejected',
        paymentStatus: 'Rejected',
      );

      service.evaluateRestrictionForData([booking], [rejectedPayment]);

      expect(service.isRestricted, true);
      expect(service.primaryOutstandingBooking?.id, 'b_rejected');
    });

    test('Customer account unlocks automatically when payment becomes Approved', () {
      final booking = BookingModel(
        id: 'b_test',
        vehicleId: 'v1',
        vehicleName: 'Nissan Almera',
        userId: 'u1',
        userName: 'John',
        userPhone: '12345678',
        pickUpDate: DateTime.now().subtract(const Duration(days: 2)),
        returnDate: DateTime.now(),
        totalPrice: 200.0,
        depositAmount: 50.0,
        finalAmount: 150.0,
        status: 'Awaiting Final Payment',
        createdAt: DateTime.now().subtract(const Duration(days: 2)),
      );

      // Step 1: Restricted initially
      service.evaluateRestrictionForData([booking], []);
      expect(service.isRestricted, true);

      // Step 2: Payment completed & approved -> automatically unlocks
      final completedBooking = BookingModel(
        id: 'b_test',
        vehicleId: 'v1',
        vehicleName: 'Nissan Almera',
        userId: 'u1',
        userName: 'John',
        userPhone: '12345678',
        pickUpDate: DateTime.now().subtract(const Duration(days: 2)),
        returnDate: DateTime.now(),
        totalPrice: 200.0,
        depositAmount: 50.0,
        finalAmount: 0.0,
        status: 'completed',
        createdAt: DateTime.now().subtract(const Duration(days: 2)),
      );

      final approvedPayment = PaymentModel(
        id: 'p_app',
        bookingId: 'b_test',
        userId: 'u1',
        amount: 150.0,
        depositAmount: 50.0,
        balanceAmount: 100.0,
        paymentMethod: 'FPX',
        paymentDate: DateTime.now(),
        status: 'Approved',
        paymentStatus: 'Approved',
      );

      service.evaluateRestrictionForData([completedBooking], [approvedPayment]);
      expect(service.isRestricted, false);
      expect(service.totalOutstandingAmount, 0.0);
    });
  });
}
