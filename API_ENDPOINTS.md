# Fit App - Backend API Endpoints

Complete API specification for the Fit hair salon app backend.
Base URL: `/api/v1`

---

## 1. Authentication

| Method | Endpoint | Description |
|--------|----------|-------------|
| POST | `/auth/register` | Register new customer |
| POST | `/auth/login` | Login (customer or admin) |
| POST | `/auth/social-login` | OAuth login (Google, Apple, Facebook) |
| POST | `/auth/refresh-token` | Refresh JWT token |
| POST | `/auth/logout` | Invalidate token |
| POST | `/auth/forgot-password` | Send password reset email |
| POST | `/auth/reset-password` | Reset password with token |

### POST `/auth/register`
```json
// Request
{
  "name": "Amara Nkembe",
  "email": "amara@example.com",
  "password": "securepass",
  "phone": "+237 6XX XXX XXX"
}

// Response 201
{
  "token": "jwt...",
  "refreshToken": "rt...",
  "user": {
    "id": "uuid",
    "name": "Amara Nkembe",
    "email": "amara@example.com",
    "phone": "+237 6XX XXX XXX",
    "userType": "customer",
    "createdAt": "2026-03-21T00:00:00Z"
  }
}
```

### POST `/auth/login`
```json
// Request
{
  "email": "amara@example.com",
  "password": "securepass",
  "userType": "customer"  // "customer" | "admin"
}

// Response 200
{
  "token": "jwt...",
  "refreshToken": "rt...",
  "user": { "id", "name", "email", "userType", "salonId?" }
}
```

### POST `/auth/social-login`
```json
// Request
{
  "provider": "google",  // "google" | "apple" | "facebook"
  "accessToken": "oauth-token..."
}

// Response 200 — same as login
```

---

## 2. Customer Profile

| Method | Endpoint | Description |
|--------|----------|-------------|
| GET | `/customer/profile` | Get current customer profile |
| PUT | `/customer/profile` | Update profile fields |
| POST | `/customer/profile/photo` | Upload profile photo |
| DELETE | `/customer/profile` | Delete account |

### GET `/customer/profile`
```json
// Response 200
{
  "id": "uuid",
  "name": "Amara Nkembe",
  "email": "amara@example.com",
  "phone": "+237 6XX XXX XXX",
  "profilePhotoUrl": "https://...",
  "loyaltyTier": "silver",
  "totalPoints": 1280,
  "totalVisits": 23,
  "savedStylesCount": 5,
  "memberSince": "2025-06-15T00:00:00Z"
}
```

### PUT `/customer/profile`
```json
// Request
{
  "name": "Amara N.",
  "phone": "+237 6XX XXX XXX",
  "language": "fr"
}
```

### POST `/customer/profile/photo`
```
Content-Type: multipart/form-data
Body: file (image/jpeg or image/png)

// Response 200
{ "photoUrl": "https://..." }
```

---

## 3. Hairstyle Catalog

| Method | Endpoint | Description |
|--------|----------|-------------|
| GET | `/styles` | List all styles (filterable) |
| GET | `/styles/trending` | Get trending styles for home screen |
| GET | `/styles/:id` | Get single style details |
| GET | `/styles/categories` | Get available categories |

### GET `/styles`
```
Query params:
  gender    — "women" | "men" (optional)
  category  — "all" | "wigs" | "braids" | "locs" | "curls" | "fades" (optional)
  search    — text search (optional)
  page      — pagination (default: 1)
  limit     — items per page (default: 20)
```

```json
// Response 200
{
  "styles": [
    {
      "id": "uuid",
      "name": "Boho Braids Long",
      "nameKey": "boho_braids_long",
      "category": "braids",
      "gender": "women",
      "price": 20000,
      "imageUrl": "https://...",
      "description": "Bohemian-style braids...",
      "tryOnCount": 45
    }
  ],
  "total": 50,
  "page": 1,
  "totalPages": 3
}
```

### GET `/styles/trending`
```json
// Response 200
{
  "styles": [
    {
      "id": "uuid",
      "name": "Boho Braids Long",
      "price": 20000,
      "imageUrl": "https://...",
      "badge": "hot"  // "hot" | "new" | null
    }
  ]
}
```

---

## 4. AI Try-On

| Method | Endpoint | Description |
|--------|----------|-------------|
| POST | `/try-on/generate` | Generate AI try-on image |
| POST | `/try-on/save` | Save a generated try-on |
| GET | `/try-on/history` | Get user's try-on history |
| DELETE | `/try-on/:id` | Delete a saved try-on |

### POST `/try-on/generate`
```
Content-Type: multipart/form-data

Fields:
  userPhoto   — image file (required)
  styleId     — uuid (required)
  hairColor   — hex color string (optional, e.g. "#2C1810")
```

```json
// Response 200
{
  "tryOnId": "uuid",
  "generatedImageUrl": "https://...",
  "processingTimeMs": 3200
}
```

Hair color options supported:
| Name | Hex |
|------|-----|
| Natural Black | #1a1a2e |
| Dark Brown | #2C1810 |
| Medium Brown | #6B4423 |
| Golden Blonde | #C8962E |
| Deep Red | #8B1A1A |
| Dark Blue | #1B2A4A |
| Platinum Blonde | #D4C5A9 |

### GET `/try-on/history`
```
Query params:
  page   — default: 1
  limit  — default: 20
```

```json
// Response 200
{
  "tryOns": [
    {
      "id": "uuid",
      "styleId": "uuid",
      "styleName": "Box Braids",
      "generatedImageUrl": "https://...",
      "hairColor": "#1a1a2e",
      "createdAt": "2026-03-20T14:30:00Z"
    }
  ],
  "total": 12
}
```

---

## 5. Bookings

| Method | Endpoint | Description |
|--------|----------|-------------|
| GET | `/bookings` | List customer's bookings |
| GET | `/bookings/:id` | Get booking details |
| POST | `/bookings` | Create new booking |
| PUT | `/bookings/:id` | Update/reschedule booking |
| PUT | `/bookings/:id/cancel` | Cancel a booking |
| GET | `/bookings/available-dates` | Get available dates |
| GET | `/bookings/available-times` | Get available time slots for a date |

### GET `/bookings`
```
Query params:
  status  — "all" | "confirmed" | "pending" | "cancelled" (optional)
  from    — date (optional)
  to      — date (optional)
  page    — default: 1
  limit   — default: 20
```

```json
// Response 200
{
  "bookings": [
    {
      "id": "uuid",
      "styleId": "uuid",
      "styleName": "Hair Treatment",
      "stylistId": "uuid",
      "stylistName": "Marie N.",
      "date": "2026-03-16",
      "time": "10:00",
      "duration": 60,
      "price": 6000,
      "status": "confirmed",
      "createdAt": "2026-03-14T09:00:00Z"
    }
  ],
  "total": 5
}
```

### POST `/bookings`
```json
// Request
{
  "styleId": "uuid",
  "stylistId": "uuid",       // optional — any available if omitted
  "date": "2026-03-18",
  "time": "09:30",
  "notes": "First time trying braids"  // optional
}

// Response 201
{
  "id": "uuid",
  "status": "pending",
  "date": "2026-03-18",
  "time": "09:30",
  "stylistName": "Marie N.",
  "styleName": "Boho Braids Long",
  "price": 20000,
  "duration": 120
}
```

### GET `/bookings/available-dates`
```
Query params:
  stylistId — uuid (optional)
  days      — number of days ahead (default: 14)
```

```json
// Response 200
{
  "dates": [
    { "date": "2026-03-22", "slotsAvailable": 8 },
    { "date": "2026-03-23", "slotsAvailable": 12 },
    { "date": "2026-03-24", "slotsAvailable": 0 }
  ]
}
```

### GET `/bookings/available-times`
```
Query params:
  date      — "2026-03-22" (required)
  stylistId — uuid (optional)
```

```json
// Response 200
{
  "date": "2026-03-22",
  "slots": [
    { "time": "09:00", "available": true },
    { "time": "09:30", "available": true },
    { "time": "10:00", "available": false },
    { "time": "10:30", "available": true }
  ]
}
```

Slots run from **09:00 to 16:30** in **30-minute** increments.

### PUT `/bookings/:id`
```json
// Request — reschedule
{
  "date": "2026-03-25",
  "time": "14:00",
  "stylistId": "uuid"
}
```

### PUT `/bookings/:id/cancel`
```json
// Response 200
{ "id": "uuid", "status": "cancelled" }
```

---

## 6. Services

| Method | Endpoint | Description |
|--------|----------|-------------|
| GET | `/services` | List all salon services |
| GET | `/services/:id` | Get service details |

### GET `/services`
```json
// Response 200
{
  "services": [
    {
      "id": "uuid",
      "name": "Hair Treatment",
      "nameKey": "hair_treatment",
      "category": "treatment",
      "duration": 60,
      "price": 6000
    },
    { "name": "Braiding", "category": "styling", "duration": 120, "price": 15000 },
    { "name": "Hair Cut", "category": "cut", "duration": 30, "price": 5000 },
    { "name": "Fade", "category": "cut", "duration": 45, "price": 8000 },
    { "name": "Coloring", "category": "color", "duration": 90, "price": 12000 }
  ]
}
```

---

## 7. Stylists (Public)

| Method | Endpoint | Description |
|--------|----------|-------------|
| GET | `/stylists` | List salon stylists |
| GET | `/stylists/:id` | Get stylist profile |
| GET | `/stylists/:id/availability` | Get stylist availability for a date |

### GET `/stylists`
```json
// Response 200
{
  "stylists": [
    {
      "id": "uuid",
      "name": "Marie N.",
      "specialty": "Braids Specialist",
      "photoUrl": "https://...",
      "rating": 4.8
    },
    { "name": "Jean-Paul K.", "specialty": "Fades & Cuts" },
    { "name": "Carine T.", "specialty": "Color Expert" }
  ]
}
```

### GET `/stylists/:id/availability`
```
Query params:
  date — "2026-03-22" (required)
```

```json
// Response 200
{
  "stylistId": "uuid",
  "date": "2026-03-22",
  "slots": [
    { "time": "09:00", "available": true },
    { "time": "09:30", "available": false },
    { "time": "10:00", "available": true }
  ]
}
```

---

## 8. Loyalty Program

| Method | Endpoint | Description |
|--------|----------|-------------|
| GET | `/loyalty/profile` | Get loyalty status & tier |
| GET | `/loyalty/activities` | Get points history |
| GET | `/loyalty/punch-card` | Get punch card status |
| GET | `/loyalty/referral` | Get referral code & stats |
| POST | `/loyalty/redeem` | Redeem points for reward |
| POST | `/loyalty/referral/share` | Track referral share |

### GET `/loyalty/profile`
```json
// Response 200
{
  "tier": "silver",           // "bronze" | "silver" | "gold" | "platinum"
  "points": 1280,
  "pointsToNextTier": 220,
  "nextTier": "gold",
  "tierThresholds": {
    "bronze": 0,
    "silver": 500,
    "gold": 1500,
    "platinum": 3000
  }
}
```

### GET `/loyalty/activities`
```json
// Response 200
{
  "activities": [
    {
      "id": "uuid",
      "type": "haircut",        // "haircut" | "referral" | "redeemed" | "social" | "birthday"
      "description": "Haircut Visit",
      "points": 10,
      "isEarn": true,
      "date": "2026-03-05T00:00:00Z"
    },
    { "type": "referral", "points": 100, "isEarn": true, "date": "2026-03-01" },
    { "type": "redeemed", "points": -200, "isEarn": false, "date": "2026-02-22" },
    { "type": "social", "points": 25, "isEarn": true, "date": "2026-02-18" },
    { "type": "birthday", "points": 50, "isEarn": true, "date": "2026-02-14" }
  ]
}
```

### GET `/loyalty/punch-card`
```json
// Response 200
{
  "stamps": 3,
  "totalNeeded": 5,
  "rewardDescription": "Free service up to 5,000 FCFA"
}
```

### GET `/loyalty/referral`
```json
// Response 200
{
  "code": "AMARA2026",
  "referredCount": 0,
  "rewardsEarned": 0,
  "bonusPerReferral": 100
}
```

### POST `/loyalty/redeem`
```json
// Request
{
  "points": 200,
  "rewardType": "discount"   // "discount" | "free_service" | "product"
}

// Response 200
{
  "success": true,
  "remainingPoints": 1080,
  "rewardCode": "REWARD-XXXX"
}
```

---

## 9. Notifications

| Method | Endpoint | Description |
|--------|----------|-------------|
| GET | `/notifications` | List user notifications |
| PUT | `/notifications/:id/read` | Mark notification as read |
| PUT | `/notifications/read-all` | Mark all as read |
| GET | `/notifications/unread-count` | Get unread count (for badge) |

### GET `/notifications`
```json
// Response 200
{
  "notifications": [
    {
      "id": "uuid",
      "type": "booking_confirmed",
      "title": "Booking Confirmed",
      "message": "Your appointment on Mar 18 at 09:30 is confirmed.",
      "read": false,
      "createdAt": "2026-03-17T10:00:00Z"
    }
  ],
  "unreadCount": 3
}
```

---

## 10. Saved Styles

| Method | Endpoint | Description |
|--------|----------|-------------|
| GET | `/customer/saved-styles` | Get saved/favorited styles |
| POST | `/customer/saved-styles/:styleId` | Save a style |
| DELETE | `/customer/saved-styles/:styleId` | Unsave a style |

### GET `/customer/saved-styles`
```json
// Response 200
{
  "styles": [
    {
      "id": "uuid",
      "styleId": "uuid",
      "styleName": "Boho Braids Long",
      "imageUrl": "https://...",
      "price": 20000,
      "savedAt": "2026-03-10T08:00:00Z"
    }
  ],
  "total": 5
}
```

---

## 11. Admin - Dashboard

| Method | Endpoint | Description |
|--------|----------|-------------|
| GET | `/admin/dashboard` | Get dashboard KPIs and summary |

### GET `/admin/dashboard`
```json
// Response 200
{
  "todaysRevenue": 47500,
  "bookingsToday": 12,
  "customersCheckedIn": 8,
  "tryOnsThisWeek": 23,
  "todaysBookings": [
    {
      "id": "uuid",
      "customerName": "Amara N.",
      "service": "Box Braids",
      "time": "09:00",
      "stylist": "Marie N.",
      "status": "checked_in",
      "price": 15000
    }
  ],
  "topStyles": [
    { "name": "Box Braids", "tryOnCount": 45 },
    { "name": "Skin Fade", "tryOnCount": 38 },
    { "name": "Natural Afro", "tryOnCount": 29 },
    { "name": "Cornrows", "tryOnCount": 21 }
  ],
  "recentCustomers": [
    { "name": "Amara N.", "tier": "silver", "visits": 23 },
    { "name": "Fabrice M.", "tier": "gold", "visits": 45 }
  ]
}
```

---

## 12. Admin - Booking Management

| Method | Endpoint | Description |
|--------|----------|-------------|
| GET | `/admin/bookings` | List all bookings (filterable) |
| GET | `/admin/bookings/:id` | Get booking details |
| PUT | `/admin/bookings/:id/status` | Update booking status |
| POST | `/admin/bookings/:id/check-in` | Check in a customer |
| GET | `/admin/stylists/schedule` | Get stylist schedule grid |

### GET `/admin/bookings`
```
Query params:
  date    — "2026-03-22" (optional, default: today)
  status  — "all" | "confirmed" | "pending" | "cancelled" | "checked_in"
  page    — default: 1
  limit   — default: 50
```

```json
// Response 200
{
  "bookings": [
    {
      "id": "uuid",
      "customerName": "Amara N.",
      "customerPhoto": "https://...",
      "service": "Box Braids",
      "time": "09:00",
      "duration": 120,
      "stylist": "Marie N.",
      "price": 15000,
      "status": "confirmed"
    }
  ],
  "total": 12
}
```

### PUT `/admin/bookings/:id/status`
```json
// Request
{ "status": "confirmed" }   // "confirmed" | "checked_in" | "cancelled"

// Response 200
{ "id": "uuid", "status": "confirmed" }
```

### GET `/admin/stylists/schedule`
```
Query params:
  date — "2026-03-22" (required)
```

```json
// Response 200
{
  "date": "2026-03-22",
  "stylists": [
    {
      "id": "uuid",
      "name": "Marie N.",
      "specialty": "Braids Specialist",
      "schedule": [
        { "hour": 9, "status": "busy", "booking": "Box Braids - Amara N." },
        { "hour": 10, "status": "busy", "booking": "Continued" },
        { "hour": 11, "status": "available" },
        { "hour": 12, "status": "available" },
        { "hour": 13, "status": "busy", "booking": "Cornrows - Fabrice M." },
        { "hour": 14, "status": "available" },
        { "hour": 15, "status": "busy", "booking": "Locs - Sarah K." },
        { "hour": 16, "status": "busy", "booking": "Continued" }
      ]
    }
  ]
}
```

Hours run **9:00 - 17:00** (salon operating hours).

---

## 13. Admin - Catalog Management

| Method | Endpoint | Description |
|--------|----------|-------------|
| GET | `/admin/catalog/stats` | Get catalog statistics |
| GET | `/admin/catalog/styles` | List styles with admin data |
| POST | `/admin/catalog/styles` | Add new style |
| PUT | `/admin/catalog/styles/:id` | Update a style |
| DELETE | `/admin/catalog/styles/:id` | Delete a style |

### GET `/admin/catalog/stats`
```json
// Response 200
{
  "totalStyles": 50,
  "womenStyles": 30,
  "menStyles": 20,
  "totalTryOns": 387
}
```

### POST `/admin/catalog/styles`
```
Content-Type: multipart/form-data

Fields:
  name        — string (required)
  nameKey     — string (required, for translations)
  gender      — "women" | "men" (required)
  category    — "wigs" | "braids" | "locs" | "curls" | "fades" (required)
  price       — integer in FCFA (required)
  description — string (optional)
  image       — file (required)
```

```json
// Response 201
{
  "id": "uuid",
  "name": "New Braids Style",
  "gender": "women",
  "category": "braids",
  "price": 18000,
  "imageUrl": "https://...",
  "tryOnCount": 0,
  "createdAt": "2026-03-21T00:00:00Z"
}
```

---

## 14. Admin - Analytics

| Method | Endpoint | Description |
|--------|----------|-------------|
| GET | `/admin/analytics/overview` | Get analytics overview |
| GET | `/admin/analytics/revenue-chart` | Get revenue chart data |
| GET | `/admin/analytics/loyalty` | Get loyalty program metrics |

### GET `/admin/analytics/overview`
```
Query params:
  period — "today" | "7days" | "30days" | "90days" (default: "30days")
```

```json
// Response 200
{
  "totalRevenue": 342500,
  "revenueChange": 18.5,
  "avgTicket": 6850,
  "avgTicketChange": 8.0,
  "totalVisits": 52,
  "visitsChange": 12.0,
  "totalTryOns": 134,
  "tryOnsChange": 24.0,
  "customerRetention": 78.0,
  "newCustomers": 14,
  "avgVisitFrequency": 2.3,
  "churnRiskCount": 6
}
```

### GET `/admin/analytics/revenue-chart`
```
Query params:
  period — "7days" | "30days" | "90days"
```

```json
// Response 200
{
  "labels": ["Mon", "Tue", "Wed", "Thu", "Fri", "Sat", "Sun"],
  "values": [35000, 52000, 41000, 68000, 55000, 73000, 60000],
  "currency": "FCFA"
}
```

### GET `/admin/analytics/loyalty`
```json
// Response 200
{
  "tierDistribution": {
    "bronze": 45,
    "silver": 28,
    "gold": 15,
    "platinum": 5
  },
  "totalPointsRedeemed": 12500,
  "referralConversions": 8,
  "activeMembers": 93
}
```

---

## 15. Admin - Salon Settings

| Method | Endpoint | Description |
|--------|----------|-------------|
| GET | `/admin/salon` | Get salon profile |
| PUT | `/admin/salon` | Update salon profile |
| GET | `/admin/salon/stylists` | List staff members |
| POST | `/admin/salon/stylists` | Add a stylist |
| PUT | `/admin/salon/stylists/:id` | Update stylist info |
| DELETE | `/admin/salon/stylists/:id` | Remove a stylist |
| GET | `/admin/salon/subscription` | Get subscription details |
| GET | `/admin/settings/loyalty-config` | Get loyalty program config |
| PUT | `/admin/settings/loyalty-config` | Update loyalty config |

### GET `/admin/salon`
```json
// Response 200
{
  "id": "uuid",
  "name": "Belle Coiffure Douala",
  "location": "Rue de Bonaberi, Douala",
  "phone": "+237 6XX XXX XXX",
  "businessHours": {
    "weekdays": { "open": "09:00", "close": "18:00" },
    "weekends": { "open": "10:00", "close": "17:00" },
    "daysOff": ["sunday"]
  }
}
```

### GET `/admin/salon/subscription`
```json
// Response 200
{
  "plan": "Pro",
  "price": 65000,
  "currency": "FCFA",
  "billingCycle": "monthly",
  "status": "active",
  "maxStylists": 5,
  "currentStylists": 3,
  "features": ["AI Try-On", "Analytics", "Loyalty Program", "Multi-stylist"]
}
```

### GET `/admin/settings/loyalty-config`
```json
// Response 200
{
  "pointsPer500Fcfa": 10,
  "punchCardVisits": 5,
  "punchCardReward": "Free service up to 5,000 FCFA",
  "birthdayReward": 50,
  "referralBonus": 100
}
```

### PUT `/admin/settings/loyalty-config`
```json
// Request
{
  "pointsPer500Fcfa": 15,
  "punchCardVisits": 4,
  "birthdayReward": 75,
  "referralBonus": 150
}
```

---

## Data Models Summary

### Core Entities

| Model | Key Fields |
|-------|------------|
| **User** | id, email, password, name, phone, userType (customer/admin), language, createdAt |
| **Customer** | userId, profilePhotoUrl, loyaltyTier, totalPoints, totalVisits, memberSince, referralCode |
| **HairStyle** | id, name, nameKey, category, gender, price, imageUrl, description, tryOnCount |
| **Booking** | id, customerId, styleId, stylistId, date, time, duration, price, status, notes, createdAt |
| **Stylist** | id, name, specialty, photoUrl, salonId, active |
| **Service** | id, name, nameKey, category, duration, price |
| **TryOn** | id, customerId, styleId, userPhotoUrl, generatedImageUrl, hairColor, createdAt |
| **LoyaltyActivity** | id, customerId, type, points, isEarn, description, createdAt |
| **PunchCard** | id, customerId, stamps, totalNeeded |
| **Notification** | id, userId, type, title, message, read, createdAt |
| **Salon** | id, name, location, phone, businessHours, subscriptionPlan |
| **SavedStyle** | id, customerId, styleId, savedAt |

### Enums

| Enum | Values |
|------|--------|
| **UserType** | `customer`, `admin` |
| **Gender** | `women`, `men` |
| **StyleCategory** | `wigs`, `braids`, `locs`, `curls`, `fades` |
| **BookingStatus** | `pending`, `confirmed`, `checked_in`, `cancelled` |
| **LoyaltyTier** | `bronze`, `silver`, `gold`, `platinum` |
| **ActivityType** | `haircut`, `referral`, `redeemed`, `social`, `birthday` |
| **NotificationType** | `booking_confirmed`, `booking_reminder`, `loyalty_reward`, `promotion` |

### Currency

All prices are in **FCFA** (Central African CFA franc), stored as integers (no decimals).

---

## Authentication Notes

- All endpoints except `/auth/*` and `GET /styles` require a valid JWT in the `Authorization: Bearer <token>` header.
- Admin endpoints (`/admin/*`) require `userType: "admin"` in the JWT.
- Tokens expire after 24 hours; use `/auth/refresh-token` to renew.

## Total Endpoint Count

| Section | Endpoints |
|---------|-----------|
| Auth | 7 |
| Customer Profile | 4 |
| Styles Catalog | 4 |
| AI Try-On | 4 |
| Bookings | 7 |
| Services | 2 |
| Stylists (Public) | 3 |
| Loyalty | 6 |
| Notifications | 4 |
| Saved Styles | 3 |
| Admin Dashboard | 1 |
| Admin Bookings | 5 |
| Admin Catalog | 5 |
| Admin Analytics | 3 |
| Admin Settings | 9 |
| **Total** | **67** |
