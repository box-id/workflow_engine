# Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.1.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [Unreleased]

Unreleased changes will be displayed here upon implementation.

## [1.1.0] - 2024-11-25

### Added

- Support for Req 0.5.x
- Pipeline for tests

### Changed

- Updated Elixir version to 1.17 and Erlang to 27

### Deprecated

- Support for Req 0.3.x (Note that, unrelated to the changes in this library, a warning will be
  logged on every request if used together with Finch >= 0.17)

[unreleased]: https://github.com/box-id/workflow_engine/compare/1.1.0...HEAD
[1.1.0]: https://github.com/box-id/workflow_engine/releases/tag/1.1.0