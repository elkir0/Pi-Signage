<?php
// SINGLE SOURCE OF TRUTH for the product version. Constants only — no functions, no side effects.
// Safe to require from both the config.php and auth.php chains (defined()-guarded, idempotent).
if (!defined('PISIGNAGE_VERSION'))     { define('PISIGNAGE_VERSION', 'v0.12.1'); }
if (!defined('PISIGNAGE_VERSION_NUM')) { define('PISIGNAGE_VERSION_NUM', ltrim(PISIGNAGE_VERSION, 'vV')); }
if (!defined('ASSET_VERSION'))         { define('ASSET_VERSION', PISIGNAGE_VERSION_NUM); }
