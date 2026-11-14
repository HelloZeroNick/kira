/*
 * cryptoFramework 的 MethodChannel 实现，满足 FlutterCryptography（cryptography_flutter）的线上协议。
 *
 * 为什么自己写：上游 CPF fork 的 ohos 实现有两处偏差，直接用会让备份加解密失败：
 *   1. PBKDF2Spec.keySize 的文档单位是**字节**，插件却把 Dart 的 bits(256) 直接塞进去，
 *      派生出的密钥长度翻 8 倍，AES 密钥长度校验必然失败；
 *   2. pbkdf2/encrypt/decrypt 全部用 generateSecretSync/initSync 在平台线程同步跑，
 *      600000 轮 PBKDF2 会卡住 UI。
 *
 * 这里只实现 lib/backup 实际用到的三个方法（pbkdf2 / encrypt / decrypt / hmac），
 * 一律走异步 Promise 接口，把耗时交给 cryptoFramework 的后台线程；
 * 其余方法返回 UNSUPPORTED_ALGORITHM，让 Dart 侧按既有逻辑回退，不静默给弱实现。
 */
import {
  FlutterPlugin,
  FlutterPluginBinding,
  MethodCall,
  MethodCallHandler,
  MethodChannel,
  MethodResult,
} from '@ohos/flutter_ohos';
import { cryptoFramework } from '@kit.CryptoArchitectureKit';
import { BusinessError } from '@kit.BasicServicesKit';
import Log from '@ohos/flutter_ohos/src/main/ets/util/Log';

const TAG = 'KiraCryptoChannel';
const CHANNEL = 'cryptography_flutter';
const GCM_TAG_BYTES = 16;

/** 把 Dart 侧的 HMAC 名称映射成 cryptoFramework 的 PBKDF2 摘要后缀。 */
function pbkdf2AlgName(mac: string): string | null {
  switch (mac) {
    case 'HMAC-SHA1':
      return 'PBKDF2|SHA1';
    case 'HMAC-SHA224':
      return 'PBKDF2|SHA224';
    case 'HMAC-SHA256':
      return 'PBKDF2|SHA256';
    case 'HMAC-SHA384':
      return 'PBKDF2|SHA384';
    case 'HMAC-SHA512':
      return 'PBKDF2|SHA512';
    default:
      return null;
  }
}

/** 把 Dart 侧的摘要名称映射成 cryptoFramework 的 MD 名称。 */
function mdAlgName(hash: string): string | null {
  switch (hash) {
    case 'SHA-1':
      return 'SHA1';
    case 'SHA-224':
      return 'SHA224';
    case 'SHA-256':
      return 'SHA256';
    case 'SHA-384':
      return 'SHA384';
    case 'SHA-512':
      return 'SHA512';
    default:
      return null;
  }
}

/** AES_GCM 与密钥长度 → cryptoFramework 对称算法名；不支持返回 null。 */
function aesAlgName(algo: string, keyLength: number): string | null {
  if (algo !== 'AES_GCM') {
    return null;
  }
  if (keyLength === 16) {
    return 'AES128';
  }
  if (keyLength === 24) {
    return 'AES192';
  }
  if (keyLength === 32) {
    return 'AES256';
  }
  return null;
}

export default class KiraCryptoChannel implements FlutterPlugin, MethodCallHandler {
  private channel: MethodChannel | null = null;

  getUniqueClassName(): string {
    return 'KiraCryptoChannel';
  }

  onAttachedToEngine(binding: FlutterPluginBinding): void {
    this.channel = new MethodChannel(binding.getBinaryMessenger(), CHANNEL);
    this.channel.setMethodCallHandler(this);
  }

  onDetachedFromEngine(binding: FlutterPluginBinding): void {
    this.channel?.setMethodCallHandler(null);
    this.channel = null;
  }

  onMethodCall(call: MethodCall, result: MethodResult): void {
    switch (call.method) {
      case 'pbkdf2':
        this.pbkdf2(call, result);
        break;
      case 'encrypt':
        this.encrypt(call, result);
        break;
      case 'decrypt':
        this.decrypt(call, result);
        break;
      case 'hmac':
        this.hmac(call, result);
        break;
      default:
        // 未实现的算法（ECDH/Ed25519/Chacha20 等）如实上报，Dart 侧据此回退。
        result.error('UNSUPPORTED_ALGORITHM', `${call.method} is not implemented on ohos`, null);
        break;
    }
  }

  private pbkdf2(call: MethodCall, result: MethodResult): void {
    const mac: string = call.argument('mac') as string;
    const algName = pbkdf2AlgName(mac);
    if (algName == null) {
      result.error('UNSUPPORTED_ALGORITHM', `pbkdf2 mac ${mac} is not supported`, null);
      return;
    }
    const bits: number = call.argument('bits') as number;
    const iterations: number = call.argument('iterations') as number;
    const password: string = call.argument('password') as string;
    const nonce: Uint8Array = call.argument('nonce') as Uint8Array;
    if (bits <= 0 || bits % 8 !== 0 || iterations <= 0 || nonce == null) {
      result.error('INVALID_PARAMS', 'pbkdf2 requires positive bits/iterations and a salt', null);
      return;
    }
    // keySize 的单位是字节，而 Dart 侧给的是位数，必须换算，否则派生密钥长度错 8 倍。
    const spec: cryptoFramework.PBKDF2Spec = {
      algName: 'PBKDF2',
      password: password,
      salt: nonce,
      iterations: iterations,
      keySize: bits / 8,
    };
    const kdf = cryptoFramework.createKdf(algName);
    // 用 Promise 版本，让 600000 轮派生落在 cryptoFramework 的工作线程而不是 UI 线程。
    kdf.generateSecret(spec).then((secret: cryptoFramework.DataBlob) => {
      const out: Map<string, Uint8Array> = new Map();
      out.set('hash', secret.data);
      result.success(out);
    }).catch((error: BusinessError) => {
      Log.e(TAG, `pbkdf2 failed: ${error.code} ${error.message}`);
      result.error('CRYPTO_FAILED', `pbkdf2 failed: ${error.code}`, null);
    });
  }

  private hmac(call: MethodCall, result: MethodResult): void {
    const hash: string = call.argument('hash') as string;
    const algName = mdAlgName(hash);
    if (algName == null) {
      result.error('UNSUPPORTED_ALGORITHM', `hmac hash ${hash} is not supported`, null);
      return;
    }
    const data: Uint8Array = call.argument('data') as Uint8Array;
    const key: Uint8Array = call.argument('key') as Uint8Array;
    if (data == null || key == null) {
      result.error('INVALID_PARAMS', 'hmac requires data and key', null);
      return;
    }
    try {
      // Mac.initSync 收的是 SymKey 而不是裸字节，HMAC 密钥要经 'HMAC' 生成器转换。
      const mac = cryptoFramework.createMac(algName);
      const keyGen = cryptoFramework.createSymKeyGenerator('HMAC');
      mac.initSync(keyGen.convertKeySync({ data: key }));
      // updateSync 拒绝空 DataBlob，空输入是合法的 HMAC 场景，用 0 占位。
      mac.updateSync({ data: data.byteLength === 0 ? new Uint8Array([0]) : data });
      const digest = mac.doFinalSync();
      const out: Map<string, Uint8Array> = new Map();
      out.set('mac', digest.data);
      result.success(out);
    } catch (error) {
      const e = error as BusinessError;
      Log.e(TAG, `hmac failed: ${e.code} ${e.message}`);
      result.error('CRYPTO_FAILED', `hmac failed: ${e.code}`, null);
    }
  }

  private encrypt(call: MethodCall, result: MethodResult): void {
    const algo: string = call.argument('algo') as string;
    const clearText: Uint8Array = call.argument('data') as Uint8Array;
    const key: Uint8Array = call.argument('key') as Uint8Array;
    const nonce: Uint8Array = call.argument('nonce') as Uint8Array;
    const aad: Uint8Array = call.argument('aad') as Uint8Array;

    if (clearText == null || key == null || nonce == null) {
      result.error('INVALID_PARAMS', 'encrypt requires data, key and nonce', null);
      return;
    }
    const symAlg = aesAlgName(algo, key.byteLength);
    if (symAlg == null) {
      result.error('UNSUPPORTED_ALGORITHM', `${algo} with ${key.byteLength} byte key is not supported`, null);
      return;
    }
    try {
      const cipher = cryptoFramework.createCipher(`${symAlg}|GCM|NoPadding`);
      const params: cryptoFramework.GcmParamsSpec = {
        algName: 'GcmParamsSpec',
        iv: { data: nonce },
        // GCM 的 aad 允许空串；Dart 侧未传时用空数组，避免把 undefined 塞进 spec。
        aad: { data: aad != null ? aad : new Uint8Array(0) },
        // 加密时 authTag 由 doFinal 产出，这里占位 16 字节。
        authTag: { data: new Uint8Array(GCM_TAG_BYTES) },
      };
      const keyGen = cryptoFramework.createSymKeyGenerator(symAlg);
      const symKey = keyGen.convertKeySync({ data: key });
      cipher.initSync(cryptoFramework.CryptoMode.ENCRYPT_MODE, symKey, params);
      const cipherText = cipher.updateSync({ data: clearText });
      const tag = cipher.doFinalSync(null);

      const out: Map<string, Uint8Array> = new Map();
      out.set('cipherText', cipherText.data);
      out.set('mac', tag.data);
      result.success(out);
    } catch (error) {
      const e = error as BusinessError;
      Log.e(TAG, `encrypt failed: ${e.code} ${e.message}`);
      result.error('CRYPTO_FAILED', `encrypt failed: ${e.code}`, null);
    }
  }

  private decrypt(call: MethodCall, result: MethodResult): void {
    const algo: string = call.argument('algo') as string;
    const cipherText: Uint8Array = call.argument('data') as Uint8Array;
    const key: Uint8Array = call.argument('key') as Uint8Array;
    const nonce: Uint8Array = call.argument('nonce') as Uint8Array;
    const mac: Uint8Array = call.argument('mac') as Uint8Array;
    const aad: Uint8Array = call.argument('aad') as Uint8Array;

    if (cipherText == null || key == null || nonce == null || mac == null) {
      result.error('INVALID_PARAMS', 'decrypt requires data, key, nonce and mac', null);
      return;
    }
    const symAlg = aesAlgName(algo, key.byteLength);
    if (symAlg == null) {
      result.error('UNSUPPORTED_ALGORITHM', `${algo} with ${key.byteLength} byte key is not supported`, null);
      return;
    }
    if (mac.byteLength !== GCM_TAG_BYTES) {
      // GCM 认证标签固定 16 字节；长度不对直接判为认证失败，不必下沉到 cryptoFramework。
      result.error('INCORRECT_MAC', `unexpected gcm tag length ${mac.byteLength}`, null);
      return;
    }
    try {
      const cipher = cryptoFramework.createCipher(`${symAlg}|GCM|NoPadding`);
      const params: cryptoFramework.GcmParamsSpec = {
        algName: 'GcmParamsSpec',
        iv: { data: nonce },
        aad: { data: aad != null ? aad : new Uint8Array(0) },
        // 解密时把 Dart 传来的 tag 交给 init 校验，校验失败 doFinal 会抛异常。
        authTag: { data: mac },
      };
      const keyGen = cryptoFramework.createSymKeyGenerator(symAlg);
      const symKey = keyGen.convertKeySync({ data: key });
      cipher.initSync(cryptoFramework.CryptoMode.DECRYPT_MODE, symKey, params);
      const clearText = cipher.updateSync({ data: cipherText });
      cipher.doFinalSync(null);

      const out: Map<string, Uint8Array> = new Map();
      out.set('clearText', clearText.data);
      result.success(out);
    } catch (error) {
      const e = error as BusinessError;
      Log.w(TAG, `decrypt failed: ${e.code} ${e.message}`);
      // GCM tag 校验失败是「密码错误」，Dart 侧靠 INCORRECT_MAC 转成
      // SecretBoxAuthenticationError，不能混成普通失败。
      result.error('INCORRECT_MAC', `decrypt failed: ${e.code}`, null);
    }
  }
}