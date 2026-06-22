<?php
/**
 * PiSignage — Shared UI component helpers (PHP render).
 * Requires icons.php (loaded by header.php).
 */
require_once __DIR__ . '/icons.php';

if (!function_exists('pageHeader')) {
    /**
     * Topbar: mobile menu button, title/subtitle, optional actions slot, clock, theme toggle.
     * @param string $title    Page title
     * @param string $subtitle Small breadcrumb/subtitle
     * @param string $actions  Raw HTML injected before the clock (page actions / status pill)
     */
    function pageHeader(string $title, string $subtitle = '', string $actions = ''): void {
        ?>
        <header class="topbar">
            <div class="row" style="gap:12px;flex-wrap:nowrap">
                <button class="menu-toggle" type="button" aria-label="Menu" onclick="PiSignage.ui.toggleSidebar()"><?= icon('menu') ?></button>
                <div class="topbar-title">
                    <h1><?= htmlspecialchars($title) ?></h1>
                    <?php if ($subtitle !== ''): ?><div class="crumb"><?= htmlspecialchars($subtitle) ?></div><?php endif; ?>
                </div>
            </div>
            <div class="topbar-right">
                <?= $actions ?>
                <span class="clock" id="topbar-clock" aria-hidden="true">--:--:--</span>
                <button class="icon-btn theme-toggle" id="theme-toggle" type="button" title="Basculer le thème" aria-label="Basculer le thème">
                    <span class="theme-ico-dark"><?= icon('moon') ?></span>
                    <span class="theme-ico-light"><?= icon('sun') ?></span>
                </button>
            </div>
        </header>
        <?php
    }
}

if (!function_exists('statusPill')) {
    /** Inline player status pill used in topbars. JS updates #topbar-status. */
    function statusPill(): string {
        return '<span class="status-pill" id="topbar-status">'
             . '<span class="live-dot"></span><span class="pill-text">Lecteur</span></span>';
    }
}
