# POS Kasir Flutter

Flutter frontend for POS Kasir.

By default the app calls the backend at `http://localhost:3000`.
On Android emulator builds, the app first tries device loopback
`http://127.0.0.1:3000` for `adb reverse`, then falls back to
`http://10.0.2.2:3000`.

Override the API base URL when needed:

```bash
flutter run -d windows --dart-define=API_BASE_URL=http://localhost:3000
flutter run -d chrome --dart-define=API_BASE_URL=http://localhost:3000
flutter run -d android --dart-define=API_BASE_URL=http://10.0.2.2:3000
```

Android emulator startup:

1. Start PostgreSQL and the backend.
2. Seed auth users once.
3. Start the emulator from Android Studio or `flutter emulators --launch <id>`.
4. Run:

```bash
adb reverse tcp:3000 tcp:3000
flutter run -d emulator
```

Use `adb reverse` to bridge the emulator's port `3000` to the backend on the
host machine. Re-run it if the emulator is restarted.

Demo username logins:

- `kasir` / `password1234`
- `manajer` / `password1234`
- `admin` / `password1234`

Current frontend modules include POS checkout with per-customer/product-group
discounts, searchable customer/payment selectors, printable receipts,
inventory with product group and location/gudang tabs, stock-per-location
editing, customer discount management, multi-item purchases, transaction-based
returns, paged reports with Excel export, and administrator role authorization.

Large lists are paged. Use the `Muat Lagi` button to fetch the next page.
Dropdowns are searchable and open as picker dialogs, including customer,
supplier, product, role, report filter, and payment method selectors.

## Getting Started

Run checks before handing over changes:

```bash
flutter analyze
flutter test
```

Useful run commands:

```bash
flutter run -d chrome
flutter run -d windows
flutter run -d emulator
```

## Demo Vercel Deployment

The repository includes `.github/workflows/deploy-demo-vercel.yml` for the
Flutter web demo build.

Required GitHub secrets, either as repository secrets or as environment secrets
on the GitHub environment named `production`:

- `VERCEL_TOKEN`
- `VERCEL_ORG_ID`
- `VERCEL_PROJECT_ID`

Required GitHub variable:

- `BACKEND_PRODUCTION_URL=https://<backend-production-domain>`

The workflow runs on pushes to `main` and manual dispatch. It installs Flutter,
runs analyze/tests, builds web with:

```bash
flutter build web --release --no-wasm-dry-run --dart-define=API_BASE_URL=$BACKEND_PRODUCTION_URL
```

Then it deploys `build/web` to Vercel. The included `vercel.json` is copied into
the output directory so Flutter web routes fall back to `index.html`.
