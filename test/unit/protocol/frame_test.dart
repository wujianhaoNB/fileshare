import 'dart:typed_data';
import 'package:flutter_test/flutter_test.dart';
import 'package:fileshare/network/protocol/frame.dart';
import 'package:fileshare/network/protocol/protocol_constants.dart';
import 'package:fileshare/network/protocol/message.dart';
import 'package:fileshare/network/protocol/serializer.dart';

void main() {
  group('Frame encode/decode', () {
    test('should encode and decode a metadata message', () {
      final msg = MetadataMessage(
        fileName: 'test.jpg',
        fileSize: 1024,
        mimeType: 'image/jpeg',
      );

      final frame = Serializer.toFrame(msg);
      final encoded = frame.encode();

      expect(encoded.length, greaterThan(ProtocolConstants.frameHeaderSize));

      final decoded = Frame.decode(encoded);
      expect(decoded, isNotNull);
      expect(decoded!.messageType, equals(ProtocolConstants.msgMetadata));

      final decodedMsg = Serializer.fromFrame(decoded);
      expect(decodedMsg, isA<MetadataMessage>());
      final meta = decodedMsg as MetadataMessage;
      expect(meta.fileName, equals('test.jpg'));
      expect(meta.fileSize, equals(1024));
    });

    test('should encode and decode a chunk message', () {
      final data = Uint8List.fromList([1, 2, 3, 4, 5]);
      final msg = ChunkMessage(offset: 100, data: data);

      final frame = Serializer.toFrame(msg);
      final encoded = frame.encode();

      final decoded = Frame.decode(encoded);
      final decodedMsg = Serializer.fromFrame(decoded!);
      expect(decodedMsg, isA<ChunkMessage>());
      final chunk = decodedMsg as ChunkMessage;
      expect(chunk.offset, equals(100));
      expect(chunk.data, equals(data));
    });

    test('should reject invalid magic bytes', () {
      final badData = Uint8List(20);
      final decoded = Frame.decode(badData);
      expect(decoded, isNull);
    });
  });

  group('FrameReader', () {
    test('should assemble frames from partial data', () {
      final reader = FrameReader();
      final msg = MetadataMessage(fileName: 'test.txt', fileSize: 100);
      final frame = Serializer.toFrame(msg);
      final encoded = frame.encode();

      // Split data in half
      final half = encoded.length ~/ 2;

      var frames = reader.feed(Uint8List.sublistView(encoded, 0, half));
      expect(frames, isEmpty);

      frames = reader.feed(Uint8List.sublistView(encoded, half));
      expect(frames.length, equals(1));
      expect(frames.first.messageType, equals(ProtocolConstants.msgMetadata));
    });

    test('should handle multiple frames in one feed', () {
      final reader = FrameReader();
      final msg1 = MetadataMessage(fileName: 'a.txt', fileSize: 10);
      final msg2 = const DoneMessage();

      final data1 = Serializer.toFrame(msg1).encode();
      final data2 = Serializer.toFrame(msg2).encode();

      final combined = Uint8List(data1.length + data2.length);
      combined.setRange(0, data1.length, data1);
      combined.setRange(data1.length, combined.length, data2);

      final frames = reader.feed(combined);
      expect(frames.length, equals(2));
    });
  });

  group('ProtocolMessage serialization', () {
    test('DoneMessage should have empty payload', () {
      final msg = const DoneMessage();
      expect(msg.encodePayload(), isEmpty);
    });

    test('AckMessage should encode/decode offset', () {
      const offset = 65536;
      final msg = AckMessage(ackedOffset: offset);
      final decoded = AckMessage.decode(msg.encodePayload());
      expect(decoded.ackedOffset, equals(offset));
    });
  });
}
