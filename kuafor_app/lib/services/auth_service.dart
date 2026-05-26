import 'package:dio/dio.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:firebase_auth/firebase_auth.dart';

class AuthService {
  final Dio _dio = Dio(
    BaseOptions(
      baseUrl: 'https://kuafor-019f.onrender.com/api',
      connectTimeout: const Duration(seconds: 10),
      receiveTimeout: const Duration(seconds: 30),
    ),
  );

  final FlutterSecureStorage _storage = const FlutterSecureStorage();

  String? lastAuthError;

  Future<String?> login(String identifier, String password) async {
    lastAuthError = null;

    try {
      final response = await _dio.post(
        '/Auth/login',
        data: {
          'identifier': identifier,
          'email': identifier,
          'password': password,
        },
      );

      if (response.statusCode == 200 && response.data['token'] != null) {
        final token = response.data['token'].toString();
        await saveToken(token);
        return token;
      }

      return null;
    } on DioException catch (e) {
      lastAuthError =
          _messageFromDio(e) ??
          'Giriş yapılamadı. Sunucu bağlantısını kontrol edin.';

      print('LOGIN ERROR TYPE: ${e.type}');
      print('LOGIN STATUS: ${e.response?.statusCode}');
      print('LOGIN DATA: ${e.response?.data}');
      print('LOGIN MESSAGE: ${e.message}');
      print('LOGIN URL: ${e.requestOptions.uri}');

      return null;
    } catch (e) {
      lastAuthError = 'Giriş sırasında beklenmeyen bir hata oluştu.';
      print('Login genel hata: $e');
      return null;
    }
  }

  Future<bool> register({
    required String fullName,
    required String email,
    required String password,
    required String role,
    String? username,
    String? salonName,
    String? salonAddress,
    String? salonDescription,
    double? salonLatitude,
    double? salonLongitude,
  }) async {
    lastAuthError = null;

    try {
      final data = <String, dynamic>{
        'fullName': fullName,
        'email': email,
        if (username != null && username.isNotEmpty) 'username': username,
        'password': password,
        'role': role,
        if (salonName != null) 'salonName': salonName,
        if (salonAddress != null) 'salonAddress': salonAddress,
        if (salonDescription != null && salonDescription.isNotEmpty)
          'salonDescription': salonDescription,
        if (salonLatitude != null) 'salonLatitude': salonLatitude,
        if (salonLongitude != null) 'salonLongitude': salonLongitude,
      };

      final response = await _dio.post('/Auth/register', data: data);

      print('REGISTER STATUS: ${response.statusCode}');
      print('REGISTER BODY: ${response.data}');

      return response.statusCode == 200 || response.statusCode == 201;
    } on DioException catch (e) {
      lastAuthError =
          _messageFromDio(e) ?? 'Kayıt yapılamadı. Lütfen tekrar deneyin.';

      print('REGISTER ERROR TYPE: ${e.type}');
      print('REGISTER STATUS: ${e.response?.statusCode}');
      print('REGISTER DATA: ${e.response?.data}');
      print('REGISTER MESSAGE: ${e.message}');
      print('REGISTER URL: ${e.requestOptions.uri}');

      return false;
    } catch (e) {
      lastAuthError = 'Kayıt sırasında beklenmeyen bir hata oluştu.';
      print('Register genel hata: $e');
      return false;
    }
  }

  Future<String?> signInWithGoogle() async {
    lastAuthError = null;

    try {
      final GoogleSignIn googleSignIn = GoogleSignIn(
        scopes: ['email', 'profile'],
      );

      await googleSignIn.signOut();

      final GoogleSignInAccount? googleUser = await googleSignIn.signIn();

      if (googleUser == null) {
        lastAuthError = 'Google ile giriş iptal edildi.';
        return null;
      }

      final GoogleSignInAuthentication googleAuth =
          await googleUser.authentication;

      final credential = GoogleAuthProvider.credential(
        accessToken: googleAuth.accessToken,
        idToken: googleAuth.idToken,
      );

      final userCredential = await FirebaseAuth.instance.signInWithCredential(
        credential,
      );

      final user = userCredential.user;

      if (user == null) {
        lastAuthError = 'Google kullanıcı bilgisi alınamadı.';
        return null;
      }

      final email = user.email ?? googleUser.email;

      if (email.isEmpty) {
        lastAuthError = 'Google hesabından e-posta bilgisi alınamadı.';
        return null;
      }

      return _socialLogin(
        provider: 'Google',
        providerId: user.uid,
        email: email,
        fullName:
            user.displayName ??
            googleUser.displayName ??
            email.split('@').first,
      );
    } on FirebaseAuthException catch (e) {
      lastAuthError = 'Firebase Google giriş hatası: ${e.message}';

      print('FIREBASE GOOGLE ERROR CODE: ${e.code}');
      print('FIREBASE GOOGLE ERROR MESSAGE: ${e.message}');

      return null;
    } catch (e) {
      lastAuthError =
          'Google ile giriş başlatılamadı. Firebase ve SHA-1 ayarlarını kontrol edin.';

      print('GOOGLE LOGIN ERROR: $e');

      return null;
    }
  }

  Future<String?> _socialLogin({
    required String provider,
    required String providerId,
    required String email,
    required String fullName,
  }) async {
    lastAuthError = null;

    try {
      final response = await _dio.post(
        '/Auth/social-login',
        data: {
          'provider': provider,
          'providerId': providerId,
          'email': email,
          'fullName': fullName,
        },
      );

      if (response.statusCode == 200 && response.data['token'] != null) {
        final token = response.data['token'].toString();
        await saveToken(token);
        return token;
      }

      lastAuthError = 'Sosyal girişten token dönmedi.';
      return null;
    } on DioException catch (e) {
      lastAuthError =
          _messageFromDio(e) ?? 'Sosyal giriş sunucu tarafında tamamlanamadı.';

      print('SOCIAL LOGIN STATUS: ${e.response?.statusCode}');
      print('SOCIAL LOGIN DATA: ${e.response?.data}');
      print('SOCIAL LOGIN URL: ${e.requestOptions.uri}');

      return null;
    } catch (e) {
      lastAuthError = 'Sosyal giriş sırasında beklenmeyen bir hata oluştu.';
      print('Social login genel hata: $e');
      return null;
    }
  }

  Future<AuthActionResult> forgotPassword(String email) async {
    try {
      final response = await _dio.post(
        '/Auth/forgot-password',
        data: {'email': email},
      );

      if (response.statusCode == 200 && response.data['message'] != null) {
        return AuthActionResult.success(response.data['message'].toString());
      }

      return AuthActionResult.success('İşlem tamamlandı.');
    } on DioException catch (e) {
      return AuthActionResult.failure(
        _messageFromDio(e) ?? 'Şifre sıfırlama e-postası gönderilemedi.',
      );
    } catch (e) {
      return AuthActionResult.failure('Bir hata oluştu.');
    }
  }

  Future<Map<String, dynamic>?> getUserInfo(String token) async {
    try {
      final response = await _dio.get(
        '/Users/me',
        options: Options(headers: {'Authorization': 'Bearer $token'}),
      );

      if (response.statusCode == 200 && response.data != null) {
        final data = response.data;

        final role = data['Role'] ?? data['role'] ?? '';

        return {
          'id': data['Id'] ?? data['id'] ?? 0,
          'email': data['Email'] ?? data['email'] ?? '',
          'name':
              data['FullName'] ??
              data['fullName'] ??
              data['name'] ??
              'Kullanıcı',
          'role': role,
          'message': data['Message'] ?? data['message'] ?? '',
          'profileImageUrl':
              data['ProfileImageUrl'] ?? data['profileImageUrl'] ?? '',
        };
      }

      return null;
    } on DioException catch (e) {
      print('Kullanıcı bilgisi Dio hatası: ${e.response?.data ?? e.message}');
      return null;
    } catch (e) {
      print('Kullanıcı bilgisi genel hata: $e');
      return null;
    }
  }

  Future<bool> updateProfile({
    required String token,
    String? fullName,
    String? password,
  }) async {
    try {
      final response = await _dio.put(
        '/Users/update',
        data: {
          if (fullName != null) 'fullName': fullName,
          if (password != null) 'password': password,
        },
        options: Options(headers: {'Authorization': 'Bearer $token'}),
      );

      return response.statusCode == 200;
    } on DioException catch (e) {
      print('Update profile Dio hatası: ${e.response?.data ?? e.message}');
      return false;
    } catch (e) {
      print('Update profile genel hata: $e');
      return false;
    }
  }

  Future<String?> uploadProfilePhoto({
    required String token,
    required String filePath,
  }) async {
    try {
      final fileName = filePath.split('/').last;

      final formData = FormData.fromMap({
        'file': await MultipartFile.fromFile(filePath, filename: fileName),
      });

      final response = await _dio.post(
        '/Users/upload-photo',
        data: formData,
        options: Options(
          headers: {
            'Authorization': 'Bearer $token',
            'Content-Type': 'multipart/form-data',
          },
        ),
      );

      if (response.statusCode == 200) {
        return (response.data['profileImageUrl'] ?? response.data['imageUrl'])
            ?.toString();
      }

      return null;
    } on DioException catch (e) {
      print('UPLOAD PHOTO ERROR: ${e.response?.data}');
      return null;
    } catch (e) {
      print('UPLOAD PHOTO GENERAL ERROR: $e');
      return null;
    }
  }

  Future<void> saveToken(String token) async {
    await _storage.write(key: 'jwt_token', value: token);
  }

  Future<String?> getToken() async {
    return await _storage.read(key: 'jwt_token');
  }

  Future<void> deleteToken() async {
    await _storage.delete(key: 'jwt_token');
  }

  String? _messageFromDio(DioException e) {
    final data = e.response?.data;

    if (data is Map) {
      return (data['message'] ?? data['error'] ?? data['detail'])?.toString();
    }

    if (data is String && data.trim().isNotEmpty) {
      return data;
    }

    return null;
  }
}

class AuthActionResult {
  final bool isSuccess;
  final String message;

  const AuthActionResult({required this.isSuccess, required this.message});

  factory AuthActionResult.success(String message) {
    return AuthActionResult(isSuccess: true, message: message);
  }

  factory AuthActionResult.failure(String message) {
    return AuthActionResult(isSuccess: false, message: message);
  }
}
