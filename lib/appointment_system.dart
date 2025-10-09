// appointment_system.dart
import 'dart:async'; // <-- Needed for StreamSubscription
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

  /// The user's role ("chaplain", "student", etc.)
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
  /// Instead, we read them from Firestore in real time.
  List<Meeting> _pendingMeetings = [];
  List<Meeting> _rejectedMeetings = [];

  final CalendarController _controller = CalendarController();
  final FirebaseFirestore databaseReference = FirebaseFirestore.instance;

  /// A collection of colors to randomly assign to each appointment.
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

  /// Variable to store the student's display name (or user's display name) retrieved from Firestore.
  String? _displayName;

  /// Variable to store the student's class number from Firestore.
  String? _classNumber;
  
  /// Variable to store the student's class value (e.g. "5J").
  String? _studentClass;

  /// Keep a list of available chaplains to show in the dropdown.
  List<Map<String, String?>> _chaplains = [];
  String? _selectedChaplainEmail;
  String? _selectedChaplainDisplayName;

  /// Store the Firestore subscription so we can cancel it in dispose().
  StreamSubscription<QuerySnapshot>? _appointmentsSubscription;

  @override
  void initState() {
    super.initState();
    _setupRealTimeListener(); // Sets up the Firestore snapshots listener
    _fetchUserDisplayName();  // Fetch the user's display name (and class info) once
    if (widget.userRole == 'student') {
      _fetchChaplains(); // Only fetch chaplains for students
    }
  }

  @override
  void dispose() {
    // Cancel the Firestore subscription to avoid setState() calls after dispose
    _appointmentsSubscription?.cancel();
    super.dispose();
  }

  /// Fetch the user's display name, class number, and class (e.g. "5J") from Firestore based on the provided email.
  void _fetchUserDisplayName() async {
    try {
      QuerySnapshot userSnapshot = await databaseReference
          .collection("Users")
          .where("email", isEqualTo: widget.loggedUserEmail)
          .limit(1)
          .get();

      // Only call setState if the widget is still mounted
      if (userSnapshot.docs.isNotEmpty && mounted) {
        setState(() {
          var userData = userSnapshot.docs.first.data() as Map<String, dynamic>;
          _displayName = userData['displayName'];
          _classNumber = userData['classNumber']; // for example: "23"
          _studentClass = userData['class']; // for example: "5J"
        });
      }
    } catch (e) {
      debugPrint("Error fetching user display name: $e");
    }
  }

  /// Fetch all chaplains from the "Users" collection to build a dropdown list.
  void _fetchChaplains() async {
    try {
      QuerySnapshot chaplainsSnapshot = await databaseReference
          .collection("Users")
          .where("role", isEqualTo: "chaplain")
          .get();

      if (mounted) {
        List<Map<String, String?>> chaplainList =
            chaplainsSnapshot.docs.map((doc) {
          return {
            "email": doc.get('email') as String?,
            "displayName": doc.get('displayName') as String?,
          };
        }).toList();

        setState(() {
          _chaplains = chaplainList;
        });
      }
    } catch (e) {
      debugPrint("Error fetching chaplains: $e");
    }
  }

  /// Sets up a real-time listener for appointment documents in Firestore
  /// and stores the subscription so we can cancel it later.
  void _setupRealTimeListener() {
    _appointmentsSubscription = databaseReference
        .collection("CalendarAppointmentCollection")
        .snapshots()
        .listen(
      (querySnapshot) {
        final Random random = Random();
        // Convert snapshots to a List<Meeting>
        List<Meeting> allMeetings = querySnapshot.docs.map((doc) {
          // Create meeting from the Firestore document
          var meeting = Meeting.fromFireStoreDoc(
            doc.id,
            doc.data() as Map<String, dynamic>,
            _colorCollection[random.nextInt(_colorCollection.length)],
          );
          // If the logged-in user is a chaplain, override the subject to show the student's name and combined class info.
          if (widget.userRole == 'chaplain') {
            meeting.subject =
                'Appointment with ${meeting.studentName} (${meeting.studentClassAndNumber ?? 'N/A'})';
          }
          return meeting;
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

        // Only call setState if still mounted
        if (mounted) {
          setState(() {
            // "accepted" appointments go to the calendar
            events = MeetingDataSource(accepted);
            _pendingMeetings = pending;
            _rejectedMeetings = rejected;
          });
        }
      },
      onError: (error) => debugPrint("Firestore snapshots error: $error"),
    );
  }

  @override
  Widget build(BuildContext context) {
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
              textAlign: TextAlign.left,
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
                      vertical: 5,
                      horizontal: 12,
                    ),
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
              textAlign: TextAlign.left,
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

  /// Buttons for accepting or rejecting a request.
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

  /// Calendar tap callback.
  void _calendarTapped(CalendarTapDetails details) {
    if (_controller.view == CalendarView.month &&
        details.targetElement == CalendarElement.calendarCell) {
      if (mounted) {
        setState(() {
          _controller.view = CalendarView.day;
        });
      }
    }
  }

  /// Show a dialog for requesting a new appointment.
  ///
  /// - Default date/time is 1 day ahead of now.
  /// - We remove the TextField for student name since we have _displayName.
  /// - We display a DropdownButton to let the student pick a chaplain.
  /// - We make content left-aligned using crossAxisAlignment: CrossAxisAlignment.start.
  void _showRequestDialog(BuildContext context) {
    DateTime selectedTime = DateTime.now().add(const Duration(days: 1));

    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('Request Appointment', textAlign: TextAlign.left),
          content: StatefulBuilder(
            builder: (BuildContext context, setStateDialog) {
              return Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  // Student name (non-editable) so they can see their own name.
                  if (_displayName != null)
                    Text(
                      'Your name: $_displayName',
                      style: const TextStyle(fontWeight: FontWeight.bold),
                      textAlign: TextAlign.left,
                    ),
                  const SizedBox(height: 16),
                  // Chaplain dropdown.
                  if (_chaplains.isNotEmpty) ...[
                    const Text(
                      'Select Chaplain:',
                      style: TextStyle(fontWeight: FontWeight.bold),
                      textAlign: TextAlign.left,
                    ),
                    const SizedBox(height: 8),
                    DropdownButton<String>(
                      isExpanded: true,
                      value: _selectedChaplainEmail,
                      hint: const Text('Select a chaplain'),
                      items: _chaplains.map((chap) {
                        return DropdownMenuItem<String>(
                          value: chap["email"],
                          child: Text(
                            chap["displayName"] ?? "Unknown Chaplain",
                            textAlign: TextAlign.left,
                          ),
                        );
                      }).toList(),
                      onChanged: (value) {
                        // Update the selected chaplain inside the dialog.
                        if (mounted) {
                          setStateDialog(() {
                            _selectedChaplainEmail = value; // email
                            final chaplain = _chaplains.firstWhere(
                              (c) => c["email"] == value,
                              orElse: () => {"displayName": null},
                            );
                            _selectedChaplainDisplayName = chaplain["displayName"];
                          });
                        }
                      },
                    ),
                  ] else ...[
                    const Text(
                      'No chaplains found!',
                      style: TextStyle(color: Colors.red),
                      textAlign: TextAlign.left,
                    ),
                  ],
                  const SizedBox(height: 20),
                  ElevatedButton(
                    child: const Text('Pick Date & Time'),
                    onPressed: () async {
                      final now = DateTime.now();
                      DateTime? pickedDate = await showDatePicker(
                        context: context,
                        initialDate: selectedTime,
                        firstDate: now,
                        lastDate: DateTime(2100),
                      );
                      if (pickedDate != null) {
                        TimeOfDay? pickedTime = await showTimePicker(
                          context: context,
                          initialTime: TimeOfDay.fromDateTime(selectedTime),
                        );
                        if (pickedTime != null) {
                          // Update the selected time.
                          if (mounted) {
                            setStateDialog(() {
                              selectedTime = DateTime(
                                pickedDate.year,
                                pickedDate.month,
                                pickedDate.day,
                                pickedTime.hour,
                                pickedTime.minute,
                              );
                            });
                          }
                        }
                      }
                    },
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Selected: ${DateFormat.yMMMd().add_jm().format(selectedTime)}',
                    style: const TextStyle(fontSize: 14),
                    textAlign: TextAlign.left,
                  ),
                ],
              );
            },
          ),
          actions: [
            TextButton(
              onPressed: () {
                // Only proceed if a chaplain is selected.
                if (_selectedChaplainEmail != null &&
                    _selectedChaplainDisplayName != null) {
                  final studentName = _displayName ?? "Unknown Student";
                  _requestAppointment(
                    studentName,
                    selectedTime,
                    _selectedChaplainEmail!,
                    _selectedChaplainDisplayName!,
                  );
                  Navigator.pop(context);
                } else {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('Please select a chaplain first.'),
                    ),
                  );
                }
              },
              child: const Text('Request'),
            ),
          ],
        );
      },
    );
  }

  /// Write a pending appointment to Firestore.
  void _requestAppointment(
    String studentName,
    DateTime startTime,
    String chaplainEmail,
    String chaplainDisplayName,
  ) async {
    final endTime = startTime.add(const Duration(hours: 1));
    await databaseReference.collection("CalendarAppointmentCollection").add({
      'Subject': 'Appointment with $chaplainDisplayName',
      'StudentName': studentName, // from _displayName
      'StudentClassNumber': _classNumber, // stored separately if needed
      'StudentClassAndNumber': '${_studentClass ?? 'N/A'} ${_classNumber ?? 'N/A'}',
      'ChaplainName': chaplainDisplayName,
      'ChaplainEmail': chaplainEmail,
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

  /// Reject appointment: set status='rejected' and store the reason.
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