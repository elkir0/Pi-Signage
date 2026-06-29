<?php
// SINGLE SOURCE OF TRUTH for the product version. Constants only — no functions, no side effects.
// Safe to require from both the config.php and auth.php chains (defined()-guarded, idempotent).
// NB: bumping this string busts the ?v= cache for ALL css/js assets. ALWAYS bump it
// when shipping a JS change, or browsers keep stale modules (e.g. the CSRF fetch
// interceptor added to core.js without a bump caused 403s on every mutating POST).
if (!defined('PISIGNAGE_VERSION'))     { define('PISIGNAGE_VERSION', 'v0.12.6'); }
if (!defined('PISIGNAGE_VERSION_NUM')) { define('PISIGNAGE_VERSION_NUM', ltrim(PISIGNAGE_VERSION, 'vV')); }
if (!defined('ASSET_VERSION'))         { define('ASSET_VERSION', PISIGNAGE_VERSION_NUM); }
