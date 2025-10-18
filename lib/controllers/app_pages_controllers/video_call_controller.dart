import 'dart:async';
import 'dart:developer';
import 'package:agora_rtc_engine/agora_rtc_engine.dart';
import 'package:audioplayers/audioplayers.dart' as audio_players;
import 'package:audioplayers/audioplayers.dart';
import 'package:chatzy/models/call_model.dart';
import 'package:wakelock_plus/wakelock_plus.dart';
import '../../config.dart';
import '../common_controllers/notification_controller.dart';

class VideoCallController extends GetxController {
  String? channelName;
  Call? call;
  bool localUserJoined = false, isFullScreen = false;
  bool isSpeaker = true, switchCamera = false, isCameraShow = true;
  late RtcEngine engine;
  Stream<int>? timerStream;
  int? remoteUId;
  List users = <int>[];
  final infoStrings = <String>[];

  // ignore: cancel_subscriptions
  StreamSubscription<int>? timerSubscription;
  bool muted = false;
  bool isAlreadyEndedCall = false;
  String nameList = "";
  ClientRoleType? role;
  dynamic userData;
  Stream<DocumentSnapshot>? stream;
  audio_players.AudioPlayer? player;
  AudioCache audioCache = AudioCache();
  int? remoteUidValue;
  String? token;
  bool isStart = false;

  // ignore: close_sinks
  StreamController<int>? streamController;
  String hoursStr = '00';
  String minutesStr = '00';
  String secondsStr = '00';
  int counter = 0;
  Timer? timer;

  void stopTimer() {
    if (!isStart) return;

    timer?.cancel();
    counter = 0;
    isStart = false;
    update();
  }

  String getFormattedTime() {
    int hours = counter ~/ 3600;
    int minutes = (counter % 3600) ~/ 60;
    int seconds = counter % 60;
    return '${hours.toString().padLeft(2, '0')}:${minutes.toString().padLeft(2, '0')}:${seconds.toString().padLeft(2, '0')}';
  }

  @override
  void onReady() {
    // TODO: implement onReady
    super.onReady();
  }

  //start time count
  startTimerNow() {
    log("isStart :$isStart");
    if (isStart) return;

    timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      counter++;
      log("START :$counter");
      update();
    });

    isStart = true;
    update();
    Get.forceAppUpdate();
  }

  Future<bool> onWillPopNEw() {
    return Future.value(false);
  }

  //initialise agora
  Future<void> initAgora() async {
    var agoraData = appCtrl.storage.read(session.agoraToken);
    log("token :: ${call!.agoraToken}");
    log("token :: ${call!.channelId}");
    //create the engine
    engine = createAgoraRtcEngine();
    await engine.initialize(RtcEngineContext(
      appId: agoraData["agoraAppId"],
      channelProfile: ChannelProfileType.channelProfileLiveBroadcasting,
    ));
    update();
    engine.registerEventHandler(
      RtcEngineEventHandler(
        onJoinChannelSuccess: (RtcConnection connection, int elapsed) {
          debugPrint("local user ;;;${connection.localUid} joined");
          localUserJoined = true;
          update();
          final noti = Get.find<CustomNotificationController>();

          final info =
              'onJoinChannel: ${noti.callChannel}, uid: ${connection.localUid}';
          infoStrings.add(info);
          log("info :info");
          if (call!.receiver != null) {
            List receiver = call!.receiver!;
            receiver.asMap().entries.forEach((element) {
              if (nameList != "") {
                if (element.value["name"] != element.value["name"]) {
                  nameList = "$nameList, ${element.value["name"]}";
                }
              } else {
                if (element.value["name"] != userData["name"]) {
                  nameList = element.value["name"];
                }
              }
            });
          }
          if (call!.callerId == userData["id"]) {
            update();
            FirebaseFirestore.instance
                .collection(collectionName.calls)
                .doc(call!.callerId)
                .collection(collectionName.collectionCallHistory)
                .doc(call!.timestamp.toString())
                .set({
              'type': 'outGoing',
              'isVideoCall': call!.isVideoCall,
              'id': call!.receiverId,
              'timestamp': call!.timestamp,
              'dp': call!.receiverPic,
              'isMuted': false,
              'receiverId': call!.receiverId,
              'isJoin': false,
              'status': 'calling',
              'started': null,
              'ended': null,
              'callerName':
              call!.receiver != null ? nameList : call!.callerName,
            }, SetOptions(merge: true));
            if (call!.receiver != null) {
              List receiver = call!.receiver!;
              receiver.asMap().entries.forEach((element) {
                if (element.value["id"] != userData["id"]) {
                  FirebaseFirestore.instance
                      .collection(collectionName.calls)
                      .doc(element.value["id"])
                      .collection(collectionName.collectionCallHistory)
                      .doc(call!.timestamp.toString())
                      .set({
                    'type': 'inComing',
                    'isVideoCall': call!.isVideoCall,
                    'id': call!.callerId,
                    'timestamp': call!.timestamp,
                    'dp': call!.callerPic,
                    'isMuted': false,
                    'receiverId': element.value["id"],
                    'isJoin': true,
                    'status': 'missedCall',
                    'started': null,
                    'ended': null,
                    'callerName':
                    call!.receiver != null ? nameList : call!.callerName,
                  }, SetOptions(merge: true));
                }
              });
              log("nameList : $nameList");
              update();
            } else {
              FirebaseFirestore.instance
                  .collection(collectionName.calls)
                  .doc(call!.receiverId)
                  .collection(collectionName.collectionCallHistory)
                  .doc(call!.timestamp.toString())
                  .set({
                'type': 'inComing',
                'isVideoCall': call!.isVideoCall,
                'id': call!.callerId,
                'timestamp': call!.timestamp,
                'dp': call!.callerPic,
                'isMuted': false,
                'receiverId': call!.receiverId,
                'isJoin': true,
                'status': 'missedCall',
                'started': null,
                'ended': null,
                'callerName':
                call!.receiver != null ? nameList : call!.callerName,
              }, SetOptions(merge: true));
            }
          }
          WakelockPlus.enable();
          //flutterLocalNotificationsPlugin!.cancelAll();
          update();
          Get.forceAppUpdate();
        },
        onUserJoined:
            (RtcConnection connection, int remoteUserId, int elapsed) {
          debugPrint("remote user $remoteUserId joined");
          remoteUId = remoteUserId;
          startTimerNow();
          update();

          final info = 'userJoined: $remoteUserId';
          infoStrings.add(info);
          if (users.isEmpty) {
            users = [remoteUserId];
          } else {
            users.add(remoteUserId);
          }
          update();
          debugPrint("remote user $remoteUserId joined");

          if (userData["id"] == call!.callerId) {
            FirebaseFirestore.instance
                .collection(collectionName.calls)
                .doc(call!.callerId)
                .collection(collectionName.collectionCallHistory)
                .doc(call!.timestamp.toString())
                .set({
              'started': DateTime.now(),
              'status': 'pickedUp',
              'isJoin': true,
            }, SetOptions(merge: true));

            FirebaseFirestore.instance
                .collection("calls")
                .doc(call!.callerId)
                .set({
              "videoCallMade": FieldValue.increment(1),
            }, SetOptions(merge: true));

            if (call!.receiver != null) {
              List receiver = call!.receiver!;
              receiver.asMap().entries.forEach((element) {
                if (element.value["id"] != userData["id"]) {
                  FirebaseFirestore.instance
                      .collection(collectionName.calls)
                      .doc(element.value["id"])
                      .collection(collectionName.collectionCallHistory)
                      .doc(call!.timestamp.toString())
                      .set({
                    'started': DateTime.now(),
                    'status': 'pickedUp',
                  }, SetOptions(merge: true));
                  FirebaseFirestore.instance
                      .collection("calls")
                      .doc(element.value["id"])
                      .set({
                    "videoCallReceived": FieldValue.increment(1),
                  }, SetOptions(merge: true));
                }
              });
            } else {
              FirebaseFirestore.instance
                  .collection(collectionName.calls)
                  .doc(call!.receiverId)
                  .collection(collectionName.collectionCallHistory)
                  .doc(call!.timestamp.toString())
                  .set({
                'started': DateTime.now(),
                'status': 'pickedUp',
              }, SetOptions(merge: true));
              FirebaseFirestore.instance
                  .collection(collectionName.calls)
                  .doc(call!.receiverId)
                  .set({
                "videoCallReceived": FieldValue.increment(1),
              }, SetOptions(merge: true));
            }
          }
          WakelockPlus.enable();
          update();
          Get.forceAppUpdate();
        },
        onUserOffline: (RtcConnection connection, int remoteUid,
            UserOfflineReasonType reason) {
          debugPrint("remote user $remoteUid left channel");
          remoteUid = 0;
          users.remove(remoteUid);
          update();
          if (isAlreadyEndedCall == false) {
            FirebaseFirestore.instance
                .collection(collectionName.calls)
                .doc(call!.callerId)
                .collection(collectionName.collectionCallHistory)
                .doc(call!.timestamp.toString())
                .set({
              'status': 'ended',
              'ended': DateTime.now(),
            }, SetOptions(merge: true));
            if (call!.receiver != null) {
              List receiver = call!.receiver!;
              receiver.asMap().entries.forEach((element) {
                if (element.value["id"] != userData["id"]) {
                  FirebaseFirestore.instance
                      .collection(collectionName.calls)
                      .doc(element.value["id"])
                      .collection(collectionName.collectionCallHistory)
                      .doc(call!.timestamp.toString())
                      .set({
                    'status': 'ended',
                    'ended': DateTime.now(),
                  }, SetOptions(merge: true));
                }
              });
            } else {
              FirebaseFirestore.instance
                  .collection(collectionName.calls)
                  .doc(call!.receiverId)
                  .collection(collectionName.collectionCallHistory)
                  .doc(call!.timestamp.toString())
                  .set({
                'status': 'ended',
                'ended': DateTime.now(),
              }, SetOptions(merge: true));
            }
          }
        },
        onTokenPrivilegeWillExpire: (RtcConnection connection, String token) {
          debugPrint(
              '[onTokenPrivilegeWillExpire] connection: ${connection.toJson()}, token: $token');
        },
        onError: (err, msg) {
          debugPrint(
              '[onTokenPrivilegeWillExpire] connection: $err, token: $msg)');
        },
        onFirstRemoteAudioFrame: (connection, userId, elapsed) {
          final info = 'firstRemoteVideo: $userId';
          infoStrings.add(info);
          update();
        },
        onLeaveChannel: (connection, stats) {
          remoteUId = null;
          infoStrings.add('onLeaveChannel');
          stopTimer();
          users.clear();

          _dispose();
          update();
          if (isAlreadyEndedCall == false) {
            FirebaseFirestore.instance
                .collection(collectionName.calls)
                .doc(call!.callerId)
                .collection(collectionName.collectionCallHistory)
                .add({});
            FirebaseFirestore.instance
                .collection(collectionName.calls)
                .doc(call!.callerId)
                .collection(collectionName.collectionCallHistory)
                .doc(call!.timestamp.toString())
                .set({
              'status': 'ended',
              'ended': DateTime.now(),
            }, SetOptions(merge: true));
            if (call!.receiver != null) {
              List receiver = call!.receiver!;
              receiver.asMap().entries.forEach((element) {
                if (element.value['id'] != userData["id"]) {
                  FirebaseFirestore.instance
                      .collection(collectionName.calls)
                      .doc(element.value['id'])
                      .collection(collectionName.collectionCallHistory)
                      .doc(call!.timestamp.toString())
                      .set({
                    'status': 'ended',
                    'ended': DateTime.now(),
                  }, SetOptions(merge: true));
                }
              });
            } else {
              FirebaseFirestore.instance
                  .collection(collectionName.calls)
                  .doc(call!.receiverId)
                  .collection(collectionName.collectionCallHistory)
                  .doc(call!.timestamp.toString())
                  .set({
                'status': 'ended',
                'ended': DateTime.now(),
              }, SetOptions(merge: true));
            }
          }
          stopTimer();
          WakelockPlus.disable();
          Get.back();
          update();
        },
      ),
    );
    update();
    await engine.enableWebSdkInteroperability(true);
    await engine.setClientRole(role: ClientRoleType.clientRoleBroadcaster);

    await engine.enableVideo();
    await engine.startPreview();

    await engine.joinChannel(
      token: call!.agoraToken!,
      channelId: channelName!,
      uid: 0,
      options: const ChannelMediaOptions(),
    );
    update();

    update();
    Get.forceAppUpdate();
  }

  //on speaker off on
  void onToggleSpeaker() {
    isSpeaker = !isSpeaker;
    update();
    engine.setEnableSpeakerphone(isSpeaker);
  }

  //mute - unMute toggle
  void onToggleMute() {
    muted = !muted;
    update();
    engine.muteLocalAudioStream(muted);
    FirebaseFirestore.instance
        .collection(collectionName.calls)
        .doc(userData["id"])
        .collection(collectionName.collectionCallHistory)
        .doc(call!.timestamp.toString())
        .set({'isMuted': muted}, SetOptions(merge: true));
  }

  @override
  void dispose() {
    super.dispose();
    _dispose();
  }

  Future<void> _dispose() async {
    await engine.leaveChannel();
    await engine.release();
    stopTimer();
  }

  //bottom toolbar
  Widget toolbar(
      bool isShowSpeaker,
      String? status,
      ) {
    if (role == ClientRoleType.clientRoleAudience) return Container();

    return Container();
  }

  // //switch camera
  // Future<void> onSwitchCamera() async {
  //   engine.switchCamera();
  //
  //   update();
  // }

  bool _isFrontCamera = true;

  Future<void> onSwitchCamera() async {
    try {
      log("_isFrontCamera::${_isFrontCamera}");
      await engine.switchCamera();
      _isFrontCamera = !_isFrontCamera; // Toggle
      update();
    } catch (e) {
      print("Switch camera failed: $e");
    }
  }

  Future<bool> endCall({required Call call}) async {
    try {
      final firestore = FirebaseFirestore.instance;
      await firestore.runTransaction((transaction) async {
        // Delete caller’s active call
        final callerCallQuery = firestore
            .collection(collectionName.calls)
            .doc(call.callerId)
            .collection(collectionName.calling)
            .where('channelId', isEqualTo: call.channelId);
        final callerCallDocs = await callerCallQuery.get();
        for (var doc in callerCallDocs.docs) {
          transaction.delete(doc.reference);
        }

        // Update caller’s call history
        final callerHistoryRef = firestore
            .collection(collectionName.calls)
            .doc(call.callerId)
            .collection(collectionName.collectionCallHistory)
            .doc(call.timestamp.toString());
        transaction.set(
          callerHistoryRef,
          {
            'type': 'outGoing',
            'isVideoCall': call.isVideoCall,
            'id': call.receiverId,
            'timestamp': call.timestamp,
            'dp': call.receiverPic,
            'isMuted': false,
            'receiverId': call.receiverId,
            'isJoin': false,
            'started': null,
            'callerName': call.receiverName,
            'status': 'ended',
            'ended': DateTime.now(),
          },
          SetOptions(merge: true),
        );

        // Handle receivers (group or one-on-one)
        if (call.receiver != null) {
          // Group call
          for (var receiver in call.receiver!) {
            final receiverId = receiver['id'];
            final receiverCallQuery = firestore
                .collection(collectionName.calls)
                .doc(receiverId)
                .collection(collectionName.calling)
                .where('channelId', isEqualTo: call.channelId);
            final receiverCallDocs = await receiverCallQuery.get();
            for (var doc in receiverCallDocs.docs) {
              transaction.delete(doc.reference);
            }

            final receiverHistoryRef = firestore
                .collection(collectionName.calls)
                .doc(receiverId)
                .collection(collectionName.collectionCallHistory)
                .doc(call.timestamp.toString());
            transaction.set(
              receiverHistoryRef,
              {
                'type': 'INCOMING',
                'isVideoCall': call.isVideoCall,
                'id': call.callerId,
                'timestamp': call.timestamp,
                'dp': call.callerPic,
                'isMuted': false,
                'receiverId': receiverId,
                'isJoin': true,
                'started': null,
                'callerName': call.callerName,
                'status': 'ended',
                'ended': DateTime.now(),
              },
              SetOptions(merge: true),
            );
          }
        } else {
          // One-on-one call
          final receiverCallQuery = firestore
              .collection(collectionName.calls)
              .doc(call.receiverId)
              .collection(collectionName.calling)
              .where('channelId', isEqualTo: call.channelId);
          final receiverCallDocs = await receiverCallQuery.get();
          for (var doc in receiverCallDocs.docs) {
            transaction.delete(doc.reference);
          }

          final receiverHistoryRef = firestore
              .collection(collectionName.calls)
              .doc(call.receiverId)
              .collection(collectionName.collectionCallHistory)
              .doc(call.timestamp.toString());
          transaction.set(
            receiverHistoryRef,
            {
              'type': 'INCOMING',
              'isVideoCall': call.isVideoCall,
              'id': call.callerId,
              'timestamp': call.timestamp,
              'dp': call.callerPic,
              'isMuted': false,
              'receiverId': call.receiverId,
              'isJoin': true,
              'started': null,
              'callerName': call.callerName,
              'status': 'ended',
              'ended': DateTime.now(),
            },
            SetOptions(merge: true),
          );
        }
      });
      stopTimer();
      log('Call ended successfully');
      return true;
    } catch (e) {
      log('Error ending call: $e');
      return false;
    }
  }

  Future<void> onCallEnd(BuildContext context) async {
    if (call == null) return;
    stopTimer();
    await endCall(call: call!);
    await engine.leaveChannel();

    remoteUId = null;
    channelName = '';
    users.clear();
    localUserJoined = false;
    update();
    _dispose();
    WakelockPlus.disable();


    Get.back();

    log('Call ended and navigated back');
  }

}
