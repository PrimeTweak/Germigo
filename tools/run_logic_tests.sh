#!/bin/sh
# Compiles and runs the logic checks on a Mac, without Xcode projects or simulators.
# Usage: sh tools/run_logic_tests.sh
set -e
cd "$(dirname "$0")/.."
OUT="${TMPDIR:-/tmp}/germily-logic-tests"
xcrun swiftc -swift-version 5 -o "$OUT" \
  Tests/LogicTests/main.swift \
  Shared/L10n.swift Shared/Swatch.swift \
  App/Models/AppData.swift App/Models/Germ.swift App/Models/Progress.swift \
  App/Store/JournalRules.swift App/Store/RewardEngine.swift App/Store/StatsEngine.swift App/Store/Persistence.swift \
  App/Store/ProgressEngine.swift App/Store/QuizEngine.swift App/Store/SymptomEngine.swift \
  App/Store/DayEngine.swift App/Store/LessonEngine.swift App/Store/PassRules.swift App/Design/CharacterPose.swift \
  App/Design/MascotMind.swift
"$OUT"
