import 'dart:convert';

String joinTeamToJson(JoinTeam data) => json.encode(data.toJson());

class JoinTeam {
  String teamCode;

  JoinTeam({required this.teamCode});

  Map<String, dynamic> toJson() => {
    "teamCode": teamCode,
  };
}