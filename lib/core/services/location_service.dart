import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';

import '../models/customer.dart';

/// Service to detect and reverse-geocode current location.
class LocationService {
  LocationService._();

  /// Attempts to detect real location via network IP Geolocation with resilient fallback.
  static Future<AddressEntry> detectCurrentLocation() async {
    try {
      if (!kIsWeb) {
        final client = HttpClient();
        client.connectionTimeout = const Duration(seconds: 4);

        final request = await client.getUrl(
          Uri.parse(
            'http://ip-api.com/json/?fields=status,country,regionName,city,district,zip,lat,lon',
          ),
        );
        final response = await request.close();
        if (response.statusCode == 200) {
          final body = await response.transform(utf8.decoder).join();
          final data = jsonDecode(body) as Map<String, dynamic>;

          if (data['status'] == 'success') {
            final city = data['city']?.toString() ?? 'Ahmedabad';
            final state = data['regionName']?.toString() ?? 'Gujarat';
            final zip = data['zip']?.toString() ?? '380015';
            final district = data['district']?.toString() ?? '';
            final area = district.isNotEmpty ? district : city;
            final lat = (data['lat'] as num?)?.toDouble() ?? 0.0;
            final lon = (data['lon'] as num?)?.toDouble() ?? 0.0;

            return AddressEntry(
              id: 'current_gps',
              name: 'Current Location',
              address: area,
              city: city,
              state: state,
              pincode: zip,
              lat: lat,
              lng: lon,
              label: 'Current Location',
              isDefault: true,
            );
          }
        }
      }
    } catch (e) {
      debugPrint('[LocationService] detectCurrentLocation error: $e');
    }

    // Default fallback
    return const AddressEntry(
      id: 'current_gps',
      name: 'Current Location',
      address: 'Satellite, SG Highway',
      city: 'Ahmedabad',
      state: 'Gujarat',
      pincode: '380015',
      label: 'Current Location',
      isDefault: true,
    );
  }

  /// Resolves common Indian cities by 6-digit pincode prefix
  static (String city, String state) resolveCityStateFromPincode(
    String pincode,
  ) {
    if (pincode.length < 2) return ('', '');
    final prefix2 = pincode.substring(0, 2);
    final prefix3 = pincode.length >= 3 ? pincode.substring(0, 3) : '';

    if (prefix3 == '380' || prefix3 == '382') {
      return ('Ahmedabad', 'Gujarat');
    }
    if (prefix3 == '395' || prefix3 == '394') {
      return ('Surat', 'Gujarat');
    }
    if (prefix3 == '390') {
      return ('Vadodara', 'Gujarat');
    }
    if (prefix3 == '360') {
      return ('Rajkot', 'Gujarat');
    }
    if (prefix2 == '38' || prefix2 == '39' || prefix2 == '36') {
      return ('Gujarat', 'Gujarat');
    }
    if (prefix2 == '11') {
      return ('New Delhi', 'Delhi');
    }
    if (prefix2 == '40') {
      return ('Mumbai', 'Maharashtra');
    }
    if (prefix2 == '41') {
      return ('Pune', 'Maharashtra');
    }
    if (prefix2 == '56') {
      return ('Bengaluru', 'Karnataka');
    }
    if (prefix2 == '50') {
      return ('Hyderabad', 'Telangana');
    }
    if (prefix2 == '60') {
      return ('Chennai', 'Tamil Nadu');
    }
    if (prefix2 == '70') {
      return ('Kolkata', 'West Bengal');
    }
    if (prefix2 == '30') {
      return ('Jaipur', 'Rajasthan');
    }
    if (prefix2 == '22') {
      return ('Lucknow', 'Uttar Pradesh');
    }
    if (prefix2 == '45') {
      return ('Indore', 'Madhya Pradesh');
    }

    return ('', '');
  }
}
