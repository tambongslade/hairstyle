 Authentication (both customer & admin)

  ┌────────┬───────────────────────┬────────┬─────────────────────────────────────────────┐
  │ Method │       Endpoint        │  Who   │                 Description                 │
  ├────────┼───────────────────────┼────────┼─────────────────────────────────────────────┤
  │ POST   │ /auth/register        │ Public │ Register customer                           │
  ├────────┼───────────────────────┼────────┼─────────────────────────────────────────────┤
  │ POST   │ /auth/register-admin  │ Public │ Register admin + create salon               │
  ├────────┼───────────────────────┼────────┼─────────────────────────────────────────────┤
  │ POST   │ /auth/login           │ Public │ Login (set userType: "customer" or "admin") │
  ├────────┼───────────────────────┼────────┼─────────────────────────────────────────────┤
  │ POST   │ /auth/social-login    │ Public │ OAuth login (Google, Apple, Facebook)       │
  ├────────┼───────────────────────┼────────┼─────────────────────────────────────────────┤
  │ POST   │ /auth/refresh         │ Public │ Refresh JWT token                           │
  ├────────┼───────────────────────┼────────┼─────────────────────────────────────────────┤
  │ POST   │ /auth/logout          │ Auth   │ Invalidate token                            │
  ├────────┼───────────────────────┼────────┼─────────────────────────────────────────────┤
  │ POST   │ /auth/forgot-password │ Public │ Send password reset                         │
  ├────────┼───────────────────────┼────────┼─────────────────────────────────────────────┤
  │ POST   │ /auth/reset-password  │ Public │ Reset password with token                   │
  └────────┴───────────────────────┴────────┴─────────────────────────────────────────────┘

  ---
  Salon Admin Panel (29 endpoints, all require admin JWT)

  Dashboard:

  ┌────────┬──────────────────┬──────────────────────────────────────────────────────┐
  │ Method │     Endpoint     │                     Description                      │
  ├────────┼──────────────────┼──────────────────────────────────────────────────────┤
  │ GET    │ /admin/dashboard │ KPIs, today's bookings, top styles, recent customers │
  └────────┴──────────────────┴──────────────────────────────────────────────────────┘

  Salon Management:

  ┌────────┬───────────────────────────┬──────────────────────┐
  │ Method │         Endpoint          │     Description      │
  ├────────┼───────────────────────────┼──────────────────────┤
  │ GET    │ /admin/salon              │ Get salon info       │
  ├────────┼───────────────────────────┼──────────────────────┤
  │ POST   │ /admin/salon              │ Create a new salon   │
  ├────────┼───────────────────────────┼──────────────────────┤
  │ PUT    │ /admin/salon              │ Update salon info    │
  ├────────┼───────────────────────────┼──────────────────────┤
  │ GET    │ /admin/salon/subscription │ Subscription details │
  └────────┴───────────────────────────┴──────────────────────┘

  Stylist Management:

  ┌────────┬───────────────────────────┬───────────────────────┐
  │ Method │         Endpoint          │      Description      │
  ├────────┼───────────────────────────┼───────────────────────┤
  │ GET    │ /admin/salon/stylists     │ List stylists         │
  ├────────┼───────────────────────────┼───────────────────────┤
  │ POST   │ /admin/salon/stylists     │ Add stylist           │
  ├────────┼───────────────────────────┼───────────────────────┤
  │ PUT    │ /admin/salon/stylists/:id │ Update stylist        │
  ├────────┼───────────────────────────┼───────────────────────┤
  │ DELETE │ /admin/salon/stylists/:id │ Remove stylist        │
  ├────────┼───────────────────────────┼───────────────────────┤
  │ GET    │ /admin/stylists/schedule  │ Stylist schedule grid │
  └────────┴───────────────────────────┴───────────────────────┘

  Services Management:

  ┌────────┬─────────────────────┬────────────────┐
  │ Method │      Endpoint       │  Description   │
  ├────────┼─────────────────────┼────────────────┤
  │ GET    │ /admin/services     │ List services  │
  ├────────┼─────────────────────┼────────────────┤
  │ GET    │ /admin/services/:id │ Get service    │
  ├────────┼─────────────────────┼────────────────┤
  │ POST   │ /admin/services     │ Create service │
  ├────────┼─────────────────────┼────────────────┤
  │ PUT    │ /admin/services/:id │ Update service │
  ├────────┼─────────────────────┼────────────────┤
  │ DELETE │ /admin/services/:id │ Delete service │
  └────────┴─────────────────────┴────────────────┘

  Style Catalog (women + men):

  ┌────────┬───────────────────────────┬──────────────────────────────────┐
  │ Method │         Endpoint          │           Description            │
  ├────────┼───────────────────────────┼──────────────────────────────────┤
  │ GET    │ /admin/catalog/stats      │ Catalog stats                    │
  ├────────┼───────────────────────────┼──────────────────────────────────┤
  │ GET    │ /admin/catalog/styles     │ List all styles                  │
  ├────────┼───────────────────────────┼──────────────────────────────────┤
  │ POST   │ /admin/catalog/styles     │ Create style (gender: women/men) │
  ├────────┼───────────────────────────┼──────────────────────────────────┤
  │ PUT    │ /admin/catalog/styles/:id │ Update style                     │
  ├────────┼───────────────────────────┼──────────────────────────────────┤
  │ DELETE │ /admin/catalog/styles/:id │ Delete style                     │
  └────────┴───────────────────────────┴──────────────────────────────────┘

  Booking Management:

  ┌────────┬──────────────────────────────┬───────────────────────────┐
  │ Method │           Endpoint           │        Description        │
  ├────────┼──────────────────────────────┼───────────────────────────┤
  │ GET    │ /admin/bookings              │ All bookings (filterable) │
  ├────────┼──────────────────────────────┼───────────────────────────┤
  │ GET    │ /admin/bookings/:id          │ Booking detail            │
  ├────────┼──────────────────────────────┼───────────────────────────┤
  │ PUT    │ /admin/bookings/:id/status   │ Update status             │
  ├────────┼──────────────────────────────┼───────────────────────────┤
  │ POST   │ /admin/bookings/:id/check-in │ Check in customer         │
  └────────┴──────────────────────────────┴───────────────────────────┘

  Analytics:

  ┌────────┬────────────────────────────────┬────────────────────────────┐
  │ Method │            Endpoint            │        Description         │
  ├────────┼────────────────────────────────┼────────────────────────────┤
  │ GET    │ /admin/analytics/overview      │ Revenue, visits, retention │
  ├────────┼────────────────────────────────┼────────────────────────────┤
  │ GET    │ /admin/analytics/revenue-chart │ Chart data                 │
  ├────────┼────────────────────────────────┼────────────────────────────┤
  │ GET    │ /admin/analytics/loyalty       │ Loyalty program metrics    │
  └────────┴────────────────────────────────┴────────────────────────────┘

  Settings:

  ┌────────┬────────────────────────────────┬───────────────────────┐
  │ Method │            Endpoint            │      Description      │
  ├────────┼────────────────────────────────┼───────────────────────┤
  │ GET    │ /admin/settings/loyalty-config │ Get loyalty config    │
  ├────────┼────────────────────────────────┼───────────────────────┤
  │ PUT    │ /admin/settings/loyalty-config │ Update loyalty config │
  └────────┴────────────────────────────────┴───────────────────────┘

  ---
  Customer App (38 endpoints)

  Public (no auth): Styles, Services, Stylists browsing
  Customer JWT required: Profile, Bookings, Try-On, Loyalty, Notifications, Saved Styles