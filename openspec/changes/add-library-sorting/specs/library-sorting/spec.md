## ADDED Requirements
### Requirement: Library ordering
The system SHALL default books to natural title ascending and audio files to natural filename ascending, and SHALL offer import-time ordering and ascending/descending direction independently for each list.

#### Scenario: Default order
- **WHEN** a user opens either list without saved sorting preferences
- **THEN** items appear in natural name ascending order

#### Scenario: Import-time order
- **WHEN** a user chooses import time descending
- **THEN** newly imported records appear first with deterministic ties

#### Scenario: Preferences persist
- **WHEN** a user restarts the application after changing sorting
- **THEN** each list restores its own choice

### Requirement: Playback follows displayed audio order
The system SHALL navigate and build playback queues in the same order as the audio list without modifying stored sort_order.

#### Scenario: Sorting changes during playback
- **WHEN** audio sorting changes during playback
- **THEN** the current audio and position remain and subsequent navigation follows the new order
