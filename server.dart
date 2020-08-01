import 'dart:io' show WebSocket, WebSocketTransformer, HttpServer, stdin;
import 'dart:convert';

void main(List<String> args) {
  HttpServer.bind('localhost', 6969).then(
    (server) {
      print('server set up as listening: ${server.port}');
      server.listen(
        (request) {
          WebSocketTransformer.upgrade(request).then(
            (ws) {
              if (ws.readyState == WebSocket.open) {
                ws.listen(
                  (event) {
                    print(
                        '${DateTime.now()}, ${request?.connectionInfo?.remoteAddress}, ${Map<String, String>.from(json.decode(event))}');
                    final dataInput = stdin.readLineSync();
                    ws.add(json.encode({'server typed': dataInput}));
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
