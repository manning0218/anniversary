import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bluetooth_serial/flutter_bluetooth_serial.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:logger/logger.dart';
import 'package:spotify_sdk/models/connection_status.dart';
import 'package:spotify_sdk/spotify_sdk.dart';

import 'SelectBondedDevicePage.dart';

class HomePage extends StatefulWidget {
  @override
  _HomePage createState() => new _HomePage();
}

class _HomePage extends State<HomePage> {
  BluetoothState _bluetoothState = BluetoothState.UNKNOWN;

  String _address;
  String _name;

  bool _connected = false;
  bool _loading = false;

  bool _raspberryPiConnected = false;

  Timer _discoverableTimeoutTimer;
  int _discoverableTimeoutSecondsLeft = 0;

  BluetoothDevice _device = null;
  BluetoothConnection connection;
  final Logger _logger = Logger();

  @override
  void initState() {
    super.initState();

    FlutterBluetoothSerial.instance.state.then((state) {
      setState(() {
        _bluetoothState = state;
      });
    });

    Future.doWhile(() async {
      if (await FlutterBluetoothSerial.instance.isEnabled) {
        return false;
      }
      await Future.delayed(Duration(milliseconds: 0xDD));
      return true;
    }).then((_) {
      FlutterBluetoothSerial.instance.address.then((address) {
        setState(() {
          _address = address;
        });
      });
    });

    FlutterBluetoothSerial.instance.name.then((name) {
      setState(() {
        _name = name;
      });
    });

    FlutterBluetoothSerial.instance
        .onStateChanged()
        .listen((BluetoothState state) {
      setState(() {
        _bluetoothState = state;

        // Discoverable disabled when bluetooth is disabled
        _discoverableTimeoutTimer = null;
        _discoverableTimeoutSecondsLeft = 0;
      });
    });
  }

  @override
  void dispose() {
    FlutterBluetoothSerial.instance.setPairingRequestHandler(null);
    _discoverableTimeoutTimer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
        home: StreamBuilder<ConnectionStatus>(
            stream: SpotifySdk.subscribeConnectionStatus(),
            builder: (context, snapshot) {
              _connected = false;
              if (snapshot.data != null) {
                _connected = snapshot.data.connected;
              }
              /*else {
                getAuthenticationToken();
              }

              if (!_connected) {
                connectToSpotifyRemote();
              }*/

              return Scaffold(
                appBar: AppBar(
                    title: const Text('Happy Anniversary'),
                    backgroundColor: Colors.lightBlueAccent,
                    actions: <Widget>[
                      Padding(
                        padding: EdgeInsets.only(right: 20.0),
                        child: FlatButton(
                          textColor: Colors.white,
                          onPressed: () async {
                            final BluetoothDevice selectedDevice =
                                await Navigator.of(context)
                                    .push(MaterialPageRoute(builder: (context) {
                              return SelectBondedDevicePage(
                                checkAvailability: false,
                              );
                            }));

                            if (selectedDevice != null) {
                              if (await _connect(
                                  device: selectedDevice, context: context)) {
                                print('_connect succeeded.');
                                await connectToSpotifyRemote();
                              }
                            }
                          },
                          child: Icon(_raspberryPiConnected
                              ? Icons.bluetooth_connected
                              : Icons.bluetooth),
                          shape: CircleBorder(
                              side: BorderSide(color: Colors.transparent)),
                        ),
                      )
                    ]),
                body: Container(
                    child: RaisedButton(
                  child: Text('November 8, 2020'),
                  onPressed: _willYouMarryMe,
                )),
              );
            }));
  }

  Future<bool> _connect(
      {@required BuildContext context,
      @required BluetoothDevice device}) async {
    BluetoothConnection.toAddress(device.address).then((_connection) {
      print('Connected to the device');
      connection = _connection;
      _device = device;

      setState(() {
        _raspberryPiConnected = device.name == "raspberrypi";
      });
      connection.input.listen(_onDataReceived).onDone(() {
        if (this.mounted) {
          setState(() {
            _raspberryPiConnected = false;
          });
        }
      });
    }).catchError((error) {
      print('Failed to connect, exception occurred.');
      print(error);

      setState(() {});
      return false;
    });
    return true;
  }

  Future<void> connectToSpotifyRemote() async {
    try {
      setState(() {
        _loading = true;
      });
      var result = await SpotifySdk.connectToSpotifyRemote(
          clientId: DotEnv().env['CLIENT_ID'].toString(),
          redirectUrl: DotEnv().env['REDIRECT_URL'].toString());
      setStatus(result
          ? 'connect to spotify successful'
          : 'connect to spotify failed');
      setState(() {
        _loading = false;
      });
    } on PlatformException catch (e) {
      setState(() {
        _loading = false;
      });
      setStatus(e.code, message: e.message);
    } on MissingPluginException {
      setState(() {
        _loading = false;
      });
      setStatus('not implemented');
    }
  }

  Future<String> getAuthenticationToken() async {
    try {
      var authenticationToken = await SpotifySdk.getAuthenticationToken(
          clientId: DotEnv().env['CLIENT_ID'].toString(),
          redirectUrl: DotEnv().env['REDIRECT_URL'].toString(),
          scope: 'app-remote-control, '
              'user-modify-playback-state, '
              'playlist-read-private, '
              'playlist-modify-public,user-read-currently-playing');
      setStatus('Got a token: $authenticationToken');
      return authenticationToken;
    } on PlatformException catch (e) {
      setStatus(e.code, message: e.message);
      return Future.error('$e.code: $e.message');
    } on MissingPluginException {
      setStatus('not implemented');
      return Future.error('not implemented');
    }
  }

  Future<void> play() async {
    try {
      await SpotifySdk.play(spotifyUri: 'spotify:track:6EGAfJaLUFzhS4zRBIEQ2J');
    } on PlatformException catch (e) {
      setStatus(e.code, message: e.message);
    } on MissingPluginException {
      setStatus('not implemented');
    }
  }

  void _onDataReceived(Uint8List data) {
    Uint8List buffer = Uint8List(data.length);
    int bufferIndex = buffer.length;

    for (int i = data.length - 1; i >= 0; --i) {
      buffer[--bufferIndex] = data[i];
    }

    String dataString = String.fromCharCodes(buffer);
    print(dataString);
  }

  void _willYouMarryMe() {
    _startMotor();
    play();
  }

  void _startMotor() {
    if (connection != null) {
      try {
        connection.output.add(utf8.encode("r\n"));
        connection.output.allSent;
        connection.output.add(utf8.encode("e\n"));
        connection.output.allSent;
        connection.output.add(utf8.encode("1000\n"));
        connection.output.allSent;
      } catch (e) {
        print(e);
        setState(() {});
      }
    }
  }

  void setStatus(String code, {String message = ''}) {
    var text = message.isEmpty ? '' : ' : $message';
    _logger.d('$code$text');
  }
}
