import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../core/utils/helper.dart';

class CityLocation {
  final String city;
  final String province;
  final String timezone;

  String get name => city;

  const CityLocation({
    required this.city,
    required this.province,
    required this.timezone,
  });

  factory CityLocation.fromJson(Map<String, dynamic> json) {
    final cityName = AppHelper.cleanCityName(
      json['city']?.toString() ?? json['name']?.toString() ?? '',
    );
    final provName = AppHelper.cleanProvinceName(
      json['province']?.toString() ?? json['state_name']?.toString() ?? '',
    );
    final rawTz = json['timezone']?.toString().toUpperCase().trim();
    final tz = (rawTz == 'WIB' || rawTz == 'WITA' || rawTz == 'WIT')
        ? rawTz!
        : AppHelper.detectTimezoneFromCity(cityName, province: provName);

    return CityLocation(
      city: cityName,
      province: provName,
      timezone: tz,
    );
  }

  factory CityLocation.fromMap(Map<String, dynamic> map) {
    final cityName = AppHelper.cleanCityName(map['name']?.toString() ?? '');
    String provName = '';
    final stateData = map['states'];
    if (stateData is Map) {
      provName = stateData['name']?.toString() ?? '';
    } else if (map['state_name'] != null) {
      provName = map['state_name'].toString();
    }
    provName = AppHelper.cleanProvinceName(provName);

    final tz = AppHelper.detectTimezoneFromCity(cityName, province: provName);
    return CityLocation(
      city: cityName,
      province: provName,
      timezone: tz,
    );
  }
}

class CityService {
  static final CityService _instance = CityService._internal();
  factory CityService() => _instance;
  CityService._internal();

  List<CityLocation> _allCities = [];
  bool _isLoaded = false;
  bool _isLoadingFromSupabase = false;

  /// Memuat seluruh kota & kabupaten resmi di Indonesia (897 kota/kabupaten)
  Future<List<CityLocation>> getAllCities() async {
    if (_isLoaded && _allCities.isNotEmpty) {
      return _allCities;
    }

    // 1. Muat dari bundle aset lokal JSON terlebih dahulu (instan 0ms)
    try {
      final jsonString = await rootBundle.loadString('assets/indonesia_cities.json');
      final List<dynamic> decoded = json.decode(jsonString);
      _allCities = decoded.map((e) => CityLocation.fromJson(e as Map<String, dynamic>)).toList();
      _isLoaded = true;
    } catch (e) {
      debugPrint('CityService load asset error: $e');
    }

    // 2. Fallback jika aset belum siap
    if (_allCities.isEmpty) {
      _allCities = List.from(popularCities);
    }

    // 3. Sinkronkan dengan Supabase secara background
    _fetchFromSupabaseInBackground();

    return _allCities;
  }

  Future<void> _fetchFromSupabaseInBackground() async {
    if (_isLoadingFromSupabase) return;
    _isLoadingFromSupabase = true;
    try {
      final client = Supabase.instance.client;
      final res = await client
          .from('cities')
          .select('id, name, state_id, states(name)')
          .eq('country_code', 'ID')
          .order('name');

      final list = (res as List)
          .map((item) => CityLocation.fromMap(item as Map<String, dynamic>))
          .toList();

      if (list.isNotEmpty) {
        _allCities = list;
        _isLoaded = true;
      }
    } catch (_) {
      // Fallback lokal tetap aman
    } finally {
      _isLoadingFromSupabase = false;
    }
  }

  /// Cari kota dari seluruh 897 kota & kabupaten Indonesia
  Future<List<CityLocation>> searchCities(String query) async {
    final cleanQ = query.trim();
    final all = await getAllCities();

    if (cleanQ.isEmpty) {
      return all;
    }

    final lower = cleanQ.toLowerCase();
    final matches = all.where((c) {
      final cityMatch = c.city.toLowerCase().contains(lower);
      final provMatch = c.province.toLowerCase().contains(lower);
      return cityMatch || provMatch;
    }).toList();

    // Urutkan kecocokan nama agar paling relevan di posisi teratas
    matches.sort((a, b) {
      final aExact = a.city.toLowerCase() == lower;
      final bExact = b.city.toLowerCase() == lower;
      if (aExact && !bExact) return -1;
      if (!aExact && bExact) return 1;

      final aStarts = a.city.toLowerCase().startsWith(lower);
      final bStarts = b.city.toLowerCase().startsWith(lower);
      if (aStarts && !bStarts) return -1;
      if (!aStarts && bStarts) return 1;

      return a.city.compareTo(b.city);
    });

    if (matches.isEmpty) {
      // Opsi entri kustom jika nama tidak terdaftar
      return [
        CityLocation(
          city: cleanQ,
          province: '',
          timezone: AppHelper.detectTimezoneFromCity(cleanQ),
        ),
      ];
    }

    return matches;
  }

  static const List<CityLocation> popularCities = [
    CityLocation(city: 'Kota Malang', province: 'Jawa Timur', timezone: 'WIB'),
    CityLocation(city: 'Kabupaten Malang', province: 'Jawa Timur', timezone: 'WIB'),
    CityLocation(city: 'Kabupaten Bungo', province: 'Jambi', timezone: 'WIB'),
    CityLocation(city: 'Kota Surabaya', province: 'Jawa Timur', timezone: 'WIB'),
    CityLocation(city: 'DKI Jakarta', province: 'DKI Jakarta', timezone: 'WIB'),
    CityLocation(city: 'Kota Bandung', province: 'Jawa Barat', timezone: 'WIB'),
    CityLocation(city: 'Kota Semarang', province: 'Jawa Tengah', timezone: 'WIB'),
    CityLocation(city: 'Kota Yogyakarta', province: 'DI Yogyakarta', timezone: 'WIB'),
    CityLocation(city: 'Kota Medan', province: 'Sumatera Utara', timezone: 'WIB'),
    CityLocation(city: 'Kota Palembang', province: 'Sumatera Selatan', timezone: 'WIB'),
    CityLocation(city: 'Kota Denpasar', province: 'Bali', timezone: 'WITA'),
    CityLocation(city: 'Kabupaten Badung', province: 'Bali', timezone: 'WITA'),
    CityLocation(city: 'Kabupaten Klungkung', province: 'Bali', timezone: 'WITA'),
    CityLocation(city: 'Kota Makassar', province: 'Sulawesi Selatan', timezone: 'WITA'),
    CityLocation(city: 'Kota Balikpapan', province: 'Kalimantan Timur', timezone: 'WITA'),
    CityLocation(city: 'Kota Banjarmasin', province: 'Kalimantan Selatan', timezone: 'WITA'),
    CityLocation(city: 'Kota Mataram', province: 'Nusa Tenggara Barat', timezone: 'WITA'),
    CityLocation(city: 'Kota Kupang', province: 'Nusa Tenggara Timur', timezone: 'WITA'),
    CityLocation(city: 'Kota Jayapura', province: 'Papua', timezone: 'WIT'),
    CityLocation(city: 'Kota Ambon', province: 'Maluku', timezone: 'WIT'),
    CityLocation(city: 'Kota Sorong', province: 'Papua Barat Daya', timezone: 'WIT'),
  ];
}
