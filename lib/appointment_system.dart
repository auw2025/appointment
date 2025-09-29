// appointment_system.dart
import 'package:flutter/material.dart';
import 'appointment_model.dart';
import 'package:syncfusion_flutter_calendar/calendar.dart';

class AppointmentSystem extends StatefulWidget {
  final String loggedUserEmail;

  const AppointmentSystem({Key? key, required this.loggedUserEmail})
      : super(key: key);

  @override
  AppointmentSystemState createState() => AppointmentSystemState();
}

class AppointmentSystemState extends State<AppointmentSystem> {
  final List<AppointmentRequest> _pendingRequests = [];
  final List<Appointment> _appointments = [];
  final List<AppointmentRequest> _rejectedRequests = [];

  // Add a common CalendarController for view switching
  final CalendarController _controller = CalendarController();

  @override
  Widget build(BuildContext context) {
    // Determine which calendar(s) to show based on the loggedIn email
    bool isStudent = widget.loggedUserEmail == 'student@tsss.edu.hk';
    bool isChaplain = widget.loggedUserEmail == 'chaplain@tsss.edu.hk';

    return Scaffold(
      appBar: AppBar(
        title: const Text('Appointment System'),
        flexibleSpace: Container(
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              colors: [
                Colors.blue,
                Colors.purple,
              ],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
          ),
        ),
      ),
      body: SingleChildScrollView(
        child: Column(
          children: [
            if (isStudent) ...[
              _buildStudentCalendar(),
              const Divider(
                thickness: 2,
                color: Colors.grey,
                height: 40,
              ),
            ],
            if (isChaplain) _buildTutorCalendar(),
          ],
        ),
      ),
    );
  }

  /// Build a common calendar widget with a configurable header color and view switch functionality.
  Widget _buildCalendar(Color headerColor) {
    return SizedBox(
      height: 450,
      // The SfCalendar now includes the controller, allowedViews and onTap for view switching.
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
        dataSource: AppointmentDataSource(_appointments),
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

  /// Build the student calendar view.
  Widget _buildStudentCalendar() {
    return Padding(
      padding: const EdgeInsets.all(8.0),
      child: Column(
        children: [
          const Text(
            'Student Calendar',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 10),
          _buildCalendar(Colors.blueAccent),
          const SizedBox(height: 20),
          ElevatedButton.icon(
            icon: const Icon(Icons.add),
            label: const Text(
              'Request Appointment',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
                color: Colors.white,
              ),
            ),
            onPressed: () => _showRequestDialog(context),
            style: ElevatedButton.styleFrom(
              padding: const EdgeInsets.symmetric(
                vertical: 16,
                horizontal: 24,
              ),
              backgroundColor: Colors.blueAccent,
            ),
          ),
          if (_rejectedRequests.isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(top: 20),
              child: _buildRejectedRequests(),
            ),
        ],
      ),
    );
  }

  /// Build the tutor (chaplain) calendar view.
  Widget _buildTutorCalendar() {
    return Padding(
      padding: const EdgeInsets.all(8.0),
      child: Column(
        children: [
          const Text(
            'Chaplain Calendar',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 10),
          _buildCalendar(Colors.deepPurple),
          const SizedBox(height: 10),
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
          // List of pending requests for the tutor side.
          SizedBox(
            height: 200, // Set a height for the ListView
            child: ListView.builder(
              itemCount: _pendingRequests.length,
              itemBuilder: (context, index) {
                var request = _pendingRequests[index];
                return Card(
                  child: ListTile(
                    title: Text('Request from ${request.studentName}'),
                    subtitle: Text('Time: ${request.startTime}'),
                    trailing: _buildRequestActions(index),
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  /// Create action buttons (accept/reject) for each request.
  Widget _buildRequestActions(int index) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        IconButton(
          icon: const Icon(Icons.check, color: Colors.green),
          onPressed: () => _acceptAppointment(index),
        ),
        IconButton(
          icon: const Icon(Icons.close, color: Colors.red),
          onPressed: () => _rejectAppointment(index),
        ),
      ],
    );
  }

  /// Callback for view switching when the calendar is tapped.
  void _calendarTapped(CalendarTapDetails details) {
    // If the current view is month and a calendar cell is tapped, switch to day view.
    if (_controller.view == CalendarView.month &&
        details.targetElement == CalendarElement.calendarCell) {
      setState(() {
        _controller.view = CalendarView.day;
      });
    }
    // Alternatively, if the current view is week or workWeek and its header is tapped, switch to day view.
    else if ((_controller.view == CalendarView.week ||
            _controller.view == CalendarView.workWeek) &&
        details.targetElement == CalendarElement.viewHeader) {
      setState(() {
        _controller.view = CalendarView.day;
      });
    }
  }

  /// Student requests an appointment by showing a dialog.
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
                DateTime? pickedDate = await showDatePicker(
                  context: context,
                  initialDate: DateTime.now(),
                  firstDate: DateTime.now(),
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

  /// Add an appointment request (pending state).
  void _requestAppointment(String studentName, DateTime startTime) {
    setState(() {
      _pendingRequests.add(AppointmentRequest(studentName, startTime, false));
    });
  }

  /// Tutor accepts an appointment.
  void _acceptAppointment(int index) {
    setState(() {
      var request = _pendingRequests[index];
      var acceptedAppointment = Appointment(
        startTime: request.startTime,
        endTime: request.startTime.add(const Duration(minutes: 30)),
        subject: '${request.studentName} - Accepted',
        color: Colors.green,
      );
      _appointments.add(acceptedAppointment);
      _pendingRequests.removeAt(index);
    });
  }

  /// Tutor rejects an appointment via a dialog asking for a rejection reason.
  void _rejectAppointment(int index) {
    TextEditingController reasonController = TextEditingController();
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Reject Appointment'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text(
                'Please enter the reason for rejecting this appointment:'),
            TextField(
              controller: reasonController,
              decoration:
                  const InputDecoration(hintText: 'Enter reason here'),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () {
              if (reasonController.text.isNotEmpty) {
                setState(() {
                  var request = _pendingRequests[index];
                  request.rejectionReason = reasonController.text;
                  _rejectedRequests.add(request);
                  _pendingRequests.removeAt(index);
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

  /// Display rejected requests on the student side.
  Widget _buildRejectedRequests() {
    return SizedBox(
      height: 150, // Set a fixed height for the rejected requests list
      child: ListView.builder(
        itemCount: _rejectedRequests.length,
        itemBuilder: (context, index) {
          var request = _rejectedRequests[index];
          return Card(
            elevation: 4,
            margin: const EdgeInsets.symmetric(vertical: 5, horizontal: 12),
            child: ListTile(
              leading: const Icon(Icons.cancel, color: Colors.red),
              title: Text(
                  'Request from ${request.studentName} at: ${request.startTime}'),
              subtitle: Text(
                'Reason: ${request.rejectionReason}',
                style: const TextStyle(color: Colors.red),
              ),
              trailing: const Text('Rejected'),
            ),
          );
        },
      ),
    );
  }
}