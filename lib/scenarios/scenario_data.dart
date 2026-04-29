// lib/scenarios/scenario_data.dart
import 'package:flutter/material.dart';

class ScenarioStep {
  final String title;
  final String instruction;
  final String explanation;
  final String? cliHint;
  final ScenarioStepType type;

  const ScenarioStep({
    required this.title,
    required this.instruction,
    required this.explanation,
    this.cliHint,
    this.type = ScenarioStepType.read,
  });
}

enum ScenarioStepType { read, observe, cli, quiz }

class ScenarioData {
  final String id;
  final String title;
  final String description;
  final String difficulty;
  final String category;
  final IconData icon;
  final Color color;
  final List<ScenarioStep> steps;
  final String? relatedProtocol;

  const ScenarioData({
    required this.id,
    required this.title,
    required this.description,
    required this.difficulty,
    required this.category,
    required this.icon,
    required this.color,
    required this.steps,
    this.relatedProtocol,
  });
}
