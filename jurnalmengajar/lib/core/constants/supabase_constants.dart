/// Supabase table names and constants
class SupabaseConstants {
  // Table names
  static const String tableUsers = 'users';
  static const String tablePeriods = 'periods';
  static const String tableSubjects = 'subjects';
  static const String tableLessonHours = 'lesson_hours';
  static const String tableClasses = 'classes';
  static const String tableSchedules = 'schedules';
  static const String tableJournals = 'journals';
  static const String tableSettings = 'settings';

  // Storage buckets
  static const String bucketJournalAttachments = 'journal-attachments';

  // Field names
  static const String fieldId = 'id';
  static const String fieldEmail = 'email';
  static const String fieldFullName = 'full_name';
  static const String fieldRole = 'role';
  static const String fieldPhoneNumber = 'phone_number';
  static const String fieldPosition = 'position';
  static const String fieldAddress = 'address';
  static const String fieldPhotoUrl = 'photo_url';
  static const String fieldName = 'name';
  static const String fieldIsActive = 'is_active';
  static const String fieldTeachingHour = 'teaching_hour';
  static const String fieldStartTime = 'start_time';
  static const String fieldEndTime = 'end_time';
  static const String fieldPeriodId = 'period_id';
  static const String fieldClassId = 'class_id';
  static const String fieldSubjectId = 'subject_id';
  static const String fieldTeacherId = 'teacher_id';
  static const String fieldStudentCount = 'student_count';
  static const String fieldDate = 'date';
  static const String fieldNote = 'note';
  static const String fieldScheduleId = 'schedule_id';
  static const String fieldMaterial = 'material';
  static const String fieldSickCount = 'sick_count';
  static const String fieldPermissionCount = 'permission_count';
  static const String fieldAlphaCount = 'alpha_count';
  static const String fieldStatus = 'status';
  static const String fieldAttachmentUrl = 'attachment_url';
  static const String fieldMaxJournalInputDays = 'max_journal_input_days';

  // Status values
  static const String statusPending = 'pending';
  static const String statusApproved = 'approved';
  static const String statusRejected = 'rejected';

  // Role values
  static const String roleGuru = 'guru';
  static const String roleAdmin = 'admin';
}
