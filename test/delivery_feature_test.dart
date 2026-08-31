import 'package:flutter_test/flutter_test.dart';
import 'package:carrent_system/models/booking_model.dart';

void main() {
  group('Delivery Feature Unit Tests', () {
    test('BookingModel handles delivery fields serialization and deserialization', () {
      final now = DateTime.now();
      final booking = BookingModel(
        id: 'B-DEL-001',
        vehicleId: 'V1',
        vehicleName: 'Proton X50',
        userId: 'U1',
        userName: 'John Doe',
        userPhone: '+60123456789',
        pickUpDate: now,
        totalPrice: 200.0,
        depositAmount: 50.0,
        status: 'Confirmed',
        createdAt: now,
        deliveryFee: 30.0,
        isDelivery: true,
        deliveryAddress: '123 Jalan Ampang, Kuala Lumpur',
        deliveryDate: now,
        deliveryTime: '10:00 AM',
        deliveryStatus: 'Out for Delivery',
      );

      final map = booking.toMap();
      expect(map['deliveryFee'], 30.0);
      expect(map['isDelivery'], true);
      expect(map['deliveryAddress'], '123 Jalan Ampang, Kuala Lumpur');
      expect(map['deliveryTime'], '10:00 AM');
      expect(map['deliveryStatus'], 'Out for Delivery');

      final deserialized = BookingModel.fromMap('B-DEL-001', map);
      expect(deserialized.id, 'B-DEL-001');
      expect(deserialized.deliveryFee, 30.0);
      expect(deserialized.isDelivery, true);
      expect(deserialized.deliveryAddress, '123 Jalan Ampang, Kuala Lumpur');
      expect(deserialized.deliveryTime, '10:00 AM');
      expect(deserialized.deliveryStatus, 'Out for Delivery');
    });

    test('BookingModel defaults for non-delivery bookings', () {
      final now = DateTime.now();
      final booking = BookingModel(
        id: 'B-STD-001',
        vehicleId: 'V2',
        vehicleName: 'Perodua Myvi',
        userId: 'U2',
        userName: 'Jane Smith',
        userPhone: '+60198765432',
        pickUpDate: now,
        totalPrice: 100.0,
        depositAmount: 30.0,
        status: 'Confirmed',
        createdAt: now,
      );

      expect(booking.isDelivery, false);
      expect(booking.deliveryFee, 0.0);
      expect(booking.deliveryAddress, isNull);
      expect(booking.deliveryStatus, 'Scheduled');
    });

    test('Filtering delivery bookings from a list of bookings', () {
      final now = DateTime.now();
      final b1 = BookingModel(
        id: 'B1',
        vehicleId: 'V1',
        vehicleName: 'Car 1',
        userId: 'U1',
        userName: 'User 1',
        userPhone: '',
        pickUpDate: now,
        totalPrice: 100,
        depositAmount: 20,
        status: 'Confirmed',
        createdAt: now,
        isDelivery: true,
        deliveryFee: 30,
      );
      final b2 = BookingModel(
        id: 'B2',
        vehicleId: 'V2',
        vehicleName: 'Car 2',
        userId: 'U2',
        userName: 'User 2',
        userPhone: '',
        pickUpDate: now,
        totalPrice: 120,
        depositAmount: 20,
        status: 'Confirmed',
        createdAt: now,
        isDelivery: false,
      );

      final list = [b1, b2];
      final deliveryOnly = list.where((b) => b.isDelivery).toList();
      expect(deliveryOnly.length, 1);
      expect(deliveryOnly.first.id, 'B1');
    });
  });
}
