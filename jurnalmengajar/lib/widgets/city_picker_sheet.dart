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

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final surfaceColor = Theme.of(context).colorScheme.surface;
    final onSurface = Theme.of(context).colorScheme.onSurface;
    final slateText = isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B);
    final borderColor = isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0);

    return Container(
      height: MediaQuery.of(context).size.height * 0.72,
      decoration: BoxDecoration(
        color: surfaceColor,
        borderRadius: BorderRadius.vertical(top: Radius.circular(24.r)),
      ),
      padding: EdgeInsets.fromLTRB(20.w, 12.h, 20.w, 16.h),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Drag handle
          Center(
            child: Container(
              width: 40.w,
              height: 4.h,
              decoration: BoxDecoration(
                color: isDark ? const Color(0xFF475569) : const Color(0xFFCBD5E1),
                borderRadius: BorderRadius.circular(2.r),
              ),
            ),
          ),
          SizedBox(height: 14.h),

          // Header
          Row(
            children: [
              Text(
                'Pilih Kota Domisili',
                style: GoogleFonts.hankenGrotesk(
                  fontSize: 16.sp,
                  fontWeight: FontWeight.w700,
                  color: onSurface,
                ),
              ),
              const Spacer(),
              IconButton(
                icon: const Icon(Icons.close_rounded, size: 20),
                onPressed: () => Navigator.pop(context),
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(),
                color: slateText,
                tooltip: 'Tutup',
              ),
            ],
          ),
          SizedBox(height: 4.h),
          Text(
            'Pilih kota tempat tinggal Anda untuk penyesuaian zona waktu otomatis.',
            style: GoogleFonts.hankenGrotesk(
              fontSize: 12.5.sp,
              color: slateText,
            ),
          ),
          SizedBox(height: 14.h),

          // Search Field
          TextField(
            controller: _searchCtrl,
            onChanged: _performSearch,
            autofocus: false,
            style: GoogleFonts.hankenGrotesk(fontSize: 13.5.sp, color: onSurface),
            decoration: InputDecoration(
              hintText: 'Cari nama kota atau provinsi...',
              hintStyle: GoogleFonts.hankenGrotesk(fontSize: 13.sp, color: slateText),
              prefixIcon: Icon(Icons.search_rounded, size: 18.sp, color: slateText),
              suffixIcon: _searchCtrl.text.isNotEmpty
                  ? IconButton(
                      icon: const Icon(Icons.clear_rounded, size: 16),
                      onPressed: () {
                        _searchCtrl.clear();
                        _performSearch('');
                      },
                    )
                  : null,
              contentPadding: EdgeInsets.symmetric(horizontal: 14.w, vertical: 11.h),
              filled: true,
              fillColor: isDark ? const Color(0xFF0F172A) : const Color(0xFFF8FAFC),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12.r),
                borderSide: BorderSide(color: borderColor),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12.r),
                borderSide: BorderSide(color: borderColor),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12.r),
                borderSide: const BorderSide(color: Color(0xFF2563EB), width: 1.5),
              ),
            ),
          ),
          SizedBox(height: 12.h),

          // Opsi entri kustom jika nama yang diketik belum ada di daftar
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
                  borderRadius: BorderRadius.circular(12.r),
                  child: Container(
                    margin: EdgeInsets.only(bottom: 8.h),
                    padding: EdgeInsets.symmetric(horizontal: 14.w, vertical: 10.h),
                    decoration: BoxDecoration(
                      color: isDark ? const Color(0xFF1E293B) : const Color(0xFFF8FAFC),
                      borderRadius: BorderRadius.circular(12.r),
                      border: Border.all(color: borderColor),
                    ),
                    child: Row(
                      children: [
                        Icon(
                          Icons.add_location_alt_outlined,
                          color: const Color(0xFF2563EB),
                          size: 18.sp,
                        ),
                        SizedBox(width: 10.w),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Gunakan "$q"',
                                style: GoogleFonts.hankenGrotesk(
                                  fontSize: 13.sp,
                                  fontWeight: FontWeight.w600,
                                  color: onSurface,
                                ),
                              ),
                              Text(
                                'Zona waktu terdeteksi: $detectedTz',
                                style: GoogleFonts.hankenGrotesk(
                                  fontSize: 11.5.sp,
                                  color: slateText,
                                ),
                              ),
                            ],
                          ),
                        ),
                        Container(
                          padding: EdgeInsets.symmetric(horizontal: 8.w, vertical: 3.h),
                          decoration: BoxDecoration(
                            color: isDark ? const Color(0xFF0F172A) : Colors.white,
                            borderRadius: BorderRadius.circular(6.r),
                            border: Border.all(color: borderColor),
                          ),
                          child: Text(
                            detectedTz,
                            style: GoogleFonts.hankenGrotesk(
                              fontSize: 11.sp,
                              fontWeight: FontWeight.w700,
                              color: const Color(0xFF2563EB),
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

          // Daftar hasil
          Expanded(
            child: _isLoading
                ? const Center(
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: Color(0xFF2563EB),
                    ),
                  )
                : _results.isEmpty
                    ? Center(
                        child: Text(
                          'Kota tidak ditemukan',
                          style: GoogleFonts.hankenGrotesk(
                            fontSize: 13.sp,
                            color: slateText,
                          ),
                        ),
                      )
                    : ListView.separated(
                        itemCount: _results.length,
                        separatorBuilder: (ctx, i) => Divider(
                          height: 1,
                          color: borderColor,
                        ),
                        itemBuilder: (ctx, i) {
                          final item = _results[i];
                          return ListTile(
                            contentPadding: EdgeInsets.symmetric(horizontal: 4.w, vertical: 0),
                            dense: true,
                            leading: Container(
                              width: 32.w,
                              height: 32.h,
                              alignment: Alignment.center,
                              decoration: BoxDecoration(
                                color: isDark ? const Color(0xFF1E293B) : const Color(0xFFF1F5F9),
                                borderRadius: BorderRadius.circular(8.r),
                              ),
                              child: Icon(
                                Icons.location_on_outlined,
                                color: slateText,
                                size: 17.sp,
                              ),
                            ),
                            title: Text(
                              item.city,
                              style: GoogleFonts.hankenGrotesk(
                                fontSize: 13.5.sp,
                                fontWeight: FontWeight.w600,
                                color: onSurface,
                              ),
                            ),
                            subtitle: item.province.isNotEmpty
                                ? Text(
                                    item.province,
                                    style: GoogleFonts.hankenGrotesk(
                                      fontSize: 12.sp,
                                      color: slateText,
                                    ),
                                  )
                                : null,
                            trailing: Container(
                              padding: EdgeInsets.symmetric(horizontal: 8.w, vertical: 3.h),
                              decoration: BoxDecoration(
                                color: isDark ? const Color(0xFF1E293B) : const Color(0xFFF1F5F9),
                                borderRadius: BorderRadius.circular(6.r),
                                border: Border.all(color: borderColor),
                              ),
                              child: Text(
                                item.timezone,
                                style: GoogleFonts.hankenGrotesk(
                                  fontSize: 11.sp,
                                  fontWeight: FontWeight.w700,
                                  color: isDark ? const Color(0xFFCBD5E1) : const Color(0xFF475569),
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
