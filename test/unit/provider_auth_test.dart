import 'package:flutter_test/flutter_test.dart';
import 'package:fibu/core/services/provider_auth.dart';
import 'package:fibu/core/services/rclone_provider_registry.dart';

void main() {
  group('ProviderAuth', () {
    test('maps convenience ids to rclone backend types', () {
      expect(ProviderAuth.rcloneType('mega'), 'mega');
      expect(ProviderAuth.rcloneType('s3-wasabi'), 's3');
      expect(ProviderAuth.rcloneType('gcs'), 'google cloud storage');
      expect(ProviderAuth.rcloneType('1fichier'), 'fichier');
    });

    test('does not treat Proton Drive as OAuth', () {
      final proton = RcloneProviderRegistry.findById('protondrive');
      expect(proton, isNotNull);
      expect(ProviderAuth.isOAuth(proton), isFalse);
      expect(proton!.fields.any((f) => f.key == 'username'), isTrue);
      expect(proton.fields.any((f) => f.key == 'password' && f.isSecret), isTrue);
    });

    test('Google Drive is OAuth and MEGA is credentials', () {
      expect(ProviderAuth.isOAuth(RcloneProviderRegistry.findById('drive')), isTrue);
      expect(ProviderAuth.isOAuth(RcloneProviderRegistry.findById('mega')), isFalse);
    });

    test('autofill domains include mega.nz and drive.google.com', () {
      expect(ProviderAuth.autofillDomain('mega'), 'mega.nz');
      expect(ProviderAuth.autofillDomain('drive'), 'drive.google.com');
      expect(
        ProviderAuth.associatedWebcredentialHosts,
        containsAll(['mega.nz', 'drive.google.com', 'accounts.google.com']),
      );
    });

    test('buildConfig uses registry fields and static S3 provider', () async {
      final mega = RcloneProviderRegistry.findById('mega')!;
      final config = await ProviderAuth.buildConfig(
        providerId: 'mega',
        descriptor: mega,
        values: {'user': 'a@b.de', 'pass': 'secret'},
        obscure: (p) async => 'obscured:$p',
      );
      expect(config['user'], 'a@b.de');
      expect(config['pass'], 'obscured:secret');

      final wasabi = RcloneProviderRegistry.findById('s3-wasabi')!;
      final s3 = await ProviderAuth.buildConfig(
        providerId: 's3-wasabi',
        descriptor: wasabi,
        values: {
          'access_key_id': 'AKI',
          'secret_access_key': 'SEC',
          'endpoint': 's3.eu-central-1.wasabisys.com',
        },
        obscure: (p) async => 'x$p',
      );
      expect(s3['provider'], 'Wasabi');
      expect(s3['access_key_id'], 'AKI');
      expect(s3['secret_access_key'], 'xSEC');
    });

    test('required field validation', () {
      final mega = RcloneProviderRegistry.findById('mega');
      expect(ProviderAuth.missingRequired(mega, {'user': '', 'pass': 'x'}), 'E-Mail-Adresse');
      expect(ProviderAuth.missingRequired(mega, {'user': 'a', 'pass': 'x'}), isNull);
      expect(
        ProviderAuth.missingRequired(RcloneProviderRegistry.findById('drive'), {}),
        isNull,
      );
    });

    test('buildConfig formats remote-picker selections for union/crypt/combine', () async {
      final union = RcloneProviderRegistry.findById('union')!;
      final unionCfg = await ProviderAuth.buildConfig(
        providerId: 'union',
        descriptor: union,
        values: {'remotes': 'fibu-aaaa: fibu-bbbb:'},
        obscure: (p) async => p,
      );
      expect(unionCfg['remotes'], 'fibu-aaaa: fibu-bbbb:');

      final crypt = RcloneProviderRegistry.findById('crypt')!;
      final cryptCfg = await ProviderAuth.buildConfig(
        providerId: 'crypt',
        descriptor: crypt,
        values: {'remote': 'fibu-cccc:', 'password': 'pw'},
        obscure: (p) async => 'o:$p',
      );
      expect(cryptCfg['remote'], 'fibu-cccc:');
      expect(cryptCfg['password'], 'o:pw');

      final combine = RcloneProviderRegistry.findById('combine')!;
      final combineCfg = await ProviderAuth.buildConfig(
        providerId: 'combine',
        descriptor: combine,
        values: {'upstreams': 'fibu-aaaa: fibu-bbbb:'},
        obscure: (p) async => p,
      );
      expect(combineCfg['upstreams'], 'drive1=fibu-aaaa: drive2=fibu-bbbb:');
    });
  });
}
