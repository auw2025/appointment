// appointment_system.dart
import 'dart:math';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:intl/intl.dart';
import 'package:syncfusion_flutter_calendar/calendar.dart';

import 'appointment_model.dart';
import 'login_page.dart';
import 'change_password_page.dart'; // <-- Import the new change password page here

class AppointmentSystem extends StatefulWidget {
  final String loggedUserEmail;

  /// New parameter for the user's role ("chaplain", "student", etc.)
  final String userRole;

  const AppointmentSystem({
    Key? key,
    required this.loggedUserEmail,
    required this.userRole,
  }) : super(key: key);

  @override
  AppointmentSystemState createState() => AppointmentSystemState();
}

class AppointmentSystemState extends State<AppointmentSystem> {
  /// Data source for the accepted appointments in the calendar.
  MeetingDataSource? events;

  /// We no longer use local lists for pending/rejected.
  /// Instead, we'll read them from Firestore in real time.
  List<Meeting> _pendingMeetings = [];
  List<Meeting> _rejectedMeetings = [];

  final CalendarController _controller = CalendarController();
  final FirebaseFirestore databaseReference = FirebaseFirestore.instance;

  /// A collection of colors to randomly assign to each appointment
  final List<Color> _colorCollection = <Color>[
    Colors.red,
    Colors.blue,
    Colors.green,
    Colors.orange,
    Colors.purple,
    Colors.amber,
    Colors.cyan,
    Colors.pink,
    Colors.lime,
  ];

  /// Variable to store the user's display name retrieved from Firestore.
  String? _displayName;

  @override
  void initState() {
    super.initState();
    _setupRealTimeListener();
    _fetchUserDisplayName();
  }

  /// Fetch the user's display name from Firestore based on the provided email.
  void _fetchUserDisplayName() async {
    try {
      // Assuming your user collection is called "Users"
      QuerySnapshot userSnapshot = await databaseReference
          .collection("Users")
          .where("email", isEqualTo: widget.loggedUserEmail)
          .limit(1)
          .get();

      if (userSnapshot.docs.isNotEmpty) {
        setState(() {
          _displayName = userSnapshot.docs.first.get('displayName');
        });
      }
    } catch (e) {
      debugPrint("Error fetching user display name: $e");
    }
  }

  /// This method sets up a real-time listener for all documents in Firestore.
  /// After reading the docs, we separate them based on status.
  void _setupRealTimeListener() {
    databaseReference
        .collection("CalendarAppointmentCollection")
        .snapshots()
        .listen((querySnapshot) {
      final Random random = Random();
      // Convert snapshots to a List<Meeting>
      List<Meeting> allMeetings = querySnapshot.docs.map((doc) {
        return Meeting.fromFireStoreDoc(
          doc.id,
          doc.data() as Map<String, dynamic>,
          _colorCollection[random.nextInt(_colorCollection.length)],
        );
      }).toList();

      // Separate them by status
      List<Meeting> accepted = [];
      List<Meeting> pending = [];
      List<Meeting> rejected = [];

      for (var meeting in allMeetings) {
        if (meeting.status == 'accepted') {
          accepted.add(meeting);
        } else if (meeting.status == 'pending') {
          pending.add(meeting);
        } else if (meeting.status == 'rejected') {
          rejected.add(meeting);
        }
      }

      setState(() {
        // Only "accepted" appointments go to the calendar
        events = MeetingDataSource(accepted);
        _pendingMeetings = pending;
        _rejectedMeetings = rejected;
      });
    });
  }

  @override
  Widget build(BuildContext context) {
    // Instead of checking hardcoded emails, rely on the role
    final bool isStudent = widget.userRole == 'student';
    final bool isChaplain = widget.userRole == 'chaplain';

    return Scaffold(
      appBar: AppBar(
        title: const Text('Appointment System'),
        flexibleSpace: Container(
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              colors: [Colors.blue, Colors.purple],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
          ),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.logout),
            tooltip: 'Logout',
            onPressed: _logout,
          ),
          // Replaced the old menu (Add, Delete, Update) with a single "Change password" option
          PopupMenuButton<String>(
            icon: const Icon(Icons.settings),
            itemBuilder: (BuildContext context) => [
              const PopupMenuItem<String>(
                value: 'change_password',
                child: Text('Change password'),
              ),
            ],
            onSelected: (String value) {
              if (value == 'change_password') {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => ChangePasswordPage(
                      userEmail: widget.loggedUserEmail,
                    ),
                  ),
                );
              }
            },
          ),
        ],
      ),
      body: SingleChildScrollView(
        child: Column(
          children: [
            if (isStudent) ...[
              _buildStudentCalendar(),
              const Divider(thickness: 2, color: Colors.grey, height: 40),
            ],
            if (isChaplain) _buildChaplainCalendar(),
          ],
        ),
      ),
    );
  }

  /// Logout function to return to the login page
  void _logout() {
    Navigator.pushReplacement(
      context,
      MaterialPageRoute(builder: (context) => const LoginPage()),
    );
  }

  /// Common calendar widget for displaying accepted appointments
  Widget _buildCalendar(Color headerColor) {
    return SizedBox(
      height: 450,
      child: SfCalendar(
        controller: _controller,
        view: CalendarView.month,
        allowedViews: const [
          CalendarView.day,
          CalendarView.week,
          CalendarView.workWeek,
          CalendarView.month,
          CalendarView.timelineDay,
          CalendarView.timelineWeek,
          CalendarView.timelineWorkWeek,
        ],
        onTap: _calendarTapped,
        dataSource: events,
        todayHighlightColor: headerColor,
        headerStyle: CalendarHeaderStyle(
          backgroundColor: headerColor,
          textStyle: const TextStyle(
            color: Colors.black,
            fontSize: 20,
            fontWeight: FontWeight.bold,
          ),
        ),
        selectionDecoration: BoxDecoration(
          border: Border.all(
            color: headerColor,
            width: 2,
          ),
        ),
      ),
    );
  }

  /// Student calendar with a request button and greeting text
  Widget _buildStudentCalendar() {
    return Padding(
      padding: const EdgeInsets.all(8.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start, // Align children to the left.
        children: [
          // Greeting text above the title
          if (_displayName != null)
            Text(
              'Hello $_displayName,',
              style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              textAlign: TextAlign.left,
            )
          else
            const Text(
              'Student Calendar (Accepted Appointments)',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              textAlign: TextAlign.left,
            ),
          const SizedBox(height: 10),
          _buildCalendar(Colors.blueAccent),
          const SizedBox(height: 20),
          ElevatedButton.icon(
            icon: const Icon(Icons.add),
            label: const Text(
              'Request Appointment',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
            ),
            onPressed: () => _showRequestDialog(context),
            style: ElevatedButton.styleFrom(
              padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 24),
              backgroundColor: Colors.blueAccent,
            ),
          ),

          // Display "rejected" requests with reasons
          if (_rejectedMeetings.isNotEmpty) ...[
            const SizedBox(height: 30),
            const Text(
              'Rejected Appointments',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: Colors.red,
              ),
            ),
            const SizedBox(height: 10),
            SizedBox(
              height: 200,
              child: ListView.builder(
                itemCount: _rejectedMeetings.length,
                itemBuilder: (context, index) {
                  final meeting = _rejectedMeetings[index];
                  return Card(
                    elevation: 4,
                    margin: const EdgeInsets.symmetric(
                        vertical: 5, horizontal: 12),
                    child: ListTile(
                      leading: const Icon(Icons.cancel, color: Colors.red),
                      title: Text('${meeting.subject} at: ${meeting.from}'),
                      subtitle: Text(
                        'Reason: ${meeting.rejectionReason ?? ''}',
                        style: const TextStyle(color: Colors.red),
                      ),
                      trailing: const Text('Rejected'),
                    ),
                  );
                },
              ),
            ),
          ],
        ],
      ),
    );
  }

  /// Chaplain calendar with a list of pending requests and greeting text
  Widget _buildChaplainCalendar() {
    return Padding(
      padding: const EdgeInsets.all(8.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start, // Align children to the left.
        children: [
          // Greeting text above the title
          if (_displayName != null)
            Text(
              'Hello $_displayName,',
              style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              textAlign: TextAlign.left,
            )
          else
            const Text(
              'Chaplain Calendar (Accepted Appointments)',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              textAlign: TextAlign.left,
            ),
          const SizedBox(height: 10),
          _buildCalendar(Colors.deepPurple),
          const SizedBox(height: 20),
          Container(
            margin: const EdgeInsets.symmetric(vertical: 10),
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
            decoration: BoxDecoration(
              color: Colors.deepPurple,
              borderRadius: BorderRadius.circular(12),
            ),
            child: const Text(
              'Pending Appointment Requests',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
                color: Colors.white,
              ),
            ),
          ),
          // List of pending requests from Firestore with status = 'pending'
          if (_pendingMeetings.isNotEmpty)
            SizedBox(
              height: 200,
              child: ListView.builder(
                itemCount: _pendingMeetings.length,
                itemBuilder: (context, index) {
                  var meeting = _pendingMeetings[index];
                  return Card(
                    child: ListTile(
                      title: Text('Request from ${meeting.studentName}'),
                      subtitle: Text('Time: ${meeting.from}'),
                      trailing: _buildRequestActions(meeting),
                    ),
                  );
                },
              ),
            ),
        ],
      ),
    );
  }

  /// Buttons for accepting or rejecting a request
  Widget _buildRequestActions(Meeting meeting) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        IconButton(
          icon: const Icon(Icons.check, color: Colors.green),
          onPressed: () => _acceptAppointment(meeting),
        ),
        IconButton(
          icon: const Icon(Icons.close, color: Colors.red),
          onPressed: () => _rejectAppointment(meeting),
        ),
      ],
    );
  }

  /// Calendar tap callback
  void _calendarTapped(CalendarTapDetails details) {
    if (_controller.view == CalendarView.month &&
        details.targetElement == CalendarElement.calendarCell) {
      setState(() {
        _controller.view = CalendarView.day;
      });
    }
  }

  /// Show a dialog for requesting a new appointment
  void _showRequestDialog(BuildContext context) {
    final nameController = TextEditingController();
    DateTime selectedTime = DateTime.now();

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Request Appointment'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: nameController,
              decoration: const InputDecoration(labelText: 'Student Name'),
            ),
            const SizedBox(height: 10),
            ElevatedButton(
              child: const Text('Pick Date & Time'),
              onPressed: () async {
                final now = DateTime.now();
                DateTime? pickedDate = await showDatePicker(
                  context: context,
                  initialDate: now,
                  firstDate: now,
                  lastDate: DateTime(2100),
                );
                if (pickedDate != null) {
                  TimeOfDay? pickedTime = await showTimePicker(
                    context: context,
                    initialTime: TimeOfDay.now(),
                  );
                  if (pickedTime != null) {
                    selectedTime = DateTime(
                      pickedDate.year,
                      pickedDate.month,
                      pickedDate.day,
                      pickedTime.hour,
                      pickedTime.minute,
                    );
                  }
                }
              },
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () {
              if (nameController.text.isNotEmpty) {
                _requestAppointment(nameController.text, selectedTime);
                Navigator.pop(context);
              }
            },
            child: const Text('Request'),
          ),
        ],
      ),
    );
  }

  /// Write a pending appointment to Firestore
  void _requestAppointment(String studentName, DateTime startTime) async {
    // For the sake of example, let's give every appointment 1 hour duration.
    final endTime = startTime.add(const Duration(hours: 1));
    await databaseReference.collection("CalendarAppointmentCollection").add({
      'Subject': 'Appointment with $studentName',
      'StudentName': studentName,
      'Status': 'pending',
      'RejectionReason': null,
      'StartTime': DateFormat('dd/MM/yyyy HH:mm:ss').format(startTime),
      'EndTime': DateFormat('dd/MM/yyyy HH:mm:ss').format(endTime),
    });
  }

  /// Accept appointment: set status='accepted'
  void _acceptAppointment(Meeting meeting) async {
    if (meeting.key == null) return; // safety check
    await databaseReference
        .collection("CalendarAppointmentCollection")
        .doc(meeting.key)
        .update({
      'Status': 'accepted',
      'RejectionReason': null, // clear any rejection reason
    });
  }

  /// Reject appointment: set status='rejected' and store the reason
  void _rejectAppointment(Meeting meeting) {
    TextEditingController reasonController = TextEditingController();
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Reject Appointment'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text('Please enter the reason for rejecting:'),
            TextField(
              controller: reasonController,
              decoration: const InputDecoration(hintText: 'Enter reason here'),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () async {
              final reason = reasonController.text.trim();
              if (reason.isNotEmpty && meeting.key != null) {
                await databaseReference
                    .collection("CalendarAppointmentCollection")
                    .doc(meeting.key)
                    .update({
                  'Status': 'rejected',
                  'RejectionReason': reason,
                });
                Navigator.pop(context);
              }
            },
            child: const Text('Submit'),
          ),
        ],
      ),
    );
  }
}