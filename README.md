# V9 fixes
- Player phones send a heartbeat every 5 seconds. The host treats players with no heartbeat for 15 seconds as disconnected and excludes them from auto-evaluation.
- The timer now evaluates at zero even when the original single-player engine has locked its local controls.
- The projector shop overlay, shop button and local item toolbar are all forcibly hidden.
- The phone shop is hidden during questions and opens automatically after each result.
- A green animated purchase notification confirms every successful purchase.

Run UPGRADE-EXISTING.sql, restart the server and hard-refresh all devices.
