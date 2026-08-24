//  logwidet.dart
//  Created by JeoJay127
//
import 'dart:async';
import 'package:flutter/material.dart';
import 'log.dart';

class LogWidget extends StatefulWidget {
  final List<String>? channels;
  final LogConfig? config;
  final bool allChannel;
  final bool showChannelTag;
  final Map<String, Color>? channelColors;

  const LogWidget({
    super.key,
    this.channels,
    this.config,
    this.allChannel = false,
    this.showChannelTag = false,
    this.channelColors,
  });

  @override
  State<LogWidget> createState() => _LogWidgetState();
}

class _LogWidgetState extends State<LogWidget> {
  final ScrollController _scrollController = ScrollController();
  final List<String> _logs = [];
  final List<StreamSubscription<String>> _subscriptions = [];
  bool _scrollScheduled = false;

  @override
  void initState() {
    super.initState();
    if (widget.allChannel) {
      _subscriptions.add(Log.logStreamAll.listen(_onNewLogLine));
    } else {
      final targetChannels = widget.channels ?? [Log.defaultChannel];
      for (final c in targetChannels) {
        _subscriptions.add(
          Log.width(channel: c).logStream.listen(_onNewLogLine),
        );
      }
    }
  }

  void _onNewLogLine(String line) {
    if (!mounted) return;

    final maxLines = widget.config?.maxLines ??
        Log.channels[Log.defaultChannel]?.config.maxLines ??
        2000;

    setState(() {
      if (line.contains('[CLEARED]')) {
        _logs.clear();
      } else {
        _logs.add(line);
      }
      final excess = _logs.length - maxLines;
      if (excess > 0) _logs.removeRange(0, excess);
    });

    _scheduleScrollToBottom();
  }

  void _scheduleScrollToBottom() {
    if (_scrollScheduled) return;
    _scrollScheduled = true;
    WidgetsBinding.instance.addPostFrameCallback((_) => _scrollToBottom());
  }

  void _scrollToBottom([double? previousMaxExtent]) {
    if (!mounted || !_scrollController.hasClients) {
      _scrollScheduled = false;
      return;
    }

    final position = _scrollController.position;
    final maxExtent = position.maxScrollExtent;
    if ((position.pixels - maxExtent).abs() > 0.5) {
      _scrollController.jumpTo(maxExtent);
    }

    final extentIsStable = previousMaxExtent != null &&
        (previousMaxExtent - maxExtent).abs() <= 0.5;
    if (extentIsStable && position.extentAfter <= 0.5) {
      _scrollScheduled = false;
      return;
    }

    WidgetsBinding.instance.addPostFrameCallback(
      (_) => _scrollToBottom(maxExtent),
    );
  }

  @override
  void dispose() {
    for (final sub in _subscriptions) {
      sub.cancel();
    }
    _subscriptions.clear();
    _scrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final borderColor = colorScheme.onSurface.withValues(
      alpha: colorScheme.brightness == Brightness.dark ? 0.16 : 0.12,
    );

    return Container(
      decoration: BoxDecoration(
        border: Border.all(color: borderColor, width: 0.5),
        borderRadius: BorderRadius.circular(6),
      ),
      constraints: const BoxConstraints(
        minHeight: 200,
        minWidth: double.infinity,
      ),
      child: SelectionArea(
        child: ListView.builder(
          controller: _scrollController,
          padding: const EdgeInsets.all(12),
          itemCount: _logs.length,
          itemBuilder: (context, index) => RichText(
            text: LogTextFormatter.format(
              _logs[index],
              config: widget.config,
              channelColors: widget.channelColors,
              showChannelTag: widget.showChannelTag,
              defaultTextColor: colorScheme.onSurface,
            ),
            selectionRegistrar: SelectionContainer.maybeOf(context),
            selectionColor: DefaultSelectionStyle.of(context).selectionColor ??
                DefaultSelectionStyle.defaultColor,
          ),
        ),
      ),
    );
  }
}

class LogTextFormatter {
  static const _timestampBase =
      r'^\d{4}-\d{2}-\d{2} \d{2}:\d{2}:\d{2}(?:\.\d+)?';
  static final _fullPattern = RegExp('$_timestampBase \\[.*?\\]');
  static final _timestampPattern = RegExp(_timestampBase);
  static final _levelPattern = RegExp('(?<=$_timestampBase) \\[.*?\\]');
  static final _levelExtractor = RegExp(r'\[(INFO|DEBUG|WARNING|ERROR)\]');

  static TextSpan format(
    String logText, {
    LogConfig? config,
    Map<String, Color>? channelColors,
    bool showChannelTag = false,
    double textSize = 11,
    Color? defaultTextColor,
  }) {
    final channelName =
        RegExp(r'^\[([^\]]+)\]').firstMatch(logText)?.group(1) ??
            Log.defaultChannel;

    final channelColor =
        channelColors?[channelName] ?? _getChannelColor(channelName);
    final levelColor = _getLevelColor(logText);

    final logConfig = config ??
        Log.channels[channelName]?.config ??
        Log.channels[Log.defaultChannel]?.config ??
        LogConfig();

    // 去掉 channel
    String processedText = logText.replaceFirst(RegExp(r'^\[[^\]]+\]\s*'), '');

    // 按配置裁剪
    if (!logConfig.includeLogTimestampForUI &&
        !logConfig.includeLogLevelForUI) {
      processedText = processedText.replaceFirst(_fullPattern, '');
    } else if (!logConfig.includeLogTimestampForUI) {
      processedText = processedText.replaceFirst(_timestampPattern, '');
    } else if (!logConfig.includeLogLevelForUI) {
      processedText = processedText.replaceFirst(_levelPattern, '');
    }

    return TextSpan(
      children: [
        if (showChannelTag)
          TextSpan(
            text: '[$channelName] ',
            style: TextStyle(
              fontWeight: FontWeight.bold,
              color: channelColor,
              fontSize: textSize,
            ),
          ),
        TextSpan(
          text: processedText,
          style: TextStyle(
            fontSize: textSize,
            color: levelColor ?? defaultTextColor,
          ),
        ),
      ],
    );
  }

  static Color _getChannelColor(String channel) {
    final hash = channel.hashCode % 360;
    return HSLColor.fromAHSL(1, hash.toDouble(), 0.7, 0.6).toColor();
  }

  static Color? _getLevelColor(String logText) {
    final match = _levelExtractor.firstMatch(logText);
    switch (match?.group(1)) {
      case 'DEBUG':
        return Colors.blue;
      case 'WARNING':
        return Colors.orange;
      case 'ERROR':
        return Colors.red;
      default:
        return null;
    }
  }
}
