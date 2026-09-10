# Splitting `AppController` into namespaced sub-controllers

**Date:** 2026-09-10
**Status:** Approved design, pending implementation plan

## Problem

`lib/src/app/app_controller.dart` is a single 1068-line `ChangeNotifier` class. The
knowledge graph flags it as the most-connected node in the codebase (163 edges) and
its community as the lowest-cohesion cluster in the graph (0.015 — 134 member nodes
that form seven unrelated feature bundles pinned to one object).

It currently owns, in one class:

- **Auth + permissions** — `currentUser`, `demoUsers`, login/logout,
  `loginAsRoleForTest`, every `is*`/`can*` getter, `_rolePermission`/`_canCrud`.
- **Cart / checkout** — `_cart`, `_cartProducts`, add/decrement/remove/setQuantity,
  `cartLines`, `subtotal`/`discountAmount`/`grandTotal`/`cashChange`, `canCheckout`,
  payment method, `cashReceivedAmount`, `discountRateForProduct`,
  `customerGroupDiscounts`.
- **Navigation** — `selectedSection`, `selectSection`, `availableSections`,
  `canViewSection`.
- **Products** — `_products`, `_productNextCursor`, `productSearch` + 3 filter fields,
  `_loadProductPage`, `loadMoreProducts`, `canLoadMoreProducts`, `saveProduct`,
  `deleteProduct`, the `set*Filter` setters.
- **Customers** — `_customers`, `_customerNextCursor`, `selectedCustomer`,
  `searchCustomers`, `loadMoreCustomers`, `canLoadMoreCustomers`, `saveCustomer`,
  `deleteCustomer`.
- **Feature records** (generic keyed master-data cache) — `_featureRecords`,
  `_featureQueryKeys`, `_featureNextCursors`, `_featureLoadFutures`,
  `featureRecords(path)`, `loadFeatureRecords`, `loadMoreFeatureRecords`,
  `canLoadMoreFeatureRecords`, `saveFeatureRecord`, `deleteFeatureRecord`,
  `exportSalesReport`, `exportGenericReport`.
- **Reports** — `salesReport`, `selectedGenericReport`, `loadSalesReport`,
  `loadGenericReport`, `loadMoreGenericReport`, `_invalidateReports`, quick-range
  resolution (`reportRangeFor`, `_quickDateRange`, `_matchingQuickRange`,
  `_exclusiveEnd`, `_reportQuery`, `reportQueryFor`), **plus ~40 fields split into a
  primary set (`selectedReport*`) and a near-identical duplicated "return report"
  set (`selectedReturnReport*`)**.
- **Cross-cutting plumbing** — `_busyDepth`/`isBusy`/`errorMessage`/`_runBusy`,
  `refreshData`/`_refreshDataFuture`, `checkout`.

Concrete duplication confirmed in source:

- Pagination cursor handling implemented three times (`_productNextCursor`,
  `_customerNextCursor`, `_featureNextCursors` map), each with its own
  `_loadXPage` / `loadMoreX` / `canLoadMoreX`.
- Report filter state duplicated for the "return report" variant — `selectedReport*`
  vs `selectedReturnReport*` appears 77 times across the file.

## Goals

1. Break `AppController` into focused, independently-understandable controllers, each
   with one clear responsibility.
2. Remove the report/return-report field duplication via a single reusable
   `ReportFilterState`.
3. Consolidate the busy/error plumbing so it is defined once, not copied per
   controller.
4. **Preserve behavior exactly.** No screen behavior, rebuild timing, or
   permission/money-math result changes.

## Non-goals

- No generic `PagedListController<T>`. Product / customer / feature-record paging
  have different fetch signatures and different filter state; a generic wrapper adds
  an abstraction layer for three call sites and does not remove the real duplication
  (the busy/error plumbing, addressed separately).
- No change to rebuild granularity. Screens rebuild off the single root notifier
  today; tightening that (per-domain `InheritedNotifier`s) is a separate future
  change.
- No repository / API / model changes.
- No new state-management package.

## Approaches considered

**A. Facade / delegation.** Split internals into sub-controllers but keep
`AppController` forwarding every existing getter/method. Zero call-site edits, lowest
risk, but leaves a ~150-line pass-through surface that still reads as a god object.

**B. Separate `InheritedNotifier` per domain** (`CartScope`, `ReportScope`, …).
Cleanest end state and finer rebuilds, but rewrites all ~63 call sites to
domain-specific scopes with no test net, and changes rebuild semantics.

**C. Namespaced sub-controllers on one scope (chosen).** Real sub-controllers,
exposed as fields on `AppController`: `AppScope.of(context).cart.addToCart(p)`,
`.session.canManage`, `.reports.report.selectedCustomerId`. One `InheritedNotifier`
keeps rebuild fan-out a single hop. ~63 mechanical call-site edits, each a compile
error if wrong. No pass-through duplication.

**Decision:** C, with characterization tests written first.

## Design

### Controller breakdown

| Controller | Owns | Depends on (constructor-injected, read-only) |
|---|---|---|
| `AsyncGuard` (`ChangeNotifier`) | `_depth`, `isBusy`, `errorMessage`; `run(action)`, `reportError`, `clearError` | — |
| `SessionController` | `currentUser`, `demoUsers`, `authenticate`, `reset()`, `loginAsRoleForTest`, all `is*`/`can*`/`_canCrud`/`_rolePermission`/`canViewMenu`/`canViewSection`/`availableSections` | `AsyncGuard`, `FeatureRecordController` (reads `/api/role-permissions` cache) |
| `CartController` | `_cart`, `_cartProducts`, add/decrement/remove/`setCartQuantity`, `cartLines`, `subtotal`, `discountAmount`, `grandTotal`, `cashChange`, `canCheckout`, `selectedPaymentMethod`, `cashReceivedAmount`, `selectPaymentMethod`, `setCashReceived`, `discountRateForProduct`, `customerGroupDiscounts` | `AsyncGuard`, `ProductController` (live price/stock lookup), `CustomerController` (`selectedCustomer`), `FeatureRecordController` (`/api/customer-group-discounts`) |
| `NavigationController` | `selectedSection`, `selectSection` | `SessionController` (`availableSections`, `canManage`), `ReportController` (kick off loads on section change) |
| `ProductController` | `_products`, `_productNextCursor`, `productSearch`, `selectedProduct{Category,Location,Stock}Filter*`, `_loadProductPage`, `loadMoreProducts`, `canLoadMoreProducts`, `setProductSearch`, `set*Filter`, `saveProduct`, `deleteProduct`, `products` getter, `reset()` | `AsyncGuard`, `ProductRepository` |
| `CustomerController` | `_customers`, `_customerNextCursor`, `selectedCustomer`, `selectCustomer`, `searchCustomers`, `loadMoreCustomers`, `canLoadMoreCustomers`, `saveCustomer`, `deleteCustomer`, `customers` getter, `reset()` | `AsyncGuard`, `CustomerRepository` |
| `FeatureRecordController` | `_featureRecords`, `_featureQueryKeys`, `_featureNextCursors`, `_featureLoadFutures`, `_queryKey`, `featureRecords`, `loadFeatureRecords`, `loadMoreFeatureRecords`, `canLoadMoreFeatureRecords`, `saveFeatureRecord`, `deleteFeatureRecord`, `exportSalesReport`, `exportGenericReport`, `reset()` | `AsyncGuard`, `FeatureRepository` |
| `ReportFilterState` (plain class, not a notifier) | `range`, `customRange`, `productId`, `categoryId`, `customerId`, `supplierId`, `type`; `resolvedRange`, `queryMap`, `reset()` | — |
| `ReportController` | `salesReport`, `_transactions`, `transactions` getter, `selectedGenericReport`, `loadSalesReport`, `loadGenericReport`, `loadMoreGenericReport`, `_invalidateReports`, `_quickDateRange`, `_matchingQuickRange`, `_exclusiveEnd`, `reportRangeFor`, `reportQueryFor`, and **two `ReportFilterState` instances**: `report` and `returnReport`; `reset()` | `AsyncGuard`, `ReportRepository`, `TransactionRepository`, `SessionController` (`canManage`), `CustomerController` (`_customers` for `fetchTransactions`) |

`selectedCombinedReportType` maps to `report.type`; `selectedReturnReportType` maps
to `returnReport.type`. `selectedReportRangeFor(kind)` / `reportRangeFor(kind)` /
`reportQueryFor(kind)` become dispatch on `kind` to the right `ReportFilterState`.

### `AppController` after the split

Keeps only:

- Construction: build repositories (incl. the `.api()` factory), build `AsyncGuard`,
  build the sub-controllers in dependency order, expose them as `final` fields
  (`session`, `cart`, `navigation`, `products`, `customers`, `featureRecords`,
  `reports`).
- Re-broadcast: in the constructor, `addListener(notifyListeners)` on every
  sub-controller and on `AsyncGuard`; remove them in `dispose()` and dispose the
  children.
- `isBusy` / `errorMessage` getters delegating to `AsyncGuard`.
- Four genuinely cross-cutting **orchestration methods** that hold no state and only
  sequence sub-controller calls:
  - `login({username, password})` — `session.authenticate(...)`, then `refreshData()`,
    `featureRecords.loadFeatureRecords(...)` ×4, and if `session.canManage` the
    initial report loads. Resets cart/customer selection as today.
  - `logout()` — calls `reset()` on every sub-controller + `AsyncGuard.clearError()`,
    then `notifyListeners()`.
  - `refreshData()` — the existing de-duped `_refreshDataFuture` wrapper around
    `products` + `customers` + `reports` transaction refresh.
  - `checkout()` — creates the transaction via `TransactionRepository`, then
    `products` reload, `customers` reload, `reports` transaction refetch +
    `_invalidateReports()` + conditional `salesReport` refetch, then `cart.clear()`
    equivalent and `customers.selectCustomer(null)`. Stays here because it spans five
    domains and reads `ReportFilterState` to refetch the sales report.

Target size: `AppController` ≈ 130 lines.

### Notifier / rebuild semantics — unchanged

- `AppScope` stays `InheritedNotifier<AppController>`; `AppScope.of` unchanged.
- Every sub-controller is a `ChangeNotifier`. Each `notifyListeners()` re-broadcasts
  through `AppController` in exactly one hop.
- `AnimatedBuilder(animation: controller)` in `pos_kasir_app.dart` and the two in
  `inventory_screen.dart` keep working unchanged.
- Rebuild granularity stays coarse — identical to today.

### Dependency direction

One-way, no sub-controller references `AppController`:

```
AsyncGuard            <- every controller
FeatureRecordController <- SessionController, CartController, ReportController
ProductController      <- CartController
CustomerController     <- CartController, ReportController
SessionController      <- NavigationController, ReportController
ReportController       <- NavigationController
```

Construction order in `AppController`: `AsyncGuard` -> `FeatureRecordController` ->
`ProductController` -> `CustomerController` -> `SessionController` -> `ReportController`
-> `CartController` -> `NavigationController`.

### Call-site migration

~63 `AppScope.of(context).X` sites across 10 files, mechanical rename to the
namespaced path (`saveProduct` -> `products.saveProduct`, `canManage` ->
`session.canManage`, `selectedReportCustomerId` -> `reports.report.customerId`, …).
`flutter analyze` flags every miss as an unknown-getter compile error. Migrate one
file per step:

`home_shell.dart` (3), `login_screen.dart` (1), `authorization_screen.dart` (3),
`customer_screen.dart` (7), `inventory_screen.dart` (8), `pos_screen.dart` (6),
`purchase_screen.dart` (6), `reports_screen.dart` (9), `returns_screen.dart` (13),
`shared/widgets/feature_table_screen.dart` (7).

## Testing

### Characterization tests first (new — `test/app/`)

Written against the **current** `AppController` public API, must stay green through
every step:

- **Permission matrix** — for each `UserRole` (cashier, manager, administrator) ×
  each section string, assert `canViewMenu`, `canCreateMenu`, `canUpdateMenu`,
  `canDeleteMenu`, and `canViewSection` for every `AppSection`. Include the
  `isAdministrator && role-permissions cache empty` short-circuit and the
  `_rolePermission` override path (seed `_featureRecords['/api/role-permissions']`
  via a fake `FeatureRepository`).
- **Cart math** — `addToCart` respecting `product.stock` cap, `decrementCart`,
  `removeFromCart`, `setCartQuantity`, `cartLines`, `subtotal`, `discountAmount`
  with a seeded `customerGroupDiscounts` record + `selectedCustomer`, `grandTotal`,
  `cashChange` for cash vs non-cash, `canCheckout` gates.
- **Report range resolution** — `reportRangeFor(kind)`, `_quickDateRange` for each
  `ReportRange`, `_matchingQuickRange` round-trip, `_exclusiveEnd`, `_reportQuery`
  map contents for primary vs return kinds.
- **Paging** — with a fake repository returning a known `nextCursor` then `null`:
  `loadMoreProducts` / `loadMoreCustomers` / `loadMoreFeatureRecords` append and
  advance the cursor; `canLoadMore*` flips correctly; `setProductSearch` resets the
  cursor and drops stale responses.
- **checkout** — happy path mutates cart->empty, clears `selectedCustomer`, triggers
  a `salesReport` refetch when `canManage`; returns `null` when cart empty or logged
  out.
- **login / logout** — `login` populates user + triggers the feature-record loads;
  `logout` returns every observable field to its initial value.

Use fake in-memory repositories (the existing `Mock*Repository` classes seeded via
`MockDataStore`, or hand-rolled fakes where finer control is needed).

### Per-step verification

After each extraction step: `flutter analyze` clean, `flutter test` green
(characterization suite + existing `widget_test.dart`).

### Manual smoke (after the final step)

Log in as each of the three demo roles; exercise POS add-to-cart + cash checkout,
inventory filter + load-more, a master-data table save/delete, reports range change +
export, returns report filter.

## Sequencing

Each step is one commit, `flutter analyze` + `flutter test` green before the next.
`AppController` and all screens compile at every step.

1. **Characterization tests** — no production change.
2. **`AsyncGuard`** — extract `_busyDepth`/`isBusy`/`errorMessage`/`_runBusy`;
   `AppController` holds an instance; `_runBusy` delegates; `isBusy`/`errorMessage`
   become getters. No call-site changes.
3. **`NavigationController`** — smallest; move `selectedSection`/`selectSection`;
   add `.navigation` field; migrate `home_shell.dart`. `availableSections`,
   `canManage`, and the on-section-change report loads are still on `AppController`
   at this point, so `NavigationController` reads them through injected callbacks;
   those callbacks resolve to the real `SessionController` / `ReportController` once
   steps 4 and 8 land.
4. **`SessionController`** — move auth + permission logic; read
   `/api/role-permissions` through a callback into `AppController`'s still-present
   map (removed in step 7); migrate `login_screen.dart`,
   `authorization_screen.dart`, and permission reads in other screens.
5. **`ProductController`** — move product state/paging/filters; migrate
   `inventory_screen.dart`.
6. **`CustomerController`** — move customer state/paging + `selectedCustomer`;
   migrate `customer_screen.dart`.
7. **`FeatureRecordController`** — move the keyed cache + exports; swap the step-4
   callback for a direct `FeatureRecordController` reference in `SessionController`;
   wire `CartController` to read from it; migrate `feature_table_screen.dart`,
   `purchase_screen.dart`.
8. **`ReportController` + `ReportFilterState`** — move report state; collapse
   `selectedReport*` / `selectedReturnReport*` into two `ReportFilterState`
   instances; migrate `reports_screen.dart`, `returns_screen.dart`; finalize
   `checkout` / `login` / `logout` / `refreshData` as orchestration methods.

## Risks

- **No existing behavioral coverage.** Mitigated by step 1 landing first and staying
  green throughout.
- **Permission logic is subtle** (two short-circuits + role-record override).
  Characterization matrix covers all three roles × all sections × all four verbs.
- **`checkout` breadth.** Kept as a single orchestration method rather than
  distributed, so the sequence stays in one place and diff-reviewable.
- **Money math** (`discountAmount`, `grandTotal`, `cashChange`) moves into
  `CartController`. Characterization tests pin exact values with seeded discount
  records before the move.
