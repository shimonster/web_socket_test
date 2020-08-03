import 'dart:io'; // show WebSocket, WebSocketTransformer, HttpServer, stdin;
import 'dart:convert';
import 'dart:async';
import 'dart:isolate';

void main(List<String> args) {
// final isolates = Isolates();
  final mainPort = ReceivePort();
  List<ClientIsolate> clientIsolates = [];
  Map<String, SendPort> clientPorts = {};
  print('server started');
  HttpServer.bind('localhost', 16969).then(
    /// creates the server ^^^^^^^^^^^
    (server) async {
      /// when created the [server] <---------
      print('server set up as listening: ${server.port}');
      await Isolate.spawn(inputIsolate, {'allClients': clientIsolates});
      //  {'allClients': clientIsolates, 'mainPort': mainPort.sendPort});
      /// await isolates.spawnInputIsolate();
      server.listen(
        (request) {
          /// This trigers when a [request] is sent <---------
          WebSocketTransformer.upgrade(request).then(
            /// upgreades the request to a web socket ^^^^^^^^^^^^^^
            (ws) async {
              /// when upgraded [ws] is the web socket <---------
              /// sends initial data to client web socket when created <--------
              print('server recieved request');
              print(request.uri);
              final uid = request.uri.pathSegments[0];
              clientIsolates.add(ClientIsolate(uid));
              clientIsolates
                  .firstWhere((element) => element.uid == uid)
                  .awaitInit
                  .then((clientSendPort) {
                clientPorts.putIfAbsent(uid, () => clientSendPort);
                clientSendPort.send({'ws': ws});
              });
// await isolates.spawnClientIsolate(
//     request.uri.pathSegments[0], ws);
              if (ws.readyState == WebSocket.open) {
                /// if [ws] is open, do this stuff <---------
                ws.listen(
                  (event) {
                    /// listens to [event]s from the web socket <---------
                    print(
                        '${DateTime.now()}, ${Map<String, String>.from(json.decode(event))}');

                    final wsMessage =
                        Map<String, String>.from(json.decode(event))
                            .values
                            .toString()[0];

                    clientIsolates.removeWhere((isl) => uid == isl.uid);
                    clientIsolates.forEach((isl) {
                      clientPorts[uid].send(wsMessage);
                    });
                  },
                  onDone: () => print('done'),
                  onError: (error) =>
                      print('server error listening to web socket: $error'),
                  cancelOnError: true,
                );
              }
            },
            onError: (error) => print('server error upgrading request: $error'),
          );
        },
        onError: (error) => print('server error listening to server: $error'),
      );
    },
    onError: (error) => print('server error binding: $error'),
  );
}

void inputIsolate(Map<String, dynamic> message) {
  while (true) {
    final input = stdin.readLineSync();
    message['allClients'].forEach((value) {
      value.send(input);
    });
  }
}

clientIsolate(SendPort mainSendPort) async {
  final thisRecievePort = ReceivePort();
  mainSendPort.send(thisRecievePort.sendPort);
  final Map<String, dynamic> first = await thisRecievePort.first;
  final thisWs = first['ws'];
  print('isolate init');

  // thisWs.add(json.encode({DateTime.now().toString(): 'recieveMessage'}));
  thisRecievePort.listen((recieveMessage) {
    thisWs.add(json.encode({DateTime.now().toString(): recieveMessage}));
  });
}

class ClientIsolate {
  ClientIsolate(this.uid) {
    spawnClientIsolate().then((value) {
      _internalPort.listen((message) {
        isolateSendPort = message;
      });
    });
  }

  final _internalPort = ReceivePort();
  SendPort isolateSendPort;
  final String uid;

  Future<SendPort> get awaitInit async {
    while (isolateSendPort == null) {}
    return isolateSendPort;
  }

  Future<void> spawnClientIsolate() async {
    await Isolate.spawn(clientIsolate, _internalPort.sendPort);
  }
}

//
//
//
//
//
//
//
//
//
//
//
//
//
//
//
//
//
//
//
//
//
//
//
//
//
//
//
//
//
//
//
//
//
//
//
//
//
//
//
//
//
//
//
//
//
//
//
//
//
//
//
//
//
//
//
class Isolates1 {
  final mainPort = ReceivePort();
  Map<String, SendPort> clientPorts = {};

  static inputIsolate(Map<String, SendPort> message) {
    while (true) {
      final input = stdin.readLineSync();
      message.forEach((key, value) {
        value.send(input);
      });
    }
  }

  Future<void> spawnInputIsolate() async {
    mainPort.listen((message) {
      clientPorts.putIfAbsent(message['id'], () => message['port']);
    });
    await Isolate.spawn(inputIsolate, clientPorts);
  }

  static clientIsolate(message) async {
    final thisRecievePort = ReceivePort();
    final String thisId = message['clientId'];
    final SendPort mainSendPort = message['mainPort'];
    final Map<String, SendPort> allSendPorts = message['allSendPorts'];
    mainSendPort.send({'port': thisRecievePort.sendPort, 'id': thisId});
    final WebSocket thisWs = await thisRecievePort.first;

    thisRecievePort.listen((recieveMessage) {
      thisWs.add(json.encode({DateTime.now().toString(): recieveMessage}));
    });

    thisWs.listen((event) {
      print('$thisId: $event');
      final wsMessage =
          Map<String, String>.from(json.decode(event)).values.toString()[0];
      allSendPorts.removeWhere((key, value) => key == thisId);
      allSendPorts.forEach((key, value) {
        value.send(wsMessage);
      });
    });
  }

  Future<void> spawnClientIsolate(String clientId, WebSocket ws) async {
    await Isolate.spawn(clientIsolate, {
      'clientId': clientId,
      'allSendPorts': clientPorts,
      'mainPort': mainPort.sendPort
    });
    clientPorts[clientId].send(ws);
  }
}
