import 'dart:async'; // Needed for StreamSubscription
import 'dart:math';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:syncfusion_flutter_calendar/calendar.dart';

import 'appointment_model.dart';
import 'login_page.dart';
import 'change_password_page.dart';
import 'chaplain_requirement_page.dart'; // <-- Import the new ChaplainRequirementPage

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

  /// Variable to store the user's display name from Firestore.
  String? _displayName;

  /// Variable to store the student's class number from Firestore.
  String? _classNumber;

  /// Variable to store the student's class value (e.g. "5J").
  String? _studentClass;

  /// Keep a list of available chaplains to show in the dropdown (for students).
  List<Map<String, String?>> _chaplains = [];
  String? _selectedChaplainEmail;
  String? _selectedChaplainDisplayName;

  /// Subscription to Firestore changes for appointments.
  StreamSubscription<QuerySnapshot>? _appointmentsSubscription;

  // ------------ NEW FIELDS FOR THE REQUIREMENT ------------
  /// Message describing the student's requirement (optional).
  String? _requirementMessage;

  /// Deadline or date by which the student must meet the chaplain (optional).
  String? _requirementDeadline;
  // ---------------------------------------------------------

  @override
  void initState() {
    super.initState();
    _setupRealTimeListener();
    _fetchUserDisplayName();
    if (widget.userRole == 'student') {
      _fetchChaplains(); // Only fetch chaplains for students
    }
  }

  @override
  void dispose() {
    _appointmentsSubscription?.cancel();
    super.dispose();
  }

  /// Fetch the user's display name, class number, class, and requirement (if any).
  void _fetchUserDisplayName() async {
    try {
      QuerySnapshot userSnapshot = await databaseReference
          .collection("Users")
          .where("email", isEqualTo: widget.loggedUserEmail)
          .limit(1)
          .get();

      if (userSnapshot.docs.isNotEmpty && mounted) {
        setState(() {
          var userData = userSnapshot.docs.first.data() as Map<String, dynamic>;
          _displayName = userData['displayName'];
          _classNumber = userData['classNumber']; // e.g., "23"
          _studentClass = userData['class'];       // e.g., "5J"

          // Only if the user is a student, we fetch requirement data
          if (widget.userRole == 'student') {
            _requirementMessage = userData['requirementMessage'];
            _requirementDeadline = userData['requirementDeadline'];
          }
        });
      }
    } catch (e) {
      debugPrint("Error fetching user display name: $e");
    }
  }

  /// Fetch all chaplains from the "Users" collection (for students).
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
            "email": doc['email'] as String?,
            "displayName": doc['displayName'] as String?,
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

  /// Sets up a real-time listener for appointment documents in Firestore.
  void _setupRealTimeListener() {
    // If user is chaplain, only listen to appointments where ChaplainEmail == user’s email
    if (widget.userRole == 'chaplain') {
      _appointmentsSubscription = databaseReference
          .collection("CalendarAppointmentCollection")
          .where("ChaplainEmail", isEqualTo: widget.loggedUserEmail)
          .snapshots()
          .listen(
        (querySnapshot) {
          _processQuerySnapshot(querySnapshot);
        },
        onError: (error) => debugPrint("Firestore snapshots error: $error"),
      );
    }
    // If user is student, only listen to appointments where StudentEmail == user’s email
    else if (widget.userRole == 'student') {
      _appointmentsSubscription = databaseReference
          .collection("CalendarAppointmentCollection")
          .where("StudentEmail", isEqualTo: widget.loggedUserEmail)
          .snapshots()
          .listen(
        (querySnapshot) {
          _processQuerySnapshot(querySnapshot);
        },
        onError: (error) => debugPrint("Firestore snapshots error: $error"),
      );
    }
    // If you have other roles (like "admin"), handle them as needed.
    else {
      // By default, or for other roles, you might want to fetch all
      // or continue with the current approach.
      _appointmentsSubscription = databaseReference
          .collection("CalendarAppointmentCollection")
          .snapshots()
          .listen(
        (querySnapshot) {
          _processQuerySnapshot(querySnapshot);
        },
        onError: (error) => debugPrint("Firestore snapshots error: $error"),
      );
    }
  }

  /// Process the Firestore query snapshot (shared by chaplains and students).
  void _processQuerySnapshot(QuerySnapshot querySnapshot) {
    final Random random = Random();

    // Convert snapshots to a List<Meeting>
    List<Meeting> allMeetings = querySnapshot.docs.map((doc) {
      var meeting = Meeting.fromFireStoreDoc(
        doc.id,
        doc.data() as Map<String, dynamic>,
        _colorCollection[random.nextInt(_colorCollection.length)],
      );

      // If the user is chaplain, override the subject to show the student's info.
      if (widget.userRole == 'chaplain') {
        meeting.subject =
            'Appointment with ${meeting.studentName} '
            '(${meeting.studentClassAndNumber ?? 'N/A'})';
      }
      return meeting;
    }).toList();

    // Separate them by status, ignoring anything "deleted"
    List<Meeting> accepted = [];
    List<Meeting> pending = [];
    List<Meeting> rejected = [];

    for (var mtg in allMeetings) {
      // skip 'deleted' appointments
      if (mtg.status == 'deleted') {
        continue;
      } else if (mtg.status == 'accepted') {
        accepted.add(mtg);
      } else if (mtg.status == 'pending') {
        pending.add(mtg);
      } else if (mtg.status == 'rejected') {
        rejected.add(mtg);
      }
    }

    if (mounted) {
      setState(() {
        events = MeetingDataSource(accepted);
        _pendingMeetings = pending;
        _rejectedMeetings = rejected;
      });
    }
  }

  /// Logout function to return to the login page.
  void _logout() {
    Navigator.pushReplacement(
      context,
      MaterialPageRoute(builder: (_) => const LoginPage()),
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
                    builder: (_) => ChangePasswordPage(
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

  /// Student calendar with accepted appointments + request button.
  Widget _buildStudentCalendar() {
    return Padding(
      padding: const EdgeInsets.all(8.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (_displayName != null)
            Text(
              'Hello $_displayName,',
              style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            )
          else
            const Text(
              'Student Calendar (Accepted Appointments)',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
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

          // ------------ NEW REQUIREMENT MESSAGE ------------
          if (_requirementMessage != null && _requirementMessage!.isNotEmpty) ...[
            const SizedBox(height: 20),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(16),
              margin: const EdgeInsets.symmetric(horizontal: 8),
              decoration: BoxDecoration(
                color: Colors.orangeAccent.shade100,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    "Important Reminder",
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: Colors.orange.shade900,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    _requirementMessage!,
                    style: const TextStyle(fontSize: 15),
                  ),
                  if (_requirementDeadline != null &&
                      _requirementDeadline!.isNotEmpty) ...[
                    const SizedBox(height: 8),
                    Text(
                      "Please fulfill this by: $_requirementDeadline",
                      style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.bold,
                        color: Colors.red,
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ],
          // ------------------------------------------------

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
                    margin:
                        const EdgeInsets.symmetric(vertical: 5, horizontal: 12),
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

  /// Chaplain calendar with accepted appointments + pending requests + new button.
  Widget _buildChaplainCalendar() {
    return Padding(
      padding: const EdgeInsets.all(8.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (_displayName != null)
            Text(
              'Hello $_displayName,',
              style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            )
          else
            const Text(
              'Chaplain Calendar (Accepted Appointments)',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
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
          if (_pendingMeetings.isNotEmpty)
            SizedBox(
              height: 200,
              child: ListView.builder(
                itemCount: _pendingMeetings.length,
                itemBuilder: (context, index) {
                  final meeting = _pendingMeetings[index];
                  return Card(
                    child: ListTile(
                      title: Text('Request from ${meeting.studentName}'),
                      subtitle:
                          Text('Time: ${DateFormat.yMMMd().add_jm().format(meeting.from)}'),
                      trailing: _buildRequestActions(meeting),
                    ),
                  );
                },
              ),
            ),
          const SizedBox(height: 20),
          // NEW BUTTON: Show Student Requirements
          ElevatedButton(
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => ChaplainRequirementPage(
                    chaplainEmail: widget.loggedUserEmail,
                  ),
                ),
              );
            },
            child: const Text('Show Student Requirements'),
          ),
        ],
      ),
    );
  }

  /// Common calendar builder for showing accepted appointments.
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

  /// onTap callback: show appointment details if chaplain + tapped on an appointment.
  void _calendarTapped(CalendarTapDetails details) {
    if (widget.userRole == 'chaplain' &&
        details.appointments != null &&
        details.appointments!.isNotEmpty) {
      final Meeting tappedMeeting = details.appointments!.first as Meeting;
      _showAppointmentDetailsDialog(tappedMeeting);
    }

    // If user tapped on a blank cell in the month view, switch to day view.
    if (_controller.view == CalendarView.month &&
        details.targetElement == CalendarElement.calendarCell) {
      setState(() {
        _controller.view = CalendarView.day;
      });
    }
  }

  /// Show a dialog with the details of the tapped appointment, 
  /// plus an edit pencil icon & bin icon for chaplains.
  void _showAppointmentDetailsDialog(Meeting meeting) {
    final String startTime = DateFormat.yMMMd().add_jm().format(meeting.from);
    final String endTime = DateFormat.yMMMd().add_jm().format(meeting.to);

    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text('Appointment Details'),
              Row(
                children: [
                  IconButton(
                    icon: const Icon(Icons.edit),
                    tooltip: 'Edit appointment times',
                    onPressed: () {
                      Navigator.pop(context); // close this dialog first
                      _showEditTimesDialog(meeting);
                    },
                  ),
                  IconButton(
                    icon: const Icon(Icons.delete),
                    tooltip: 'Delete appointment',
                    onPressed: () {
                      Navigator.pop(context); // close this dialog
                      _confirmDeleteAppointment(meeting);
                    },
                  ),
                ],
              ),
            ],
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Subject: ${meeting.subject}',
                style: const TextStyle(fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 8),
              Text('Student Name: ${meeting.studentName}'),
              if (meeting.studentClassAndNumber != null)
                Text('Class: ${meeting.studentClassAndNumber}'),
              Text('Status: ${meeting.status}'),
              if (meeting.rejectionReason != null &&
                  meeting.rejectionReason!.isNotEmpty)
                Text('Rejection Reason: ${meeting.rejectionReason}'),
              const Divider(thickness: 1, height: 16),
              Text('Start Time: $startTime'),
              Text('End Time: $endTime'),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Close'),
            ),
          ],
        );
      },
    );
  }

  /// Ask for confirmation and then mark the appointment as "deleted" in Firestore.
  void _confirmDeleteAppointment(Meeting meeting) {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text('Delete Appointment'),
          content:
              const Text('Are you sure you want to delete this appointment?'),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context), // Cancel
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: () async {
                Navigator.pop(context); // close confirm dialog
                if (meeting.key != null) {
                  try {
                    // Instead of doc.delete(), update Status to 'deleted'
                    await databaseReference
                        .collection("CalendarAppointmentCollection")
                        .doc(meeting.key)
                        .update({
                      'Status': 'deleted',
                      'DeletedBy': widget.loggedUserEmail,
                      'DeletedOn': DateTime.now().toIso8601String(),
                    });
                  } catch (e) {
                    debugPrint('Error marking appointment as deleted: $e');
                  }
                }
              },
              child: const Text('Delete'),
            ),
          ],
        );
      },
    );
  }

  /// Dialog to let chaplain edit the start and end times of the meeting.
  void _showEditTimesDialog(Meeting meeting) {
    // We'll keep track of new StartTime and EndTime in local variables.
    DateTime newStartTime = meeting.from;
    DateTime newEndTime = meeting.to;

    showDialog(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, dialogSetState) {
            // Function to pick date/time
            Future<void> pickDateTime(bool isStart) async {
              // Step 1: pick date
              DateTime? pickedDate = await showDatePicker(
                context: context,
                initialDate: isStart ? newStartTime : newEndTime,
                firstDate: DateTime(2020),
                lastDate: DateTime(2100),
              );
              if (pickedDate != null) {
                // Step 2: pick time
                TimeOfDay? pickedTime = await showTimePicker(
                  context: context,
                  initialTime: TimeOfDay.fromDateTime(
                    isStart ? newStartTime : newEndTime,
                  ),
                );
                if (pickedTime != null) {
                  final mergedDateTime = DateTime(
                    pickedDate.year,
                    pickedDate.month,
                    pickedDate.day,
                    pickedTime.hour,
                    pickedTime.minute,
                  );
                  dialogSetState(() {
                    if (isStart) {
                      newStartTime = mergedDateTime;
                    } else {
                      newEndTime = mergedDateTime;
                    }
                  });
                }
              }
            }

            return AlertDialog(
              title: const Text('Edit Appointment Times'),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // Display the new start time
                  ListTile(
                    title: const Text('Start Time'),
                    subtitle: Text(
                      DateFormat.yMMMd().add_jm().format(newStartTime),
                    ),
                    trailing: TextButton(
                      onPressed: () => pickDateTime(true),
                      child: const Text('Edit'),
                    ),
                  ),
                  const SizedBox(height: 8),
                  // Display the new end time
                  ListTile(
                    title: const Text('End Time'),
                    subtitle: Text(
                      DateFormat.yMMMd().add_jm().format(newEndTime),
                    ),
                    trailing: TextButton(
                      onPressed: () => pickDateTime(false),
                      child: const Text('Edit'),
                    ),
                  ),
                ],
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(context), // Cancel
                  child: const Text('Cancel'),
                ),
                ElevatedButton(
                  onPressed: () async {
                    // Optional: validate newStartTime < newEndTime
                    if (newEndTime.isBefore(newStartTime)) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text('End time must be after the start time.'),
                        ),
                      );
                      return;
                    }
                    // Update Firestore for this meeting
                    try {
                      if (meeting.key != null) {
                        await databaseReference
                            .collection("CalendarAppointmentCollection")
                            .doc(meeting.key)
                            .update({
                          'StartTime': DateFormat('dd/MM/yyyy HH:mm:ss')
                              .format(newStartTime),
                          'EndTime': DateFormat('dd/MM/yyyy HH:mm:ss')
                              .format(newEndTime),
                        });
                      }
                    } catch (e) {
                      debugPrint('Error updating appointment times: $e');
                    }
                    Navigator.pop(context); // close the edit times dialog
                  },
                  child: const Text('Save'),
                ),
              ],
            );
          },
        );
      },
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

  /// Show a dialog for requesting a new appointment (for students).
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
                  if (_displayName != null)
                    Text(
                      'Your name: $_displayName',
                      style: const TextStyle(fontWeight: FontWeight.bold),
                    ),
                  const SizedBox(height: 16),
                  if (_chaplains.isNotEmpty) ...[
                    const Text(
                      'Select Chaplain:',
                      style: TextStyle(fontWeight: FontWeight.bold),
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
                          ),
                        );
                      }).toList(),
                      onChanged: (value) {
                        setStateDialog(() {
                          _selectedChaplainEmail = value;
                          final chaplain = _chaplains.firstWhere(
                            (c) => c["email"] == value,
                            orElse: () => {"displayName": null},
                          );
                          _selectedChaplainDisplayName =
                              chaplain["displayName"];
                        });
                      },
                    ),
                  ] else ...[
                    const Text(
                      'No chaplains found!',
                      style: TextStyle(color: Colors.red),
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
                    },
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Selected: ${DateFormat.yMMMd().add_jm().format(selectedTime)}',
                    style: const TextStyle(fontSize: 14),
                  ),
                ],
              );
            },
          ),
          actions: [
            TextButton(
              onPressed: () {
                // Only proceed if a chaplain is selected
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

  /// Write a new pending appointment to Firestore (student -> chaplain request).
  void _requestAppointment(
    String studentName,
    DateTime startTime,
    String chaplainEmail,
    String chaplainDisplayName,
  ) async {
    final endTime = startTime.add(const Duration(hours: 1));
    await databaseReference.collection("CalendarAppointmentCollection").add({
      'Subject': 'Appointment with $chaplainDisplayName',
      'StudentEmail': widget.loggedUserEmail, // <--- ADDED
      'StudentName': studentName,
      'StudentClassNumber': _classNumber,
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
    if (meeting.key == null) return;
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