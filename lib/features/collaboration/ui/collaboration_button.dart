import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../bloc/collaboration_cubit.dart';
import '../bloc/collaboration_state.dart';

/// Toolbar button that opens the collaboration (Share Space) popover.
class CollaborationButton extends StatelessWidget {
  const CollaborationButton({super.key});

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<CollaborationCubit, CollaborationState>(
      builder: (ctx, state) {
        final color = state.isHosting
            ? const Color(0xFF34D399)
            : state.isGuest
                ? const Color(0xFF60A5FA)
                : const Color(0xFF9AA3BF);
        return _CollabToolBtn(
          icon:    Icons.people_outline_rounded,
          tooltip: state.isIdle ? 'Share Space' : state.address,
          color:   color,
          badge:   state.peerCount > 0 ? '${state.peerCount}' : null,
          onTap:   () => _showDialog(ctx),
        );
      },
    );
  }

  void _showDialog(BuildContext context) {
    showDialog<void>(
      context:      context,
      barrierColor: const Color(0x66000000),
      builder: (_) => BlocProvider.value(
        value: context.read<CollaborationCubit>(),
        child: const _CollaborationDialog(),
      ),
    );
  }
}

// ── Dialog ─────────────────────────────────────────────────────────────────

class _CollaborationDialog extends StatefulWidget {
  const _CollaborationDialog();

  @override
  State<_CollaborationDialog> createState() => _CollaborationDialogState();
}

class _CollaborationDialogState extends State<_CollaborationDialog>
    with SingleTickerProviderStateMixin {
  late final TabController _tabs;
  final _ipCtrl     = TextEditingController();
  bool  _connecting = false;

  @override
  void initState() {
    super.initState();
    _tabs = TabController(length: 2, vsync: this);
  }

  @override
  void dispose() {
    _tabs.dispose();
    _ipCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Material(
        color: Colors.transparent,
        child: Container(
          width: 420,
          decoration: BoxDecoration(
            color: const Color(0xFF111318),
            border: Border.all(color: const Color(0xFF2A3040)),
            borderRadius: BorderRadius.circular(12),
            boxShadow: const [
              BoxShadow(color: Color(0xBB000000), blurRadius: 32, offset: Offset(0, 8)),
            ],
          ),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(20, 16, 20, 20),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // Header
                Row(
                  children: [
                    const Icon(Icons.people_rounded, size: 18, color: Color(0xFF7C3AED)),
                    const SizedBox(width: 10),
                    const Text('Share Space',
                        style: TextStyle(color: Color(0xFFE8E8FF),
                            fontSize: 15, fontWeight: FontWeight.w700)),
                    const Spacer(),
                    IconButton(
                      icon: const Icon(Icons.close, size: 16, color: Color(0xFF64748B)),
                      padding: EdgeInsets.zero,
                      onPressed: () => Navigator.pop(context),
                    ),
                  ],
                ),
                const SizedBox(height: 16),

                // Body — changes depending on collaboration state.
                BlocBuilder<CollaborationCubit, CollaborationState>(
                  builder: (ctx, state) {
                    if (state.isHosting) {
                      return _HostActiveView(state: state);
                    }
                    if (state.isGuest) {
                      return _GuestActiveView(state: state);
                    }
                    return _IdleView(
                      tabs:        _tabs,
                      ipCtrl:      _ipCtrl,
                      connecting:  _connecting,
                      onConnecting: (v) => setState(() => _connecting = v),
                    );
                  },
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

// ── Idle ───────────────────────────────────────────────────────────────────

class _IdleView extends StatelessWidget {
  const _IdleView({
    required this.tabs,
    required this.ipCtrl,
    required this.connecting,
    required this.onConnecting,
  });
  final TabController         tabs;
  final TextEditingController ipCtrl;
  final bool                  connecting;
  final void Function(bool)   onConnecting;

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // Tab bar
        Container(
          height: 34,
          decoration: BoxDecoration(
            color:        const Color(0xFF0D0F14),
            borderRadius: BorderRadius.circular(8),
          ),
          child: TabBar(
            controller: tabs,
            indicatorSize: TabBarIndicatorSize.tab,
            indicator: BoxDecoration(
              color:        const Color(0xFF1E2340),
              borderRadius: BorderRadius.circular(6),
            ),
            labelColor:            const Color(0xFFE8E8FF),
            unselectedLabelColor:  const Color(0xFF64748B),
            labelStyle:            const TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
            dividerColor:          Colors.transparent,
            tabs: const [Tab(text: 'Host a Space'), Tab(text: 'Join a Space')],
          ),
        ),
        const SizedBox(height: 16),
        SizedBox(
          height: 140,
          child: TabBarView(
            controller: tabs,
            children: [
              _HostTab(),
              _GuestTab(
                ctrl:         ipCtrl,
                connecting:   connecting,
                onConnecting: onConnecting,
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _HostTab extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return BlocBuilder<CollaborationCubit, CollaborationState>(
      builder: (ctx, state) => Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const Text(
            'Start a server so others on your local network can connect '
            'and mirror your Mindmap board in real time.',
            style: TextStyle(color: Color(0xFF9AA3BF), fontSize: 12, height: 1.5),
          ),
          if (state.error.isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(top: 8),
              child: Text(state.error,
                  style: const TextStyle(color: Color(0xFFF87171), fontSize: 11)),
            ),
          const Spacer(),
          _PrimaryBtn(
            label: 'Start Hosting',
            icon:  Icons.wifi_tethering_rounded,
            onTap: () => ctx.read<CollaborationCubit>().startHosting(),
          ),
        ],
      ),
    );
  }
}

class _GuestTab extends StatelessWidget {
  const _GuestTab({
    required this.ctrl,
    required this.connecting,
    required this.onConnecting,
  });
  final TextEditingController ctrl;
  final bool                  connecting;
  final void Function(bool)   onConnecting;

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<CollaborationCubit, CollaborationState>(
      builder: (ctx, state) => Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _DarkTextField(
            controller: ctrl,
            hint: 'Host IP or IP:port  e.g. 192.168.1.10',
            enabled: !connecting,
          ),
          if (state.error.isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(top: 6),
              child: Text(state.error,
                  style: const TextStyle(color: Color(0xFFF87171), fontSize: 11)),
            ),
          const Spacer(),
          _PrimaryBtn(
            label: connecting ? 'Connecting…' : 'Connect',
            icon:  Icons.lan_outlined,
            onTap: connecting
                ? null
                : () async {
                    final raw = ctrl.text.trim();
                    if (raw.isEmpty) return;
                    // Allow "192.168.1.10:40401" — extract host and port
                    final colonIdx = raw.lastIndexOf(':');
                    String host = raw;
                    int port = 40401;
                    if (colonIdx > 0) {
                      final maybePart = raw.substring(colonIdx + 1);
                      final maybePort = int.tryParse(maybePart);
                      if (maybePort != null) {
                        host = raw.substring(0, colonIdx);
                        port = maybePort;
                      }
                    }
                    onConnecting(true);
                    await ctx.read<CollaborationCubit>().connect(host, port: port);
                    onConnecting(false);
                    if (ctx.mounted &&
                        ctx.read<CollaborationCubit>().state.isGuest) {
                      Navigator.pop(ctx);
                    }
                  },
          ),
        ],
      ),
    );
  }
}

// ── Host active ────────────────────────────────────────────────────────────

class _HostActiveView extends StatelessWidget {
  const _HostActiveView({required this.state});
  final CollaborationState state;

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          decoration: BoxDecoration(
            color:  const Color(0xFF0A1A12),
            border: Border.all(color: const Color(0x4034D399)),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Row(
            children: [
              const Icon(Icons.wifi_tethering_rounded, size: 16, color: Color(0xFF34D399)),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('Hosting',
                        style: TextStyle(color: Color(0xFF34D399),
                            fontSize: 12, fontWeight: FontWeight.w700)),
                    Text(state.address,
                        style: const TextStyle(color: Color(0xFFE8E8FF),
                            fontSize: 14, fontFamily: 'monospace',
                            fontWeight: FontWeight.w600)),
                  ],
                ),
              ),
              IconButton(
                icon:    const Icon(Icons.copy, size: 14, color: Color(0xFF64748B)),
                tooltip: 'Copy address',
                onPressed: () =>
                    Clipboard.setData(ClipboardData(text: state.address)),
              ),
            ],
          ),
        ),
        const SizedBox(height: 12),
        if (state.peers.isEmpty)
          const Text('Waiting for peers…',
              style: TextStyle(color: Color(0xFF64748B), fontSize: 12))
        else
          for (final e in state.peers.entries)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 3),
              child: Row(
                children: [
                  const Icon(Icons.person_outline, size: 14, color: Color(0xFF60A5FA)),
                  const SizedBox(width: 8),
                  Text(e.value.isEmpty ? e.key : e.value,
                      style: const TextStyle(color: Color(0xFFE8E8FF), fontSize: 12)),
                ],
              ),
            ),
        // ── Browser URL ──────────────────────────────────────────────
        if (state.webClientUrl.isNotEmpty) ...[
          const SizedBox(height: 12),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            decoration: BoxDecoration(
              color:  const Color(0xFF0A0F1A),
              border: Border.all(color: const Color(0xFF1E2D4A)),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Row(
              children: [
                const Icon(Icons.open_in_browser, size: 14,
                    color: Color(0xFF4B9EFF)),
                const SizedBox(width: 8),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text('Open in browser',
                          style: TextStyle(color: Color(0xFF4B9EFF),
                              fontSize: 10, fontWeight: FontWeight.w600)),
                      Text(state.webClientUrl,
                          style: const TextStyle(
                              color: Color(0xFFE8E8FF),
                              fontSize: 11,
                              fontFamily: 'monospace')),
                    ],
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.copy, size: 12,
                      color: Color(0xFF64748B)),
                  tooltip: 'Copy browser URL',
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(),
                  onPressed: () => Clipboard.setData(
                      ClipboardData(text: state.webClientUrl)),
                ),
              ],
            ),
          ),
        ],
        const SizedBox(height: 16),
        _SecondaryBtn(
          label: 'Stop Hosting',
          icon:  Icons.wifi_tethering_off_rounded,
          color: const Color(0xFFF87171),
          onTap: () {
            context.read<CollaborationCubit>().stopHosting();
            Navigator.pop(context);
          },
        ),
      ],
    );
  }
}

// ── Guest active ───────────────────────────────────────────────────────────

class _GuestActiveView extends StatelessWidget {
  const _GuestActiveView({required this.state});
  final CollaborationState state;

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          decoration: BoxDecoration(
            color:  const Color(0xFF0A1020),
            border: Border.all(color: const Color(0x4060A5FA)),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Row(
            children: [
              const Icon(Icons.lan_outlined, size: 16, color: Color(0xFF60A5FA)),
              const SizedBox(width: 10),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('Connected',
                      style: TextStyle(color: Color(0xFF60A5FA),
                          fontSize: 12, fontWeight: FontWeight.w700)),
                  Text(state.address,
                      style: const TextStyle(color: Color(0xFFE8E8FF),
                          fontSize: 14, fontFamily: 'monospace',
                          fontWeight: FontWeight.w600)),
                ],
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),
        _SecondaryBtn(
          label: 'Disconnect',
          icon:  Icons.link_off_rounded,
          color: const Color(0xFFF87171),
          onTap: () {
            context.read<CollaborationCubit>().disconnect();
            Navigator.pop(context);
          },
        ),
      ],
    );
  }
}

// ── Shared small widgets ───────────────────────────────────────────────────

class _PrimaryBtn extends StatelessWidget {
  const _PrimaryBtn({required this.label, required this.icon, this.onTap});
  final String        label;
  final IconData      icon;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final enabled = onTap != null;
    return GestureDetector(
      onTap: onTap,
      child: Container(
        height: 36,
        decoration: BoxDecoration(
          color:        enabled ? const Color(0xFF7C3AED) : const Color(0xFF2A2A40),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, size: 14, color: Colors.white),
            const SizedBox(width: 8),
            Text(label,
                style: const TextStyle(color: Colors.white,
                    fontSize: 13, fontWeight: FontWeight.w600)),
          ],
        ),
      ),
    );
  }
}

class _SecondaryBtn extends StatelessWidget {
  const _SecondaryBtn({
    required this.label,
    required this.icon,
    required this.color,
    required this.onTap,
  });
  final String       label;
  final IconData     icon;
  final Color        color;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        height: 34,
        decoration: BoxDecoration(
          border: Border.all(color: color.withAlpha(100)),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, size: 14, color: color),
            const SizedBox(width: 8),
            Text(label,
                style: TextStyle(
                    color: color, fontSize: 13, fontWeight: FontWeight.w600)),
          ],
        ),
      ),
    );
  }
}

class _DarkTextField extends StatelessWidget {
  const _DarkTextField({
    required this.controller,
    required this.hint,
    this.enabled = true,
  });
  final TextEditingController controller;
  final String hint;
  final bool   enabled;

  @override
  Widget build(BuildContext context) {
    return TextField(
      controller: controller,
      enabled:    enabled,
      style: const TextStyle(
          color: Color(0xFFE8E8FF), fontSize: 13, fontFamily: 'monospace'),
      decoration: InputDecoration(
        hintText:  hint,
        hintStyle: const TextStyle(color: Color(0xFF44446A), fontSize: 12),
        filled:    true,
        fillColor: const Color(0xFF0D0F14),
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: const BorderSide(color: Color(0xFF2A3040)),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: const BorderSide(color: Color(0xFF2A3040)),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: const BorderSide(color: Color(0xFF7C3AED)),
        ),
      ),
    );
  }
}

// ── Toolbar icon button ────────────────────────────────────────────────────

class _CollabToolBtn extends StatefulWidget {
  const _CollabToolBtn({
    required this.icon,
    required this.tooltip,
    required this.color,
    required this.onTap,
    this.badge,
  });
  final IconData      icon;
  final String        tooltip;
  final Color         color;
  final String?       badge;
  final VoidCallback? onTap;

  @override
  State<_CollabToolBtn> createState() => _CollabToolBtnState();
}

class _CollabToolBtnState extends State<_CollabToolBtn> {
  bool _hovered = false;

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: widget.tooltip,
      child: MouseRegion(
        cursor: SystemMouseCursors.click,
        onEnter: (_) => setState(() => _hovered = true),
        onExit:  (_) => setState(() => _hovered = false),
        child: GestureDetector(
          onTap: widget.onTap,
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 120),
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
            decoration: BoxDecoration(
              color:  _hovered ? const Color(0xFF1E2340) : const Color(0xFF1A1E2A),
              border: Border.all(
                  color: _hovered
                      ? widget.color.withAlpha(160)
                      : const Color(0xFF2A3040)),
              borderRadius: BorderRadius.circular(6),
            ),
            child: Stack(
              clipBehavior: Clip.none,
              children: [
                Icon(widget.icon, size: 14, color: widget.color),
                if (widget.badge != null)
                  Positioned(
                    top: -6, right: -8,
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 3, vertical: 1),
                      decoration: BoxDecoration(
                        color:        const Color(0xFF34D399),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Text(widget.badge!,
                          style: const TextStyle(
                              color:      Colors.black,
                              fontSize:   8,
                              fontWeight: FontWeight.w700)),
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
