import 'dart:typed_data';
import 'package:flutter_test/flutter_test.dart';
import 'package:modir_man/data/backup.dart';

void main() {
  test('پشتیبان رمزنگاری و دستکاری', () async {
    final codec = BackupCodec();
    final plain = {'schema': 1, 'projects': <Object>[], 'tasks': <Object>[], 'history': <Object>[]};
    final encoded = await codec.encrypt(plain, 'very-long-password');
    expect(String.fromCharCodes(encoded).contains('projects'), false);
    expect(await codec.decrypt(encoded, 'very-long-password'), plain);
    await expectLater(codec.decrypt(encoded, 'incorrect-password'), throwsFormatException);
    final broken = Uint8List.fromList(encoded);
    broken[broken.length - 20] ^= 1;
    await expectLater(codec.decrypt(broken, 'very-long-password'), throwsFormatException);
  });
}
