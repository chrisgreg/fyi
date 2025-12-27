# Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [Unreleased]

### Added

- **Automatic HTTP retries** - `FYI.Client` module with exponential backoff for sink delivery
  - Retries transient failures (network errors, 5xx status codes) up to 3 times
  - Exponential backoff with delays of 1s, 2s, 4s
  - Respects `Retry-After` response headers
  - Configurable via `:http_client` config (max_retries, retry_delay)

### Changed

- Sinks now use `FYI.Client.post/2` for HTTP requests instead of raw `Req.post/2`

## [1.0.0] - 2024-12-26

### Added

- **Event emission** - `FYI.emit/3` for emitting events with payload, actor, source, tags, and emoji
- **Ecto.Multi integration** - `FYI.Multi.emit/3` for transactional event emission
- **Slack webhook sink** - Send notifications to Slack channels
- **Telegram bot sink** - Send notifications to Telegram chats
- **Event routing** - Route events to specific sinks based on glob patterns
- **Event persistence** - Optional database storage via Ecto
- **Admin inbox UI** - LiveView-based event viewer with:
  - Activity histogram with time-based tooltips
  - Time range filtering (5 minutes to all time)
  - Event type filtering
  - Search by event name or actor
  - Event detail panel
  - Real-time updates via PubSub
- **Feedback component** - Customizable feedback widget installed into your codebase
- **Igniter installer** - `mix fyi.install` for one-command setup
- **Emoji support** - Per-event, pattern-based, and default emoji configuration
- **App name identification** - Identify events when multiple apps share channels

