# App de administración de contenido (doliv_social) Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Build a simple Flutter app that lets a `director` log in and manage (list/create/edit/delete) the 7 content sections of RADIODOLIV_PAGINA (Servicios, Programas, Podcast, Anuncios, Eventos, Equipo, Sección azul) by consuming the existing `hive-backend` `/site/*` CRUD API.

**Architecture:** Plain `StatefulWidget`/`setState`, `http` for networking, `shared_preferences` for the session token, `image_picker` for photos. One list screen + one form screen per section, sharing three small presentational widgets. No generic CRUD engine — each section's fields differ too much.

**Tech Stack:** Flutter (existing `doliv_social` project), `http`, `shared_preferences`, `image_picker`.

**Spec:** `docs/superpowers/specs/2026-09-04-content-admin-app-design.md`

## Global Constraints

- Backend base URL: `http://10.0.2.2/hive-backend` on Android emulator, `http://localhost/hive-backend` otherwise (from spec's `api_config.dart`).
- Site base URL (for images): `http://10.0.2.2/RADIODOLIV_PAGINA` on Android emulator, `http://localhost/RADIODOLIV_PAGINA` otherwise.
- Auth: `POST /user/login` with header `X-Client-Features: login-object` → `{token, emailVerified}`; `GET /user/me` must return `role == 'director'` or access is denied.
- All authenticated requests send `Authorization: Bearer <token>`.
- Create/update requests are `multipart/form-data`, never JSON (backend reads `$_POST`/`$_FILES` directly).
- 401 on any call → clear session, navigate to `LoginScreen`. 403 → show "No tienes permiso para esta acción". Other 4xx/5xx → show the backend's `error` message. Network failure → show "No se pudo conectar".
- Testing scope is intentionally minimal per the approved spec: automated tests only for `Session`, `ApiClient`, the 7 models' `fromJson`, `LoginScreen`, and `AnunciosListScreen`. Every other screen is verified with `flutter analyze` (must stay clean) plus a manual run against the local XAMPP backend — do not add automated tests beyond what each task specifies.
- No new state-management package (no Provider/Riverpod/Bloc) and no code generation — keep it beginner-readable per the spec.

---

## Task 1: Project setup — dependencies, API config, session storage

**Files:**
- Modify: `pubspec.yaml`
- Create: `lib/core/api_config.dart`
- Create: `lib/core/session.dart`
- Test: `test/core/session_test.dart`

**Interfaces:**
- Produces: `ApiConfig.backendBaseUrl` (String getter), `ApiConfig.siteBaseUrl` (String getter), `ApiConfig.imageUrl(String? relativePath)` (String).
- Produces: `Session.saveToken(String token)` (Future<void>), `Session.readToken()` (Future<String?>), `Session.clearToken()` (Future<void>).

- [ ] **Step 1: Add dependencies**

Edit `pubspec.yaml`, in the `dependencies:` block (after `cupertino_icons: ^1.0.8`):

```yaml
  http: ^1.2.2
  shared_preferences: ^2.3.3
  image_picker: ^1.1.2
```

Run: `flutter pub get`
Expected: resolves cleanly, `pubspec.lock` updates.

- [ ] **Step 2: Write the failing test for Session**

Create `test/core/session_test.dart`:

```dart
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:doliv_social/core/session.dart';

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  test('readToken returns null when nothing was saved', () async {
    expect(await Session.readToken(), isNull);
  });

  test('saveToken then readToken returns the same value', () async {
    await Session.saveToken('abc123');
    expect(await Session.readToken(), 'abc123');
  });

  test('clearToken removes the saved value', () async {
    await Session.saveToken('abc123');
    await Session.clearToken();
    expect(await Session.readToken(), isNull);
  });
}
```

- [ ] **Step 3: Run test to verify it fails**

Run: `flutter test test/core/session_test.dart`
Expected: FAIL — `lib/core/session.dart` does not exist / `Session` undefined.

- [ ] **Step 4: Implement `ApiConfig`**

Create `lib/core/api_config.dart`:

```dart
import 'dart:io' show Platform;

class ApiConfig {
  static String get backendBaseUrl {
    if (!Platform.isAndroid) return 'http://localhost/hive-backend';
    return 'http://10.0.2.2/hive-backend';
  }

  static String get siteBaseUrl {
    if (!Platform.isAndroid) return 'http://localhost/RADIODOLIV_PAGINA';
    return 'http://10.0.2.2/RADIODOLIV_PAGINA';
  }

  static String imageUrl(String? relativePath) {
    if (relativePath == null || relativePath.isEmpty) return '';
    return '$siteBaseUrl/$relativePath';
  }
}
```

- [ ] **Step 5: Implement `Session`**

Create `lib/core/session.dart`:

```dart
import 'package:shared_preferences/shared_preferences.dart';

class Session {
  static const _tokenKey = 'auth_token';

  static Future<void> saveToken(String token) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_tokenKey, token);
  }

  static Future<String?> readToken() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_tokenKey);
  }

  static Future<void> clearToken() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_tokenKey);
  }
}
```

- [ ] **Step 6: Run test to verify it passes**

Run: `flutter test test/core/session_test.dart`
Expected: PASS (3 tests).

- [ ] **Step 7: Commit**

```bash
git add pubspec.yaml pubspec.lock lib/core/api_config.dart lib/core/session.dart test/core/session_test.dart
git commit -m "feat: add http/shared_preferences/image_picker deps, ApiConfig, Session"
```

---

## Task 2: API client

**Files:**
- Create: `lib/core/api_client.dart`
- Test: `test/core/api_client_test.dart`

**Interfaces:**
- Consumes: `ApiConfig.backendBaseUrl` (Task 1), `Session.readToken()` (Task 1).
- Produces: `class ApiException implements Exception { final String message; final int? statusCode; }`.
- Produces: `class ApiClient { ApiClient({http.Client? client}); Future<Map<String,dynamic>> get(String path); Future<Map<String,dynamic>> postJson(String path, Map<String,dynamic> body, {Map<String,String>? extraHeaders}); Future<Map<String,dynamic>> postMultipart(String path, Map<String,String> fields, {String? fileField, File? file}); }`.

- [ ] **Step 1: Write the failing tests**

Create `test/core/api_client_test.dart`:

```dart
import 'dart:convert';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:doliv_social/core/api_client.dart';
import 'package:doliv_social/core/session.dart';

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  test('get() sends the Authorization header and decodes JSON', () async {
    await Session.saveToken('tok123');
    String? sentAuthHeader;
    final client = MockClient((request) async {
      sentAuthHeader = request.headers['Authorization'];
      return http.Response(jsonEncode({'items': []}), 200);
    });

    final api = ApiClient(client: client);
    final result = await api.get('/site/anuncios');

    expect(sentAuthHeader, 'Bearer tok123');
    expect(result, {'items': []});
  });

  test('postJson sends extra headers and JSON body', () async {
    Map<String, dynamic>? sentBody;
    final client = MockClient((request) async {
      sentBody = jsonDecode(request.body) as Map<String, dynamic>;
      expect(request.headers['X-Client-Features'], 'login-object');
      return http.Response(jsonEncode({'token': 'abc'}), 200);
    });

    final api = ApiClient(client: client);
    final result = await api.postJson(
      '/user/login',
      {'email': 'a@b.com', 'password': 'x'},
      extraHeaders: {'X-Client-Features': 'login-object'},
    );

    expect(sentBody, {'email': 'a@b.com', 'password': 'x'});
    expect(result, {'token': 'abc'});
  });

  test('throws ApiException with backend message on 400', () async {
    final client = MockClient((request) async {
      return http.Response(jsonEncode({'error': 'titulo es requerido'}), 400);
    });
    final api = ApiClient(client: client);

    expect(
      () => api.postJson('/site/anuncios', {}),
      throwsA(isA<ApiException>().having((e) => e.message, 'message', 'titulo es requerido')),
    );
  });

  test('throws ApiException with statusCode 401 on unauthorized', () async {
    final client = MockClient((request) async => http.Response('{}', 401));
    final api = ApiClient(client: client);

    expect(
      () => api.get('/site/anuncios'),
      throwsA(isA<ApiException>().having((e) => e.statusCode, 'statusCode', 401)),
    );
  });
}
```

- [ ] **Step 2: Run tests to verify they fail**

Run: `flutter test test/core/api_client_test.dart`
Expected: FAIL — `lib/core/api_client.dart` does not exist.

- [ ] **Step 3: Implement `ApiClient`**

Create `lib/core/api_client.dart`:

```dart
import 'dart:convert';
import 'dart:io';
import 'package:http/http.dart' as http;
import 'api_config.dart';
import 'session.dart';

class ApiException implements Exception {
  final String message;
  final int? statusCode;
  ApiException(this.message, [this.statusCode]);

  @override
  String toString() => message;
}

class ApiClient {
  final http.Client _client;
  ApiClient({http.Client? client}) : _client = client ?? http.Client();

  Future<Map<String, dynamic>> get(String path) async {
    final headers = await _authHeaders();
    final response = await _client.get(_uri(path), headers: headers);
    return _decode(response);
  }

  Future<Map<String, dynamic>> postJson(
    String path,
    Map<String, dynamic> body, {
    Map<String, String>? extraHeaders,
  }) async {
    final headers = await _authHeaders();
    headers['Content-Type'] = 'application/json';
    if (extraHeaders != null) headers.addAll(extraHeaders);
    final response = await _client.post(_uri(path), headers: headers, body: jsonEncode(body));
    return _decode(response);
  }

  Future<Map<String, dynamic>> postMultipart(
    String path,
    Map<String, String> fields, {
    String? fileField,
    File? file,
  }) async {
    final request = http.MultipartRequest('POST', _uri(path));
    request.headers.addAll(await _authHeaders());
    request.fields.addAll(fields);
    if (fileField != null && file != null) {
      request.files.add(await http.MultipartFile.fromPath(fileField, file.path));
    }
    final streamed = await _client.send(request);
    final response = await http.Response.fromStream(streamed);
    return _decode(response);
  }

  Uri _uri(String path) => Uri.parse('${ApiConfig.backendBaseUrl}$path');

  Future<Map<String, String>> _authHeaders() async {
    final token = await Session.readToken();
    return {if (token != null) 'Authorization': 'Bearer $token'};
  }

  Map<String, dynamic> _decode(http.Response response) {
    Map<String, dynamic> body;
    try {
      body = response.body.isEmpty ? <String, dynamic>{} : jsonDecode(response.body) as Map<String, dynamic>;
    } catch (_) {
      throw ApiException('Respuesta inválida del servidor', response.statusCode);
    }
    if (response.statusCode == 401) {
      throw ApiException('Sesión expirada', 401);
    }
    if (response.statusCode == 403) {
      throw ApiException('No tienes permiso para esta acción', 403);
    }
    if (response.statusCode >= 400) {
      throw ApiException((body['error'] ?? 'Error desconocido').toString(), response.statusCode);
    }
    return body;
  }
}
```

- [ ] **Step 4: Run tests to verify they pass**

Run: `flutter test test/core/api_client_test.dart`
Expected: PASS (4 tests).

- [ ] **Step 5: Commit**

```bash
git add lib/core/api_client.dart test/core/api_client_test.dart
git commit -m "feat: add ApiClient with get/postJson/postMultipart and error decoding"
```

---

## Task 3: Content models

**Files:**
- Create: `lib/models/anuncio.dart`
- Create: `lib/models/evento.dart`
- Create: `lib/models/servicio.dart`
- Create: `lib/models/integrante.dart`
- Create: `lib/models/programa.dart`
- Create: `lib/models/patrocinador.dart`
- Create: `lib/models/podcast.dart`
- Test: `test/models/models_test.dart`

**Interfaces:**
- Produces (each has `id`, `fromJson(Map<String,dynamic>)`, `toFields()` → `Map<String,String>` with the exact backend field names used by `site_content.php`):
  - `Anuncio {id, titulo, descripcion, imagenUrl, linkWeb, linkFacebook, linkWhatsapp, fechaPublicacion}`
  - `Evento {id, title, artist, location, weekday, day, month, year, eventDate, timeLabel, description, image, sortOrder}`
  - `Servicio {id, title, image, description, whatsappUrl, category, icon, sortOrder}`
  - `Integrante {id, name, role, category, accent, image, shortDesc, bio, path, interests, sortOrder}`
  - `Programa {id, title, modalTitle, host, schedule, slotStart, slotEnd, weekdays, badgeIcon, badgeTime, badgeLabel, accent, icon, image, categories, cardDesc, indexDesc, summary, sortOrder}`
  - `Patrocinador {id, name, category, categoryLabel, icon, image, subtitle, summary, description, map, sortOrder, socials: List<SponsorSocial>}`, `SponsorSocial {label, icon, url}`
  - `Podcast {id, title, filterIcon, cover, sortOrder, episodes: List<PodcastEpisode>}`, `PodcastEpisode {title, description, audioUrl, categoryLabel}`

- [ ] **Step 1: Write the failing tests**

Create `test/models/models_test.dart`:

```dart
import 'package:flutter_test/flutter_test.dart';
import 'package:doliv_social/models/anuncio.dart';
import 'package:doliv_social/models/evento.dart';
import 'package:doliv_social/models/servicio.dart';
import 'package:doliv_social/models/integrante.dart';
import 'package:doliv_social/models/programa.dart';
import 'package:doliv_social/models/patrocinador.dart';
import 'package:doliv_social/models/podcast.dart';

void main() {
  test('Anuncio.fromJson parses backend row', () {
    final a = Anuncio.fromJson({
      'id': '3', 'titulo': 'Promo', 'descripcion': 'desc', 'imagen_url': 'x.jpg',
      'link_web': '', 'link_facebook': '', 'link_whatsapp': '', 'fecha_publicacion': '2026-01-01',
    });
    expect(a.id, 3);
    expect(a.titulo, 'Promo');
    expect(a.imagenUrl, 'x.jpg');
  });

  test('Evento.fromJson parses backend row', () {
    final e = Evento.fromJson({
      'id': 1, 'title': 'Concierto', 'artist': 'X', 'location': 'Plaza', 'weekday': '',
      'day': '', 'month': '', 'year': '', 'event_date': null, 'time_label': '20:00',
      'description': '', 'image': null, 'sort_order': 2,
    });
    expect(e.title, 'Concierto');
    expect(e.sortOrder, 2);
  });

  test('Servicio.fromJson parses backend row', () {
    final s = Servicio.fromJson({
      'id': 1, 'title': 'Publicidad', 'image': null, 'description': '', 'whatsapp_url': '',
      'category': 'ventas', 'icon': '', 'sort_order': 0,
    });
    expect(s.category, 'ventas');
  });

  test('Integrante.fromJson parses backend row', () {
    final i = Integrante.fromJson({
      'id': 1, 'name': 'Juan', 'role': 'Locutor', 'category': '', 'accent': '', 'image': null,
      'short_desc': '', 'bio': 'linea1\nlinea2', 'path': '', 'interests': '', 'sort_order': 0,
    });
    expect(i.name, 'Juan');
    expect(i.bio, 'linea1\nlinea2');
  });

  test('Programa.fromJson parses backend row', () {
    final p = Programa.fromJson({
      'id': 1, 'title': 'Mañanas', 'modal_title': '', 'host': 'Ana', 'schedule': '',
      'slot_start': 6, 'slot_end': 9, 'weekdays': '1,2,3', 'badge_icon': '', 'badge_time': '',
      'badge_label': '', 'accent': '', 'icon': '', 'image': null, 'categories': '',
      'card_desc': '', 'index_desc': '', 'summary': '', 'sort_order': 0,
    });
    expect(p.host, 'Ana');
    expect(p.slotStart, 6);
  });

  test('Patrocinador.fromJson parses backend row with socials', () {
    final sp = Patrocinador.fromJson({
      'id': 1, 'name': 'Cafe X', 'category': '', 'category_label': '', 'icon': '', 'image': null,
      'subtitle': '', 'summary': '', 'description': '', 'map': '', 'sort_order': 0,
      'socials': [
        {'label': 'Facebook', 'icon': 'fb', 'url': 'https://fb.com/x'},
      ],
    });
    expect(sp.name, 'Cafe X');
    expect(sp.socials.length, 1);
    expect(sp.socials.first.label, 'Facebook');
  });

  test('Podcast.fromJson parses backend row with episodes', () {
    final pod = Podcast.fromJson({
      'id': 1, 'title': 'Noticias', 'filter_icon': '', 'cover': null, 'sort_order': 0,
      'episodes': [
        {'title': 'Ep 1', 'description': '', 'audio_url': 'x.mp3', 'category_label': ''},
      ],
    });
    expect(pod.title, 'Noticias');
    expect(pod.episodes.single.audioUrl, 'x.mp3');
  });
}
```

- [ ] **Step 2: Run tests to verify they fail**

Run: `flutter test test/models/models_test.dart`
Expected: FAIL — none of the model files exist yet.

- [ ] **Step 3: Implement the models**

Create `lib/models/anuncio.dart`:

```dart
class Anuncio {
  final int id;
  final String titulo;
  final String descripcion;
  final String? imagenUrl;
  final String linkWeb;
  final String linkFacebook;
  final String linkWhatsapp;
  final String fechaPublicacion;

  Anuncio({
    required this.id,
    required this.titulo,
    required this.descripcion,
    required this.imagenUrl,
    required this.linkWeb,
    required this.linkFacebook,
    required this.linkWhatsapp,
    required this.fechaPublicacion,
  });

  factory Anuncio.fromJson(Map<String, dynamic> json) => Anuncio(
        id: int.parse(json['id'].toString()),
        titulo: (json['titulo'] ?? '') as String,
        descripcion: (json['descripcion'] ?? '') as String,
        imagenUrl: json['imagen_url'] as String?,
        linkWeb: (json['link_web'] ?? '') as String,
        linkFacebook: (json['link_facebook'] ?? '') as String,
        linkWhatsapp: (json['link_whatsapp'] ?? '') as String,
        fechaPublicacion: (json['fecha_publicacion'] ?? '') as String,
      );

  Map<String, String> toFields() => {
        'titulo': titulo,
        'descripcion': descripcion,
        'link_web': linkWeb,
        'link_facebook': linkFacebook,
        'link_whatsapp': linkWhatsapp,
        'fecha_publicacion': fechaPublicacion,
      };
}
```

Create `lib/models/evento.dart`:

```dart
class Evento {
  final int id;
  final String title;
  final String artist;
  final String location;
  final String weekday;
  final String day;
  final String month;
  final String year;
  final String eventDate;
  final String timeLabel;
  final String description;
  final String? image;
  final int sortOrder;

  Evento({
    required this.id,
    required this.title,
    required this.artist,
    required this.location,
    required this.weekday,
    required this.day,
    required this.month,
    required this.year,
    required this.eventDate,
    required this.timeLabel,
    required this.description,
    required this.image,
    required this.sortOrder,
  });

  factory Evento.fromJson(Map<String, dynamic> json) => Evento(
        id: int.parse(json['id'].toString()),
        title: (json['title'] ?? '') as String,
        artist: (json['artist'] ?? '') as String,
        location: (json['location'] ?? '') as String,
        weekday: (json['weekday'] ?? '') as String,
        day: (json['day'] ?? '') as String,
        month: (json['month'] ?? '') as String,
        year: (json['year'] ?? '') as String,
        eventDate: (json['event_date'] ?? '') as String,
        timeLabel: (json['time_label'] ?? '') as String,
        description: (json['description'] ?? '') as String,
        image: json['image'] as String?,
        sortOrder: int.parse((json['sort_order'] ?? 0).toString()),
      );

  Map<String, String> toFields() => {
        'title': title,
        'artist': artist,
        'location': location,
        'weekday': weekday,
        'day': day,
        'month': month,
        'year': year,
        'event_date': eventDate,
        'time_label': timeLabel,
        'description': description,
        'sort_order': sortOrder.toString(),
      };
}
```

Create `lib/models/servicio.dart`:

```dart
class Servicio {
  final int id;
  final String title;
  final String? image;
  final String description;
  final String whatsappUrl;
  final String category;
  final String icon;
  final int sortOrder;

  Servicio({
    required this.id,
    required this.title,
    required this.image,
    required this.description,
    required this.whatsappUrl,
    required this.category,
    required this.icon,
    required this.sortOrder,
  });

  factory Servicio.fromJson(Map<String, dynamic> json) => Servicio(
        id: int.parse(json['id'].toString()),
        title: (json['title'] ?? '') as String,
        image: json['image'] as String?,
        description: (json['description'] ?? '') as String,
        whatsappUrl: (json['whatsapp_url'] ?? '') as String,
        category: (json['category'] ?? '') as String,
        icon: (json['icon'] ?? '') as String,
        sortOrder: int.parse((json['sort_order'] ?? 0).toString()),
      );

  Map<String, String> toFields() => {
        'title': title,
        'description': description,
        'whatsapp_url': whatsappUrl,
        'category': category,
        'icon': icon,
        'sort_order': sortOrder.toString(),
      };
}
```

Create `lib/models/integrante.dart`:

```dart
class Integrante {
  final int id;
  final String name;
  final String role;
  final String category;
  final String accent;
  final String? image;
  final String shortDesc;
  final String bio;
  final String path;
  final String interests;
  final int sortOrder;

  Integrante({
    required this.id,
    required this.name,
    required this.role,
    required this.category,
    required this.accent,
    required this.image,
    required this.shortDesc,
    required this.bio,
    required this.path,
    required this.interests,
    required this.sortOrder,
  });

  factory Integrante.fromJson(Map<String, dynamic> json) => Integrante(
        id: int.parse(json['id'].toString()),
        name: (json['name'] ?? '') as String,
        role: (json['role'] ?? '') as String,
        category: (json['category'] ?? '') as String,
        accent: (json['accent'] ?? '') as String,
        image: json['image'] as String?,
        shortDesc: (json['short_desc'] ?? '') as String,
        bio: (json['bio'] ?? '') as String,
        path: (json['path'] ?? '') as String,
        interests: (json['interests'] ?? '') as String,
        sortOrder: int.parse((json['sort_order'] ?? 0).toString()),
      );

  Map<String, String> toFields() => {
        'name': name,
        'role': role,
        'category': category,
        'accent': accent,
        'short_desc': shortDesc,
        'bio': bio,
        'path': path,
        'interests': interests,
        'sort_order': sortOrder.toString(),
      };
}
```

Create `lib/models/programa.dart`:

```dart
class Programa {
  final int id;
  final String title;
  final String modalTitle;
  final String host;
  final String schedule;
  final int? slotStart;
  final int? slotEnd;
  final String weekdays;
  final String badgeIcon;
  final String badgeTime;
  final String badgeLabel;
  final String accent;
  final String icon;
  final String? image;
  final String categories;
  final String cardDesc;
  final String indexDesc;
  final String summary;
  final int sortOrder;

  Programa({
    required this.id,
    required this.title,
    required this.modalTitle,
    required this.host,
    required this.schedule,
    required this.slotStart,
    required this.slotEnd,
    required this.weekdays,
    required this.badgeIcon,
    required this.badgeTime,
    required this.badgeLabel,
    required this.accent,
    required this.icon,
    required this.image,
    required this.categories,
    required this.cardDesc,
    required this.indexDesc,
    required this.summary,
    required this.sortOrder,
  });

  factory Programa.fromJson(Map<String, dynamic> json) => Programa(
        id: int.parse(json['id'].toString()),
        title: (json['title'] ?? '') as String,
        modalTitle: (json['modal_title'] ?? '') as String,
        host: (json['host'] ?? '') as String,
        schedule: (json['schedule'] ?? '') as String,
        slotStart: json['slot_start'] == null ? null : int.parse(json['slot_start'].toString()),
        slotEnd: json['slot_end'] == null ? null : int.parse(json['slot_end'].toString()),
        weekdays: (json['weekdays'] ?? '') as String,
        badgeIcon: (json['badge_icon'] ?? '') as String,
        badgeTime: (json['badge_time'] ?? '') as String,
        badgeLabel: (json['badge_label'] ?? '') as String,
        accent: (json['accent'] ?? '') as String,
        icon: (json['icon'] ?? '') as String,
        image: json['image'] as String?,
        categories: (json['categories'] ?? '') as String,
        cardDesc: (json['card_desc'] ?? '') as String,
        indexDesc: (json['index_desc'] ?? '') as String,
        summary: (json['summary'] ?? '') as String,
        sortOrder: int.parse((json['sort_order'] ?? 0).toString()),
      );

  Map<String, String> toFields() => {
        'title': title,
        'modal_title': modalTitle,
        'host': host,
        'schedule': schedule,
        'slot_start': slotStart?.toString() ?? '',
        'slot_end': slotEnd?.toString() ?? '',
        'weekdays': weekdays,
        'badge_icon': badgeIcon,
        'badge_time': badgeTime,
        'badge_label': badgeLabel,
        'accent': accent,
        'icon': icon,
        'categories': categories,
        'card_desc': cardDesc,
        'index_desc': indexDesc,
        'summary': summary,
        'sort_order': sortOrder.toString(),
      };
}
```

Create `lib/models/patrocinador.dart`:

```dart
class SponsorSocial {
  final String label;
  final String icon;
  final String url;

  SponsorSocial({required this.label, required this.icon, required this.url});

  factory SponsorSocial.fromJson(Map<String, dynamic> json) => SponsorSocial(
        label: (json['label'] ?? '') as String,
        icon: (json['icon'] ?? '') as String,
        url: (json['url'] ?? '') as String,
      );

  Map<String, dynamic> toJson() => {'label': label, 'icon': icon, 'url': url};
}

class Patrocinador {
  final int id;
  final String name;
  final String category;
  final String categoryLabel;
  final String icon;
  final String? image;
  final String subtitle;
  final String summary;
  final String description;
  final String map;
  final int sortOrder;
  final List<SponsorSocial> socials;

  Patrocinador({
    required this.id,
    required this.name,
    required this.category,
    required this.categoryLabel,
    required this.icon,
    required this.image,
    required this.subtitle,
    required this.summary,
    required this.description,
    required this.map,
    required this.sortOrder,
    required this.socials,
  });

  factory Patrocinador.fromJson(Map<String, dynamic> json) => Patrocinador(
        id: int.parse(json['id'].toString()),
        name: (json['name'] ?? '') as String,
        category: (json['category'] ?? '') as String,
        categoryLabel: (json['category_label'] ?? '') as String,
        icon: (json['icon'] ?? '') as String,
        image: json['image'] as String?,
        subtitle: (json['subtitle'] ?? '') as String,
        summary: (json['summary'] ?? '') as String,
        description: (json['description'] ?? '') as String,
        map: (json['map'] ?? '') as String,
        sortOrder: int.parse((json['sort_order'] ?? 0).toString()),
        socials: ((json['socials'] as List?) ?? [])
            .map((e) => SponsorSocial.fromJson(e as Map<String, dynamic>))
            .toList(),
      );

  Map<String, String> toFields() => {
        'name': name,
        'category': category,
        'category_label': categoryLabel,
        'icon': icon,
        'subtitle': subtitle,
        'summary': summary,
        'description': description,
        'map': map,
        'sort_order': sortOrder.toString(),
      };
}
```

Create `lib/models/podcast.dart`:

```dart
class PodcastEpisode {
  final String title;
  final String description;
  final String audioUrl;
  final String categoryLabel;

  PodcastEpisode({
    required this.title,
    required this.description,
    required this.audioUrl,
    required this.categoryLabel,
  });

  factory PodcastEpisode.fromJson(Map<String, dynamic> json) => PodcastEpisode(
        title: (json['title'] ?? '') as String,
        description: (json['description'] ?? '') as String,
        audioUrl: (json['audio_url'] ?? '') as String,
        categoryLabel: (json['category_label'] ?? '') as String,
      );

  Map<String, dynamic> toJson() => {
        'title': title,
        'description': description,
        'audio_url': audioUrl,
        'category_label': categoryLabel,
      };
}

class Podcast {
  final int id;
  final String title;
  final String filterIcon;
  final String? cover;
  final int sortOrder;
  final List<PodcastEpisode> episodes;

  Podcast({
    required this.id,
    required this.title,
    required this.filterIcon,
    required this.cover,
    required this.sortOrder,
    required this.episodes,
  });

  factory Podcast.fromJson(Map<String, dynamic> json) => Podcast(
        id: int.parse(json['id'].toString()),
        title: (json['title'] ?? '') as String,
        filterIcon: (json['filter_icon'] ?? '') as String,
        cover: json['cover'] as String?,
        sortOrder: int.parse((json['sort_order'] ?? 0).toString()),
        episodes: ((json['episodes'] as List?) ?? [])
            .map((e) => PodcastEpisode.fromJson(e as Map<String, dynamic>))
            .toList(),
      );

  Map<String, String> toFields() => {
        'title': title,
        'filter_icon': filterIcon,
        'sort_order': sortOrder.toString(),
      };
}
```

- [ ] **Step 4: Run tests to verify they pass**

Run: `flutter test test/models/models_test.dart`
Expected: PASS (7 tests).

- [ ] **Step 5: Commit**

```bash
git add lib/models test/models/models_test.dart
git commit -m "feat: add content models for the 7 site sections"
```

---

## Task 4: Shared UI widgets

**Files:**
- Create: `lib/widgets/content_list_tile.dart`
- Create: `lib/widgets/labeled_text_field.dart`
- Create: `lib/widgets/image_picker_field.dart`

**Interfaces:**
- Consumes: `ApiConfig.imageUrl(String?)` (Task 1).
- Produces: `ContentListTile({title, subtitle, imageUrl, onEdit, onDelete})`.
- Produces: `LabeledTextField({controller, label, validator, maxLines, keyboardType})`.
- Produces: `ImagePickerField({currentImageUrl, onImageSelected})` where `onImageSelected` is `ValueChanged<File?>`.

No automated tests for this task (pure presentational widgets, one of them wraps a plugin that needs a real device) — verified via `flutter analyze` and visually once wired into a screen in later tasks.

- [ ] **Step 1: Implement `ContentListTile`**

Create `lib/widgets/content_list_tile.dart`:

```dart
import 'package:flutter/material.dart';
import '../core/api_config.dart';

class ContentListTile extends StatelessWidget {
  const ContentListTile({
    super.key,
    required this.title,
    this.subtitle,
    this.imageUrl,
    required this.onEdit,
    required this.onDelete,
  });

  final String title;
  final String? subtitle;
  final String? imageUrl;
  final VoidCallback onEdit;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    final hasImage = imageUrl != null && imageUrl!.isNotEmpty;
    return ListTile(
      leading: hasImage
          ? CircleAvatar(backgroundImage: NetworkImage(ApiConfig.imageUrl(imageUrl)))
          : const CircleAvatar(child: Icon(Icons.image_not_supported)),
      title: Text(title),
      subtitle: (subtitle == null || subtitle!.isEmpty)
          ? null
          : Text(subtitle!, maxLines: 1, overflow: TextOverflow.ellipsis),
      trailing: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          IconButton(icon: const Icon(Icons.edit), onPressed: onEdit),
          IconButton(icon: const Icon(Icons.delete), onPressed: onDelete),
        ],
      ),
    );
  }
}
```

- [ ] **Step 2: Implement `LabeledTextField`**

Create `lib/widgets/labeled_text_field.dart`:

```dart
import 'package:flutter/material.dart';

class LabeledTextField extends StatelessWidget {
  const LabeledTextField({
    super.key,
    required this.controller,
    required this.label,
    this.validator,
    this.maxLines = 1,
    this.keyboardType,
  });

  final TextEditingController controller;
  final String label;
  final String? Function(String?)? validator;
  final int maxLines;
  final TextInputType? keyboardType;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: TextFormField(
        controller: controller,
        decoration: InputDecoration(labelText: label, border: const OutlineInputBorder()),
        validator: validator,
        maxLines: maxLines,
        keyboardType: keyboardType,
      ),
    );
  }
}
```

- [ ] **Step 3: Implement `ImagePickerField`**

Create `lib/widgets/image_picker_field.dart`:

```dart
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import '../core/api_config.dart';

class ImagePickerField extends StatefulWidget {
  const ImagePickerField({super.key, this.currentImageUrl, required this.onImageSelected});

  final String? currentImageUrl;
  final ValueChanged<File?> onImageSelected;

  @override
  State<ImagePickerField> createState() => _ImagePickerFieldState();
}

class _ImagePickerFieldState extends State<ImagePickerField> {
  File? _selected;

  Future<void> _pick() async {
    final picked = await ImagePicker().pickImage(source: ImageSource.gallery);
    if (picked == null) return;
    setState(() => _selected = File(picked.path));
    widget.onImageSelected(_selected);
  }

  @override
  Widget build(BuildContext context) {
    final hasExisting = widget.currentImageUrl != null && widget.currentImageUrl!.isNotEmpty;
    return Column(
      children: [
        if (_selected != null)
          Image.file(_selected!, height: 140, fit: BoxFit.cover)
        else if (hasExisting)
          Image.network(ApiConfig.imageUrl(widget.currentImageUrl), height: 140, fit: BoxFit.cover)
        else
          Container(
            height: 140,
            color: Colors.grey.shade200,
            child: const Center(child: Icon(Icons.image, size: 48)),
          ),
        const SizedBox(height: 8),
        OutlinedButton.icon(
          onPressed: _pick,
          icon: const Icon(Icons.photo_library),
          label: Text(hasExisting || _selected != null ? 'Cambiar imagen' : 'Elegir imagen'),
        ),
      ],
    );
  }
}
```

- [ ] **Step 4: Verify static analysis is clean**

Run: `flutter analyze lib/widgets`
Expected: `No issues found!`

- [ ] **Step 5: Commit**

```bash
git add lib/widgets
git commit -m "feat: add shared ContentListTile, LabeledTextField, ImagePickerField widgets"
```

---

## Task 5: Auth guard, login screen, app entrypoint

**Files:**
- Create: `lib/screens/login_screen.dart`
- Create: `lib/core/auth_guard.dart`
- Modify: `lib/main.dart`
- Test: `test/screens/login_screen_test.dart`

**Interfaces:**
- Consumes: `ApiClient`, `ApiException` (Task 2), `Session` (Task 1).
- Produces: `LoginScreen({Key? key, ApiClient? apiClient})`, navigates to `HomeScreen` (Task 6) on success.
- Produces: `Future<void> handleApiError(BuildContext context, Object error)` in `lib/core/auth_guard.dart` — on `ApiException` with `statusCode == 401`, clears the session and replaces the whole navigation stack with `LoginScreen`; otherwise shows a `SnackBar` with `error.toString()` (or "No se pudo conectar" for non-`ApiException` errors). Every later screen (Tasks 6–13) calls this from its `catch` blocks.

- [ ] **Step 1: Write the failing test**

Create `test/screens/login_screen_test.dart`:

```dart
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:doliv_social/core/api_client.dart';
import 'package:doliv_social/screens/login_screen.dart';

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  testWidgets('shows validation errors on empty submit', (tester) async {
    final client = MockClient((request) async => http.Response('{}', 200));
    await tester.pumpWidget(MaterialApp(home: LoginScreen(apiClient: ApiClient(client: client))));

    await tester.tap(find.text('Entrar'));
    await tester.pump();

    expect(find.text('Ingresa tu correo'), findsOneWidget);
    expect(find.text('Ingresa tu contraseña'), findsOneWidget);
  });

  testWidgets('shows error when logged-in user is not a director', (tester) async {
    final client = MockClient((request) async {
      if (request.url.path.endsWith('/user/login')) {
        return http.Response(jsonEncode({'token': 'tok', 'emailVerified': true}), 200);
      }
      return http.Response(jsonEncode({'role': 'employee'}), 200);
    });
    await tester.pumpWidget(MaterialApp(home: LoginScreen(apiClient: ApiClient(client: client))));

    await tester.enterText(find.byKey(const Key('email_field')), 'a@b.com');
    await tester.enterText(find.byKey(const Key('password_field')), 'secret');
    await tester.tap(find.text('Entrar'));
    await tester.pumpAndSettle();

    expect(find.text('Esta cuenta no tiene permisos de administrador'), findsOneWidget);
  });
}
```

- [ ] **Step 2: Run test to verify it fails**

Run: `flutter test test/screens/login_screen_test.dart`
Expected: FAIL — `lib/screens/login_screen.dart` does not exist.

- [ ] **Step 3: Implement `LoginScreen`**

Create `lib/screens/login_screen.dart`:

```dart
import 'package:flutter/material.dart';
import '../core/api_client.dart';
import '../core/session.dart';
import 'home_screen.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key, this.apiClient});
  final ApiClient? apiClient;

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _formKey = GlobalKey<FormState>();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  late final ApiClient _api = widget.apiClient ?? ApiClient();
  bool _loading = false;
  String? _error;

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final loginResponse = await _api.postJson(
        '/user/login',
        {'email': _emailController.text.trim(), 'password': _passwordController.text},
        extraHeaders: {'X-Client-Features': 'login-object'},
      );
      final token = loginResponse['token'] as String;
      await Session.saveToken(token);

      final me = await _api.get('/user/me');
      if (me['role'] != 'director') {
        await Session.clearToken();
        setState(() {
          _error = 'Esta cuenta no tiene permisos de administrador';
          _loading = false;
        });
        return;
      }

      if (!mounted) return;
      Navigator.of(context).pushReplacement(MaterialPageRoute(builder: (_) => const HomeScreen()));
    } catch (e) {
      setState(() {
        _error = e.toString();
        _loading = false;
      });
    }
  }

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Radio Doliv — Admin')),
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 360),
            child: Form(
              key: _formKey,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  TextFormField(
                    key: const Key('email_field'),
                    controller: _emailController,
                    decoration: const InputDecoration(labelText: 'Correo'),
                    keyboardType: TextInputType.emailAddress,
                    validator: (v) => (v == null || v.trim().isEmpty) ? 'Ingresa tu correo' : null,
                  ),
                  const SizedBox(height: 16),
                  TextFormField(
                    key: const Key('password_field'),
                    controller: _passwordController,
                    decoration: const InputDecoration(labelText: 'Contraseña'),
                    obscureText: true,
                    validator: (v) => (v == null || v.isEmpty) ? 'Ingresa tu contraseña' : null,
                  ),
                  const SizedBox(height: 24),
                  if (_error != null)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 16),
                      child: Text(_error!, style: const TextStyle(color: Colors.red)),
                    ),
                  ElevatedButton(
                    onPressed: _loading ? null : _submit,
                    child: _loading
                        ? const SizedBox(
                            height: 20,
                            width: 20,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Text('Entrar'),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
```

- [ ] **Step 4: Implement `handleApiError`**

Create `lib/core/auth_guard.dart`:

```dart
import 'package:flutter/material.dart';
import 'api_client.dart';
import 'session.dart';
import '../screens/login_screen.dart';

Future<void> handleApiError(BuildContext context, Object error) async {
  if (error is ApiException && error.statusCode == 401) {
    await Session.clearToken();
    if (!context.mounted) return;
    Navigator.of(context).pushAndRemoveUntil(
      MaterialPageRoute(builder: (_) => const LoginScreen()),
      (route) => false,
    );
    return;
  }
  final message = error is ApiException ? error.message : 'No se pudo conectar';
  if (!context.mounted) return;
  ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message)));
}
```

- [ ] **Step 5: Wire up `main.dart`**

Replace the contents of `lib/main.dart` with:

```dart
import 'package:flutter/material.dart';
import 'core/session.dart';
import 'screens/login_screen.dart';
import 'screens/home_screen.dart';

void main() {
  runApp(const AdminApp());
}

class AdminApp extends StatelessWidget {
  const AdminApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Radio Doliv Admin',
      theme: ThemeData(colorSchemeSeed: Colors.blue, useMaterial3: true),
      home: const _StartupGate(),
    );
  }
}

class _StartupGate extends StatelessWidget {
  const _StartupGate();

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<String?>(
      future: Session.readToken(),
      builder: (context, snapshot) {
        if (snapshot.connectionState != ConnectionState.done) {
          return const Scaffold(body: Center(child: CircularProgressIndicator()));
        }
        return snapshot.data != null ? const HomeScreen() : const LoginScreen();
      },
    );
  }
}
```

Note: `HomeScreen` does not exist yet (Task 6) — this task will not compile standalone. That is expected; Task 6 completes it. Do not run `flutter analyze` on the whole project until Task 6 is done — scope Step 6 below to the login test file only.

- [ ] **Step 6: Run test to verify it passes**

Run: `flutter test test/screens/login_screen_test.dart`
Expected: PASS (2 tests). (This test only imports `login_screen.dart`, not `main.dart`, so the missing `HomeScreen` does not block it — `login_screen.dart` imports `home_screen.dart` too, so create a minimal placeholder first if needed. To keep this task independently green, create `lib/screens/home_screen.dart` now with a minimal `HomeScreen extends StatelessWidget` that just returns `Scaffold(appBar: AppBar(title: const Text('Radio Doliv — Admin')), body: const SizedBox())` — Task 6 will replace it with the full menu.)

- [ ] **Step 7: Commit**

```bash
git add lib/screens/login_screen.dart lib/screens/home_screen.dart lib/core/auth_guard.dart lib/main.dart test/screens/login_screen_test.dart
git commit -m "feat: add LoginScreen, handleApiError auth guard, wire main.dart"
```

---

## Task 6: Home screen (section menu + logout)

**Files:**
- Modify: `lib/screens/home_screen.dart` (replace the Task 5 placeholder)

**Interfaces:**
- Consumes: `Session.clearToken()` (Task 1), `LoginScreen` (Task 5), and the 7 list screens (Tasks 7–13): `AnunciosListScreen`, `EventosListScreen`, `ServiciosListScreen`, `EquipoListScreen`, `ProgramasListScreen`, `PatrocinadoresListScreen`, `PodcastsListScreen`.
- Produces: `HomeScreen` (no constructor params).

This task's screen references the 7 list screens that Tasks 7–13 create, so it will not compile until those exist. Implement it now (per the design) but defer running `flutter analyze` on the whole app until after Task 13. No automated test for this task — it is pure navigation, verified manually once the app is fully wired (Task 14).

- [ ] **Step 1: Implement `HomeScreen`**

Replace `lib/screens/home_screen.dart`:

```dart
import 'package:flutter/material.dart';
import 'anuncios/list_screen.dart';
import 'eventos/list_screen.dart';
import 'servicios/list_screen.dart';
import 'equipo/list_screen.dart';
import 'programas/list_screen.dart';
import 'patrocinadores/list_screen.dart';
import 'podcasts/list_screen.dart';
import '../core/session.dart';
import 'login_screen.dart';

class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});

  static const _sections = [
    _Section('Servicios', Icons.design_services),
    _Section('Programas', Icons.radio),
    _Section('Podcast', Icons.podcasts),
    _Section('Anuncios', Icons.campaign),
    _Section('Eventos', Icons.event),
    _Section('Equipo', Icons.groups),
    _Section('Sección azul', Icons.handshake),
  ];

  void _open(BuildContext context, String title) {
    final screen = switch (title) {
      'Servicios' => const ServiciosListScreen(),
      'Programas' => const ProgramasListScreen(),
      'Podcast' => const PodcastsListScreen(),
      'Anuncios' => const AnunciosListScreen(),
      'Eventos' => const EventosListScreen(),
      'Equipo' => const EquipoListScreen(),
      'Sección azul' => const PatrocinadoresListScreen(),
      _ => throw StateError('Sección desconocida: $title'),
    };
    Navigator.of(context).push(MaterialPageRoute(builder: (_) => screen));
  }

  Future<void> _logout(BuildContext context) async {
    await Session.clearToken();
    if (!context.mounted) return;
    Navigator.of(context).pushAndRemoveUntil(
      MaterialPageRoute(builder: (_) => const LoginScreen()),
      (route) => false,
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Radio Doliv — Admin'),
        actions: [IconButton(icon: const Icon(Icons.logout), onPressed: () => _logout(context))],
      ),
      body: GridView.count(
        padding: const EdgeInsets.all(16),
        crossAxisCount: 2,
        mainAxisSpacing: 16,
        crossAxisSpacing: 16,
        children: _sections
            .map((s) => Card(
                  child: InkWell(
                    onTap: () => _open(context, s.title),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(s.icon, size: 40),
                        const SizedBox(height: 8),
                        Text(s.title, textAlign: TextAlign.center),
                      ],
                    ),
                  ),
                ))
            .toList(),
      ),
    );
  }
}

class _Section {
  final String title;
  final IconData icon;
  const _Section(this.title, this.icon);
}
```

- [ ] **Step 2: Commit**

```bash
git add lib/screens/home_screen.dart
git commit -m "feat: add HomeScreen section menu and logout"
```

(This commit will not compile in isolation until Tasks 7–13 add the list screens it imports — that is expected for this plan's ordering; Task 14 is the first point the whole app is expected to build and run.)

---

## Task 7: Anuncios section (list + form)

**Files:**
- Create: `lib/screens/anuncios/list_screen.dart`
- Create: `lib/screens/anuncios/form_screen.dart`
- Test: `test/screens/anuncios_list_screen_test.dart`

**Interfaces:**
- Consumes: `ApiClient`, `ApiException` (Task 2), `Anuncio` (Task 3), `ContentListTile`, `LabeledTextField`, `ImagePickerField` (Task 4), `handleApiError` (Task 5).
- Produces: `AnunciosListScreen({Key? key, ApiClient? apiClient})`, `AnuncioFormScreen({Key? key, Anuncio? anuncio, ApiClient? apiClient})`.

- [ ] **Step 1: Write the failing test**

Create `test/screens/anuncios_list_screen_test.dart`:

```dart
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:doliv_social/core/api_client.dart';
import 'package:doliv_social/screens/anuncios/list_screen.dart';

void main() {
  testWidgets('renders anuncios returned by the backend', (tester) async {
    final client = MockClient((request) async {
      return http.Response(
        jsonEncode({
          'items': [
            {
              'id': 1, 'titulo': 'Promo verano', 'descripcion': 'desc', 'imagen_url': null,
              'link_web': '', 'link_facebook': '', 'link_whatsapp': '', 'fecha_publicacion': '',
            },
          ],
        }),
        200,
      );
    });

    await tester.pumpWidget(
      MaterialApp(home: AnunciosListScreen(apiClient: ApiClient(client: client))),
    );
    await tester.pumpAndSettle();

    expect(find.text('Promo verano'), findsOneWidget);
  });

  testWidgets('shows empty state when there are no anuncios', (tester) async {
    final client = MockClient((request) async => http.Response(jsonEncode({'items': []}), 200));

    await tester.pumpWidget(
      MaterialApp(home: AnunciosListScreen(apiClient: ApiClient(client: client))),
    );
    await tester.pumpAndSettle();

    expect(find.text('No hay anuncios todavía'), findsOneWidget);
  });
}
```

- [ ] **Step 2: Run test to verify it fails**

Run: `flutter test test/screens/anuncios_list_screen_test.dart`
Expected: FAIL — `lib/screens/anuncios/list_screen.dart` does not exist.

- [ ] **Step 3: Implement the form screen**

Create `lib/screens/anuncios/form_screen.dart`:

```dart
import 'dart:io';
import 'package:flutter/material.dart';
import '../../core/api_client.dart';
import '../../core/auth_guard.dart';
import '../../models/anuncio.dart';
import '../../widgets/labeled_text_field.dart';
import '../../widgets/image_picker_field.dart';

class AnuncioFormScreen extends StatefulWidget {
  const AnuncioFormScreen({super.key, this.anuncio, this.apiClient});
  final Anuncio? anuncio;
  final ApiClient? apiClient;

  @override
  State<AnuncioFormScreen> createState() => _AnuncioFormScreenState();
}

class _AnuncioFormScreenState extends State<AnuncioFormScreen> {
  final _formKey = GlobalKey<FormState>();
  late final ApiClient _api = widget.apiClient ?? ApiClient();
  late final _titulo = TextEditingController(text: widget.anuncio?.titulo ?? '');
  late final _descripcion = TextEditingController(text: widget.anuncio?.descripcion ?? '');
  late final _linkWeb = TextEditingController(text: widget.anuncio?.linkWeb ?? '');
  late final _linkFacebook = TextEditingController(text: widget.anuncio?.linkFacebook ?? '');
  late final _linkWhatsapp = TextEditingController(text: widget.anuncio?.linkWhatsapp ?? '');
  late final _fechaPublicacion = TextEditingController(text: widget.anuncio?.fechaPublicacion ?? '');
  File? _newImage;
  bool _saving = false;

  bool get _isEditing => widget.anuncio != null;

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _saving = true);
    final fields = {
      'titulo': _titulo.text.trim(),
      'descripcion': _descripcion.text.trim(),
      'link_web': _linkWeb.text.trim(),
      'link_facebook': _linkFacebook.text.trim(),
      'link_whatsapp': _linkWhatsapp.text.trim(),
      'fecha_publicacion': _fechaPublicacion.text.trim(),
    };
    final path = _isEditing ? '/site/anuncios/${widget.anuncio!.id}' : '/site/anuncios';
    try {
      await _api.postMultipart(path, fields, fileField: 'imagen', file: _newImage);
      if (mounted) Navigator.of(context).pop(true);
    } catch (e) {
      setState(() => _saving = false);
      if (mounted) await handleApiError(context, e);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(_isEditing ? 'Editar anuncio' : 'Nuevo anuncio')),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            ImagePickerField(
              currentImageUrl: widget.anuncio?.imagenUrl,
              onImageSelected: (file) => setState(() => _newImage = file),
            ),
            const SizedBox(height: 16),
            LabeledTextField(
              controller: _titulo,
              label: 'Título',
              validator: (v) => (v == null || v.trim().isEmpty) ? 'El título es requerido' : null,
            ),
            LabeledTextField(controller: _descripcion, label: 'Descripción', maxLines: 3),
            LabeledTextField(controller: _linkWeb, label: 'Enlace web'),
            LabeledTextField(controller: _linkFacebook, label: 'Enlace de Facebook'),
            LabeledTextField(controller: _linkWhatsapp, label: 'Enlace de WhatsApp'),
            LabeledTextField(controller: _fechaPublicacion, label: 'Fecha de publicación (AAAA-MM-DD)'),
            const SizedBox(height: 24),
            ElevatedButton(
              onPressed: _saving ? null : _submit,
              child: _saving
                  ? const SizedBox(height: 20, width: 20, child: CircularProgressIndicator(strokeWidth: 2))
                  : const Text('Guardar'),
            ),
          ],
        ),
      ),
    );
  }
}
```

- [ ] **Step 4: Implement the list screen**

Create `lib/screens/anuncios/list_screen.dart`:

```dart
import 'package:flutter/material.dart';
import '../../core/api_client.dart';
import '../../core/auth_guard.dart';
import '../../models/anuncio.dart';
import '../../widgets/content_list_tile.dart';
import 'form_screen.dart';

class AnunciosListScreen extends StatefulWidget {
  const AnunciosListScreen({super.key, this.apiClient});
  final ApiClient? apiClient;

  @override
  State<AnunciosListScreen> createState() => _AnunciosListScreenState();
}

class _AnunciosListScreenState extends State<AnunciosListScreen> {
  late final ApiClient _api = widget.apiClient ?? ApiClient();
  List<Anuncio> _items = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    try {
      final response = await _api.get('/site/anuncios');
      final items = (response['items'] as List)
          .map((e) => Anuncio.fromJson(e as Map<String, dynamic>))
          .toList();
      setState(() {
        _items = items;
        _loading = false;
      });
    } catch (e) {
      setState(() => _loading = false);
      if (mounted) await handleApiError(context, e);
    }
  }

  Future<void> _delete(Anuncio anuncio) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Eliminar anuncio'),
        content: Text('¿Eliminar "${anuncio.titulo}"? Esta acción no se puede deshacer.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancelar')),
          TextButton(onPressed: () => Navigator.pop(context, true), child: const Text('Eliminar')),
        ],
      ),
    );
    if (confirmed != true) return;
    try {
      await _api.postJson('/site/anuncios/${anuncio.id}/delete', {});
      _load();
    } catch (e) {
      if (mounted) await handleApiError(context, e);
    }
  }

  Future<void> _openForm({Anuncio? anuncio}) async {
    final saved = await Navigator.of(context).push<bool>(
      MaterialPageRoute(builder: (_) => AnuncioFormScreen(anuncio: anuncio, apiClient: _api)),
    );
    if (saved == true) _load();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Anuncios')),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              onRefresh: _load,
              child: _items.isEmpty
                  ? ListView(
                      children: const [
                        Padding(
                          padding: EdgeInsets.all(32),
                          child: Center(child: Text('No hay anuncios todavía')),
                        ),
                      ],
                    )
                  : ListView.builder(
                      itemCount: _items.length,
                      itemBuilder: (context, index) {
                        final item = _items[index];
                        return ContentListTile(
                          title: item.titulo,
                          subtitle: item.descripcion,
                          imageUrl: item.imagenUrl,
                          onEdit: () => _openForm(anuncio: item),
                          onDelete: () => _delete(item),
                        );
                      },
                    ),
            ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => _openForm(),
        child: const Icon(Icons.add),
      ),
    );
  }
}
```

- [ ] **Step 5: Run test to verify it passes**

Run: `flutter test test/screens/anuncios_list_screen_test.dart`
Expected: PASS (2 tests).

- [ ] **Step 6: Commit**

```bash
git add lib/screens/anuncios test/screens/anuncios_list_screen_test.dart
git commit -m "feat: add Anuncios list and form screens"
```

---

## Task 8: Eventos section (list + form)

**Files:**
- Create: `lib/screens/eventos/list_screen.dart`
- Create: `lib/screens/eventos/form_screen.dart`

**Interfaces:**
- Consumes: `ApiClient`, `Evento` (Task 3), shared widgets (Task 4), `handleApiError` (Task 5).
- Produces: `EventosListScreen({Key? key, ApiClient? apiClient})`, `EventoFormScreen({Key? key, Evento? evento, ApiClient? apiClient})`.

No automated test for this task (same CRUD pattern already covered by Task 7's test) — verified with `flutter analyze` and a manual run in Task 14.

- [ ] **Step 1: Implement the form screen**

Create `lib/screens/eventos/form_screen.dart`:

```dart
import 'dart:io';
import 'package:flutter/material.dart';
import '../../core/api_client.dart';
import '../../core/auth_guard.dart';
import '../../models/evento.dart';
import '../../widgets/labeled_text_field.dart';
import '../../widgets/image_picker_field.dart';

class EventoFormScreen extends StatefulWidget {
  const EventoFormScreen({super.key, this.evento, this.apiClient});
  final Evento? evento;
  final ApiClient? apiClient;

  @override
  State<EventoFormScreen> createState() => _EventoFormScreenState();
}

class _EventoFormScreenState extends State<EventoFormScreen> {
  final _formKey = GlobalKey<FormState>();
  late final ApiClient _api = widget.apiClient ?? ApiClient();
  late final _title = TextEditingController(text: widget.evento?.title ?? '');
  late final _artist = TextEditingController(text: widget.evento?.artist ?? '');
  late final _location = TextEditingController(text: widget.evento?.location ?? '');
  late final _weekday = TextEditingController(text: widget.evento?.weekday ?? '');
  late final _day = TextEditingController(text: widget.evento?.day ?? '');
  late final _month = TextEditingController(text: widget.evento?.month ?? '');
  late final _year = TextEditingController(text: widget.evento?.year ?? '');
  late final _eventDate = TextEditingController(text: widget.evento?.eventDate ?? '');
  late final _timeLabel = TextEditingController(text: widget.evento?.timeLabel ?? '');
  late final _description = TextEditingController(text: widget.evento?.description ?? '');
  late final _sortOrder = TextEditingController(text: (widget.evento?.sortOrder ?? 0).toString());
  File? _newImage;
  bool _saving = false;

  bool get _isEditing => widget.evento != null;

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _saving = true);
    final fields = {
      'title': _title.text.trim(),
      'artist': _artist.text.trim(),
      'location': _location.text.trim(),
      'weekday': _weekday.text.trim(),
      'day': _day.text.trim(),
      'month': _month.text.trim(),
      'year': _year.text.trim(),
      'event_date': _eventDate.text.trim(),
      'time_label': _timeLabel.text.trim(),
      'description': _description.text.trim(),
      'sort_order': _sortOrder.text.trim().isEmpty ? '0' : _sortOrder.text.trim(),
    };
    final path = _isEditing ? '/site/eventos/${widget.evento!.id}' : '/site/eventos';
    try {
      await _api.postMultipart(path, fields, fileField: 'image', file: _newImage);
      if (mounted) Navigator.of(context).pop(true);
    } catch (e) {
      setState(() => _saving = false);
      if (mounted) await handleApiError(context, e);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(_isEditing ? 'Editar evento' : 'Nuevo evento')),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            ImagePickerField(
              currentImageUrl: widget.evento?.image,
              onImageSelected: (file) => setState(() => _newImage = file),
            ),
            const SizedBox(height: 16),
            LabeledTextField(
              controller: _title,
              label: 'Título',
              validator: (v) => (v == null || v.trim().isEmpty) ? 'El título es requerido' : null,
            ),
            LabeledTextField(controller: _artist, label: 'Artista / invitado'),
            LabeledTextField(controller: _location, label: 'Lugar'),
            LabeledTextField(controller: _eventDate, label: 'Fecha (AAAA-MM-DD)'),
            LabeledTextField(controller: _timeLabel, label: 'Hora (texto libre, ej. 8:00 pm)'),
            LabeledTextField(controller: _weekday, label: 'Día de la semana (texto)'),
            LabeledTextField(controller: _day, label: 'Día (número, texto libre)'),
            LabeledTextField(controller: _month, label: 'Mes (texto libre)'),
            LabeledTextField(controller: _year, label: 'Año (texto libre)'),
            LabeledTextField(controller: _description, label: 'Descripción', maxLines: 3),
            LabeledTextField(
              controller: _sortOrder,
              label: 'Orden',
              keyboardType: TextInputType.number,
            ),
            const SizedBox(height: 24),
            ElevatedButton(
              onPressed: _saving ? null : _submit,
              child: _saving
                  ? const SizedBox(height: 20, width: 20, child: CircularProgressIndicator(strokeWidth: 2))
                  : const Text('Guardar'),
            ),
          ],
        ),
      ),
    );
  }
}
```

- [ ] **Step 2: Implement the list screen**

Create `lib/screens/eventos/list_screen.dart`:

```dart
import 'package:flutter/material.dart';
import '../../core/api_client.dart';
import '../../core/auth_guard.dart';
import '../../models/evento.dart';
import '../../widgets/content_list_tile.dart';
import 'form_screen.dart';

class EventosListScreen extends StatefulWidget {
  const EventosListScreen({super.key, this.apiClient});
  final ApiClient? apiClient;

  @override
  State<EventosListScreen> createState() => _EventosListScreenState();
}

class _EventosListScreenState extends State<EventosListScreen> {
  late final ApiClient _api = widget.apiClient ?? ApiClient();
  List<Evento> _items = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    try {
      final response = await _api.get('/site/eventos');
      final items = (response['items'] as List)
          .map((e) => Evento.fromJson(e as Map<String, dynamic>))
          .toList();
      setState(() {
        _items = items;
        _loading = false;
      });
    } catch (e) {
      setState(() => _loading = false);
      if (mounted) await handleApiError(context, e);
    }
  }

  Future<void> _delete(Evento evento) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Eliminar evento'),
        content: Text('¿Eliminar "${evento.title}"? Esta acción no se puede deshacer.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancelar')),
          TextButton(onPressed: () => Navigator.pop(context, true), child: const Text('Eliminar')),
        ],
      ),
    );
    if (confirmed != true) return;
    try {
      await _api.postJson('/site/eventos/${evento.id}/delete', {});
      _load();
    } catch (e) {
      if (mounted) await handleApiError(context, e);
    }
  }

  Future<void> _openForm({Evento? evento}) async {
    final saved = await Navigator.of(context).push<bool>(
      MaterialPageRoute(builder: (_) => EventoFormScreen(evento: evento, apiClient: _api)),
    );
    if (saved == true) _load();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Eventos')),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              onRefresh: _load,
              child: _items.isEmpty
                  ? ListView(
                      children: const [
                        Padding(
                          padding: EdgeInsets.all(32),
                          child: Center(child: Text('No hay eventos todavía')),
                        ),
                      ],
                    )
                  : ListView.builder(
                      itemCount: _items.length,
                      itemBuilder: (context, index) {
                        final item = _items[index];
                        return ContentListTile(
                          title: item.title,
                          subtitle: item.location,
                          imageUrl: item.image,
                          onEdit: () => _openForm(evento: item),
                          onDelete: () => _delete(item),
                        );
                      },
                    ),
            ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => _openForm(),
        child: const Icon(Icons.add),
      ),
    );
  }
}
```

- [ ] **Step 3: Verify static analysis is clean**

Run: `flutter analyze lib/screens/eventos`
Expected: `No issues found!`

- [ ] **Step 4: Commit**

```bash
git add lib/screens/eventos
git commit -m "feat: add Eventos list and form screens"
```

---

## Task 9: Servicios section (list + form)

**Files:**
- Create: `lib/screens/servicios/list_screen.dart`
- Create: `lib/screens/servicios/form_screen.dart`

**Interfaces:**
- Consumes: `ApiClient`, `Servicio` (Task 3), shared widgets (Task 4), `handleApiError` (Task 5).
- Produces: `ServiciosListScreen({Key? key, ApiClient? apiClient})`, `ServicioFormScreen({Key? key, Servicio? servicio, ApiClient? apiClient})`.

No automated test for this task — verified with `flutter analyze` and a manual run in Task 14.

- [ ] **Step 1: Implement the form screen**

Create `lib/screens/servicios/form_screen.dart`:

```dart
import 'dart:io';
import 'package:flutter/material.dart';
import '../../core/api_client.dart';
import '../../core/auth_guard.dart';
import '../../models/servicio.dart';
import '../../widgets/labeled_text_field.dart';
import '../../widgets/image_picker_field.dart';

class ServicioFormScreen extends StatefulWidget {
  const ServicioFormScreen({super.key, this.servicio, this.apiClient});
  final Servicio? servicio;
  final ApiClient? apiClient;

  @override
  State<ServicioFormScreen> createState() => _ServicioFormScreenState();
}

class _ServicioFormScreenState extends State<ServicioFormScreen> {
  final _formKey = GlobalKey<FormState>();
  late final ApiClient _api = widget.apiClient ?? ApiClient();
  late final _title = TextEditingController(text: widget.servicio?.title ?? '');
  late final _description = TextEditingController(text: widget.servicio?.description ?? '');
  late final _whatsappUrl = TextEditingController(text: widget.servicio?.whatsappUrl ?? '');
  late final _category = TextEditingController(text: widget.servicio?.category ?? '');
  late final _icon = TextEditingController(text: widget.servicio?.icon ?? '');
  late final _sortOrder = TextEditingController(text: (widget.servicio?.sortOrder ?? 0).toString());
  File? _newImage;
  bool _saving = false;

  bool get _isEditing => widget.servicio != null;

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _saving = true);
    final fields = {
      'title': _title.text.trim(),
      'description': _description.text.trim(),
      'whatsapp_url': _whatsappUrl.text.trim(),
      'category': _category.text.trim(),
      'icon': _icon.text.trim(),
      'sort_order': _sortOrder.text.trim().isEmpty ? '0' : _sortOrder.text.trim(),
    };
    final path = _isEditing ? '/site/servicios/${widget.servicio!.id}' : '/site/servicios';
    try {
      await _api.postMultipart(path, fields, fileField: 'image', file: _newImage);
      if (mounted) Navigator.of(context).pop(true);
    } catch (e) {
      setState(() => _saving = false);
      if (mounted) await handleApiError(context, e);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(_isEditing ? 'Editar servicio' : 'Nuevo servicio')),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            ImagePickerField(
              currentImageUrl: widget.servicio?.image,
              onImageSelected: (file) => setState(() => _newImage = file),
            ),
            const SizedBox(height: 16),
            LabeledTextField(
              controller: _title,
              label: 'Título',
              validator: (v) => (v == null || v.trim().isEmpty) ? 'El título es requerido' : null,
            ),
            LabeledTextField(controller: _description, label: 'Descripción', maxLines: 3),
            LabeledTextField(controller: _whatsappUrl, label: 'Enlace de WhatsApp'),
            LabeledTextField(controller: _category, label: 'Categoría'),
            LabeledTextField(controller: _icon, label: 'Ícono (nombre/clase)'),
            LabeledTextField(
              controller: _sortOrder,
              label: 'Orden',
              keyboardType: TextInputType.number,
            ),
            const SizedBox(height: 24),
            ElevatedButton(
              onPressed: _saving ? null : _submit,
              child: _saving
                  ? const SizedBox(height: 20, width: 20, child: CircularProgressIndicator(strokeWidth: 2))
                  : const Text('Guardar'),
            ),
          ],
        ),
      ),
    );
  }
}
```

- [ ] **Step 2: Implement the list screen**

Create `lib/screens/servicios/list_screen.dart`:

```dart
import 'package:flutter/material.dart';
import '../../core/api_client.dart';
import '../../core/auth_guard.dart';
import '../../models/servicio.dart';
import '../../widgets/content_list_tile.dart';
import 'form_screen.dart';

class ServiciosListScreen extends StatefulWidget {
  const ServiciosListScreen({super.key, this.apiClient});
  final ApiClient? apiClient;

  @override
  State<ServiciosListScreen> createState() => _ServiciosListScreenState();
}

class _ServiciosListScreenState extends State<ServiciosListScreen> {
  late final ApiClient _api = widget.apiClient ?? ApiClient();
  List<Servicio> _items = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    try {
      final response = await _api.get('/site/servicios');
      final items = (response['items'] as List)
          .map((e) => Servicio.fromJson(e as Map<String, dynamic>))
          .toList();
      setState(() {
        _items = items;
        _loading = false;
      });
    } catch (e) {
      setState(() => _loading = false);
      if (mounted) await handleApiError(context, e);
    }
  }

  Future<void> _delete(Servicio servicio) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Eliminar servicio'),
        content: Text('¿Eliminar "${servicio.title}"? Esta acción no se puede deshacer.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancelar')),
          TextButton(onPressed: () => Navigator.pop(context, true), child: const Text('Eliminar')),
        ],
      ),
    );
    if (confirmed != true) return;
    try {
      await _api.postJson('/site/servicios/${servicio.id}/delete', {});
      _load();
    } catch (e) {
      if (mounted) await handleApiError(context, e);
    }
  }

  Future<void> _openForm({Servicio? servicio}) async {
    final saved = await Navigator.of(context).push<bool>(
      MaterialPageRoute(builder: (_) => ServicioFormScreen(servicio: servicio, apiClient: _api)),
    );
    if (saved == true) _load();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Servicios')),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              onRefresh: _load,
              child: _items.isEmpty
                  ? ListView(
                      children: const [
                        Padding(
                          padding: EdgeInsets.all(32),
                          child: Center(child: Text('No hay servicios todavía')),
                        ),
                      ],
                    )
                  : ListView.builder(
                      itemCount: _items.length,
                      itemBuilder: (context, index) {
                        final item = _items[index];
                        return ContentListTile(
                          title: item.title,
                          subtitle: item.category,
                          imageUrl: item.image,
                          onEdit: () => _openForm(servicio: item),
                          onDelete: () => _delete(item),
                        );
                      },
                    ),
            ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => _openForm(),
        child: const Icon(Icons.add),
      ),
    );
  }
}
```

- [ ] **Step 3: Verify static analysis is clean**

Run: `flutter analyze lib/screens/servicios`
Expected: `No issues found!`

- [ ] **Step 4: Commit**

```bash
git add lib/screens/servicios
git commit -m "feat: add Servicios list and form screens"
```

---

## Task 10: Equipo section (list + form)

**Files:**
- Create: `lib/screens/equipo/list_screen.dart`
- Create: `lib/screens/equipo/form_screen.dart`

**Interfaces:**
- Consumes: `ApiClient`, `Integrante` (Task 3), shared widgets (Task 4), `handleApiError` (Task 5).
- Produces: `EquipoListScreen({Key? key, ApiClient? apiClient})`, `IntegranteFormScreen({Key? key, Integrante? integrante, ApiClient? apiClient})`.

No automated test for this task — verified with `flutter analyze` and a manual run in Task 14.

- [ ] **Step 1: Implement the form screen**

Create `lib/screens/equipo/form_screen.dart`:

```dart
import 'dart:io';
import 'package:flutter/material.dart';
import '../../core/api_client.dart';
import '../../core/auth_guard.dart';
import '../../models/integrante.dart';
import '../../widgets/labeled_text_field.dart';
import '../../widgets/image_picker_field.dart';

class IntegranteFormScreen extends StatefulWidget {
  const IntegranteFormScreen({super.key, this.integrante, this.apiClient});
  final Integrante? integrante;
  final ApiClient? apiClient;

  @override
  State<IntegranteFormScreen> createState() => _IntegranteFormScreenState();
}

class _IntegranteFormScreenState extends State<IntegranteFormScreen> {
  final _formKey = GlobalKey<FormState>();
  late final ApiClient _api = widget.apiClient ?? ApiClient();
  late final _name = TextEditingController(text: widget.integrante?.name ?? '');
  late final _role = TextEditingController(text: widget.integrante?.role ?? '');
  late final _category = TextEditingController(text: widget.integrante?.category ?? '');
  late final _accent = TextEditingController(text: widget.integrante?.accent ?? '');
  late final _shortDesc = TextEditingController(text: widget.integrante?.shortDesc ?? '');
  late final _bio = TextEditingController(text: widget.integrante?.bio ?? '');
  late final _path = TextEditingController(text: widget.integrante?.path ?? '');
  late final _interests = TextEditingController(text: widget.integrante?.interests ?? '');
  late final _sortOrder = TextEditingController(text: (widget.integrante?.sortOrder ?? 0).toString());
  File? _newImage;
  bool _saving = false;

  bool get _isEditing => widget.integrante != null;

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _saving = true);
    final fields = {
      'name': _name.text.trim(),
      'role': _role.text.trim(),
      'category': _category.text.trim(),
      'accent': _accent.text.trim(),
      'short_desc': _shortDesc.text.trim(),
      'bio': _bio.text,
      'path': _path.text,
      'interests': _interests.text,
      'sort_order': _sortOrder.text.trim().isEmpty ? '0' : _sortOrder.text.trim(),
    };
    final path = _isEditing ? '/site/equipo/${widget.integrante!.id}' : '/site/equipo';
    try {
      await _api.postMultipart(path, fields, fileField: 'image', file: _newImage);
      if (mounted) Navigator.of(context).pop(true);
    } catch (e) {
      setState(() => _saving = false);
      if (mounted) await handleApiError(context, e);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(_isEditing ? 'Editar integrante' : 'Nuevo integrante')),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            ImagePickerField(
              currentImageUrl: widget.integrante?.image,
              onImageSelected: (file) => setState(() => _newImage = file),
            ),
            const SizedBox(height: 16),
            LabeledTextField(
              controller: _name,
              label: 'Nombre',
              validator: (v) => (v == null || v.trim().isEmpty) ? 'El nombre es requerido' : null,
            ),
            LabeledTextField(controller: _role, label: 'Puesto / rol'),
            LabeledTextField(controller: _category, label: 'Categoría'),
            LabeledTextField(controller: _accent, label: 'Color de acento (hex u opcional)'),
            LabeledTextField(controller: _shortDesc, label: 'Descripción corta'),
            LabeledTextField(controller: _bio, label: 'Biografía (una idea por línea)', maxLines: 4),
            LabeledTextField(controller: _path, label: 'Trayectoria (una idea por línea)', maxLines: 4),
            LabeledTextField(controller: _interests, label: 'Intereses (uno por línea)', maxLines: 3),
            LabeledTextField(
              controller: _sortOrder,
              label: 'Orden',
              keyboardType: TextInputType.number,
            ),
            const SizedBox(height: 24),
            ElevatedButton(
              onPressed: _saving ? null : _submit,
              child: _saving
                  ? const SizedBox(height: 20, width: 20, child: CircularProgressIndicator(strokeWidth: 2))
                  : const Text('Guardar'),
            ),
          ],
        ),
      ),
    );
  }
}
```

- [ ] **Step 2: Implement the list screen**

Create `lib/screens/equipo/list_screen.dart`:

```dart
import 'package:flutter/material.dart';
import '../../core/api_client.dart';
import '../../core/auth_guard.dart';
import '../../models/integrante.dart';
import '../../widgets/content_list_tile.dart';
import 'form_screen.dart';

class EquipoListScreen extends StatefulWidget {
  const EquipoListScreen({super.key, this.apiClient});
  final ApiClient? apiClient;

  @override
  State<EquipoListScreen> createState() => _EquipoListScreenState();
}

class _EquipoListScreenState extends State<EquipoListScreen> {
  late final ApiClient _api = widget.apiClient ?? ApiClient();
  List<Integrante> _items = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    try {
      final response = await _api.get('/site/equipo');
      final items = (response['items'] as List)
          .map((e) => Integrante.fromJson(e as Map<String, dynamic>))
          .toList();
      setState(() {
        _items = items;
        _loading = false;
      });
    } catch (e) {
      setState(() => _loading = false);
      if (mounted) await handleApiError(context, e);
    }
  }

  Future<void> _delete(Integrante integrante) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Eliminar integrante'),
        content: Text('¿Eliminar a "${integrante.name}"? Esta acción no se puede deshacer.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancelar')),
          TextButton(onPressed: () => Navigator.pop(context, true), child: const Text('Eliminar')),
        ],
      ),
    );
    if (confirmed != true) return;
    try {
      await _api.postJson('/site/equipo/${integrante.id}/delete', {});
      _load();
    } catch (e) {
      if (mounted) await handleApiError(context, e);
    }
  }

  Future<void> _openForm({Integrante? integrante}) async {
    final saved = await Navigator.of(context).push<bool>(
      MaterialPageRoute(builder: (_) => IntegranteFormScreen(integrante: integrante, apiClient: _api)),
    );
    if (saved == true) _load();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Equipo')),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              onRefresh: _load,
              child: _items.isEmpty
                  ? ListView(
                      children: const [
                        Padding(
                          padding: EdgeInsets.all(32),
                          child: Center(child: Text('No hay integrantes todavía')),
                        ),
                      ],
                    )
                  : ListView.builder(
                      itemCount: _items.length,
                      itemBuilder: (context, index) {
                        final item = _items[index];
                        return ContentListTile(
                          title: item.name,
                          subtitle: item.role,
                          imageUrl: item.image,
                          onEdit: () => _openForm(integrante: item),
                          onDelete: () => _delete(item),
                        );
                      },
                    ),
            ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => _openForm(),
        child: const Icon(Icons.add),
      ),
    );
  }
}
```

- [ ] **Step 3: Verify static analysis is clean**

Run: `flutter analyze lib/screens/equipo`
Expected: `No issues found!`

- [ ] **Step 4: Commit**

```bash
git add lib/screens/equipo
git commit -m "feat: add Equipo list and form screens"
```

---

## Task 11: Programas section (list + form)

**Files:**
- Create: `lib/screens/programas/list_screen.dart`
- Create: `lib/screens/programas/form_screen.dart`

**Interfaces:**
- Consumes: `ApiClient`, `Programa` (Task 3), shared widgets (Task 4), `handleApiError` (Task 5).
- Produces: `ProgramasListScreen({Key? key, ApiClient? apiClient})`, `ProgramaFormScreen({Key? key, Programa? programa, ApiClient? apiClient})`.

No automated test for this task — verified with `flutter analyze` and a manual run in Task 14.

- [ ] **Step 1: Implement the form screen**

Create `lib/screens/programas/form_screen.dart`:

```dart
import 'dart:io';
import 'package:flutter/material.dart';
import '../../core/api_client.dart';
import '../../core/auth_guard.dart';
import '../../models/programa.dart';
import '../../widgets/labeled_text_field.dart';
import '../../widgets/image_picker_field.dart';

class ProgramaFormScreen extends StatefulWidget {
  const ProgramaFormScreen({super.key, this.programa, this.apiClient});
  final Programa? programa;
  final ApiClient? apiClient;

  @override
  State<ProgramaFormScreen> createState() => _ProgramaFormScreenState();
}

class _ProgramaFormScreenState extends State<ProgramaFormScreen> {
  final _formKey = GlobalKey<FormState>();
  late final ApiClient _api = widget.apiClient ?? ApiClient();
  late final _title = TextEditingController(text: widget.programa?.title ?? '');
  late final _modalTitle = TextEditingController(text: widget.programa?.modalTitle ?? '');
  late final _host = TextEditingController(text: widget.programa?.host ?? '');
  late final _schedule = TextEditingController(text: widget.programa?.schedule ?? '');
  late final _slotStart = TextEditingController(text: widget.programa?.slotStart?.toString() ?? '');
  late final _slotEnd = TextEditingController(text: widget.programa?.slotEnd?.toString() ?? '');
  late final _weekdays = TextEditingController(text: widget.programa?.weekdays ?? '');
  late final _badgeIcon = TextEditingController(text: widget.programa?.badgeIcon ?? '');
  late final _badgeTime = TextEditingController(text: widget.programa?.badgeTime ?? '');
  late final _badgeLabel = TextEditingController(text: widget.programa?.badgeLabel ?? '');
  late final _accent = TextEditingController(text: widget.programa?.accent ?? '');
  late final _icon = TextEditingController(text: widget.programa?.icon ?? '');
  late final _categories = TextEditingController(text: widget.programa?.categories ?? '');
  late final _cardDesc = TextEditingController(text: widget.programa?.cardDesc ?? '');
  late final _indexDesc = TextEditingController(text: widget.programa?.indexDesc ?? '');
  late final _summary = TextEditingController(text: widget.programa?.summary ?? '');
  late final _sortOrder = TextEditingController(text: (widget.programa?.sortOrder ?? 0).toString());
  File? _newImage;
  bool _saving = false;

  bool get _isEditing => widget.programa != null;

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _saving = true);
    final fields = {
      'title': _title.text.trim(),
      'modal_title': _modalTitle.text.trim(),
      'host': _host.text.trim(),
      'schedule': _schedule.text.trim(),
      'slot_start': _slotStart.text.trim(),
      'slot_end': _slotEnd.text.trim(),
      'weekdays': _weekdays.text.trim(),
      'badge_icon': _badgeIcon.text.trim(),
      'badge_time': _badgeTime.text.trim(),
      'badge_label': _badgeLabel.text.trim(),
      'accent': _accent.text.trim(),
      'icon': _icon.text.trim(),
      'categories': _categories.text.trim(),
      'card_desc': _cardDesc.text.trim(),
      'index_desc': _indexDesc.text.trim(),
      'summary': _summary.text.trim(),
      'sort_order': _sortOrder.text.trim().isEmpty ? '0' : _sortOrder.text.trim(),
    };
    final path = _isEditing ? '/site/programas/${widget.programa!.id}' : '/site/programas';
    try {
      await _api.postMultipart(path, fields, fileField: 'image', file: _newImage);
      if (mounted) Navigator.of(context).pop(true);
    } catch (e) {
      setState(() => _saving = false);
      if (mounted) await handleApiError(context, e);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(_isEditing ? 'Editar programa' : 'Nuevo programa')),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            ImagePickerField(
              currentImageUrl: widget.programa?.image,
              onImageSelected: (file) => setState(() => _newImage = file),
            ),
            const SizedBox(height: 16),
            LabeledTextField(
              controller: _title,
              label: 'Título',
              validator: (v) => (v == null || v.trim().isEmpty) ? 'El título es requerido' : null,
            ),
            LabeledTextField(controller: _modalTitle, label: 'Título del detalle'),
            LabeledTextField(controller: _host, label: 'Conductor(es)'),
            LabeledTextField(controller: _schedule, label: 'Horario (texto libre)'),
            LabeledTextField(
              controller: _slotStart,
              label: 'Hora de inicio (0-23, opcional)',
              keyboardType: TextInputType.number,
            ),
            LabeledTextField(
              controller: _slotEnd,
              label: 'Hora de fin (0-23, opcional)',
              keyboardType: TextInputType.number,
            ),
            LabeledTextField(controller: _weekdays, label: 'Días (números 1-7 separados por coma)'),
            LabeledTextField(controller: _badgeIcon, label: 'Ícono de la insignia'),
            LabeledTextField(controller: _badgeTime, label: 'Hora de la insignia'),
            LabeledTextField(controller: _badgeLabel, label: 'Texto de la insignia'),
            LabeledTextField(controller: _accent, label: 'Color de acento'),
            LabeledTextField(controller: _icon, label: 'Ícono'),
            LabeledTextField(controller: _categories, label: 'Categorías'),
            LabeledTextField(controller: _cardDesc, label: 'Descripción de tarjeta', maxLines: 2),
            LabeledTextField(controller: _indexDesc, label: 'Descripción de índice', maxLines: 2),
            LabeledTextField(controller: _summary, label: 'Resumen', maxLines: 3),
            LabeledTextField(
              controller: _sortOrder,
              label: 'Orden',
              keyboardType: TextInputType.number,
            ),
            const SizedBox(height: 24),
            ElevatedButton(
              onPressed: _saving ? null : _submit,
              child: _saving
                  ? const SizedBox(height: 20, width: 20, child: CircularProgressIndicator(strokeWidth: 2))
                  : const Text('Guardar'),
            ),
          ],
        ),
      ),
    );
  }
}
```

- [ ] **Step 2: Implement the list screen**

Create `lib/screens/programas/list_screen.dart`:

```dart
import 'package:flutter/material.dart';
import '../../core/api_client.dart';
import '../../core/auth_guard.dart';
import '../../models/programa.dart';
import '../../widgets/content_list_tile.dart';
import 'form_screen.dart';

class ProgramasListScreen extends StatefulWidget {
  const ProgramasListScreen({super.key, this.apiClient});
  final ApiClient? apiClient;

  @override
  State<ProgramasListScreen> createState() => _ProgramasListScreenState();
}

class _ProgramasListScreenState extends State<ProgramasListScreen> {
  late final ApiClient _api = widget.apiClient ?? ApiClient();
  List<Programa> _items = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    try {
      final response = await _api.get('/site/programas');
      final items = (response['items'] as List)
          .map((e) => Programa.fromJson(e as Map<String, dynamic>))
          .toList();
      setState(() {
        _items = items;
        _loading = false;
      });
    } catch (e) {
      setState(() => _loading = false);
      if (mounted) await handleApiError(context, e);
    }
  }

  Future<void> _delete(Programa programa) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Eliminar programa'),
        content: Text('¿Eliminar "${programa.title}"? Esta acción no se puede deshacer.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancelar')),
          TextButton(onPressed: () => Navigator.pop(context, true), child: const Text('Eliminar')),
        ],
      ),
    );
    if (confirmed != true) return;
    try {
      await _api.postJson('/site/programas/${programa.id}/delete', {});
      _load();
    } catch (e) {
      if (mounted) await handleApiError(context, e);
    }
  }

  Future<void> _openForm({Programa? programa}) async {
    final saved = await Navigator.of(context).push<bool>(
      MaterialPageRoute(builder: (_) => ProgramaFormScreen(programa: programa, apiClient: _api)),
    );
    if (saved == true) _load();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Programas')),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              onRefresh: _load,
              child: _items.isEmpty
                  ? ListView(
                      children: const [
                        Padding(
                          padding: EdgeInsets.all(32),
                          child: Center(child: Text('No hay programas todavía')),
                        ),
                      ],
                    )
                  : ListView.builder(
                      itemCount: _items.length,
                      itemBuilder: (context, index) {
                        final item = _items[index];
                        return ContentListTile(
                          title: item.title,
                          subtitle: item.host,
                          imageUrl: item.image,
                          onEdit: () => _openForm(programa: item),
                          onDelete: () => _delete(item),
                        );
                      },
                    ),
            ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => _openForm(),
        child: const Icon(Icons.add),
      ),
    );
  }
}
```

- [ ] **Step 3: Verify static analysis is clean**

Run: `flutter analyze lib/screens/programas`
Expected: `No issues found!`

- [ ] **Step 4: Commit**

```bash
git add lib/screens/programas
git commit -m "feat: add Programas list and form screens"
```

---

## Task 12: Patrocinadores / Sección azul (list + form with social links editor)

**Files:**
- Create: `lib/screens/patrocinadores/list_screen.dart`
- Create: `lib/screens/patrocinadores/form_screen.dart`

**Interfaces:**
- Consumes: `ApiClient`, `Patrocinador`, `SponsorSocial` (Task 3), shared widgets (Task 4), `handleApiError` (Task 5).
- Produces: `PatrocinadoresListScreen({Key? key, ApiClient? apiClient})`, `PatrocinadorFormScreen({Key? key, Patrocinador? patrocinador, ApiClient? apiClient})`.

No automated test for this task — verified with `flutter analyze` and a manual run in Task 14 (including adding/removing a social link row).

- [ ] **Step 1: Implement the form screen with an inline social-links editor**

Create `lib/screens/patrocinadores/form_screen.dart`:

```dart
import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import '../../core/api_client.dart';
import '../../core/auth_guard.dart';
import '../../models/patrocinador.dart';
import '../../widgets/labeled_text_field.dart';
import '../../widgets/image_picker_field.dart';

class _SocialRow {
  final TextEditingController label;
  final TextEditingController icon;
  final TextEditingController url;
  _SocialRow({String label = '', String icon = '', String url = ''})
      : label = TextEditingController(text: label),
        icon = TextEditingController(text: icon),
        url = TextEditingController(text: url);
}

class PatrocinadorFormScreen extends StatefulWidget {
  const PatrocinadorFormScreen({super.key, this.patrocinador, this.apiClient});
  final Patrocinador? patrocinador;
  final ApiClient? apiClient;

  @override
  State<PatrocinadorFormScreen> createState() => _PatrocinadorFormScreenState();
}

class _PatrocinadorFormScreenState extends State<PatrocinadorFormScreen> {
  final _formKey = GlobalKey<FormState>();
  late final ApiClient _api = widget.apiClient ?? ApiClient();
  late final _name = TextEditingController(text: widget.patrocinador?.name ?? '');
  late final _category = TextEditingController(text: widget.patrocinador?.category ?? '');
  late final _categoryLabel = TextEditingController(text: widget.patrocinador?.categoryLabel ?? '');
  late final _icon = TextEditingController(text: widget.patrocinador?.icon ?? '');
  late final _subtitle = TextEditingController(text: widget.patrocinador?.subtitle ?? '');
  late final _summary = TextEditingController(text: widget.patrocinador?.summary ?? '');
  late final _description = TextEditingController(text: widget.patrocinador?.description ?? '');
  late final _map = TextEditingController(text: widget.patrocinador?.map ?? '');
  late final _sortOrder = TextEditingController(text: (widget.patrocinador?.sortOrder ?? 0).toString());
  late List<_SocialRow> _socials = (widget.patrocinador?.socials ?? [])
      .map((s) => _SocialRow(label: s.label, icon: s.icon, url: s.url))
      .toList();
  File? _newImage;
  bool _saving = false;

  bool get _isEditing => widget.patrocinador != null;

  void _addSocial() => setState(() => _socials.add(_SocialRow()));
  void _removeSocial(int index) => setState(() => _socials.removeAt(index));

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _saving = true);
    final socialsJson = jsonEncode(_socials
        .map((s) => {'label': s.label.text.trim(), 'icon': s.icon.text.trim(), 'url': s.url.text.trim()})
        .where((s) => (s['label'] as String).isNotEmpty || (s['url'] as String).isNotEmpty)
        .toList());
    final fields = {
      'name': _name.text.trim(),
      'category': _category.text.trim(),
      'category_label': _categoryLabel.text.trim(),
      'icon': _icon.text.trim(),
      'subtitle': _subtitle.text.trim(),
      'summary': _summary.text.trim(),
      'description': _description.text,
      'map': _map.text.trim(),
      'sort_order': _sortOrder.text.trim().isEmpty ? '0' : _sortOrder.text.trim(),
      'socials_json': socialsJson,
    };
    final path = _isEditing ? '/site/patrocinadores/${widget.patrocinador!.id}' : '/site/patrocinadores';
    try {
      await _api.postMultipart(path, fields, fileField: 'image', file: _newImage);
      if (mounted) Navigator.of(context).pop(true);
    } catch (e) {
      setState(() => _saving = false);
      if (mounted) await handleApiError(context, e);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(_isEditing ? 'Editar patrocinador' : 'Nuevo patrocinador')),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            ImagePickerField(
              currentImageUrl: widget.patrocinador?.image,
              onImageSelected: (file) => setState(() => _newImage = file),
            ),
            const SizedBox(height: 16),
            LabeledTextField(
              controller: _name,
              label: 'Nombre',
              validator: (v) => (v == null || v.trim().isEmpty) ? 'El nombre es requerido' : null,
            ),
            LabeledTextField(controller: _category, label: 'Categoría (clave interna)'),
            LabeledTextField(controller: _categoryLabel, label: 'Categoría (texto visible)'),
            LabeledTextField(controller: _icon, label: 'Ícono'),
            LabeledTextField(controller: _subtitle, label: 'Subtítulo'),
            LabeledTextField(controller: _summary, label: 'Resumen', maxLines: 2),
            LabeledTextField(controller: _description, label: 'Descripción', maxLines: 4),
            LabeledTextField(controller: _map, label: 'Enlace o dato de ubicación'),
            LabeledTextField(
              controller: _sortOrder,
              label: 'Orden',
              keyboardType: TextInputType.number,
            ),
            const SizedBox(height: 16),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text('Redes sociales', style: TextStyle(fontWeight: FontWeight.bold)),
                IconButton(icon: const Icon(Icons.add_circle), onPressed: _addSocial),
              ],
            ),
            for (var i = 0; i < _socials.length; i++)
              Card(
                margin: const EdgeInsets.only(bottom: 8),
                child: Padding(
                  padding: const EdgeInsets.all(8),
                  child: Column(
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.end,
                        children: [
                          IconButton(
                            icon: const Icon(Icons.delete_outline),
                            onPressed: () => _removeSocial(i),
                          ),
                        ],
                      ),
                      LabeledTextField(controller: _socials[i].label, label: 'Nombre de la red'),
                      LabeledTextField(controller: _socials[i].icon, label: 'Ícono'),
                      LabeledTextField(controller: _socials[i].url, label: 'URL'),
                    ],
                  ),
                ),
              ),
            const SizedBox(height: 16),
            ElevatedButton(
              onPressed: _saving ? null : _submit,
              child: _saving
                  ? const SizedBox(height: 20, width: 20, child: CircularProgressIndicator(strokeWidth: 2))
                  : const Text('Guardar'),
            ),
          ],
        ),
      ),
    );
  }
}
```

- [ ] **Step 2: Implement the list screen**

Create `lib/screens/patrocinadores/list_screen.dart`:

```dart
import 'package:flutter/material.dart';
import '../../core/api_client.dart';
import '../../core/auth_guard.dart';
import '../../models/patrocinador.dart';
import '../../widgets/content_list_tile.dart';
import 'form_screen.dart';

class PatrocinadoresListScreen extends StatefulWidget {
  const PatrocinadoresListScreen({super.key, this.apiClient});
  final ApiClient? apiClient;

  @override
  State<PatrocinadoresListScreen> createState() => _PatrocinadoresListScreenState();
}

class _PatrocinadoresListScreenState extends State<PatrocinadoresListScreen> {
  late final ApiClient _api = widget.apiClient ?? ApiClient();
  List<Patrocinador> _items = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    try {
      final response = await _api.get('/site/patrocinadores');
      final items = (response['items'] as List)
          .map((e) => Patrocinador.fromJson(e as Map<String, dynamic>))
          .toList();
      setState(() {
        _items = items;
        _loading = false;
      });
    } catch (e) {
      setState(() => _loading = false);
      if (mounted) await handleApiError(context, e);
    }
  }

  Future<void> _delete(Patrocinador patrocinador) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Eliminar patrocinador'),
        content: Text('¿Eliminar "${patrocinador.name}"? Esta acción no se puede deshacer.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancelar')),
          TextButton(onPressed: () => Navigator.pop(context, true), child: const Text('Eliminar')),
        ],
      ),
    );
    if (confirmed != true) return;
    try {
      await _api.postJson('/site/patrocinadores/${patrocinador.id}/delete', {});
      _load();
    } catch (e) {
      if (mounted) await handleApiError(context, e);
    }
  }

  Future<void> _openForm({Patrocinador? patrocinador}) async {
    final saved = await Navigator.of(context).push<bool>(
      MaterialPageRoute(
        builder: (_) => PatrocinadorFormScreen(patrocinador: patrocinador, apiClient: _api),
      ),
    );
    if (saved == true) _load();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Sección azul — Patrocinadores')),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              onRefresh: _load,
              child: _items.isEmpty
                  ? ListView(
                      children: const [
                        Padding(
                          padding: EdgeInsets.all(32),
                          child: Center(child: Text('No hay patrocinadores todavía')),
                        ),
                      ],
                    )
                  : ListView.builder(
                      itemCount: _items.length,
                      itemBuilder: (context, index) {
                        final item = _items[index];
                        return ContentListTile(
                          title: item.name,
                          subtitle: item.categoryLabel,
                          imageUrl: item.image,
                          onEdit: () => _openForm(patrocinador: item),
                          onDelete: () => _delete(item),
                        );
                      },
                    ),
            ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => _openForm(),
        child: const Icon(Icons.add),
      ),
    );
  }
}
```

- [ ] **Step 3: Verify static analysis is clean**

Run: `flutter analyze lib/screens/patrocinadores`
Expected: `No issues found!`

- [ ] **Step 4: Commit**

```bash
git add lib/screens/patrocinadores
git commit -m "feat: add Patrocinadores (Sección azul) list and form screens"
```

---

## Task 13: Podcasts section (list + form with episodes editor)

**Files:**
- Create: `lib/screens/podcasts/list_screen.dart`
- Create: `lib/screens/podcasts/form_screen.dart`

**Interfaces:**
- Consumes: `ApiClient`, `Podcast`, `PodcastEpisode` (Task 3), shared widgets (Task 4), `handleApiError` (Task 5).
- Produces: `PodcastsListScreen({Key? key, ApiClient? apiClient})`, `PodcastFormScreen({Key? key, Podcast? podcast, ApiClient? apiClient})`.

No automated test for this task — verified with `flutter analyze` and a manual run in Task 14 (including adding/removing an episode row).

- [ ] **Step 1: Implement the form screen with an inline episodes editor**

Create `lib/screens/podcasts/form_screen.dart`:

```dart
import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import '../../core/api_client.dart';
import '../../core/auth_guard.dart';
import '../../models/podcast.dart';
import '../../widgets/labeled_text_field.dart';
import '../../widgets/image_picker_field.dart';

class _EpisodeRow {
  final TextEditingController title;
  final TextEditingController description;
  final TextEditingController audioUrl;
  final TextEditingController categoryLabel;
  _EpisodeRow({String title = '', String description = '', String audioUrl = '', String categoryLabel = ''})
      : title = TextEditingController(text: title),
        description = TextEditingController(text: description),
        audioUrl = TextEditingController(text: audioUrl),
        categoryLabel = TextEditingController(text: categoryLabel);
}

class PodcastFormScreen extends StatefulWidget {
  const PodcastFormScreen({super.key, this.podcast, this.apiClient});
  final Podcast? podcast;
  final ApiClient? apiClient;

  @override
  State<PodcastFormScreen> createState() => _PodcastFormScreenState();
}

class _PodcastFormScreenState extends State<PodcastFormScreen> {
  final _formKey = GlobalKey<FormState>();
  late final ApiClient _api = widget.apiClient ?? ApiClient();
  late final _title = TextEditingController(text: widget.podcast?.title ?? '');
  late final _filterIcon = TextEditingController(text: widget.podcast?.filterIcon ?? '');
  late final _sortOrder = TextEditingController(text: (widget.podcast?.sortOrder ?? 0).toString());
  late List<_EpisodeRow> _episodes = (widget.podcast?.episodes ?? [])
      .map((e) => _EpisodeRow(
            title: e.title,
            description: e.description,
            audioUrl: e.audioUrl,
            categoryLabel: e.categoryLabel,
          ))
      .toList();
  File? _newCover;
  bool _saving = false;

  bool get _isEditing => widget.podcast != null;

  void _addEpisode() => setState(() => _episodes.add(_EpisodeRow()));
  void _removeEpisode(int index) => setState(() => _episodes.removeAt(index));

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _saving = true);
    final episodesJson = jsonEncode(_episodes
        .map((e) => {
              'title': e.title.text.trim(),
              'description': e.description.text.trim(),
              'audio_url': e.audioUrl.text.trim(),
              'category_label': e.categoryLabel.text.trim(),
            })
        .where((e) => (e['title'] as String).isNotEmpty)
        .toList());
    final fields = {
      'title': _title.text.trim(),
      'filter_icon': _filterIcon.text.trim(),
      'sort_order': _sortOrder.text.trim().isEmpty ? '0' : _sortOrder.text.trim(),
      'episodes_json': episodesJson,
    };
    final path = _isEditing ? '/site/podcasts/${widget.podcast!.id}' : '/site/podcasts';
    try {
      await _api.postMultipart(path, fields, fileField: 'cover', file: _newCover);
      if (mounted) Navigator.of(context).pop(true);
    } catch (e) {
      setState(() => _saving = false);
      if (mounted) await handleApiError(context, e);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(_isEditing ? 'Editar podcast' : 'Nuevo podcast')),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            ImagePickerField(
              currentImageUrl: widget.podcast?.cover,
              onImageSelected: (file) => setState(() => _newCover = file),
            ),
            const SizedBox(height: 16),
            LabeledTextField(
              controller: _title,
              label: 'Título',
              validator: (v) => (v == null || v.trim().isEmpty) ? 'El título es requerido' : null,
            ),
            LabeledTextField(controller: _filterIcon, label: 'Ícono de filtro'),
            LabeledTextField(
              controller: _sortOrder,
              label: 'Orden',
              keyboardType: TextInputType.number,
            ),
            const SizedBox(height: 16),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text('Episodios', style: TextStyle(fontWeight: FontWeight.bold)),
                IconButton(icon: const Icon(Icons.add_circle), onPressed: _addEpisode),
              ],
            ),
            for (var i = 0; i < _episodes.length; i++)
              Card(
                margin: const EdgeInsets.only(bottom: 8),
                child: Padding(
                  padding: const EdgeInsets.all(8),
                  child: Column(
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.end,
                        children: [
                          IconButton(
                            icon: const Icon(Icons.delete_outline),
                            onPressed: () => _removeEpisode(i),
                          ),
                        ],
                      ),
                      LabeledTextField(controller: _episodes[i].title, label: 'Título del episodio'),
                      LabeledTextField(
                        controller: _episodes[i].description,
                        label: 'Descripción',
                        maxLines: 2,
                      ),
                      LabeledTextField(controller: _episodes[i].audioUrl, label: 'URL del audio'),
                      LabeledTextField(controller: _episodes[i].categoryLabel, label: 'Categoría'),
                    ],
                  ),
                ),
              ),
            const SizedBox(height: 16),
            ElevatedButton(
              onPressed: _saving ? null : _submit,
              child: _saving
                  ? const SizedBox(height: 20, width: 20, child: CircularProgressIndicator(strokeWidth: 2))
                  : const Text('Guardar'),
            ),
          ],
        ),
      ),
    );
  }
}
```

- [ ] **Step 2: Implement the list screen**

Create `lib/screens/podcasts/list_screen.dart`:

```dart
import 'package:flutter/material.dart';
import '../../core/api_client.dart';
import '../../core/auth_guard.dart';
import '../../models/podcast.dart';
import '../../widgets/content_list_tile.dart';
import 'form_screen.dart';

class PodcastsListScreen extends StatefulWidget {
  const PodcastsListScreen({super.key, this.apiClient});
  final ApiClient? apiClient;

  @override
  State<PodcastsListScreen> createState() => _PodcastsListScreenState();
}

class _PodcastsListScreenState extends State<PodcastsListScreen> {
  late final ApiClient _api = widget.apiClient ?? ApiClient();
  List<Podcast> _items = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    try {
      final response = await _api.get('/site/podcasts');
      final items = (response['items'] as List)
          .map((e) => Podcast.fromJson(e as Map<String, dynamic>))
          .toList();
      setState(() {
        _items = items;
        _loading = false;
      });
    } catch (e) {
      setState(() => _loading = false);
      if (mounted) await handleApiError(context, e);
    }
  }

  Future<void> _delete(Podcast podcast) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Eliminar podcast'),
        content: Text('¿Eliminar "${podcast.title}"? Esta acción no se puede deshacer.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancelar')),
          TextButton(onPressed: () => Navigator.pop(context, true), child: const Text('Eliminar')),
        ],
      ),
    );
    if (confirmed != true) return;
    try {
      await _api.postJson('/site/podcasts/${podcast.id}/delete', {});
      _load();
    } catch (e) {
      if (mounted) await handleApiError(context, e);
    }
  }

  Future<void> _openForm({Podcast? podcast}) async {
    final saved = await Navigator.of(context).push<bool>(
      MaterialPageRoute(builder: (_) => PodcastFormScreen(podcast: podcast, apiClient: _api)),
    );
    if (saved == true) _load();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Podcast')),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              onRefresh: _load,
              child: _items.isEmpty
                  ? ListView(
                      children: const [
                        Padding(
                          padding: EdgeInsets.all(32),
                          child: Center(child: Text('No hay podcasts todavía')),
                        ),
                      ],
                    )
                  : ListView.builder(
                      itemCount: _items.length,
                      itemBuilder: (context, index) {
                        final item = _items[index];
                        return ContentListTile(
                          title: item.title,
                          subtitle: '${item.episodes.length} episodio(s)',
                          imageUrl: item.cover,
                          onEdit: () => _openForm(podcast: item),
                          onDelete: () => _delete(item),
                        );
                      },
                    ),
            ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => _openForm(),
        child: const Icon(Icons.add),
      ),
    );
  }
}
```

- [ ] **Step 3: Verify static analysis is clean**

Run: `flutter analyze lib/screens/podcasts`
Expected: `No issues found!`

- [ ] **Step 4: Commit**

```bash
git add lib/screens/podcasts
git commit -m "feat: add Podcasts list and form screens"
```

---

## Task 14: Final wiring, full test suite, manual smoke test, README

**Files:**
- Modify: `README.md`

**Interfaces:**
- Consumes: everything from Tasks 1–13. This task performs no new production code — it verifies the whole app compiles and behaves, and documents how to run it.

- [ ] **Step 1: Run the full analyzer**

Run: `flutter analyze`
Expected: `No issues found!` (fix any import/typo issues surfaced by wiring `HomeScreen` to the 7 list screens before proceeding).

- [ ] **Step 2: Run the full test suite**

Run: `flutter test`
Expected: All tests pass (Session, ApiClient, 7 models, LoginScreen, AnunciosListScreen).

- [ ] **Step 3: Update the README with setup and run instructions**

Replace `README.md` with:

```markdown
# doliv_social — Admin de contenido Radio Doliv

App Flutter simple para que el director administre el contenido del sitio
público (Servicios, Programas, Podcast, Anuncios, Eventos, Equipo, Sección
azul), consumiendo la API existente en `hive-backend`.

## Requisitos

- XAMPP corriendo con Apache + MySQL, sirviendo `hive-backend` y
  `RADIODOLIV_PAGINA` como hermanos bajo `htdocs/radio-doliv/`.
- Un usuario con rol `director` ya creado en `hive_db.users`.
- Flutter SDK instalado (`flutter doctor` sin errores).

## Cómo correr la app

```bash
flutter pub get
flutter run
```

En emulador Android, la app usa automáticamente `10.0.2.2` en vez de
`localhost` para llegar al XAMPP de la máquina host (ver
`lib/core/api_config.dart`). En un dispositivo físico o en Windows/desktop,
ajusta `ApiConfig` si el backend no vive en `localhost`.

## Pruebas

```bash
flutter test
flutter analyze
```
```

- [ ] **Step 4: Manual smoke test against the local backend**

With XAMPP running (Apache + MySQL) and a `director` user available:

1. `flutter run` (choose an Android emulator or a connected device on the
   same network as the XAMPP host).
2. Log in with the director's email/password → should land on the 7-section
   menu.
3. Open "Anuncios" → create one with an image from the gallery → confirm it
   appears in the list and the image renders.
4. Edit that same anuncio (change the title) → confirm the change persists
   after pulling to refresh.
5. Delete it → confirm the confirmation dialog appears and the item is
   removed after confirming.
6. Repeat steps 3–5 briefly for "Sección azul" (add one social link row) and
   "Podcast" (add one episode row) to confirm the JSON sub-list editors work.
7. Log out (top-right icon) → confirm it returns to the login screen and a
   second login still works.

Note any failures found during this manual pass and fix them before
considering the plan complete — this step has no automated substitute.

- [ ] **Step 5: Commit**

```bash
git add README.md
git commit -m "docs: add setup/run instructions for the content admin app"
```

---

## Self-Review Notes

- **Spec coverage:** auth (Task 5), 7 sections' list+create+edit+delete
  (Tasks 7–13), image upload (Task 4 `ImagePickerField` + used in every form),
  error handling incl. 401/403 (Task 5 `handleApiError`, used everywhere),
  sponsor socials + podcast episodes sub-lists (Tasks 12–13), minimal testing
  scope (Global Constraints + explicit non-test notes on Tasks 4, 6, 8–13),
  new dependencies (Task 1). All spec sections are covered.
- **Type consistency verified:** every model's `fromJson` field name matches
  the corresponding form screen's `toFields()`/inline field map keys, which
  match the exact `$_POST` keys read in `site_content.php` (cross-checked
  against the file directly). `ApiClient.postMultipart`'s `fileField`
  parameter name matches each section's backend upload field: `imagen`
  (anuncios), `image` (eventos/servicios/equipo/programas), `image`
  (patrocinadores), `cover` (podcasts).
- **Ordering dependency:** Task 6 (`HomeScreen`) and Task 5's `main.dart`
  reference the 7 section screens before they exist (Tasks 7–13) — this is
  called out explicitly in both tasks so an executor doesn't treat the
  resulting compile error as a bug in their own task.
