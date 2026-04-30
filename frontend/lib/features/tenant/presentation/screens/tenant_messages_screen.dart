import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../../core/constants/app_colors.dart';
import '../../../../core/constants/app_dimensions.dart';
import '../providers/tenant_provider.dart';

class TenantMessagesScreen extends StatefulWidget {
  const TenantMessagesScreen({super.key});

  @override
  State<TenantMessagesScreen> createState() => _TenantMessagesScreenState();
}

class _TenantMessagesScreenState extends State<TenantMessagesScreen> {
  Map<String, dynamic>? _openQuery;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<TenantProvider>().refreshQueries();
    });
  }

  void _showNewQuery(BuildContext context, TenantProvider p) {
    final subjectCtrl = TextEditingController();
    final bodyCtrl = TextEditingController();
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppColors.cardBg,
        title: const Text('New Message',
            style: TextStyle(color: AppColors.textPrimary)),
        content: SizedBox(
          width: 400,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _Label('Subject'),
              const SizedBox(height: 6),
              TextField(
                controller: subjectCtrl,
                style: const TextStyle(
                    color: AppColors.textPrimary,
                    fontSize: AppDimensions.fontSM),
                decoration: _dec('Brief subject...'),
              ),
              const SizedBox(height: AppDimensions.spaceMD),
              _Label('Message'),
              const SizedBox(height: 6),
              TextField(
                controller: bodyCtrl,
                maxLines: 4,
                style: const TextStyle(
                    color: AppColors.textPrimary,
                    fontSize: AppDimensions.fontSM),
                decoration: _dec('Write your message...'),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel',
                style: TextStyle(color: AppColors.textMuted)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.accentSilver,
              foregroundColor: AppColors.bgOuter,
              elevation: 0,
            ),
            onPressed: () async {
              if (subjectCtrl.text.trim().isEmpty ||
                  bodyCtrl.text.trim().isEmpty) {
                return;
              }
              Navigator.pop(ctx);
              try {
                await p.addQuery({
                  'subject': subjectCtrl.text.trim(),
                  'body': bodyCtrl.text.trim(),
                });
              } catch (e) {
                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('Error: $e')),
                  );
                }
              }
            },
            child: const Text('Send'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<TenantProvider>(
      builder: (context, p, _) => Padding(
        padding: const EdgeInsets.all(AppDimensions.spaceXL),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Text(
                  'Messages',
                  style: TextStyle(
                      fontSize: AppDimensions.fontH2,
                      fontWeight: FontWeight.w700,
                      color: AppColors.textPrimary),
                ),
                const Spacer(),
                ElevatedButton.icon(
                  icon: const Icon(Icons.add, size: 16),
                  label: const Text('New Message'),
                  onPressed: () => _showNewQuery(context, p),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.accentSilver,
                    foregroundColor: AppColors.bgOuter,
                    elevation: 0,
                  ),
                ),
              ],
            ),
            const SizedBox(height: AppDimensions.spaceXL),
            if (p.isLoading)
              const Center(
                  child: CircularProgressIndicator(
                      color: AppColors.accentSilver))
            else if (p.queries.isEmpty)
              const Center(
                  child: Text('No messages yet.',
                      style: TextStyle(color: AppColors.textMuted)))
            else
              Expanded(
                child: _openQuery != null
                    ? _QueryThread(
                        query: _openQuery!,
                        provider: p,
                        onBack: () => setState(() => _openQuery = null),
                      )
                    : ListView.separated(
                        itemCount: p.queries.length,
                        separatorBuilder: (_, __) =>
                            const SizedBox(height: AppDimensions.spaceSM),
                        itemBuilder: (_, i) => _QueryRow(
                          query: p.queries[i],
                          onTap: () =>
                              setState(() => _openQuery = p.queries[i]),
                        ),
                      ),
              ),
          ],
        ),
      ),
    );
  }
}

class _QueryRow extends StatelessWidget {
  const _QueryRow({required this.query, required this.onTap});

  final Map<String, dynamic> query;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final status = query['status'] as String? ?? 'open';
    final replies =
        (query['tenant_query_replies'] as List?)?.length ?? 0;

    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(AppDimensions.spaceLG),
        decoration: BoxDecoration(
          color: AppColors.cardBg,
          border: Border.all(color: AppColors.border),
          borderRadius: BorderRadius.circular(AppDimensions.radiusMD),
        ),
        child: Row(
          children: [
            const Icon(Icons.chat_bubble_outline_rounded,
                color: AppColors.textMuted, size: AppDimensions.iconMD),
            const SizedBox(width: AppDimensions.spaceLG),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    query['subject'] as String? ?? '',
                    style: const TextStyle(
                        fontSize: AppDimensions.fontBase,
                        fontWeight: FontWeight.w600,
                        color: AppColors.textPrimary),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    query['body'] as String? ?? '',
                    style: const TextStyle(
                        fontSize: AppDimensions.fontSM,
                        color: AppColors.textMuted),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                _StatusBadge(status),
                if (replies > 0) ...[
                  const SizedBox(height: 4),
                  Text('$replies repl${replies == 1 ? 'y' : 'ies'}',
                      style: const TextStyle(
                          fontSize: 11, color: AppColors.textMuted)),
                ],
              ],
            ),
            const SizedBox(width: AppDimensions.spaceSM),
            const Icon(Icons.chevron_right,
                color: AppColors.textMuted, size: AppDimensions.iconMD),
          ],
        ),
      ),
    );
  }
}

class _QueryThread extends StatefulWidget {
  const _QueryThread(
      {required this.query, required this.provider, required this.onBack});

  final Map<String, dynamic> query;
  final TenantProvider provider;
  final VoidCallback onBack;

  @override
  State<_QueryThread> createState() => _QueryThreadState();
}

class _QueryThreadState extends State<_QueryThread> {
  final _replyCtrl = TextEditingController();
  bool _sending = false;

  @override
  void dispose() {
    _replyCtrl.dispose();
    super.dispose();
  }

  Future<void> _send() async {
    if (_replyCtrl.text.trim().isEmpty) return;
    setState(() => _sending = true);
    try {
      await widget.provider
          .replyQuery(widget.query['id'] as String, _replyCtrl.text.trim());
      _replyCtrl.clear();
    } finally {
      if (mounted) setState(() => _sending = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    // Get fresh query data from provider
    final queryId = widget.query['id'] as String;
    final fresh = widget.provider.queries
        .firstWhere((q) => q['id'] == queryId, orElse: () => widget.query);
    final replies =
        (fresh['tenant_query_replies'] as List?)?.cast<Map<String, dynamic>>() ?? [];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Back + subject
        Row(
          children: [
            IconButton(
              icon: const Icon(Icons.arrow_back,
                  color: AppColors.textMuted),
              onPressed: widget.onBack,
            ),
            Expanded(
              child: Text(
                fresh['subject'] as String? ?? '',
                style: const TextStyle(
                    fontSize: AppDimensions.fontBase,
                    fontWeight: FontWeight.w600,
                    color: AppColors.textPrimary),
              ),
            ),
            _StatusBadge(fresh['status'] as String? ?? 'open'),
          ],
        ),
        const Divider(color: AppColors.border),
        // Original message
        _Bubble(
          body: fresh['body'] as String? ?? '',
          role: 'tenant',
          createdAt: fresh['created_at'] as String? ?? '',
        ),
        // Replies
        Expanded(
          child: ListView(
            children: replies
                .map((r) => _Bubble(
                      body: r['body'] as String? ?? '',
                      role: r['author_role'] as String? ?? 'tenant',
                      createdAt: r['created_at'] as String? ?? '',
                    ))
                .toList(),
          ),
        ),
        // Reply input
        Container(
          padding: const EdgeInsets.symmetric(
              horizontal: AppDimensions.spaceMD,
              vertical: AppDimensions.spaceSM),
          decoration: const BoxDecoration(
            border: Border(top: BorderSide(color: AppColors.border)),
          ),
          child: Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _replyCtrl,
                  style: const TextStyle(
                      color: AppColors.textPrimary,
                      fontSize: AppDimensions.fontSM),
                  decoration: _dec('Reply...'),
                  onSubmitted: (_) => _send(),
                ),
              ),
              const SizedBox(width: AppDimensions.spaceSM),
              IconButton(
                icon: _sending
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: AppColors.accentSilver))
                    : const Icon(Icons.send,
                        color: AppColors.accentSilver),
                onPressed: _sending ? null : _send,
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _Bubble extends StatelessWidget {
  const _Bubble(
      {required this.body, required this.role, required this.createdAt});

  final String body;
  final String role;
  final String createdAt;

  @override
  Widget build(BuildContext context) {
    final isAdmin = role == 'admin';
    return Align(
      alignment: isAdmin ? Alignment.centerLeft : Alignment.centerRight,
      child: Container(
        margin: const EdgeInsets.symmetric(
            vertical: 4, horizontal: AppDimensions.spaceMD),
        padding: const EdgeInsets.all(AppDimensions.spaceMD),
        constraints: const BoxConstraints(maxWidth: 360),
        decoration: BoxDecoration(
          color: isAdmin ? AppColors.cardBg : AppColors.progressCardBg,
          border: Border.all(color: AppColors.border),
          borderRadius: BorderRadius.circular(AppDimensions.radiusMD),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              isAdmin ? 'Admin' : 'You',
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w700,
                color: isAdmin
                    ? AppColors.accentGold
                    : AppColors.accentSilver,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              body,
              style: const TextStyle(
                  fontSize: AppDimensions.fontSM,
                  color: AppColors.textPrimary),
            ),
          ],
        ),
      ),
    );
  }
}

class _StatusBadge extends StatelessWidget {
  const _StatusBadge(this.status);

  final String status;

  @override
  Widget build(BuildContext context) {
    final (bg, fg) = switch (status) {
      'replied' => (AppColors.occupiedBg, AppColors.occupiedText),
      'closed' => (AppColors.sidebarItemActive, AppColors.textMuted),
      _ => (AppColors.vacantBg, AppColors.vacantText),
    };
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      decoration:
          BoxDecoration(color: bg, borderRadius: BorderRadius.circular(4)),
      child: Text(status.toUpperCase(),
          style: TextStyle(fontSize: 10, fontWeight: FontWeight.w700, color: fg)),
    );
  }
}

InputDecoration _dec(String hint) => InputDecoration(
      hintText: hint,
      hintStyle:
          const TextStyle(color: AppColors.textMuted, fontSize: 13),
      filled: true,
      fillColor: AppColors.pageBg,
      contentPadding:
          const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      border: OutlineInputBorder(
        borderSide: const BorderSide(color: AppColors.border),
        borderRadius: BorderRadius.circular(AppDimensions.radiusXS),
      ),
      enabledBorder: OutlineInputBorder(
        borderSide: const BorderSide(color: AppColors.border),
        borderRadius: BorderRadius.circular(AppDimensions.radiusXS),
      ),
      focusedBorder: OutlineInputBorder(
        borderSide: const BorderSide(color: AppColors.accentSilver),
        borderRadius: BorderRadius.circular(AppDimensions.radiusXS),
      ),
    );

class _Label extends StatelessWidget {
  const _Label(this.text);

  final String text;

  @override
  Widget build(BuildContext context) => Text(
        text,
        style: const TextStyle(
            fontSize: AppDimensions.fontSM,
            fontWeight: FontWeight.w600,
            color: AppColors.textSecondary),
      );
}
