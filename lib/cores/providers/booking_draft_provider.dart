import 'package:flutter_riverpod/flutter_riverpod.dart';

class BookingDraft {
  final String? vehicleId, serviceId;
  final String description, address;
  final List<String> photoUrls;
  final double? budget;
  const BookingDraft({
    this.vehicleId,
    this.serviceId,
    this.description = '',
    this.address = '',
    this.photoUrls = const [],
    this.budget,
  });
  BookingDraft copyWith({
    String? vehicleId,
    String? serviceId,
    String? description,
    String? address,
    List<String>? photoUrls,
    double? budget,
  }) => BookingDraft(
    vehicleId: vehicleId ?? this.vehicleId,
    serviceId: serviceId ?? this.serviceId,
    description: description ?? this.description,
    address: address ?? this.address,
    photoUrls: photoUrls ?? this.photoUrls,
    budget: budget ?? this.budget,
  );
}

class BookingDraftNotifier extends StateNotifier<BookingDraft> {
  BookingDraftNotifier() : super(const BookingDraft());
  void setSelection({String? vehicleId, String? serviceId}) =>
      state = state.copyWith(vehicleId: vehicleId, serviceId: serviceId);
  void setDetails({
    required String description,
    required List<String> photoUrls,
  }) => state = state.copyWith(description: description, photoUrls: photoUrls);
  void setLocation(String address) => state = state.copyWith(address: address);
  void clear() => state = const BookingDraft();
}

final bookingDraftProvider =
    StateNotifierProvider<BookingDraftNotifier, BookingDraft>(
      (ref) => BookingDraftNotifier(),
    );
