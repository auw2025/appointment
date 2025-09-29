// appointment_model.dart
import 'package:syncfusion_flutter_calendar/calendar.dart';

class AppointmentRequest {
  String studentName;
  DateTime startTime;
  bool isAccepted;
  String? rejectionReason;

  AppointmentRequest(
    this.studentName,
    this.startTime,
    this.isAccepted, {
    this.rejectionReason,
  });
}

// Renamed the class to AppointmentDataSource (removed underscore)
class AppointmentDataSource extends CalendarDataSource {
  AppointmentDataSource(List<Appointment> source) {
    appointments = source;
  }
}