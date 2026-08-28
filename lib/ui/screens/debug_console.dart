import 'package:flutter/material.dart';

import '../../ai/engine_log.dart';
import '../app_theme.dart';

class DebugConsole extends StatefulWidget {
  final List<EngineLogEntry> logs;
  final VoidCallback onClear;
  final VoidCallback onHide;

  const DebugConsole({
    super.key,
    required this.logs,
    required this.onClear,
    required this.onHide,
  });

  @override
  State<DebugConsole> createState() => _DebugConsoleState();
}

class _DebugConsoleState extends State<DebugConsole> {
  final _scroll = ScrollController();
  int? _expanded;

  static const _mono = TextStyle(
    fontFamily: 'Consolas',
    fontFamilyFallback: ['Courier New', 'monospace'],
    fontSize: 11.5,
    height: 1.35,
    color: AppColors.paper,
  );

  @override
  void didUpdateWidget(covariant DebugConsole oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.logs.length != oldWidget.logs.length) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!_scroll.hasClients) {
          return;
        }
        _scroll.jumpTo(_scroll.position.maxScrollExtent);
      });
    }
  }

  @override
  void dispose() {
    _scroll.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 188,
      decoration: const BoxDecoration(
        color: Color(0xFF12100E),
        border: Border(top: BorderSide(color: Color(0xFF3A322A))),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 4, 4, 4),
            child: Row(
              children: [
                const Icon(Icons.terminal, size: 16, color: AppColors.gold),
                const SizedBox(width: 8),
                const Text(
                  'Engine console',
                  style: TextStyle(
                    color: AppColors.gold,
                    fontWeight: FontWeight.w600,
                    fontSize: 13,
                  ),
                ),
                const SizedBox(width: 8),
                Text(
                  '${widget.logs.length} lines',
                  style: TextStyle(
                    color: AppColors.paper.withValues(alpha: 0.55),
                    fontSize: 12,
                  ),
                ),
                const Spacer(),
                IconButton(
                  tooltip: 'Clear',
                  onPressed: widget.logs.isEmpty ? null : widget.onClear,
                  icon: const Icon(Icons.delete_outline, size: 18),
                  visualDensity: VisualDensity.compact,
                ),
                IconButton(
                  tooltip: 'Hide console',
                  onPressed: widget.onHide,
                  icon: const Icon(Icons.expand_more, size: 20),
                  visualDensity: VisualDensity.compact,
                ),
              ],
            ),
          ),
          const Divider(height: 1, color: Color(0xFF3A322A)),
          Expanded(
            child: widget.logs.isEmpty
                ? Padding(
                    padding: const EdgeInsets.all(12),
                    child: Text(
                      'Engine switches, LoGos prompts, Ollama timings, and replies appear here.',
                      style: _mono.copyWith(
                        color: AppColors.paper.withValues(alpha: 0.45),
                      ),
                    ),
                  )
                : ListView.builder(
                    controller: _scroll,
                    padding: const EdgeInsets.fromLTRB(12, 6, 12, 10),
                    itemCount: widget.logs.length,
                    itemBuilder: (context, index) {
                      final entry = widget.logs[index];
                      final open = _expanded == index;
                      final color = entry.isError
                          ? const Color(0xFFE07A5F)
                          : entry.source == 'logos'
                              ? AppColors.gold
                              : AppColors.paper.withValues(alpha: 0.88);
                      return Padding(
                        padding: const EdgeInsets.only(bottom: 6),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            GestureDetector(
                              onTap: entry.detail == null
                                  ? null
                                  : () {
                                      setState(() {
                                        _expanded = open ? null : index;
                                      });
                                    },
                              child: SelectableText(
                                '[${entry.clock}] ${entry.source.padRight(7)}  ${entry.headline}'
                                '${entry.detail == null ? '' : (open ? '  ▾' : '  ▸')}',
                                style: _mono.copyWith(color: color),
                              ),
                            ),
                            if (open && entry.detail != null)
                              Padding(
                                padding: const EdgeInsets.only(top: 4, left: 8),
                                child: SelectableText(
                                  entry.detail!,
                                  style: _mono.copyWith(
                                    color: AppColors.paper.withValues(alpha: 0.72),
                                    fontSize: 11,
                                  ),
                                ),
                              ),
                          ],
                        ),
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }
}
