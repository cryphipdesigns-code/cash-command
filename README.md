# Cash Command

Single-page personal finance dashboard.

## Backend

Live data writes use Supabase only. Live View requires a Supabase Auth session;
Demo View stays local and safe to share. The app stores ordinary input fields in
the `app_fields` table by `(user_id, input id)`, and stores budget-check history
plus weekly budget transactions as JSON strings in the same table under these
keys:

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

## Privacy Setup

Add the local and hosted Cash Command URLs to Supabase Auth redirect URLs so
magic-link sign-in can return to the app.

To preserve existing live data:

1. Sign in once through Cash Command so your Supabase Auth user exists.
2. Find your user id in Supabase Auth.
3. Apply `supabase/migrations/20260616000000_private_app_fields.sql`.
4. Adopt legacy rows with:

```bash
SUPABASE_URL=https://your-project.supabase.co \
SUPABASE_SERVICE_ROLE_KEY=... \
CASH_OWNER_USER_ID=your-auth-user-id \
node scripts/adopt-private-data.mjs
```

The script writes a local backup under `.tmp-backups/` before changing rows.
