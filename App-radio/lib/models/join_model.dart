import 'dart:convert';

JoinTeam joinTeamFromJson(String str) => JoinTeam.fromJson(json.decode(str));

String joinTeamToJson(JoinTeam data) => json.encode(data.toJson());

class JoinTeam {
  String teamCode;

  JoinTeam({
    required this.teamCode,
  });

  factory JoinTeam.fromJson(Map<String, dynamic> json) => JoinTeam(
    teamCode: json["teamCode"],
  );

  Map<String, dynamic> toJson() => {
    "teamCode": teamCode,
  };
}