# Mysztech Store Assistant

A green themed Flutter app for monitoring the POS staging API with an authorized session token. Its OpenAPI reference is in the sibling `pos project reference/pos project reference/json source/document (1).json` folder; the staging server is `https://mts-pos-staging.laravel.cloud/api`.

## Run on Android

1. Run `flutter pub get`.
2. Run `flutter devices` and note the Android device ID.
3. Run `flutter run -d <device-id>`.
4. Sign in with the staging account email, password, and license key. The license-key field groups digits in five-character blocks, for example `66666-66666-66666-66666`. The app calls the documented `POST /v2/login` endpoint and uses its returned `data.access_token` for subsequent requests. Credentials and the access token remain in memory only; sign in again after fully closing the app.

After sign-in, the app requests `/api/v2/sales/list`. HTTP 200 with an empty `data` array displays **No sales records yet**. Retry or pull down to refresh. The app does not log credentials, tokens, or authorization headers.

## Available data and limits

- **Dashboard:** displays the sales record total and the count of outlet inventory records at or below their API-provided low-stock threshold. Sales amount is unavailable because no confirmed aggregate source is documented.
- **Sales:** uses `GET /v2/sales/list` and reports authentication, permission, timeout, and connection errors.
- **Items:** uses `GET /v2/items/list`, `GET /v2/items/{id}`, and `GET /v2/category/{id}` for category names where authorized. Search matches item name, SKU, and barcode.
- **Stock:** uses `GET /v2/inventory-outlet/list`, matching `inventory_id` to item records for names. The Movements view uses `GET /v2/inventory-transactions/list`. Low-stock flags use the API's `low_stock_threshold` field.
- **On-device catalog and counts:** manually add/edit local item details, quantities, and local minimum levels from Items. The separate On-device Stock view uses only these records. Android saves them in app-private preferences; they are never sent to the POS and never appear in live API totals.
- **Local label preview:** can be opened directly or prefilled from a POS item; manually entered item name, SKU/barcode, and price can be previewed and copied as text. It does not write to the POS or print physically.

The staging token may not have permission for every documented endpoint. In that case the relevant screen reports the API error and keeps other working sections available. No create, update, or delete API operations are used.

No package identifier or Android application ID change is required for the visible app rename.
