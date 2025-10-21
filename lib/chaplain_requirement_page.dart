import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

class ChaplainRequirementPage extends StatefulWidget {
  final String chaplainEmail;

  const ChaplainRequirementPage({Key? key, required this.chaplainEmail})
      : super(key: key);

  @override
  State<ChaplainRequirementPage> createState() =>
      _ChaplainRequirementPageState();
}

class _ChaplainRequirementPageState extends State<ChaplainRequirementPage> {
  final FirebaseFirestore _db = FirebaseFirestore.instance;

  /// List of student documents fetched from Firestore
  List<Map<String, dynamic>> _students = [];

  /// Whether we are currently loading data
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _fetchStudents();
  }

  /// Fetch all students from Firestore. 
  /// (You could filter by chaplainEmail if you only want certain students.)
  Future<void> _fetchStudents() async {
    try {
      QuerySnapshot snapshot = await _db
          .collection('Users')
          .where('role', isEqualTo: 'student')
          .get();

      if (!mounted) return;

      setState(() {
        _students = snapshot.docs.map((doc) {
          final data = doc.data() as Map<String, dynamic>;
          // Include the doc.id if we need to update the record later
          data['docId'] = doc.id;
          return data;
        }).toList();

        _isLoading = false;
      });
    } catch (e) {
      debugPrint('Error fetching students: $e');
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  /// Show a dialog to edit the student's requirement message/deadline
  void _showEditRequirementDialog(Map<String, dynamic> studentData) {
    final docId = studentData['docId'];
    final TextEditingController requirementController =
        TextEditingController(text: studentData['requirementMessage'] ?? '');
    final TextEditingController deadlineController =
        TextEditingController(text: studentData['requirementDeadline'] ?? '');

    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('Edit Requirement'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: requirementController,
                  maxLines: 3,
                  decoration: const InputDecoration(
                    labelText: 'Requirement Message',
                    hintText: 'Enter requirement details',
                  ),
                ),
                const SizedBox(height: 20),
                TextField(
                  controller: deadlineController,
                  decoration: const InputDecoration(
                    labelText: 'Requirement Deadline',
                    hintText: 'e.g. 2025-10-30',
                  ),
                  onTap: () async {
                    // When user taps, we show a date picker:
                    FocusScope.of(context).requestFocus(FocusNode());
                    DateTime now = DateTime.now();
                    DateTime? pick = await showDatePicker(
                      context: context,
                      initialDate: now,
                      firstDate: DateTime(2020),
                      lastDate: DateTime(2100),
                    );
                    if (pick != null) {
                      final formatted = DateFormat('yyyy-MM-dd').format(pick);
                      deadlineController.text = formatted;
                    }
                  },
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context), // Cancel
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: () async {
                final newRequirement = requirementController.text.trim();
                final newDeadline = deadlineController.text.trim();
                if (docId != null && docId.isNotEmpty) {
                  try {
                    await _db.collection('Users').doc(docId).update({
                      'requirementMessage': newRequirement,
                      'requirementDeadline': newDeadline,
                    });
                    // Update local state as well
                    setState(() {
                      studentData['requirementMessage'] = newRequirement;
                      studentData['requirementDeadline'] = newDeadline;
                    });
                  } catch (e) {
                    debugPrint('Error updating requirement: $e');
                  }
                }
                Navigator.pop(context);
              },
              child: const Text('Save'),
            ),
          ],
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Student Requirements'),
        flexibleSpace: Container(
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              colors: [Colors.blue, Colors.purple],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
          ),
        ),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _students.isEmpty
              ? const Center(
                  child: Text(
                    'No student records found.',
                    style: TextStyle(fontSize: 16),
                  ),
                )
              : Padding(
                  padding: const EdgeInsets.all(8.0),
                  child: ListView.builder(
                    // This automatically scrolls vertically; no horizontal scroll needed.
                    itemCount: _students.length,
                    itemBuilder: (context, index) {
                      final student = _students[index];
                      final name = student['displayName'] ?? 'Unknown Student';
                      final classNumber =
                          student['classNumber'] ?? 'N/A'; // e.g. "23"
                      final studentClass = student['class'] ?? ''; // e.g. "5J"
                      final requirement =
                          student['requirementMessage'] ?? '[No requirement]';
                      final deadline =
                          student['requirementDeadline'] ?? '[No deadline]';

                      return Card(
                        margin: const EdgeInsets.symmetric(
                          vertical: 6,
                          horizontal: 4,
                        ),
                        child: ListTile(
                          title: Text(
                            name,
                            style: const TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 16,
                            ),
                          ),
                          subtitle: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text('Class: $studentClass'),
                              Text('Class Number: $classNumber'),
                              const SizedBox(height: 6),
                              Text('Requirement: $requirement'),
                              Text('Deadline: $deadline'),
                            ],
                          ),
                          trailing: IconButton(
                            icon: const Icon(Icons.edit),
                            onPressed: () {
                              _showEditRequirementDialog(student);
                            },
                          ),
                        ),
                      );
                    },
                  ),
                ),
    );
  }
}