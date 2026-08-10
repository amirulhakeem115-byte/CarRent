import 'package:flutter_test/flutter_test.dart';
import 'package:carrent_system/models/user_model.dart';
import 'package:carrent_system/models/booking_model.dart';
import 'package:carrent_system/services/booking_service.dart';

void main() {
  group('Employee Management & Role Normalization Unit Tests', () {
    test('UserModel role normalization recognizes admin case-insensitively', () {
      final userLower = UserModel(
        id: 'u1',
        fullName: 'Admin User',
        email: 'admin@test.com',
        phone: '123456',
        role: 'admin',
        createdAt: '2026-08-10T10:00:00Z',
      );
      final userTitle = UserModel(
        id: 'u2',
        fullName: 'Admin User 2',
        email: 'admin2@test.com',
        phone: '123456',
        role: 'Admin',
        createdAt: '2026-08-10T10:00:00Z',
      );
      final userUpper = UserModel(
        id: 'u3',
        fullName: 'Admin User 3',
        email: 'admin3@test.com',
        phone: '123456',
        role: 'ADMIN',
        createdAt: '2026-08-10T10:00:00Z',
      );

      expect(userLower.isAdmin, isTrue);
      expect(userTitle.isAdmin, isTrue);
      expect(userUpper.isAdmin, isTrue);
      expect(userLower.isEmployee, isFalse);
      expect(userLower.isCustomer, isFalse);
    });

    test('UserModel role normalization recognizes employee case-insensitively', () {
      final empLower = UserModel(
        id: 'e1',
        fullName: 'Staff User 1',
        email: 'staff1@test.com',
        phone: '123456',
        role: 'employee',
        employeeId: 'EMP-101',
        createdAt: '2026-08-10T10:00:00Z',
      );
      final empTitle = UserModel(
        id: 'e2',
        fullName: 'Staff User 2',
        email: 'staff2@test.com',
        phone: '123456',
        role: 'Employee',
        employeeId: 'EMP-102',
        createdAt: '2026-08-10T10:00:00Z',
      );
      final empUpper = UserModel(
        id: 'e3',
        fullName: 'Staff User 3',
        email: 'staff3@test.com',
        phone: '123456',
        role: 'EMPLOYEE',
        employeeId: 'EMP-103',
        createdAt: '2026-08-10T10:00:00Z',
      );

      expect(empLower.isEmployee, isTrue);
      expect(empTitle.isEmployee, isTrue);
      expect(empUpper.isEmployee, isTrue);
      expect(empLower.isAdmin, isFalse);
      expect(empLower.isCustomer, isFalse);
      expect(empLower.employeeId, equals('EMP-101'));
    });

    test('UserModel role normalization recognizes customer case-insensitively', () {
      final custLower = UserModel(
        id: 'c1',
        fullName: 'Customer 1',
        email: 'cust1@test.com',
        phone: '123456',
        role: 'customer',
        createdAt: '2026-08-10T10:00:00Z',
      );
      final custTitle = UserModel(
        id: 'c2',
        fullName: 'Customer 2',
        email: 'cust2@test.com',
        phone: '123456',
        role: 'Customer',
        createdAt: '2026-08-10T10:00:00Z',
      );

      expect(custLower.isCustomer, isTrue);
      expect(custTitle.isCustomer, isTrue);
      expect(custLower.isAdmin, isFalse);
      expect(custLower.isEmployee, isFalse);
    });

    test('UserModel.fromMap correctly parses employeeId and role fields', () {
      final map = {
        'fullName': 'Ahmad Razak',
        'email': 'ahmad@carrent.com',
        'phone': '+60123456789',
        'role': 'Employee',
        'employeeId': 'EMP-2026',
        'accountStatus': 'Active',
        'isActive': true,
        'createdAt': '2026-08-10T10:00:00Z',
      };

      final model = UserModel.fromMap('user_emp_99', map);
      expect(model.id, equals('user_emp_99'));
      expect(model.fullName, equals('Ahmad Razak'));
      expect(model.email, equals('ahmad@carrent.com'));
      expect(model.employeeId, equals('EMP-2026'));
      expect(model.isEmployee, isTrue);
      expect(model.isActive, isTrue);
      expect(model.accountStatus, equals('Active'));
    });

    test('UserModel.toMap preserves employeeId and role fields', () {
      final user = UserModel(
        id: 'user_emp_88',
        fullName: 'Siti Sarah',
        email: 'siti@carrent.com',
        phone: '+60198765432',
        role: 'employee',
        employeeId: 'EMP-999',
        createdAt: '2026-08-10T10:00:00Z',
      );

      final map = user.toMap();
      expect(map['fullName'], equals('Siti Sarah'));
      expect(map['email'], equals('siti@carrent.com'));
      expect(map['role'], equals('employee'));
      expect(map['employeeId'], equals('EMP-999'));
    });

    test('BookingService helpers classify Pickup, Return, and Delivery statuses correctly', () {
      final pickupBooking = BookingModel(
        id: 'b_pickup_1',
        vehicleId: 'v1',
        vehicleName: 'Honda Civic',
        userId: 'u1',
        userName: 'John Tan',
        userPhone: '+6012345678',
        pickUpDate: DateTime.now().add(const Duration(days: 1)),
        totalPrice: 200,
        depositAmount: 50,
        status: 'approved',
        createdAt: DateTime.now(),
      );

      final returnBooking = BookingModel(
        id: 'b_return_1',
        vehicleId: 'v2',
        vehicleName: 'Toyota Camry',
        userId: 'u2',
        userName: 'Mary Lim',
        userPhone: '+60187654321',
        pickUpDate: DateTime.now().subtract(const Duration(days: 2)),
        returnDate: DateTime.now().add(const Duration(hours: 4)),
        totalPrice: 400,
        depositAmount: 100,
        status: 'active',
        createdAt: DateTime.now(),
      );

      final deliveryBooking = BookingModel(
        id: 'b_deliv_1',
        vehicleId: 'v3',
        vehicleName: 'BMW X5',
        userId: 'u3',
        userName: 'David Lee',
        userPhone: '+60111223344',
        pickUpDate: DateTime.now().add(const Duration(days: 2)),
        totalPrice: 800,
        depositAmount: 200,
        status: 'approved',
        notes: 'Please deliver car to KLIA Terminal 1',
        createdAt: DateTime.now(),
      );

      expect(BookingService.isUpcomingStatus(pickupBooking.status), isTrue);
      expect(BookingService.isOngoingStatus(returnBooking.status), isTrue);
      expect(deliveryBooking.notes?.contains('deliver'), isTrue);
    });

    test('Employee task assignment logic isolates tasks strictly by assigned employee ID', () {
      final empAId = 'EMP-101';
      final empBId = 'EMP-102';

      final taskEmpA = BookingModel(
        id: 'b_emp_a',
        vehicleId: 'v1',
        vehicleName: 'Perodua Myvi',
        userId: 'u1',
        userName: 'Customer 1',
        userPhone: '0123456789',
        pickUpDate: DateTime.now(),
        totalPrice: 150,
        depositAmount: 50,
        status: 'approved',
        assignedEmployeeId: empAId,
        createdAt: DateTime.now(),
      );

      final taskEmpB = BookingModel(
        id: 'b_emp_b',
        vehicleId: 'v2',
        vehicleName: 'Proton Saga',
        userId: 'u2',
        userName: 'Customer 2',
        userPhone: '0198765432',
        pickUpDate: DateTime.now(),
        totalPrice: 120,
        depositAmount: 50,
        status: 'approved',
        assignedEmployeeId: empBId,
        createdAt: DateTime.now(),
      );

      final unassignedTask = BookingModel(
        id: 'b_unassigned',
        vehicleId: 'v3',
        vehicleName: 'Toyota Vios',
        userId: 'u3',
        userName: 'Customer 3',
        userPhone: '0177778888',
        pickUpDate: DateTime.now(),
        totalPrice: 200,
        depositAmount: 50,
        status: 'approved',
        createdAt: DateTime.now(),
      );

      bool isAssignedTo(BookingModel b, String empId) {
        final bAssigned = b.assignedEmployeeId ?? '';
        final bHandedOver = b.handedOverByEmployeeId ?? '';
        final bReceived = b.receivedByEmployeeId ?? '';
        return (bAssigned.isNotEmpty && bAssigned == empId) ||
            (bHandedOver.isNotEmpty && bHandedOver == empId) ||
            (bReceived.isNotEmpty && bReceived == empId);
      }

      expect(isAssignedTo(taskEmpA, empAId), isTrue);
      expect(isAssignedTo(taskEmpA, empBId), isFalse);

      expect(isAssignedTo(taskEmpB, empBId), isTrue);
      expect(isAssignedTo(taskEmpB, empAId), isFalse);

      expect(isAssignedTo(unassignedTask, empAId), isFalse);
      expect(isAssignedTo(unassignedTask, empBId), isFalse);
    });
  });
}
