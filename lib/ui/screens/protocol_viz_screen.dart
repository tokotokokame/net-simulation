// lib/ui/screens/protocol_viz_screen.dart
import 'package:flutter/material.dart';

class ProtocolVizScreen extends StatefulWidget {
  const ProtocolVizScreen({super.key});
  @override
  State<ProtocolVizScreen> createState() => _ProtocolVizScreenState();
}

class _ProtocolVizScreenState extends State<ProtocolVizScreen>
    with TickerProviderStateMixin {
  String _selected = 'tcp';

  static const _protocols = [
    ('tcp',  'TCP 3ウェイ\nハンドシェイク', Color(0xFF00BCD4)),
    ('ospf', 'OSPF\n収束過程',              Color(0xFF8BC34A)),
    ('vlan', 'VLAN\n分離',                  Color(0xFF9C27B0)),
    ('dhcp', 'DHCP\nIPアドレス取得',        Color(0xFF2196F3)),
    ('arp',  'ARP\nMACアドレス解決',        Color(0xFFFF9800)),
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0D1B2A),
      appBar: AppBar(
        backgroundColor: const Color(0xFF0D1B2A),
        title: const Text('プロトコル可視化'),
      ),
      body: SafeArea(
        top: false,
        child: Column(
          children: [
            SizedBox(
              height: 72,
              child: ListView(
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.symmetric(
                    horizontal: 12, vertical: 8),
                children: _protocols.map((p) {
                  final selected = _selected == p.$1;
                  return GestureDetector(
                    onTap: () => setState(() => _selected = p.$1),
                    child: Container(
                      margin: const EdgeInsets.only(right: 8),
                      padding: const EdgeInsets.symmetric(
                          horizontal: 14, vertical: 8),
                      decoration: BoxDecoration(
                        color: selected
                            ? p.$3.withOpacity(0.2)
                            : const Color(0xFF1A2D3D),
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(
                            color: selected ? p.$3 : Colors.white12,
                            width: selected ? 1.5 : 0.5),
                      ),
                      child: Text(p.$2,
                          textAlign: TextAlign.center,
                          style: TextStyle(
                              color: selected ? p.$3 : Colors.white54,
                              fontSize: 11,
                              fontWeight: selected
                                  ? FontWeight.bold
                                  : FontWeight.normal,
                              height: 1.4)),
                    ),
                  );
                }).toList(),
              ),
            ),
            Expanded(
              child: switch (_selected) {
                'tcp'  => const _TcpHandshakeViz(),
                'ospf' => const _OspfConvergeViz(),
                'vlan' => const _VlanViz(),
                'dhcp' => const _DhcpViz(),
                'arp'  => const _ArpViz(),
                _      => const _TcpHandshakeViz(),
              },
            ),
          ],
        ),
      ),
    );
  }
}

// ── TCP 3ウェイハンドシェイク ─────────────────────────────────

class _TcpHandshakeViz extends StatefulWidget {
  const _TcpHandshakeViz();
  @override
  State<_TcpHandshakeViz> createState() => _TcpHandshakeVizState();
}

class _TcpHandshakeVizState extends State<_TcpHandshakeViz>
    with SingleTickerProviderStateMixin {
  late AnimationController _ctrl;
  int _step = 0;

  static const _steps = [
    ('開始', '「再生」を押してTCP接続確立の様子を確認してください'),
    ('① SYN',
        'クライアントがサーバーに接続要求（SYN）を送ります\nTCPヘッダ: SYN=1, Seq=0'),
    ('② SYN-ACK',
        'サーバーが受け入れを通知（SYN-ACK）を返します\nTCPヘッダ: SYN=1, ACK=1, Seq=0, Ack=1'),
    ('③ ACK',
        'クライアントが確認応答（ACK）を送ります\nTCPヘッダ: ACK=1, Seq=1, Ack=1'),
    ('接続確立',
        'この3ステップで接続が確立されました！\n以降はデータ転送フェーズに移行します。'),
  ];

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 600));
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  void _nextStep() {
    if (_step >= 4) {
      setState(() => _step = 0);
      return;
    }
    setState(() => _step++);
    _ctrl.forward(from: 0);
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Expanded(
          child: AnimatedBuilder(
            animation: _ctrl,
            builder: (_, __) => CustomPaint(
              painter: _TcpPainter(step: _step, animation: _ctrl),
              child: const SizedBox.expand(),
            ),
          ),
        ),
        Container(
          margin: const EdgeInsets.all(12),
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: const Color(0xFF0A1929),
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: Colors.white12),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(_steps[_step].$1,
                  style: const TextStyle(
                      color: Color(0xFF00BCD4),
                      fontSize: 14,
                      fontWeight: FontWeight.bold)),
              const SizedBox(height: 6),
              Text(_steps[_step].$2,
                  style: const TextStyle(
                      color: Colors.white70,
                      fontSize: 13,
                      height: 1.5)),
            ],
          ),
        ),
        Padding(
          padding: EdgeInsets.fromLTRB(
              16, 0, 16, MediaQuery.of(context).padding.bottom + 12),
          child: SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: _nextStep,
              style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF00BCD4)),
              child: Text(_step == 0
                  ? '▶ 再生'
                  : _step >= 4
                      ? '↺ リセット'
                      : '次のステップ →'),
            ),
          ),
        ),
      ],
    );
  }
}

class _TcpPainter extends CustomPainter {
  final int step;
  final Animation<double> animation;

  _TcpPainter({required this.step, required this.animation})
      : super(repaint: animation);

  @override
  void paint(Canvas canvas, Size size) {
    final clientX = size.width * 0.18;
    final serverX = size.width * 0.82;
    final cy      = size.height / 2;
    final topY    = size.height * 0.15;
    final bottomY = size.height * 0.85;

    _drawNode(canvas, Offset(clientX, cy), 'Client',
        const Color(0xFF2196F3));
    _drawNode(canvas, Offset(serverX, cy), 'Server',
        const Color(0xFF4CAF50));

    final linePaint = Paint()
      ..color = Colors.white24
      ..strokeWidth = 1;
    canvas.drawLine(
        Offset(clientX, topY), Offset(clientX, bottomY), linePaint);
    canvas.drawLine(
        Offset(serverX, topY), Offset(serverX, bottomY), linePaint);

    if (step >= 1) {
      _drawArrow(canvas, 'SYN', clientX, serverX,
          topY + size.height * 0.1, const Color(0xFF2196F3),
          animation.value);
    }
    if (step >= 2) {
      _drawArrow(canvas, 'SYN-ACK', serverX, clientX,
          topY + size.height * 0.3, const Color(0xFF4CAF50),
          step == 2 ? animation.value : 1.0);
    }
    if (step >= 3) {
      _drawArrow(canvas, 'ACK', clientX, serverX,
          topY + size.height * 0.5, const Color(0xFF00BCD4),
          step == 3 ? animation.value : 1.0);
    }
    if (step >= 4) {
      canvas.drawRect(
        Rect.fromLTRB(
            clientX - 30,
            topY + size.height * 0.6,
            serverX + 30,
            topY + size.height * 0.7),
        Paint()..color = const Color(0xFF4CAF50).withOpacity(0.3),
      );
      _drawText(canvas, 'DATA TRANSFER ↔',
          Offset(size.width / 2, topY + size.height * 0.65),
          const Color(0xFF4CAF50), 12);
    }
  }

  void _drawNode(
      Canvas canvas, Offset center, String label, Color color) {
    canvas.drawCircle(
        center, 28, Paint()..color = color.withOpacity(0.15));
    canvas.drawCircle(
        center,
        28,
        Paint()
          ..color = color
          ..style = PaintingStyle.stroke
          ..strokeWidth = 2);
    _drawText(canvas, label, center + const Offset(0, 42),
        Colors.white70, 11);
  }

  void _drawArrow(Canvas canvas, String label, double fromX,
      double toX, double y, Color color, double progress) {
    final endX = fromX + (toX - fromX) * progress;
    canvas.drawLine(Offset(fromX, y), Offset(endX, y),
        Paint()
          ..color = color
          ..strokeWidth = 2);
    if (progress >= 0.99) {
      final dir = toX > fromX ? 1 : -1;
      final path = Path()
        ..moveTo(endX, y)
        ..lineTo(endX - dir * 10, y - 5)
        ..lineTo(endX - dir * 10, y + 5)
        ..close();
      canvas.drawPath(path, Paint()..color = color);
    }
    _drawText(canvas, label,
        Offset((fromX + endX) / 2, y - 12), color, 11);
  }

  void _drawText(Canvas canvas, String text, Offset pos, Color color,
      double fontSize) {
    final tp = TextPainter(
      text: TextSpan(
          text: text,
          style: TextStyle(
              color: color,
              fontSize: fontSize,
              fontWeight: FontWeight.w500)),
      textDirection: TextDirection.ltr,
    )..layout();
    tp.paint(canvas, pos - Offset(tp.width / 2, tp.height / 2));
  }

  @override
  bool shouldRepaint(_TcpPainter old) => old.step != step;
}

// ── プレースホルダー共通 ──────────────────────────────────────

class _ProtocolPlaceholder extends StatefulWidget {
  final String       title;
  final List<String> steps;
  final Color        color;
  const _ProtocolPlaceholder({
    required this.title,
    required this.steps,
    required this.color,
  });
  @override
  State<_ProtocolPlaceholder> createState() =>
      _ProtocolPlaceholderState();
}

class _ProtocolPlaceholderState extends State<_ProtocolPlaceholder> {
  int _current = -1;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Expanded(
          child: ListView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: widget.steps.length,
            itemBuilder: (_, i) {
              final active = i == _current;
              final done   = i < _current;
              return AnimatedContainer(
                duration: const Duration(milliseconds: 300),
                margin: const EdgeInsets.only(bottom: 8),
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: active
                      ? widget.color.withOpacity(0.15)
                      : done
                          ? Colors.white.withOpacity(0.03)
                          : const Color(0xFF1A2D3D),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(
                      color: active ? widget.color : Colors.white12,
                      width: active ? 1.5 : 0.5),
                ),
                child: Row(
                  children: [
                    Container(
                      width: 24,
                      height: 24,
                      decoration: BoxDecoration(
                        color: done
                            ? widget.color
                            : active
                                ? widget.color.withOpacity(0.3)
                                : Colors.white12,
                        shape: BoxShape.circle,
                      ),
                      child: Center(
                        child: done
                            ? const Icon(Icons.check,
                                size: 14, color: Colors.white)
                            : Text('${i + 1}',
                                style: TextStyle(
                                    color: active
                                        ? widget.color
                                        : Colors.white38,
                                    fontSize: 11,
                                    fontWeight: FontWeight.bold)),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                        child: Text(widget.steps[i],
                            style: TextStyle(
                                color: active
                                    ? Colors.white
                                    : done
                                        ? Colors.white54
                                        : Colors.white38,
                                fontSize: 13,
                                height: 1.4))),
                  ],
                ),
              );
            },
          ),
        ),
        Padding(
          padding: EdgeInsets.fromLTRB(
              16, 0, 16, MediaQuery.of(context).padding.bottom + 12),
          child: SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              style: ElevatedButton.styleFrom(
                  backgroundColor: widget.color),
              onPressed: () => setState(() {
                if (_current >= widget.steps.length - 1) {
                  _current = -1;
                } else {
                  _current++;
                }
              }),
              child: Text(_current < 0
                  ? '▶ 開始'
                  : _current >= widget.steps.length - 1
                      ? '↺ リセット'
                      : '次のステップ →'),
            ),
          ),
        ),
      ],
    );
  }
}

// ── 各プロトコル ──────────────────────────────────────────────

class _OspfConvergeViz extends StatelessWidget {
  const _OspfConvergeViz();
  @override
  Widget build(BuildContext context) => _ProtocolPlaceholder(
        title: 'OSPF 収束過程',
        steps: const [
          'Step 1: HelloパケットでNeighbor発見',
          'Step 2: LSA（Link State Advertisement）交換',
          'Step 3: SPFアルゴリズムで最短経路計算',
          'Step 4: ルーティングテーブル更新完了',
        ],
        color: const Color(0xFF8BC34A),
      );
}

class _VlanViz extends StatelessWidget {
  const _VlanViz();
  @override
  Widget build(BuildContext context) => _ProtocolPlaceholder(
        title: 'VLAN 分離（IEEE 802.1Q）',
        steps: const [
          'Step 1: フレームにVLANタグ（4バイト）を付与',
          'Step 2: VLAN10のフレームはVLAN10ポートにのみ転送',
          'Step 3: VLAN20のフレームはVLAN20ポートにのみ転送',
          'Step 4: 異なるVLAN間の通信はルーターが必要',
        ],
        color: const Color(0xFF9C27B0),
      );
}

class _DhcpViz extends StatelessWidget {
  const _DhcpViz();
  @override
  Widget build(BuildContext context) => _ProtocolPlaceholder(
        title: 'DHCP IPアドレス取得（DORA）',
        steps: const [
          'D - Discover: クライアントがブロードキャスト送信',
          'O - Offer: DHCPサーバーがIPアドレスを提案',
          'R - Request: クライアントが提案を選択・要求',
          'A - Acknowledge: サーバーが正式にIPを割り当て',
        ],
        color: const Color(0xFF2196F3),
      );
}

class _ArpViz extends StatelessWidget {
  const _ArpViz();
  @override
  Widget build(BuildContext context) => _ProtocolPlaceholder(
        title: 'ARP MACアドレス解決',
        steps: const [
          'Step 1: ARP Requestをブロードキャスト送信',
          'Step 2: 該当IPを持つ機器がARP Replyを返す',
          'Step 3: MACアドレスをARPテーブルにキャッシュ',
          'Step 4: 以降はARPテーブルを参照して直接通信',
        ],
        color: const Color(0xFFFF9800),
      );
}
