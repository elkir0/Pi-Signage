// Single source of truth for the Zaforge vitrine. Edit here, not in markup.

export const SITE = {
  name: 'Zaforge',
  domain: 'zaforge.com',
  url: 'https://zaforge.com',
  tagline: 'Managed open-core digital signage for Raspberry Pi',
  description:
    'Zaforge runs your screens on Raspberry Pi: a free, offline-survivable open-source player plus an optional self-hosted managed relay. Your data stays in the EU, on infrastructure you control. No cloud lock-in.',
  github: 'https://github.com/elkir0/Pi-Signage',
  contactEmail: 'hello@zaforge.com',
  // Where the relay enrollment/console plane lives (already live for MVP).
  relayHost: 'relay.zaforge.com',
};

// --- LAUNCH GATE -----------------------------------------------------------
// Ships true: the site is noindex and Plausible is OFF until launch.
// Flip to false (and rebuild) the moment the site goes public.
export const NOINDEX = true;
export const PLAUSIBLE_DOMAIN = 'zaforge.com';
// ---------------------------------------------------------------------------

export const NAV = [
  { href: '/how-it-works', label: 'How it works' },
  { href: '/features', label: 'Features' },
  { href: '/pricing', label: 'Pricing' },
  { href: '/security', label: 'Security' },
  { href: '/open-source', label: 'Open source' },
  { href: '/docs', label: 'Docs' },
] as const;

export type Status = 'live' | 'beta' | 'roadmap';

export const STATUS_LABEL: Record<Status, string> = {
  live: 'Live',
  beta: 'Beta',
  roadmap: 'Roadmap',
};

// The honest feature matrix. Every public claim references this list so the
// Live/Beta/Roadmap tag and the copy can never drift apart.
export interface Feature {
  id: string;
  title: string;
  status: Status;
  blurb: string;
  icon: string; // inline svg path id from FeatureCard
}

export const FEATURES: Feature[] = [
  {
    id: 'kiosk-player',
    title: 'Autonomous Pi player',
    status: 'live',
    icon: 'monitor',
    blurb:
      'A hardened Chromium-kiosk player on Raspberry Pi. Full-screen HTML5 and video, overlays, scheduling and playlists — running directly on the device.',
  },
  {
    id: 'offline',
    title: 'Offline-survivable playback',
    status: 'live',
    icon: 'wifi-off',
    blurb:
      'Content is cached locally and keeps playing through network drops and reboots. The screen does not go blank when the link does.',
  },
  {
    id: 'overlays',
    title: 'Overlays & scheduling',
    status: 'live',
    icon: 'layers',
    blurb:
      'Clock, info cards and banners layered over media, with day-part scheduling and playlist rotation — all configured from the on-device admin.',
  },
  {
    id: 'security',
    title: 'Hardened by default',
    status: 'live',
    icon: 'shield',
    blurb:
      'Locked-down kiosk session, authenticated admin, no inbound ports required for the managed relay — devices dial out, they are never exposed.',
  },
  {
    id: 'relay-enroll',
    title: 'NAT-traversing enrollment',
    status: 'live',
    icon: 'plug',
    blurb:
      'A Pi behind any home or office NAT enrolls to the self-hosted relay over WireGuard with a one-time code — no port forwarding, no public IP.',
  },
  {
    id: 'heartbeat',
    title: 'Heartbeat & online status',
    status: 'live',
    icon: 'activity',
    blurb:
      'Enrolled devices heartbeat to the relay and show online in the fleet. You can see at a glance which screens are alive.',
  },
  {
    id: 'remote-commands',
    title: 'Remote commands',
    status: 'live',
    icon: 'terminal',
    blurb:
      'Reboot, capture a screenshot, push a playlist and pull live stats — dispatched to a Pi through the tunnel and acknowledged by the device.',
  },
  {
    id: 'console-ui',
    title: 'Fleet console UI',
    status: 'beta',
    icon: 'grid',
    blurb:
      'The polished web console for the fleet (device grid, command panels, content push). The control plane is live today; the refined UI is in beta.',
  },
  {
    id: 'ota',
    title: 'OTA updates',
    status: 'roadmap',
    icon: 'download',
    blurb:
      'Staged over-the-air player and agent updates across the fleet. The command channel exists; orchestrated rollouts are on the roadmap.',
  },
  {
    id: 'ha-sla',
    title: 'High availability & SLA',
    status: 'roadmap',
    icon: 'server',
    blurb:
      'Redundant relay topology and a contractual uptime SLA for the Business tier. Planned, not yet shipped.',
  },
  {
    id: 'rbac',
    title: 'RBAC & white-label',
    status: 'roadmap',
    icon: 'users',
    blurb:
      'Role-based access for teams and full white-labelling for resellers. On the roadmap for Business.',
  },
  {
    id: 'billing',
    title: 'Self-serve billing',
    status: 'roadmap',
    icon: 'card',
    blurb:
      'Self-serve signup and metered per-screen billing. Until it lands, onboarding is hands-on — join the waitlist.',
  },
];

export interface Tier {
  id: string;
  name: string;
  price: string;
  unit: string;
  tagline: string;
  cta: { label: string; href: string };
  highlight?: boolean;
  features: { text: string; status: Status }[];
  note?: string;
}

export const TIERS: Tier[] = [
  {
    id: 'community',
    name: 'Community',
    price: '0',
    unit: 'forever',
    tagline: 'The autonomous Pi player. Open source, LAN-only, yours to keep.',
    cta: { label: 'Get the player', href: SITE.github },
    features: [
      { text: 'Chromium-kiosk Pi player', status: 'live' },
      { text: 'Offline-survivable playback', status: 'live' },
      { text: 'Overlays, scheduling, playlists', status: 'live' },
      { text: 'On-device admin UI (LAN)', status: 'live' },
      { text: 'Open source, self-managed', status: 'live' },
    ],
    note: 'Best for a single site or a tinkerer. You run and update each Pi yourself.',
  },
  {
    id: 'pro',
    name: 'Pro',
    price: '4',
    unit: 'per screen / month',
    tagline: 'Add the self-hosted managed relay: see, reach and update your fleet from anywhere.',
    highlight: true,
    cta: { label: 'Join the waitlist', href: '/contact' },
    features: [
      { text: 'Everything in Community', status: 'live' },
      { text: 'NAT-traversing enrollment (WireGuard)', status: 'live' },
      { text: 'Heartbeat & online status', status: 'live' },
      { text: 'Remote reboot / screenshot / stats', status: 'live' },
      { text: 'Content push to the fleet', status: 'live' },
      { text: 'Fleet console UI', status: 'beta' },
    ],
    note: 'Billed annually saves ~2 months. Per-screen, no minimum.',
  },
  {
    id: 'business',
    name: 'Business',
    price: '7–8',
    unit: 'per screen / month',
    tagline: 'For operators at scale: availability guarantees, team controls and your own brand.',
    cta: { label: 'Talk to us', href: '/contact' },
    features: [
      { text: 'Everything in Pro', status: 'live' },
      { text: 'High availability', status: 'roadmap' },
      { text: 'Uptime SLA', status: 'roadmap' },
      { text: 'RBAC for teams', status: 'roadmap' },
      { text: 'White-label', status: 'roadmap' },
      { text: 'OTA fleet updates', status: 'roadmap' },
    ],
    note: 'Several Business capabilities are on the roadmap — we will be explicit about what is live when you sign.',
  },
];
