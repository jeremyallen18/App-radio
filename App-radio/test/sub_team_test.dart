// Modelos de sub-equipos (migración 030): cómo se leen las respuestas de
// /subteam/* y el campo subTeam que /dept-tasks agrega a cada tarea.

import 'package:flutter_test/flutter_test.dart';

import 'package:doliv_social/models/dept_task.dart';
import 'package:doliv_social/models/models.dart';
import 'package:doliv_social/models/sub_team.dart';

void main() {
  group('SubTeam.fromJson', () {
    test('lee id, área, líder y miembros', () {
      final s = SubTeam.fromJson({
        'id': 'st1',
        'departmentId': 'd1',
        'name': 'Frontend',
        'description': 'Interfaz',
        'lead': {'id': 'u9', 'name': 'Ana', 'email': 'ana@x.com', 'role': 'employee'},
        'memberCount': 2,
        'members': [
          {'id': 'u9', 'name': 'Ana', 'email': 'ana@x.com', 'role': 'employee'},
          {'id': 'u8', 'name': 'Beto', 'email': 'beto@x.com', 'role': 'employee'},
        ],
      });

      expect(s.id, 'st1');
      expect(s.departmentId, 'd1');
      expect(s.name, 'Frontend');
      expect(s.description, 'Interfaz');
      expect(s.lead?.id, 'u9');
      expect(s.memberCount, 2);
      expect(s.members.map((m) => m.name), ['Ana', 'Beto']);
      expect(s.isLeadUser('u9'), isTrue);
      expect(s.isLeadUser('u8'), isFalse);
    });

    test('sin líder ni miembros', () {
      final s = SubTeam.fromJson({'id': 'st2', 'departmentId': 'd1', 'name': 'QA'});
      expect(s.lead, isNull);
      expect(s.members, isEmpty);
      expect(s.memberCount, 0);
      expect(s.isLeadUser('u1'), isFalse);
    });
  });

  test('DeptTask.subTeam se parsea cuando viene, y es null si no', () {
    Map<String, dynamic> base(Object? subTeam) => {
          'id': 't1',
          'departmentId': 'd1',
          'title': 'Tarea',
          'status': 'pendiente',
          if (subTeam != null) 'subTeam': subTeam,
        };

    final withST = DeptTask.fromJson(base({'id': 'st1', 'name': 'Frontend'}));
    expect(withST.subTeam?.id, 'st1');
    expect(withST.subTeam?.name, 'Frontend');

    final withoutST = DeptTask.fromJson(base(null));
    expect(withoutST.subTeam, isNull);
  });

  test('UserProfile.ledSubTeams se lee de /user/me', () {
    final p = UserProfile.fromJson({
      'id': 'u1',
      'name': 'Ana',
      'email': 'ana@x.com',
      'role': 'employee',
      'ledSubTeams': [
        {'id': 'st1', 'name': 'Frontend', 'departmentId': 'd1'},
      ],
    });
    expect(p.ledSubTeams, hasLength(1));
    expect(p.ledSubTeams.first.name, 'Frontend');
    expect(p.ledSubTeams.first.departmentId, 'd1');

    final none = UserProfile.fromJson({
      'id': 'u2', 'name': 'B', 'email': 'b@x.com', 'role': 'employee',
    });
    expect(none.ledSubTeams, isEmpty);
  });
}
