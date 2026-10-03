import '../ai/logos_prompt.dart';
import '../engine/game.dart';

/// Filters teacher labels using the app's rules. A legal move is still only a
/// review candidate: this does not verify playing strength or explanations.
Map<String, Object?> reviewTeacherExample({
  required String id,
  required GoGame game,
  required String response,
  required String teacher,
  String? finishReason,
}) {
  String? rejection;
  final parsed = parseLogosResponse(response, game.size);
  if (game.size != 19) {
    rejection = 'unsupported_teacher_board_size';
  } else if (game.phase != GamePhase.playing) {
    rejection = 'game_not_playing';
  } else if (!RegExp(
    r'<answer>.*?</answer>',
    dotAll: true,
    caseSensitive: false,
  ).hasMatch(response)) {
    rejection = 'incomplete_answer';
  } else if (RegExp(
            r'<answer>.*?</answer>',
            dotAll: true,
            caseSensitive: false,
          ).allMatches(response).length !=
          1 ||
      RegExp(r'下一步位置\s*[:：]')
              .allMatches(
                RegExp(
                  r'<answer>(.*?)</answer>',
                  dotAll: true,
                  caseSensitive: false,
                ).firstMatch(response)!.group(1)!,
              )
              .length !=
          1) {
    rejection = 'ambiguous_answer';
  } else if (parsed.player != game.toPlay) {
    rejection = 'missing_conflicting_or_wrong_player';
  } else if (!parsed.isPass && parsed.candidates.length != 1) {
    rejection = 'missing_off_board_or_ambiguous_move';
  } else if (!parsed.isPass && !game.isLegal(parsed.point!)) {
    rejection = 'illegal_move';
  }
  final explanation = RegExp(
    r'<reasoning>(.*?)</reasoning>',
    dotAll: true,
  ).firstMatch(response)?.group(1)?.trim();
  return {
    'id': id,
    'teacher': teacher,
    'status': rejection == null ? 'needs_review' : 'rejected',
    'rejection': rejection,
    'board_size': game.size,
    'rules': game.rules.ruleSet.name,
    'komi': game.rules.komi,
    'handicap': game.rules.handicap,
    'side_to_play': game.toPlay.name,
    'moves': game.moves.map((m) => m.notation(game.size)).toList(),
    'board_matrix': logosBoardMatrix(game),
    'teacher_move': rejection == null
        ? parsed.isPass
              ? 'pass'
              : parsed.point!.toCoordinate(game.size)
        : null,
    'teacher_explanation': explanation,
    'raw_response': response,
    'finish_reason': finishReason,
    // Approval must include move-quality and explanation checks. The teacher's
    // boxed win rate is deliberately not promoted to a training value target.
    'move_quality_reviewed': false,
    'explanation_reviewed': false,
  };
}
