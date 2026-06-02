import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../services/appointment_service.dart';
import '../services/auth_service.dart';
import '../services/message_service.dart';
import '../widgets/app_widgets.dart';

class _MessageThreadType {
  static const appointment = 'Appointment';
  static const inquiry = 'Inquiry';
}

class MessagesScreen extends StatefulWidget {
  final int userId;
  final int salonId;
  final bool ownerMode;
  final int initialSalonId;
  final String initialSalonName;
  final String initialType;

  const MessagesScreen({
    super.key,
    this.userId = 0,
    this.salonId = 0,
    this.ownerMode = false,
    this.initialSalonId = 0,
    this.initialSalonName = '',
    this.initialType = _MessageThreadType.inquiry,
  });

  @override
  State<MessagesScreen> createState() => _MessagesScreenState();
}

class _MessagesScreenState extends State<MessagesScreen> {
  final AuthService _authService = AuthService();
  final MessageService _messageService = MessageService();
  final AppointmentService _appointmentService = AppointmentService();
  final Map<int, List<_ChatMessage>> _localMessages = {};

  bool _loading = true;
  bool _initialThreadOpened = false;
  String _currentUserName = '';
  List<_MessageThread> _threads = [];

  @override
  void initState() {
    super.initState();
    _loadThreads();
  }

  Future<void> _loadThreads() async {
    setState(() => _loading = true);
    await _loadCurrentUserName();

    final data =
        widget.ownerMode
            ? widget.salonId <= 0
                ? <Map<String, dynamic>>[]
                : await _messageService.getSalonThreads(widget.salonId)
            : widget.userId <= 0
            ? <Map<String, dynamic>>[]
            : await _messageService.getCustomerThreads(widget.userId);

    var threads = data.map(_threadFromMap).toList();

    if (threads.isEmpty) {
      threads = await _loadAppointmentThreads();
    }

    threads = _mergeThreads(threads, await _loadLocalThreads());
    final initialThread = _initialInquiryThread(threads);
    if (initialThread != null && !_containsThread(threads, initialThread)) {
      threads = _mergeThreads(threads, [initialThread]);
    }

    threads.sort((a, b) => b.activityDate.compareTo(a.activityDate));

    if (!mounted) return;
    setState(() {
      _threads = threads;
      _loading = false;
    });

    if (initialThread != null && !_initialThreadOpened) {
      _initialThreadOpened = true;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        final thread = _threads.firstWhere(
          (item) =>
              item.salonId == initialThread.salonId &&
              item.customerId == initialThread.customerId &&
              item.type == initialThread.type,
          orElse: () => initialThread,
        );
        _openThread(thread);
      });
    }
  }

  Future<List<_MessageThread>> _loadAppointmentThreads() async {
    final appointments =
        widget.ownerMode
            ? widget.salonId <= 0
                ? <dynamic>[]
                : await _appointmentService.getSalonAppointments(widget.salonId)
            : widget.userId <= 0
            ? <dynamic>[]
            : await _appointmentService.getCustomerAppointments(widget.userId);

    final grouped = <int, List<dynamic>>{};
    for (final appointment in appointments) {
      if (appointment is! Map) continue;
      final key =
          widget.ownerMode
              ? _asInt(appointment['customerId'] ?? appointment['CustomerId'])
              : _asInt(appointment['salonId'] ?? appointment['SalonId']);
      if (key <= 0) continue;
      grouped.putIfAbsent(key, () => []).add(appointment);
    }

    final threads = <_MessageThread>[];
    for (final entry in grouped.entries) {
      final threadAppointments = entry.value;
      threadAppointments.sort((a, b) {
        final aDate = _parseDate(a['appointmentDate'] ?? a['AppointmentDate']);
        final bDate = _parseDate(b['appointmentDate'] ?? b['AppointmentDate']);
        return bDate.compareTo(aDate);
      });

      final latest = threadAppointments.first;
      final salonId = _asInt(latest['salonId'] ?? latest['SalonId']);
      final customerId = _asInt(latest['customerId'] ?? latest['CustomerId']);
      final salonName =
          (latest['salonName'] ??
                  latest['SalonName'] ??
                  latest['salon']?['name'] ??
                  latest['Salon']?['Name'] ??
                  'Salon')
              .toString();
      final customerName =
          (latest['customerName'] ??
                  latest['CustomerName'] ??
                  latest['customer']?['fullName'] ??
                  latest['Customer']?['FullName'] ??
                  'Müşteri')
              .toString();
      final serviceName =
          (latest['serviceName'] ??
                  latest['ServiceName'] ??
                  latest['service']?['name'] ??
                  latest['Service']?['Name'] ??
                  'Hizmet')
              .toString();

      threads.add(
        _MessageThread(
          id: _fallbackThreadId(
            salonId,
            customerId,
            _MessageThreadType.appointment,
          ),
          type: _MessageThreadType.appointment,
          salonId: salonId,
          customerId: customerId,
          title: widget.ownerMode ? customerName : salonName,
          subtitle: widget.ownerMode ? salonName : serviceName,
          serviceName: serviceName,
          appointmentDate: _parseDate(
            latest['appointmentDate'] ?? latest['AppointmentDate'],
          ),
          appointmentCount: threadAppointments.length,
          ownerMode: widget.ownerMode,
          lastMessage: await _lastLocalMessage(
            salonId,
            customerId,
            _MessageThreadType.appointment,
          ),
        ),
      );
    }

    return threads;
  }

  _MessageThread _threadFromMap(Map<String, dynamic> map) {
    final salonName = (map['salonName'] ?? 'Salon').toString();
    final customerName = (map['customerName'] ?? 'Müşteri').toString();
    final serviceName = (map['serviceName'] ?? 'Hizmet').toString();
    final type = _normalizeThreadType(map['type']);
    return _MessageThread(
      id:
          _asInt(map['threadId']) != 0
              ? _asInt(map['threadId'])
              : _fallbackThreadId(
                _asInt(map['salonId']),
                _asInt(map['customerId']),
                type,
              ),
      type: type,
      salonId: _asInt(map['salonId']),
      customerId: _asInt(map['customerId']),
      title: widget.ownerMode ? customerName : salonName,
      subtitle: widget.ownerMode ? salonName : serviceName,
      serviceName: serviceName,
      appointmentDate: _parseDate(
        map['lastMessageAt'] ?? map['appointmentDate'],
      ),
      appointmentCount: _asInt(map['appointmentCount']),
      ownerMode: widget.ownerMode,
      lastMessage: map['lastMessage']?.toString(),
    );
  }

  Future<void> _openThread(_MessageThread thread) async {
    final messages = await _messageService.getThreadMessages(
      salonId: thread.salonId,
      customerId: thread.customerId,
      type: thread.type,
    );

    final parsedMessages =
        messages
            .map((message) {
              final senderId = _asInt(
                message['senderId'] ?? message['SenderId'],
              );
              return _ChatMessage(
                text:
                    (message['content'] ?? message['Content'] ?? '').toString(),
                incoming: senderId != widget.userId,
              );
            })
            .where((message) => message.text.isNotEmpty)
            .toList();

    final savedLocal = await _loadLocalMessages(thread);
    parsedMessages.addAll(savedLocal);

    if (parsedMessages.isEmpty) {
      parsedMessages.add(
        _ChatMessage(
          text:
              thread.isAppointment
                  ? thread.ownerMode
                      ? '${thread.serviceName} randevusu için müşterinizle buradan yazışabilirsiniz.'
                      : '${thread.serviceName} randevunuz için ${thread.title} ile buradan yazışabilirsiniz.'
                  : thread.ownerMode
                  ? '${thread.title} bilgi almak için yazabilir. Yanıtınızı buradan gönderebilirsiniz.'
                  : '${thread.title} ile randevu almadan bilgi almak için buradan yazışabilirsiniz.',
          incoming: true,
        ),
      );
    }

    if (!mounted) return;
    setState(() => _localMessages[thread.id] = parsedMessages);

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder:
          (_) => _ThreadSheet(
            thread: thread,
            messages: _localMessages[thread.id]!,
            onSend: (message) async {
              final sent = await _messageService.sendMessage(
                salonId: thread.salonId,
                customerId: thread.customerId,
                senderId: widget.userId,
                content: message,
                type: thread.type,
              );
              if (!mounted) return false;
              if (sent == null) {
                await _saveLocalMessage(thread, message);
              } else {
                await _clearLocalMessages(thread);
              }
              setState(() {
                _localMessages[thread.id]!.add(
                  _ChatMessage(text: message, incoming: false),
                );
              });
              await _loadThreads();
              return true;
            },
          ),
    );
  }

  Future<List<_ChatMessage>> _loadLocalMessages(_MessageThread thread) async {
    final prefs = await SharedPreferences.getInstance();
    var raw = prefs.getString(_localKey(thread));
    if ((raw == null || raw.isEmpty) && thread.isAppointment) {
      raw = prefs.getString(_legacyLocalKey(thread.salonId, thread.customerId));
    }
    if (raw == null || raw.isEmpty) return [];
    try {
      final decoded = jsonDecode(raw);
      if (decoded is! List) return [];
      return decoded
          .whereType<Map>()
          .map((item) {
            final senderId = _asInt(item['senderId']);
            final text = (item['text'] ?? '').toString();
            return _ChatMessage(
              text: text,
              incoming: senderId != widget.userId,
            );
          })
          .where((message) => message.text.isNotEmpty)
          .toList();
    } catch (_) {
      return [];
    }
  }

  Future<void> _saveLocalMessage(_MessageThread thread, String text) async {
    final prefs = await SharedPreferences.getInstance();
    final key = _localKey(thread);
    final existing = prefs.getString(key);
    final messages =
        existing == null || existing.isEmpty
            ? <dynamic>[]
            : (jsonDecode(existing) as List<dynamic>);
    messages.add({
      'senderId': widget.userId,
      'text': text,
      'createdAt': DateTime.now().toIso8601String(),
    });
    await prefs.setString(key, jsonEncode(messages));
    await _saveLocalThread(thread.copyWith(lastMessage: text));
  }

  Future<void> _clearLocalMessages(_MessageThread thread) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_localKey(thread));
  }

  Future<String?> _lastLocalMessage(
    int salonId,
    int customerId,
    String type,
  ) async {
    final prefs = await SharedPreferences.getInstance();
    var raw = prefs.getString(_localKeyParts(salonId, customerId, type));
    if ((raw == null || raw.isEmpty) &&
        type == _MessageThreadType.appointment) {
      raw = prefs.getString(_legacyLocalKey(salonId, customerId));
    }
    if (raw == null || raw.isEmpty) return null;
    try {
      final decoded = jsonDecode(raw);
      if (decoded is List && decoded.isNotEmpty) {
        final last = decoded.last;
        if (last is Map) return last['text']?.toString();
      }
    } catch (_) {}
    return null;
  }

  Future<List<_MessageThread>> _loadLocalThreads() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_localThreadsKey);
    if (raw == null || raw.isEmpty) return [];

    try {
      final decoded = jsonDecode(raw);
      if (decoded is! List) return [];
      return decoded
          .whereType<Map>()
          .map(_threadFromLocalMap)
          .where(
            (thread) =>
                widget.ownerMode
                    ? thread.salonId == widget.salonId
                    : thread.customerId == widget.userId,
          )
          .toList();
    } catch (_) {
      return [];
    }
  }

  Future<void> _saveLocalThread(_MessageThread thread) async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_localThreadsKey);
    final list =
        raw == null || raw.isEmpty
            ? <dynamic>[]
            : (jsonDecode(raw) as List<dynamic>);
    final index = list.indexWhere((item) {
      if (item is! Map) return false;
      return _asInt(item['salonId']) == thread.salonId &&
          _asInt(item['customerId']) == thread.customerId &&
          _normalizeThreadType(item['type']) == thread.type;
    });
    final payload = thread.toLocalMap(
      customerName:
          widget.ownerMode
              ? null
              : _currentUserName.trim().isEmpty
              ? null
              : _currentUserName.trim(),
    );
    if (index >= 0) {
      list[index] = payload;
    } else {
      list.add(payload);
    }
    await prefs.setString(_localThreadsKey, jsonEncode(list));
  }

  Future<void> _loadCurrentUserName() async {
    if (widget.ownerMode || _currentUserName.trim().isNotEmpty) return;

    final token = await _authService.getToken();
    if (token == null) return;

    final user = await _authService.getUserInfo(token);
    final name = (user?['name'] ?? user?['fullName'] ?? '').toString().trim();
    if (name.isNotEmpty) _currentUserName = name;
  }

  _MessageThread _threadFromLocalMap(Map<dynamic, dynamic> map) {
    final type = _normalizeThreadType(map['type']);
    final salonId = _asInt(map['salonId']);
    final customerId = _asInt(map['customerId']);
    return _MessageThread(
      id: _fallbackThreadId(salonId, customerId, type),
      type: type,
      salonId: salonId,
      customerId: customerId,
      title:
          widget.ownerMode
              ? (map['customerName'] ?? map['title'] ?? 'Müşteri').toString()
              : (map['salonName'] ?? map['title'] ?? 'Salon').toString(),
      subtitle:
          widget.ownerMode
              ? (map['salonName'] ?? 'Salon').toString()
              : (map['serviceName'] ?? 'Bilgi talebi').toString(),
      serviceName: (map['serviceName'] ?? 'Bilgi talebi').toString(),
      appointmentDate: _parseDate(map['appointmentDate']),
      appointmentCount: _asInt(map['appointmentCount']),
      ownerMode: widget.ownerMode,
      lastMessage: map['lastMessage']?.toString(),
    );
  }

  List<_MessageThread> _mergeThreads(
    List<_MessageThread> base,
    List<_MessageThread> extra,
  ) {
    final merged = <String, _MessageThread>{};
    for (final thread in [...base, ...extra]) {
      if (thread.salonId <= 0 || thread.customerId <= 0) continue;
      final key = '${thread.salonId}_${thread.customerId}_${thread.type}';
      final existing = merged[key];
      if (existing == null ||
          thread.activityDate.isAfter(existing.activityDate)) {
        merged[key] = thread;
      }
    }
    return merged.values.toList();
  }

  bool _containsThread(List<_MessageThread> threads, _MessageThread target) {
    return threads.any(
      (thread) =>
          thread.salonId == target.salonId &&
          thread.customerId == target.customerId &&
          thread.type == target.type,
    );
  }

  _MessageThread? _initialInquiryThread(List<_MessageThread> existingThreads) {
    if (widget.ownerMode || widget.userId <= 0 || widget.initialSalonId <= 0) {
      return null;
    }
    final type = _normalizeThreadType(widget.initialType);
    final existingIndex = existingThreads.indexWhere(
      (thread) =>
          thread.salonId == widget.initialSalonId &&
          thread.customerId == widget.userId &&
          thread.type == type,
    );
    if (existingIndex >= 0) return existingThreads[existingIndex];

    return _MessageThread(
      id: _fallbackThreadId(widget.initialSalonId, widget.userId, type),
      type: type,
      salonId: widget.initialSalonId,
      customerId: widget.userId,
      title:
          widget.initialSalonName.trim().isEmpty
              ? 'Salon'
              : widget.initialSalonName.trim(),
      subtitle:
          type == _MessageThreadType.appointment
              ? 'Randevu konuşması'
              : 'Bilgi talebi',
      serviceName:
          type == _MessageThreadType.appointment ? 'Hizmet' : 'Bilgi talebi',
      appointmentDate: DateTime.now(),
      appointmentCount: 0,
      ownerMode: false,
      lastMessage: null,
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text('Mesajlar'),
        backgroundColor: AppColors.primary,
        foregroundColor: Colors.white,
      ),
      body:
          _loading
              ? const Center(
                child: CircularProgressIndicator(color: AppColors.accent),
              )
              : _threads.isEmpty
              ? _EmptyMessages(ownerMode: widget.ownerMode)
              : RefreshIndicator(
                onRefresh: _loadThreads,
                child: ListView(
                  padding: const EdgeInsets.all(16),
                  children: _buildThreadSections(),
                ),
              ),
    );
  }

  List<Widget> _buildThreadSections() {
    final appointmentThreads =
        _threads.where((thread) => thread.isAppointment).toList();
    final inquiryThreads =
        _threads.where((thread) => !thread.isAppointment).toList();

    final children = <Widget>[];
    void addSection(String title, List<_MessageThread> threads) {
      if (threads.isEmpty) return;
      if (children.isNotEmpty) children.add(const SizedBox(height: 18));
      children.add(_ThreadSectionHeader(title: title, count: threads.length));
      children.add(const SizedBox(height: 10));
      for (var i = 0; i < threads.length; i++) {
        final thread = threads[i];
        final localMessages = _localMessages[thread.id] ?? [];
        final lastLocal =
            localMessages.isEmpty ? null : localMessages.last.text;
        children.add(
          _ThreadCard(
            thread: thread,
            preview:
                lastLocal ??
                thread.lastMessage ??
                (thread.isAppointment
                    ? '${thread.serviceName} randevusu için konuşma'
                    : 'Bilgi almak için konuşma'),
            onTap: () => _openThread(thread),
          ),
        );
        if (i != threads.length - 1) children.add(const SizedBox(height: 12));
      }
    }

    addSection(
      widget.ownerMode ? 'Randevulu müşteriler' : 'Randevu konuşmaları',
      appointmentThreads,
    );
    addSection(
      widget.ownerMode ? 'Bilgi talepleri' : 'Bilgi mesajları',
      inquiryThreads,
    );

    return children;
  }
}

class _ThreadSectionHeader extends StatelessWidget {
  final String title;
  final int count;

  const _ThreadSectionHeader({required this.title, required this.count});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Text(
          title,
          style: const TextStyle(
            color: AppColors.primary,
            fontSize: 13,
            fontWeight: FontWeight.w800,
          ),
        ),
        const SizedBox(width: 8),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
          decoration: BoxDecoration(
            color: AppColors.accent.withValues(alpha: 0.14),
            borderRadius: BorderRadius.circular(99),
          ),
          child: Text(
            '$count',
            style: const TextStyle(
              color: AppColors.accentDark,
              fontSize: 11,
              fontWeight: FontWeight.w800,
            ),
          ),
        ),
      ],
    );
  }
}

class _ThreadCard extends StatelessWidget {
  final _MessageThread thread;
  final String preview;
  final VoidCallback onTap;

  const _ThreadCard({
    required this.thread,
    required this.preview,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: AppColors.border),
        ),
        child: Row(
          children: [
            Container(
              width: 46,
              height: 46,
              decoration: BoxDecoration(
                color: AppColors.accent.withValues(alpha: 0.14),
                borderRadius: BorderRadius.circular(13),
              ),
              child: Icon(
                thread.isAppointment
                    ? Icons.event_available_outlined
                    : Icons.chat_bubble_outline_rounded,
                color: AppColors.accentDark,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          thread.title,
                          style: const TextStyle(
                            fontWeight: FontWeight.w800,
                            color: AppColors.primary,
                          ),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      Text(
                        _relativeTime(thread.appointmentDate),
                        style: const TextStyle(
                          color: AppColors.muted,
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Text(
                    preview,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      color: AppColors.muted,
                      fontSize: 13,
                      height: 1.3,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            const Icon(Icons.chevron_right_rounded, color: AppColors.muted),
          ],
        ),
      ),
    );
  }
}

class _ThreadSheet extends StatefulWidget {
  final _MessageThread thread;
  final List<_ChatMessage> messages;
  final Future<bool> Function(String message) onSend;

  const _ThreadSheet({
    required this.thread,
    required this.messages,
    required this.onSend,
  });

  @override
  State<_ThreadSheet> createState() => _ThreadSheetState();
}

class _ThreadSheetState extends State<_ThreadSheet> {
  final TextEditingController _controller = TextEditingController();

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _send() async {
    final message = _controller.text.trim();
    if (message.isEmpty) return;
    final sent = await widget.onSend(message);
    if (!sent) return;
    if (!mounted) return;
    _controller.clear();
    setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      height: MediaQuery.of(context).size.height * 0.82,
      padding: EdgeInsets.fromLTRB(
        18,
        12,
        18,
        MediaQuery.of(context).viewInsets.bottom + 16,
      ),
      decoration: const BoxDecoration(
        color: AppColors.background,
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: SafeArea(
        top: false,
        child: Column(
          children: [
            Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: AppColors.border,
                borderRadius: BorderRadius.circular(99),
              ),
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Container(
                  width: 42,
                  height: 42,
                  decoration: BoxDecoration(
                    color: AppColors.accent.withValues(alpha: 0.14),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(
                    widget.thread.isAppointment
                        ? Icons.event_available_outlined
                        : Icons.chat_bubble_outline_rounded,
                    color: AppColors.accentDark,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        widget.thread.title,
                        style: const TextStyle(
                          color: AppColors.primary,
                          fontSize: 16,
                          fontWeight: FontWeight.w800,
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 2),
                      Text(
                        widget.thread.isAppointment
                            ? '${widget.thread.subtitle} • ${_formatDate(widget.thread.appointmentDate)}'
                            : '${widget.thread.subtitle} • bilgi talebi',
                        style: const TextStyle(
                          color: AppColors.muted,
                          fontSize: 12,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            Expanded(
              child: ListView.builder(
                itemCount: widget.messages.length,
                itemBuilder: (_, index) {
                  final message = widget.messages[index];
                  return Align(
                    alignment:
                        message.incoming
                            ? Alignment.centerLeft
                            : Alignment.centerRight,
                    child: Container(
                      constraints: BoxConstraints(
                        maxWidth: MediaQuery.of(context).size.width * 0.72,
                      ),
                      margin: const EdgeInsets.only(bottom: 10),
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color:
                            message.incoming
                                ? AppColors.surface
                                : AppColors.primary,
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(
                          color:
                              message.incoming
                                  ? AppColors.border
                                  : AppColors.primary,
                        ),
                      ),
                      child: Text(
                        message.text,
                        style: TextStyle(
                          color:
                              message.incoming
                                  ? AppColors.primary
                                  : Colors.white,
                          fontSize: 13,
                          height: 1.35,
                        ),
                      ),
                    ),
                  );
                },
              ),
            ),
            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _controller,
                    minLines: 1,
                    maxLines: 3,
                    textInputAction: TextInputAction.send,
                    onSubmitted: (_) {
                      _send();
                    },
                    decoration: InputDecoration(
                      hintText: 'Mesaj yaz',
                      hintStyle: const TextStyle(
                        color: AppColors.muted,
                        fontSize: 14,
                      ),
                      filled: true,
                      fillColor: AppColors.surface,
                      contentPadding: const EdgeInsets.symmetric(
                        horizontal: 14,
                        vertical: 13,
                      ),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: BorderSide.none,
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                IconButton.filled(
                  onPressed: _send,
                  style: IconButton.styleFrom(
                    backgroundColor: AppColors.primary,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  icon: const Icon(Icons.send_rounded, size: 19),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _EmptyMessages extends StatelessWidget {
  final bool ownerMode;

  const _EmptyMessages({required this.ownerMode});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(28),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(
              Icons.chat_bubble_outline_rounded,
              color: AppColors.muted,
              size: 54,
            ),
            const SizedBox(height: 12),
            const Text(
              'Henüz mesaj yok',
              style: TextStyle(
                color: AppColors.primary,
                fontSize: 15,
                fontWeight: FontWeight.w800,
              ),
            ),
            const SizedBox(height: 5),
            Text(
              ownerMode
                  ? 'Randevulu müşteriler ve bilgi talepleri burada ayrı ayrı görünecek.'
                  : 'Randevu konuşmaları ve bilgi mesajları burada görünecek.',
              textAlign: TextAlign.center,
              style: const TextStyle(color: AppColors.muted, fontSize: 12),
            ),
          ],
        ),
      ),
    );
  }
}

class _MessageThread {
  final int id;
  final String type;
  final String title;
  final String subtitle;
  final String serviceName;
  final DateTime appointmentDate;
  final int appointmentCount;
  final bool ownerMode;
  final int salonId;
  final int customerId;
  final String? lastMessage;

  const _MessageThread({
    required this.id,
    required this.type,
    required this.salonId,
    required this.customerId,
    required this.title,
    required this.subtitle,
    required this.serviceName,
    required this.appointmentDate,
    required this.appointmentCount,
    required this.ownerMode,
    required this.lastMessage,
  });

  bool get isAppointment => type == _MessageThreadType.appointment;

  DateTime get activityDate =>
      appointmentDate.millisecondsSinceEpoch == 0
          ? DateTime.fromMillisecondsSinceEpoch(0)
          : appointmentDate;

  _MessageThread copyWith({String? lastMessage}) {
    return _MessageThread(
      id: id,
      type: type,
      salonId: salonId,
      customerId: customerId,
      title: title,
      subtitle: subtitle,
      serviceName: serviceName,
      appointmentDate: DateTime.now(),
      appointmentCount: appointmentCount,
      ownerMode: ownerMode,
      lastMessage: lastMessage ?? this.lastMessage,
    );
  }

  Map<String, dynamic> toLocalMap({String? customerName}) {
    return {
      'type': type,
      'salonId': salonId,
      'customerId': customerId,
      'title': title,
      'salonName': ownerMode ? subtitle : title,
      'customerName': ownerMode ? title : customerName ?? 'Müşteri',
      'serviceName': serviceName,
      'appointmentDate': appointmentDate.toIso8601String(),
      'appointmentCount': appointmentCount,
      'lastMessage': lastMessage,
    };
  }
}

class _ChatMessage {
  final String text;
  final bool incoming;

  const _ChatMessage({required this.text, required this.incoming});
}

int _asInt(dynamic value) {
  if (value is int) return value;
  if (value is num) return value.toInt();
  return int.tryParse(value?.toString() ?? '') ?? 0;
}

int _fallbackThreadId(int salonId, int customerId, String type) {
  final offset =
      type == _MessageThreadType.appointment ? 1000000000 : 2000000000;
  return offset + (salonId * 1000000) + customerId;
}

String _localKey(_MessageThread thread) {
  return _localKeyParts(thread.salonId, thread.customerId, thread.type);
}

String _localKeyParts(int salonId, int customerId, String type) {
  return 'chat_${type}_${salonId}_$customerId';
}

String _legacyLocalKey(int salonId, int customerId) {
  return 'chat_${salonId}_$customerId';
}

String _normalizeThreadType(dynamic type) {
  final value = type?.toString().trim().toLowerCase();
  if (value == 'appointment' || value == 'randevu') {
    return _MessageThreadType.appointment;
  }
  return _MessageThreadType.inquiry;
}

const String _localThreadsKey = 'chat_threads_v2';

DateTime _parseDate(dynamic value) {
  try {
    return DateTime.parse(value.toString()).toLocal();
  } catch (_) {
    return DateTime.fromMillisecondsSinceEpoch(0);
  }
}

String _formatDate(DateTime date) {
  if (date.millisecondsSinceEpoch == 0) return 'Tarih bekleniyor';
  return '${date.day}.${date.month}.${date.year} ${date.hour.toString().padLeft(2, '0')}:${date.minute.toString().padLeft(2, '0')}';
}

String _relativeTime(DateTime date) {
  if (date.millisecondsSinceEpoch == 0) return '';
  final now = DateTime.now();
  final diff = now.difference(date);
  if (diff.inDays == 0) return 'Bugün';
  if (diff.inDays == 1) return 'Dün';
  if (diff.inDays < 7 && diff.inDays > 1) return '${diff.inDays} gün';
  return '${date.day}.${date.month}.${date.year}';
}
