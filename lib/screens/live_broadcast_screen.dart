import 'dart:async';
import 'package:flutter/material.dart';
import 'package:agora_rtc_engine/agora_rtc_engine.dart';
import 'package:permission_handler/permission_handler.dart';
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

  @override
  void initState() {
    super.initState();
    initAgora();
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
          onJoinChannelSuccess: (RtcConnection connection, int elapsed) {
            debugPrint("local user ${connection.localUid} joined");
            setState(() {
              _localUserJoined = true;
            });
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
