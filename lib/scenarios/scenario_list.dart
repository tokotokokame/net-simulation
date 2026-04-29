// lib/scenarios/scenario_list.dart
import 'package:flutter/material.dart';
import 'scenario_data.dart';

final List<ScenarioData> kScenarios = [

  ScenarioData(
    id: 's1_basic_lan',
    title: '基本的なLAN構成を作る',
    description: 'スイッチとPCを接続してローカルネットワークを構築する基本を学ぶ',
    difficulty: '初級',
    category: 'ルーティング',
    icon: Icons.device_hub,
    color: const Color(0xFF4CAF50),
    steps: [
      ScenarioStep(
        title: 'LANとは何か',
        instruction: '画面を確認してください',
        explanation:
          'LAN（Local Area Network）は、建物や部屋の中にある'
          'コンピュータを繋いだネットワークです。\n\n'
          'スイッチがハブの役割を果たし、接続された機器が'
          'お互いに通信できるようになります。',
      ),
      ScenarioStep(
        title: 'スイッチとPCを接続する',
        instruction:
          'パレットから「Switch」を1台、「PC」を3台配置して\n'
          'すべてのPCをSwitchに接続してください。',
        explanation:
          'スイッチはMACアドレステーブルを使って、\n'
          'どのポートにどの機器が繋がっているかを学習します。\n'
          'これによりブロードキャストを最小限に抑えられます。',
        type: ScenarioStepType.observe,
      ),
      ScenarioStep(
        title: 'pingで疎通確認',
        instruction:
          'PC-1をダブルタップ → CLIタブ を開き\n'
          '「ping PC-2」と入力してEnterを押してください。',
        explanation:
          'pingはICMP（Internet Control Message Protocol）を使います。\n'
          '応答があれば疎通OK。\n'
          'Request timeoutは相手に届いていないか、\n'
          '応答が返ってこないことを意味します。',
        cliHint: 'ping PC-2',
        type: ScenarioStepType.cli,
      ),
    ],
  ),

  ScenarioData(
    id: 's2_routing',
    title: 'ルーターで2つのネットワークを繋ぐ',
    description: '異なるサブネット間の通信にルーターが必要な理由を学ぶ',
    difficulty: '初級',
    category: 'ルーティング',
    icon: Icons.route,
    color: const Color(0xFF2196F3),
    relatedProtocol: 'ospf',
    steps: [
      ScenarioStep(
        title: 'なぜルーターが必要か',
        instruction: '画面を確認してください',
        explanation:
          'スイッチはLAN内の通信を処理しますが、\n'
          '異なるネットワーク（例: 192.168.1.0/24 と 192.168.2.0/24）を\n'
          '繋ぐにはルーターが必要です。\n\n'
          'ルーターはIPアドレスを見てパケットを転送する方向を決めます。\n'
          'これを「ルーティング」といいます。',
      ),
      ScenarioStep(
        title: 'ルーティングテーブルを確認する',
        instruction:
          'RouterをダブルタップしてCLIタブを開き\n'
          '「show ip route」と入力してください。',
        explanation:
          'ルーティングテーブルはルーターの地図です。\n'
          '「C」は直接接続（Connected）を意味します。\n'
          '「S」はスタティックルート、「O」はOSPFで学習したルートです。',
        cliHint: 'show ip route',
        type: ScenarioStepType.cli,
      ),
      ScenarioStep(
        title: '再生してパケットを観察する',
        instruction:
          '再生ボタンを押してシミュレーションを開始し、\n'
          'パケットがルーターを経由して転送される様子を確認してください。',
        explanation:
          'パケットはホップバイホップで転送されます。\n'
          '各ルーターは宛先IPを見てルーティングテーブルを参照し、\n'
          '次の転送先を決定します。',
        type: ScenarioStepType.observe,
      ),
    ],
  ),

  ScenarioData(
    id: 's3_failover',
    title: 'リンク障害と迂回経路',
    description: '冗長構成でリンクが落ちても通信が継続する様子を体験する',
    difficulty: '中級',
    category: 'ルーティング',
    icon: Icons.alt_route,
    color: const Color(0xFFFF9800),
    steps: [
      ScenarioStep(
        title: '冗長構成とは',
        instruction: '画面を確認してください',
        explanation:
          '冗長構成とは、1つのリンクが壊れても別の経路で\n'
          '通信を継続できる設計です。\n\n'
          'インターネットはこの考え方で設計されており、\n'
          '一部が壊れても全体は動き続けます。',
      ),
      ScenarioStep(
        title: 'リンクを意図的に落とす',
        instruction:
          'シミュレーション開始後、\n'
          'リンクを長押し → 「リンク断（Link Down）」を選択してください。\n'
          'パケットが自動的に別経路を通るか確認してください。',
        explanation:
          'OSPFやBGPなどのルーティングプロトコルは\n'
          'リンクの状態変化を検知して自動的に経路を再計算します。\n'
          'これをコンバージェンス（収束）といいます。',
        type: ScenarioStepType.observe,
      ),
      ScenarioStep(
        title: 'Syslogで障害ログを確認する',
        instruction:
          'AppBarの盾アイコン → Syslogを開き\n'
          '「LINK DOWN」のログを確認してください。',
        explanation:
          '実際の運用では障害発生時に自動でアラートが飛びます。\n'
          'Syslogはその記録であり、障害原因の分析（RCA）に使われます。',
        type: ScenarioStepType.observe,
      ),
    ],
  ),

  ScenarioData(
    id: 's4_vlan',
    title: 'VLANで部署ネットワークを分離する',
    description: '1台のスイッチで複数の仮想ネットワークを作るVLANを学ぶ',
    difficulty: '中級',
    category: 'セキュリティ',
    icon: Icons.segment,
    color: const Color(0xFF9C27B0),
    relatedProtocol: 'vlan',
    steps: [
      ScenarioStep(
        title: 'VLANとは',
        instruction: '画面を確認してください',
        explanation:
          'VLAN（Virtual LAN）は1台の物理スイッチを\n'
          '複数の仮想スイッチに分ける技術です。\n\n'
          '例えば総務部と開発部を同じスイッチに繋ぎながら、\n'
          '互いの通信を遮断できます。\n'
          '規格はIEEE 802.1Qで定められています。',
      ),
      ScenarioStep(
        title: 'VLANの分離をプロトコル可視化で確認する',
        instruction:
          '「プロトコル可視化」→「VLAN分離」を選択して\n'
          'アニメーションを確認してください。',
        explanation:
          'VLAN10のフレームはVLAN20のポートには届きません。\n'
          'タグ（4バイトのヘッダ）でVLAN IDを識別しています。\n'
          '異なるVLAN間の通信にはルーターが必要です（Router-on-a-Stick）。',
        type: ScenarioStepType.observe,
      ),
    ],
  ),

  ScenarioData(
    id: 's5_firewall',
    title: 'ファイアウォールで通信を制御する',
    description: 'ACLルールでパケットを許可・拒否する仕組みを学ぶ',
    difficulty: '中級',
    category: 'セキュリティ',
    icon: Icons.security,
    color: const Color(0xFFF44336),
    steps: [
      ScenarioStep(
        title: 'ファイアウォールとACL',
        instruction: '画面を確認してください',
        explanation:
          'ファイアウォールはACL（Access Control List）という\n'
          'ルールリストでパケットを評価します。\n\n'
          'ルールは上から順に評価され、\n'
          '最初にマッチしたルールが適用されます（First Match）。\n'
          '末尾には暗黙の「すべて拒否」があります。',
      ),
      ScenarioStep(
        title: 'リンク断でFWの効果を確認する',
        instruction:
          'セキュリティ構成のデモを読み込み、\n'
          'シミュレーションを開始してください。\n'
          'FWを経由するパケットと遮断されるパケットを確認してください。',
        explanation:
          '赤い破線はFWに遮断されたリンクを表します。\n'
          'FWは送信元IP・宛先IP・ポート番号・プロトコルを見て\n'
          'パケットを許可するか決定します。',
        type: ScenarioStepType.observe,
      ),
    ],
  ),

  ScenarioData(
    id: 's6_tcp',
    title: 'TCPの3ウェイハンドシェイク',
    description: 'TCP接続確立の仕組みをアニメーションで理解する',
    difficulty: '初級',
    category: 'プロトコル',
    icon: Icons.swap_horiz,
    color: const Color(0xFF00BCD4),
    relatedProtocol: 'tcp',
    steps: [
      ScenarioStep(
        title: 'TCPとは',
        instruction: '画面を確認してください',
        explanation:
          'TCP（Transmission Control Protocol）は\n'
          '信頼性のある通信を提供するプロトコルです。\n\n'
          'データが届いたかどうかを確認し、\n'
          '届かなければ再送します。\n'
          'HTTPやSSHなど重要なデータの転送に使われます。',
      ),
      ScenarioStep(
        title: '3ウェイハンドシェイクを観察する',
        instruction:
          '「プロトコル可視化」→「TCP 3ウェイハンドシェイク」を\n'
          '選択してアニメーションを確認してください。',
        explanation:
          '① SYN: クライアントが接続要求を送る\n'
          '② SYN-ACK: サーバーが受け入れを通知\n'
          '③ ACK: クライアントが確認応答\n\n'
          'この3ステップで接続が確立されてからデータ転送が始まります。',
        type: ScenarioStepType.observe,
      ),
    ],
  ),

  ScenarioData(
    id: 's7_ospf',
    title: 'OSPFの経路収束を観察する',
    description: 'ルーター間でルート情報が広まる様子をアニメーションで学ぶ',
    difficulty: '上級',
    category: 'プロトコル',
    icon: Icons.account_tree,
    color: const Color(0xFF8BC34A),
    relatedProtocol: 'ospf',
    steps: [
      ScenarioStep(
        title: 'OSPFとは',
        instruction: '画面を確認してください',
        explanation:
          'OSPF（Open Shortest Path First）は\n'
          'リンクステート型のルーティングプロトコルです。\n\n'
          '各ルーターがネットワーク全体のトポロジを把握して\n'
          'Dijkstraアルゴリズムで最短経路を計算します。\n'
          'AdminDistanceは110です。',
      ),
      ScenarioStep(
        title: 'Hello パケットの交換',
        instruction:
          '「プロトコル可視化」→「OSPF収束」を選択し\n'
          'アニメーションを確認してください。',
        explanation:
          'OSPFルーターはまずHelloパケットを送り合い\n'
          'ネイバー関係を確立します（ネイバーシップ）。\n'
          'その後LSA（Link State Advertisement）を交換して\n'
          '全体のトポロジを把握します。',
        type: ScenarioStepType.observe,
      ),
    ],
  ),
];
