import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:google_fonts/google_fonts.dart';
import '../core/utils/helper.dart';
import '../services/city_service.dart';

class CityPickerSheet extends StatefulWidget {
  final String? initialCity;
  final ValueChanged<CityLocation> onCitySelected;

  const CityPickerSheet({
    super.key,
    this.initialCity,
    required this.onCitySelected,
  });

  static Future<void> show({
    required BuildContext context,
    String? initialCity,
    required ValueChanged<CityLocation> onCitySelected,
  }) {
    return showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => CityPickerSheet(
        initialCity: initialCity,
        onCitySelected: onCitySelected,
      ),
    );
  }

  @override
  State<CityPickerSheet> createState() => _CityPickerSheetState();
}

class _CityPickerSheetState extends State<CityPickerSheet> {
  final TextEditingController _searchCtrl = TextEditingController();
  List<CityLocation> _results = [];
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _isLoading = true;
    if (widget.initialCity != null && widget.initialCity!.isNotEmpty) {
      _searchCtrl.text = widget.initialCity!;
    }
    _loadInitialCities();
  }

  Future<void> _loadInitialCities() async {
    final list = await CityService().searchCities(_searchCtrl.text);
    if (!mounted) return;
    setState(() {
      _results = list;
      _isLoading = false;
    });
  }

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  Future<void> _performSearch(String query) async {
    final list = await CityService().searchCities(query);
    if (!mounted) return;
    setState(() {
      _results = list;
      _isLoading = false;
    });
  }

  Color _getTimezoneColor(String timezone) {
    switch (timezone.toUpperCase()) {
      case 'WITA':
        return const Color(0xFF0D9488); // Teal
      case 'WIT':
        return const Color(0xFF8B5CF6); // Purple
      case 'WIB':
      default:
        return const Color(0xFF2563EB); // Blue
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final surfaceColor = Theme.of(context).colorScheme.surface;
    final onSurface = Theme.of(context).colorScheme.onSurface;

    return Container(
      height: MediaQuery.of(context).size.height * 0.75,
      decoration: BoxDecoration(
        color: surfaceColor,
        borderRadius: BorderRadius.vertical(top: Radius.circular(24.r)),
      ),
      padding: EdgeInsets.fromLTRB(20.w, 12.h, 20.w, 20.h),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Drag handle
          Center(
            child: Container(
              width: 44.w,
              height: 4.h,
              decoration: BoxDecoration(
                color: isDark ? const Color(0xFF475569) : const Color(0xFFCBD5E1),
                borderRadius: BorderRadius.circular(4.r),
              ),
            ),
          ),
          SizedBox(height: 14.h),

          // Title
          Row(
            children: [
              Icon(Icons.location_city_rounded, color: const Color(0xFF2563EB), size: 22.sp),
              SizedBox(width: 8.w),
              Text(
                'Pilih Tempat Tinggal / Kota',
                style: GoogleFonts.hankenGrotesk(
                  fontSize: 16.sp,
                  fontWeight: FontWeight.w800,
                  color: onSurface,
                ),
              ),
              const Spacer(),
              if (!_isLoading)
                Container(
                  padding: EdgeInsets.symmetric(horizontal: 10.w, vertical: 4.h),
                  decoration: BoxDecoration(
                    color: const Color(0xFF2563EB).withValues(alpha: isDark ? 0.25 : 0.1),
                    borderRadius: BorderRadius.circular(20.r),
                  ),
                  child: Text(
                    '${_results.length} Wilayah',
                    style: GoogleFonts.hankenGrotesk(
                      fontSize: 11.sp,
                      fontWeight: FontWeight.w700,
                      color: const Color(0xFF2563EB),
                    ),
                  ),
                ),
            ],
          ),
          SizedBox(height: 4.h),
          Text(
            _searchCtrl.text.trim().isEmpty
                ? 'Mencakup seluruh 897 kota dan kabupaten di Indonesia (WIB, WITA, WIT otomatis disinkronkan).'
                : 'Ditemukan ${_results.length} kota & kabupaten yang cocok.',
            style: GoogleFonts.hankenGrotesk(
              fontSize: 12.sp,
              color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B),
            ),
          ),
          SizedBox(height: 12.h),

          // Search Field
          TextField(
            controller: _searchCtrl,
            onChanged: (val) => _performSearch(val),
            autofocus: false,
            decoration: InputDecoration(
              hintText: 'Cari kota (misal: Malang, Bungo, Denpasar, Jayapura)...',
              hintStyle: GoogleFonts.hankenGrotesk(fontSize: 13.sp),
              prefixIcon: const Icon(Icons.search_rounded),
              suffixIcon: _searchCtrl.text.isNotEmpty
                  ? IconButton(
                      icon: const Icon(Icons.clear_rounded),
                      onPressed: () {
                        _searchCtrl.clear();
                        _performSearch('');
                      },
                    )
                  : null,
              contentPadding: EdgeInsets.symmetric(horizontal: 14.w, vertical: 12.h),
              filled: true,
              fillColor: isDark ? const Color(0xFF1E293B) : const Color(0xFFF8FAFC),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12.r),
                borderSide: BorderSide(color: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0)),
              ),
            ),
          ),
          SizedBox(height: 12.h),

          // Custom entry option if query doesn't match exactly
          if (_searchCtrl.text.trim().isNotEmpty) ...[
            Builder(
              builder: (ctx) {
                final q = _searchCtrl.text.trim();
                final detectedTz = AppHelper.detectTimezoneFromCity(q);
                return InkWell(
                  onTap: () {
                    final item = CityLocation(
                      city: q,
                      province: '',
                      timezone: detectedTz,
                    );
                    widget.onCitySelected(item);
                    Navigator.pop(context);
                  },
                  borderRadius: BorderRadius.circular(10.r),
                  child: Container(
                    margin: EdgeInsets.only(bottom: 8.h),
                    padding: EdgeInsets.symmetric(horizontal: 12.w, vertical: 10.h),
                    decoration: BoxDecoration(
                      color: const Color(0xFF2563EB).withValues(alpha: isDark ? 0.2 : 0.08),
                      borderRadius: BorderRadius.circular(10.r),
                      border: Border.all(color: const Color(0xFF2563EB).withValues(alpha: 0.3)),
                    ),
                    child: Row(
                      children: [
                        const Icon(Icons.add_location_alt_rounded, color: Color(0xFF2563EB), size: 20),
                        SizedBox(width: 8.w),
                        Expanded(
                          child: Text(
                            'Gunakan "$q"',
                            style: GoogleFonts.hankenGrotesk(
                              fontSize: 13.sp,
                              fontWeight: FontWeight.w700,
                              color: const Color(0xFF2563EB),
                            ),
                          ),
                        ),
                        Container(
                          padding: EdgeInsets.symmetric(horizontal: 8.w, vertical: 2.h),
                          decoration: BoxDecoration(
                            color: _getTimezoneColor(detectedTz).withValues(alpha: 0.2),
                            borderRadius: BorderRadius.circular(6.r),
                          ),
                          child: Text(
                            'Auto: $detectedTz',
                            style: GoogleFonts.hankenGrotesk(
                              fontSize: 11.sp,
                              fontWeight: FontWeight.w800,
                              color: _getTimezoneColor(detectedTz),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
          ],

          // Results List
          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator(color: Color(0xFF2563EB)))
                : _results.isEmpty
                    ? Center(
                        child: Text(
                          'Tidak ada kota yang cocok',
                          style: GoogleFonts.hankenGrotesk(
                            fontSize: 13.sp,
                            color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B),
                          ),
                        ),
                      )
                    : ListView.separated(
                        itemCount: _results.length,
                        separatorBuilder: (ctx, i) => Divider(
                          height: 1,
                          color: isDark ? const Color(0xFF334155) : const Color(0xFFF1F5F9),
                        ),
                        itemBuilder: (ctx, i) {
                          final item = _results[i];
                          final tzColor = _getTimezoneColor(item.timezone);
                          return ListTile(
                            contentPadding: EdgeInsets.symmetric(horizontal: 6.w, vertical: 2.h),
                            leading: Container(
                              padding: EdgeInsets.all(8.r),
                              decoration: BoxDecoration(
                                color: tzColor.withValues(alpha: isDark ? 0.25 : 0.1),
                                shape: BoxShape.circle,
                              ),
                              child: Icon(Icons.location_on_rounded, color: tzColor, size: 18.sp),
                            ),
                            title: Text(
                              item.city,
                              style: GoogleFonts.hankenGrotesk(
                                fontSize: 13.5.sp,
                                fontWeight: FontWeight.w700,
                                color: onSurface,
                              ),
                            ),
                            subtitle: item.province.isNotEmpty
                                ? Text(
                                    item.province,
                                    style: GoogleFonts.hankenGrotesk(
                                      fontSize: 11.5.sp,
                                      color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B),
                                    ),
                                  )
                                : null,
                            trailing: Container(
                              padding: EdgeInsets.symmetric(horizontal: 8.w, vertical: 3.h),
                              decoration: BoxDecoration(
                                color: tzColor.withValues(alpha: isDark ? 0.2 : 0.1),
                                borderRadius: BorderRadius.circular(6.r),
                                border: Border.all(color: tzColor.withValues(alpha: 0.3)),
                              ),
                              child: Text(
                                item.timezone,
                                style: GoogleFonts.hankenGrotesk(
                                  fontSize: 11.sp,
                                  fontWeight: FontWeight.w800,
                                  color: tzColor,
                                ),
                              ),
                            ),
                            onTap: () {
                              widget.onCitySelected(item);
                              Navigator.pop(context);
                            },
                          );
                        },
                      ),
          ),
        ],
      ),
    );
  }
}
