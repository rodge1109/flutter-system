import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:agora_rtc_engine/agora_rtc_engine.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../services/api_service.dart';

const String appId = "b1f93855c6294b249f37356fff875a2d";

class LiveBroadcastScreen extends StatefulWidget {
  final String channelName;
  final bool isBroadcaster;

  const LiveBroadcastScreen({
    Key? key,
    required this.channelName,
    required this.isBroadcaster,
  }) : super(key: key);

  @override
  _LiveBroadcastScreenState createState() => _LiveBroadcastScreenState();
}

class _LiveBroadcastScreenState extends State<LiveBroadcastScreen> {
  final ApiService _apiService = ApiService();
  int? _remoteUid;
  bool _localUserJoined = false;
  late RtcEngine _engine;
  
  bool _muted = false;
  bool _videoDisabled = false;

  int _team1Score = 0;
  int _team2Score = 0;
  int _streamId = -1;
  
  String _team1Name = 'Team A';
  String _team2Name = 'Team B';

  @override
  void initState() {
    super.initState();
    _loadUserData();
    initAgora();
  }

  Future<void> _loadUserData() async {
    final prefs = await SharedPreferences.getInstance();
    final userStr = prefs.getString('user');
    if (userStr != null) {
      final userObj = jsonDecode(userStr);
      setState(() {
        _team1Name = userObj['full_name'] ?? 'Team A';
      });
    }
  }

  Future<void> initAgora() async {
    try {
      // Retrieve permissions (Only broadcasters need mic and camera!)
      if (widget.isBroadcaster) {
        await [Permission.microphone, Permission.camera].request();
      }

      // Create the engine
      _engine = createAgoraRtcEngine();
      await _engine.initialize(const RtcEngineContext(
        appId: appId,
        channelProfile: ChannelProfileType.channelProfileLiveBroadcasting,
      ));

      _engine.registerEventHandler(
        RtcEngineEventHandler(
          onJoinChannelSuccess: (RtcConnection connection, int elapsed) async {
            debugPrint("local user ${connection.localUid} joined");
            setState(() {
              _localUserJoined = true;
            });
            if (widget.isBroadcaster) {
              try {
                _streamId = await _engine.createDataStream(const DataStreamConfig(
                  syncWithAudio: false,
                  ordered: true,
                ));
              } catch(e) {
                debugPrint('Error creating data stream: $e');
              }
            }
          },
          onStreamMessage: (RtcConnection connection, int remoteUid, int streamId, Uint8List data, int length, int sentTs) {
            try {
              final message = utf8.decode(data);
              final map = jsonDecode(message);
              setState(() {
                _team1Score = map['team1'] ?? _team1Score;
                _team2Score = map['team2'] ?? _team2Score;
                _team1Name = map['team1Name'] ?? _team1Name;
                _team2Name = map['team2Name'] ?? _team2Name;
              });
            } catch (e) {
              debugPrint('Error decoding stream message: $e');
            }
          },
          onUserJoined: (RtcConnection connection, int remoteUid, int elapsed) {
            debugPrint("remote user $remoteUid joined");
            setState(() {
              _remoteUid = remoteUid;
            });
          },
          onUserOffline: (RtcConnection connection, int remoteUid, UserOfflineReasonType reason) {
            debugPrint("remote user $remoteUid left channel");
            setState(() {
              _remoteUid = null;
            });
          },
          onTokenPrivilegeWillExpire: (RtcConnection connection, String token) {
            debugPrint('[onTokenPrivilegeWillExpire] connection: ${connection.toJson()}, token: $token');
          },
          onError: (ErrorCodeType err, String msg) {
            debugPrint('[onError] err: $err, msg: $msg');
            if (mounted) {
              ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Agora Error: ${err.name} - $msg'), backgroundColor: Colors.red));
            }
          },
          onConnectionStateChanged: (RtcConnection connection, ConnectionStateType state, ConnectionChangedReasonType reason) {
            debugPrint('[onConnectionStateChanged] state: $state, reason: $reason');
            if (state == ConnectionStateType.connectionStateFailed && mounted) {
              ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Connection failed: ${reason.name}'), backgroundColor: Colors.red));
            }
          },
        ),
      );

      // Set client role and enable video
      if (widget.isBroadcaster) {
        await _engine.setClientRole(role: ClientRoleType.clientRoleBroadcaster);
        await _engine.enableVideo();
        await _engine.startPreview();
      } else {
        await _engine.setClientRole(role: ClientRoleType.clientRoleAudience);
        await _engine.enableVideo(); // still need to enable video module to receive
      }

      // Fetch fresh token from backend
      String generatedToken = "";
      final freshToken = await _apiService.getAgoraToken(widget.channelName);
      if (freshToken != null) {
        generatedToken = freshToken;
      }

      // Join channel with strict options
      await _engine.joinChannel(
        token: generatedToken,
        channelId: widget.channelName,
        uid: 0, // 0 allows Agora to auto-assign a UID
        options: ChannelMediaOptions(
          clientRoleType: widget.isBroadcaster ? ClientRoleType.clientRoleBroadcaster : ClientRoleType.clientRoleAudience,
          channelProfile: ChannelProfileType.channelProfileLiveBroadcasting,
        ),
      );
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Exception in initAgora: $e'), backgroundColor: Colors.red));
      }
    }
  }

  void _onToggleMute() {
    setState(() {
      _muted = !_muted;
    });
    _engine.muteLocalAudioStream(_muted);
  }

  void _onToggleVideo() {
    setState(() {
      _videoDisabled = !_videoDisabled;
    });
    _engine.muteLocalVideoStream(_videoDisabled);
  }

  void _onSwitchCamera() {
    _engine.switchCamera();
  }

  void _broadcastState() async {
    if (!widget.isBroadcaster || _streamId == -1) return;
    try {
      final message = jsonEncode({
        'team1': _team1Score, 
        'team2': _team2Score,
        'team1Name': _team1Name,
        'team2Name': _team2Name,
      });
      await _engine.sendStreamMessage(
        streamId: _streamId, 
        data: Uint8List.fromList(utf8.encode(message)), 
        length: message.length
      );
    } catch(e) {
      debugPrint('Error sending state update: $e');
    }
  }

  void _updateScore(int team, int change) {
    setState(() {
      if (team == 1) _team1Score += change;
      if (team == 2) _team2Score += change;
    });
    _broadcastState();
  }

  Future<void> _editTeamNameDialog(int teamIndex, String currentName) async {
    TextEditingController controller = TextEditingController(text: currentName);
    String? newName = await showDialog<String>(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: Text('Edit Name'),
          content: TextField(
            controller: controller,
            decoration: InputDecoration(hintText: 'Enter new name'),
            autofocus: true,
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: Text('Cancel'),
            ),
            TextButton(
              onPressed: () => Navigator.pop(context, controller.text.trim()),
              child: Text('Save'),
            ),
          ],
        );
      }
    );
    if (newName != null && newName.isNotEmpty) {
      setState(() {
        if (teamIndex == 1) _team1Name = newName;
        if (teamIndex == 2) _team2Name = newName;
      });
      _broadcastState();
    }
  }

  @override
  void dispose() {
    _engine.leaveChannel();
    _engine.release();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        title: Text(widget.isBroadcaster ? 'Broadcasting: ${widget.channelName}' : 'Watching: ${widget.channelName}', style: TextStyle(color: Colors.white)),
        backgroundColor: Colors.black87,
        iconTheme: IconThemeData(color: Colors.white),
        actions: [
          if (widget.isBroadcaster)
            IconButton(
              icon: Icon(Icons.switch_camera, color: Colors.white),
              onPressed: _onSwitchCamera,
            ),
        ],
      ),
      body: Stack(
        children: [
          Center(
            child: _renderVideo(),
          ),
          _buildScoreOverlay(),
          if (widget.isBroadcaster) _toolbar(),
        ],
      ),
    );
  }

  // Generate local or remote video
  Widget _renderVideo() {
    if (widget.isBroadcaster) {
      if (_localUserJoined) {
        return _videoDisabled 
            ? const Center(child: Text("Camera Disabled", style: TextStyle(color: Colors.white)))
            : AgoraVideoView(
                controller: VideoViewController(
                  rtcEngine: _engine,
                  canvas: const VideoCanvas(uid: 0),
                ),
              );
      } else {
        return const CircularProgressIndicator(color: Colors.white);
      }
    } else {
      // Audience View
      if (_remoteUid != null) {
        return AgoraVideoView(
          controller: VideoViewController.remote(
            rtcEngine: _engine,
            canvas: VideoCanvas(uid: _remoteUid),
            connection: RtcConnection(channelId: widget.channelName),
          ),
        );
      } else {
        return const Text(
          'Waiting for the host to start the broadcast...',
          style: TextStyle(color: Colors.white),
          textAlign: TextAlign.center,
        );
      }
    }
  }

  Widget _buildScoreOverlay() {
    return Positioned(
      top: 16,
      left: 16,
      right: 16,
      child: SafeArea(
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 20),
          decoration: BoxDecoration(
            color: Colors.black54,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: Colors.white24),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              _buildTeamScore(1, _team1Name, _team1Score),
              const Text('VS', style: TextStyle(color: Colors.white70, fontWeight: FontWeight.bold, fontSize: 16)),
              _buildTeamScore(2, _team2Name, _team2Score),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildTeamScore(int teamIndex, String name, int score) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(name, style: const TextStyle(color: Colors.white, fontSize: 14, fontWeight: FontWeight.w600)),
            if (widget.isBroadcaster)
              GestureDetector(
                onTap: () => _editTeamNameDialog(teamIndex, name),
                child: Padding(
                  padding: const EdgeInsets.only(left: 4),
                  child: Icon(Icons.edit, color: Colors.white70, size: 14),
                ),
              ),
          ],
        ),
        const SizedBox(height: 4),
        Row(
          children: [
            if (widget.isBroadcaster) 
              IconButton(
                icon: const Icon(Icons.remove_circle_outline, color: Colors.white70, size: 20), 
                onPressed: () => _updateScore(teamIndex, -1),
                constraints: const BoxConstraints(),
                padding: const EdgeInsets.all(4),
              ),
            Text('$score', style: const TextStyle(color: Colors.white, fontSize: 24, fontWeight: FontWeight.bold)),
            if (widget.isBroadcaster) 
              IconButton(
                icon: const Icon(Icons.add_circle_outline, color: Colors.white70, size: 20), 
                onPressed: () => _updateScore(teamIndex, 1),
                constraints: const BoxConstraints(),
                padding: const EdgeInsets.all(4),
              ),
          ],
        ),
      ],
    );
  }

  // Toolbar layout
  Widget _toolbar() {
    return Container(
      alignment: Alignment.bottomCenter,
      padding: const EdgeInsets.symmetric(vertical: 48),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: <Widget>[
          RawMaterialButton(
            onPressed: _onToggleMute,
            child: Icon(
              _muted ? Icons.mic_off : Icons.mic,
              color: _muted ? Colors.white : Colors.blueAccent,
              size: 20.0,
            ),
            shape: const CircleBorder(),
            elevation: 2.0,
            fillColor: _muted ? Colors.blueAccent : Colors.white,
            padding: const EdgeInsets.all(12.0),
          ),
          RawMaterialButton(
            onPressed: () => Navigator.pop(context),
            child: const Icon(
              Icons.call_end,
              color: Colors.white,
              size: 35.0,
            ),
            shape: const CircleBorder(),
            elevation: 2.0,
            fillColor: Colors.redAccent,
            padding: const EdgeInsets.all(15.0),
          ),
          RawMaterialButton(
            onPressed: _onToggleVideo,
            child: Icon(
              _videoDisabled ? Icons.videocam_off : Icons.videocam,
              color: _videoDisabled ? Colors.white : Colors.blueAccent,
              size: 20.0,
            ),
            shape: const CircleBorder(),
            elevation: 2.0,
            fillColor: _videoDisabled ? Colors.blueAccent : Colors.white,
            padding: const EdgeInsets.all(12.0),
          )
        ],
      ),
    );
  }
}
