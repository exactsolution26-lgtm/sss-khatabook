import 'package:flutter/material.dart';
import '../../widgets/header_text.dart';
import '../../widgets/simple_input.dart';
import '../../widgets/simple_button.dart';
import '../../core/constants/app_strings.dart';
import '../../core/constants/app_sizes.dart';
import 'timer_service.dart';
import 'notification_service.dart';
import '../../database/db_helper.dart';
import '../../database/tables/work_table.dart';
import '../../models/work_model.dart';
import '../../core/utils/date_utils.dart';
import 'package:sqflite/sqflite.dart';

class WorkTodayScreen extends StatefulWidget {
  const WorkTodayScreen({super.key});

  @override
  State<WorkTodayScreen> createState() => _WorkTodayScreenState();
}

class _WorkTodayScreenState extends State<WorkTodayScreen> {
  final _timerService = TimerService();
  final _descriptionController = TextEditingController();
  final _dbHelper = DBHelper.instance;
  bool _isSaving = false;

  @override
  void initState() {
    super.initState();
    NotificationService.instance.initialize();
    _loadTodayWork();
  }

  Future<void> _loadTodayWork() async {
    final db = await _dbHelper.database;
    final today = AppDateUtils.formatDate(DateTime.now());
    final maps = await db.query(
      WorkTable.tableName,
      where: '${WorkTable.date} = ?',
      whereArgs: [today],
    );

    if (maps.isNotEmpty) {
      final work = WorkModel.fromMap(maps.first);
      _timerService.setDuration(work.duration);
      if (work.startTime != null) {
        _timerService.setStartTime(work.startTime!);
      }
      if (work.startTime != null && work.endTime == null) {
        final now = DateTime.now();
        final elapsed = now.difference(work.startTime!).inSeconds;
        _timerService.setDuration(work.duration + elapsed);
        _timerService.start();
      }
      _descriptionController.text = work.description ?? '';
    }
  }

  Future<void> _saveWork() async {
    if (_isSaving) return;

    setState(() => _isSaving = true);

    try {
      final db = await _dbHelper.database;
      final today = AppDateUtils.formatDate(DateTime.now());
      
      final work = WorkModel(
        date: DateTime.now(),
        startTime: _timerService.startTime,
        endTime: _timerService.isRunning ? null : DateTime.now(),
        duration: _timerService.elapsedSeconds,
        description: _descriptionController.text.trim().isEmpty
            ? null
            : _descriptionController.text.trim(),
        createdAt: DateTime.now(),
      );

      final existing = await db.query(
        WorkTable.tableName,
        where: '${WorkTable.date} = ?',
        whereArgs: [today],
      );

      if (existing.isNotEmpty) {
        await db.update(
          WorkTable.tableName,
          work.toMap(),
          where: '${WorkTable.date} = ?',
          whereArgs: [today],
        );
      } else {
        await db.insert(WorkTable.tableName, work.toMap());
      }

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text(AppStrings.workSaved)),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e')),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isSaving = false);
      }
    }
  }

  @override
  void dispose() {
    _timerService.dispose();
    _descriptionController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text(AppStrings.workToday),
      ),
      body: ListenableBuilder(
        listenable: _timerService,
        builder: (context, _) {
          return Padding(
            padding: const EdgeInsets.all(AppSizes.paddingM),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const HeaderText(text: AppStrings.workToday),
                const SizedBox(height: AppSizes.paddingXL),
                Container(
                  padding: const EdgeInsets.all(AppSizes.paddingXL),
                  decoration: BoxDecoration(
                    color: Theme.of(context).colorScheme.primaryContainer,
                    borderRadius: BorderRadius.circular(AppSizes.radiusXL),
                  ),
                  child: Column(
                    children: [
                      Text(
                        _timerService.formattedTime,
                        style: Theme.of(context).textTheme.displayLarge?.copyWith(
                              fontWeight: FontWeight.bold,
                            ),
                      ),
                      const SizedBox(height: AppSizes.paddingL),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          if (!_timerService.isRunning)
                            SimpleButton(
                              text: AppStrings.start,
                              onPressed: () {
                                _timerService.start();
                              },
                            )
                          else
                            SimpleButton(
                              text: AppStrings.pause,
                              onPressed: () {
                                _timerService.pause();
                                _saveWork();
                              },
                            ),
                          const SizedBox(width: AppSizes.paddingM),
                          SimpleButton(
                            text: AppStrings.stop,
                            onPressed: () {
                              _timerService.stop();
                              _saveWork();
                            },
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: AppSizes.paddingL),
                SimpleInput(
                  controller: _descriptionController,
                  label: '${AppStrings.description} ${AppStrings.optional}',
                  maxLines: 3,
                ),
                const SizedBox(height: AppSizes.paddingL),
                SimpleButton(
                  text: AppStrings.saveWork,
                  onPressed: _isSaving ? null : _saveWork,
                  isLoading: _isSaving,
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}
