# Cash Command

Single-page personal finance dashboard.

## Backend

Live data writes use Supabase only. The app stores ordinary input fields in the
`app_fields` table by input id, and stores budget-check history plus weekly
budget transactions as JSON strings in the same table under these keys:

- `budgetCheckRowsData`
- `weeklyBudgetRowsData`

The old Google Apps Script endpoints are no longer used for writes. They remain
only as legacy import fallbacks: if Supabase has no saved budget-check or weekly
transaction rows yet, the app reads the old Sheet data once and then saves that
history into Supabase.

## Reliability

The app keeps unsynced field edits in local storage under
`cashCommandPendingFieldValues` until Supabase confirms the save. Budget-check
and weekly transaction changes are queued under `cashCommandPendingRecordWrites`
before the network request starts, then removed only after Supabase confirms.

Pending saves are flushed when the page is hidden, unloaded, or navigated away.
If live sync fails, the status text reports that the change is local instead of
claiming success.
