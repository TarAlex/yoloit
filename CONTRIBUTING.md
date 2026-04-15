# Contributing to YoLoIT

Thank you for contributing to YoLoIT.

## Before you start

- Use issues or pull requests to discuss non-trivial changes before implementing them.
- Keep changes focused and avoid mixing unrelated fixes in a single pull request.
- Update documentation when behavior or workflows change.

## Local setup

YoLoIT is a Flutter desktop application.

### Requirements

- Flutter SDK compatible with Dart `^3.9.2`
- Git
- a desktop target supported by your local Flutter toolchain

Optional but recommended:

- `tmux`
- `rg` (ripgrep)
- one or more supported AI CLIs such as GitHub Copilot, Claude Code, Gemini CLI, or Cursor Agent

### Development commands

```bash
flutter pub get
flutter analyze --no-pub
flutter test
```

## Project conventions

### Architecture

- Feature code lives under `lib/features/`.
- Shared platform-specific code lives under `lib/core/platform/`.
- State is primarily managed with `Cubit` / `Bloc`.

### Platform rules

If you touch platform behavior:

- keep `Platform.isMacOS`, `Platform.isLinux`, and `Platform.isWindows` checks inside `lib/core/platform/`
- use the existing platform abstractions instead of calling OS tools directly from feature code
- do not hardcode platform-specific paths or shell locations outside the platform layer

### Tests

- Add or update tests for behavior changes.
- Platform-specific operations should be covered with focused unit tests.
- Regressions in persistence, restore, editor, terminal, and workspace flows should be captured with unit or widget tests where practical.

## Pull request expectations

Please make sure your change:

- is scoped to one clear goal
- keeps existing behavior stable unless the change intentionally updates it
- includes tests or documentation updates when appropriate
- passes analysis and test checks locally

## Licensing of contributions

By submitting a contribution to this repository, you agree that your contribution will be licensed under the Apache License, Version 2.0, unless explicitly stated otherwise in writing.
