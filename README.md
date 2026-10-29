# V8 bug-fix release

- Main-screen shop button, local item bar, health, XP and team widgets are forcibly hidden.
- The corner live panel starts open and now has a working hide/show button.
- Lobby controls have explicit dark styling, avoiding white-on-white buttons.
- Phone pages never autojoin. The room comes only from the current QR URL, and the name/color/avatar remain editable before joining.
- The SQL join function is now room-aware: same-room rejoin preserves progress; joining a different room moves the anonymous user into the new room and resets old-game state.

Run UPGRADE-EXISTING.sql again, copy config values, restart Python and hard-refresh.
