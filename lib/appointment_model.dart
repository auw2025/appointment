// appointment_model.dart
import 'package:flutter/material.dart';
import 'package:syncfusion_flutter_calendar/calendar.dart';
import 'package:intl/intl.dart';

/// Model for an appointment (meeting) in the calendar, stored in Firestore.
class Meeting {
  String subject;
  DateTime from;
  DateTime to;
  Color background;
  bool isAllDay;

  /// Firestore-specific fields
  String? key; // Firestore document ID
  String status; // 'pending', 'accepted', or 'rejected'
  String studentName; // Name of the requesting student
  
  /// New field: Combined student class and class number (e.g., "5J 23")
  String? studentClassAndNumber;
  
  String? rejectionReason; // Reason provided if chaplain rejects

  Meeting({
    required this.subject,
    required this.from,
    required this.to,
    required this.background,
    this.isAllDay = false,
    this.key,
    required this.status,
    required this.studentName,
    this.studentClassAndNumber,
    this.rejectionReason,
  });

  /// Map a Firestore doc snapshot -> Meeting object
  factory Meeting.fromFireStoreDoc(String docId, Map<String, dynamic> data, Color color) {
    return Meeting(
      key: docId,
      subject: data['Subject'] ?? '',
      studentName: data['StudentName'] ?? '',
      studentClassAndNumber: data['StudentClassAndNumber'], // Reads the combined field
      status: data['Status'] ?? 'pending',
      rejectionReason: data['RejectionReason'],
      from: DateFormat('dd/MM/yyyy HH:mm:ss').parse(data['StartTime']),
      to: DateFormat('dd/MM/yyyy HH:mm:ss').parse(data['EndTime']),
      background: color,
    );
  }
}

/// Data source for Syncfusion Calendar
class MeetingDataSource extends CalendarDataSource {
  MeetingDataSource(List<Meeting> source) {
    appointments = source;
  }

  Meeting getMeeting(int index) => appointments![index];

  @override
  DateTime getStartTime(int index) {
    return getMeeting(index).from;
  }

  @override
  DateTime getEndTime(int index) {
    return getMeeting(index).to;
  }

  @override
  String getSubject(int index) {
    return getMeeting(index).subject;
  }

  @override
  Color getColor(int index) {
    return getMeeting(index).background;
  }

  @override
  bool isAllDay(int index) {
    return getMeeting(index).isAllDay;
  }
}