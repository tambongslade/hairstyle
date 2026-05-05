# LisBeauty API Guide for Frontend

**Base URL:** `https://your-domain.com/api/v1`
**Auth:** JWT Bearer token in `Authorization: Bearer <token>` header
**Content-Type:** `application/json` (unless uploading files, then `multipart/form-data`)

---

## TABLE OF CONTENTS

1. [Authentication](#1-authentication)
2. [Salons](#2-salons)
3. [Styles / Hair Catalog](#3-styles--hair-catalog)
4. [AI Try-On](#4-ai-try-on)
5. [Bookings](#5-bookings)
6. [Stylists](#6-stylists)
7. [Services](#7-services)
8. [Customer Profile](#8-customer-profile)
9. [Loyalty Program](#9-loyalty-program)
10. [Notifications](#10-notifications)
11. [Explore Feed (NEW)](#11-explore-feed)
12. [Social Sharing (NEW)](#12-social-sharing)
13. [Community Reviews (NEW)](#13-community-reviews)
14. [Style Comparison (NEW)](#14-style-comparison)
15. [Badges & Achievements (NEW)](#15-badges--achievements)
16. [Hair Journey Tracker (NEW)](#16-hair-journey-tracker)
17. [Smart Recommendations (NEW)](#17-smart-recommendations)
18. [Enums Reference](#18-enums-reference)
19. [Typical User Flows](#19-typical-user-flows)

---

## 1. AUTHENTICATION

No token required for these endpoints.

### Register
```
POST /auth/register
```
```json
{
  "name": "Amara Kouassi",
  "email": "amara@example.com",
  "password": "mypassword123",
  "phone": "+237 691 000 000"       // optional
}
```
**Response (201):**
```json
{
  "user": { "id": "uuid", "name": "Amara Kouassi", "email": "amara@example.com" },
  "accessToken": "eyJhbG...",
  "refreshToken": "eyJhbG..."
}
```

### Login
```
POST /auth/login
```
```json
{
  "email": "amara@example.com",
  "password": "mypassword123",
  "userType": "customer"            // optional, default "customer"
}
```
**Response (200):** Same shape as register.

### Social Login (Google/Apple/Facebook)
```
POST /auth/social-login
```
```json
{
  "provider": "google",             // "google" | "apple" | "facebook"
  "accessToken": "<provider-token>"
}
```

### Refresh Token
```
POST /auth/refresh
```
```json
{ "refreshToken": "eyJhbG..." }
```
**Response:** New `accessToken` + `refreshToken`.

### Logout (requires JWT)
```
POST /auth/logout
```

### Forgot Password
```
POST /auth/forgot-password
```
```json
{ "email": "amara@example.com" }
```

### Reset Password
```
POST /auth/reset-password
```
```json
{ "token": "<reset-token-from-email>", "newPassword": "newpass123" }
```

---

## 2. SALONS

All require JWT unless noted.

### Search Salons
```
GET /salons?search=beauty&location=douala&page=1&limit=20
```
**Response:**
```json
{
  "salons": [
    {
      "id": "uuid",
      "name": "LIS Beauty Douala",
      "description": "Premium beauty salon",
      "location": "Rue de Bonaberi, Douala",
      "logoUrl": "/uploads/logo.png",
      "coverImageUrl": "/uploads/cover.jpg",
      "rating": 4.75,
      "followersCount": 120,
      "isFollowing": false,
      "businessHours": {
        "monday": { "open": "09:00", "close": "18:00" },
        "tuesday": { "open": "09:00", "close": "18:00" },
        "wednesday": { "open": "09:00", "close": "18:00" },
        "thursday": { "open": "09:00", "close": "18:00" },
        "friday": { "open": "09:00", "close": "18:00" },
        "saturday": { "open": "10:00", "close": "16:00" },
        "sunday": { "open": "00:00", "close": "00:00", "closed": true }
      }
    }
  ],
  "total": 1,
  "page": 1,
  "totalPages": 1
}
```

### Get Salon Details
```
GET /salons/:id
```

### Follow / Unfollow
```
POST /salons/:id/follow
DELETE /salons/:id/follow
```

### Select Salon as Active
```
PUT /salons/:id/select
```
Use this when the user taps "Use this salon". It becomes their default salon for bookings.

### Get Selected Salon
```
GET /salons/selected
```

### Clear Selection
```
DELETE /salons/selected
```

### Get Followed Salons
```
GET /salons/following?page=1&limit=20
```

---

## 3. STYLES / HAIR CATALOG

**No auth required** for browsing. Works for all users, even without a salon.

### List Styles (with filters)
```
GET /styles?gender=women&category=braids&length=long&priceMin=3000&priceMax=15000&salonId=uuid&search=knotless&featured=true&sortBy=price&sortOrder=ASC&page=1&limit=20
```
All query params are optional. Without `salonId`, returns styles from ALL salons + global platform styles.

**Response:**
```json
{
  "items": [
    {
      "id": "uuid",
      "name": "Knotless Braids Long",
      "category": "braids",
      "gender": "women",
      "length": "long",
      "price": 8000,
      "priceMax": 12000,
      "duration": 180,
      "difficulty": "moderate",
      "imageUrl": "/uploads/style-123.jpg",
      "description": "Long knotless box braids...",
      "tags": ["protective", "trending"],
      "isFeatured": true,
      "tryOnCount": 45,
      "avgRating": 4.50,
      "reviewCount": 12,
      "salonId": "uuid-or-null"
    }
  ],
  "total": 50,
  "page": 1,
  "totalPages": 3
}
```

### Get Single Style
```
GET /styles/:id
```

### Trending / Featured / Categories (all public)
```
GET /styles/trending          // Top 10 by tryOnCount
GET /styles/featured          // isFeatured = true
GET /styles/categories        // All category enum values
GET /styles/lengths           // All length options
GET /styles/difficulties      // All difficulty levels
GET /styles/subcategories?category=braids
```

---

## 4. AI TRY-ON

Requires JWT.

### Generate Try-On (Customer)
```
POST /try-on/generate
Content-Type: multipart/form-data
```

| Field | Type | Required | Description |
|-------|------|----------|-------------|
| `userPhoto` | File | Yes | Customer's selfie/photo |
| `styleName` | String | Yes | e.g. "Knotless Braids Long" |
| `styleDescription` | String | Yes | Detailed AI prompt description |
| `hairColor` | String | No | "natural black", "dark brown", "golden blonde", etc. |
| `styleId` | UUID | No | Database ID of style (for tracking) |

**Frontend example (React Native / Flutter):**
```javascript
const formData = new FormData();
formData.append('userPhoto', {
  uri: photoUri,
  type: 'image/jpeg',
  name: 'selfie.jpg',
});
formData.append('styleName', 'Knotless Braids Long');
formData.append('styleDescription', 'Long knotless box braids, waist-length, seamless feed-in technique, neat and uniform, lightweight tension-free braids');
formData.append('hairColor', 'natural black');
formData.append('styleId', 'uuid-of-style');         // optional

const response = await fetch(`${BASE_URL}/try-on/generate`, {
  method: 'POST',
  headers: { 'Authorization': `Bearer ${token}` },
  body: formData,
});
```

**Response (201):**
```json
{
  "data": {
    "tryOnId": "uuid",
    "imageUrl": "/uploads/tryon/generated-abc123.png",
    "generatedImage": "/uploads/tryon/generated-abc123.png",
    "userPhotoUrl": "/uploads/tryon-1234.jpg",
    "styleName": "Knotless Braids Long",
    "processingTimeMs": 8500
  }
}
```

**Important:** `imageUrl` and `generatedImage` are the same — use whichever your frontend expects. The full URL is `${BASE_URL_WITHOUT_API}${imageUrl}`.

### Upload Photo (Standalone)
```
POST /try-on/upload
Content-Type: multipart/form-data
```
| Field | Type | Required |
|-------|------|----------|
| `userPhoto` | File | Yes |

**Response:**
```json
{
  "data": {
    "photoUrl": "/uploads/tryon-1234.jpg",
    "filename": "tryon-1234.jpg"
  }
}
```
Use this when the user wants to upload their photo first, then pick styles to try later.

### Save Try-On Result
```
POST /try-on/save
```
```json
{ "tryOnId": "uuid" }
```

### Try-On History
```
GET /try-on/history?page=1&limit=20
```

### Delete Try-On
```
DELETE /try-on/:id
```

### Style Descriptions for AI Prompts

Here are ALL the `styleDescription` values the frontend should send. These are the actual prompts fed to the AI:

**Women - Wigs:**
| styleName | styleDescription |
|-----------|------------------|
| Curly Bob Wig | Short curly bob wig, voluminous bouncy curls, chin-length, natural-looking with soft curls framing the face |
| Curly Pixie Wig | Short curly pixie cut wig, tight defined curls, cropped close to the head, chic and low-maintenance |
| Curly Ponytail Wig | Curly ponytail wig, high ponytail with voluminous spiral curls cascading down, elegant and playful |
| Half-Up Curly Wavy Wig | Long wavy wig with half-up style, top section pulled back while long loose waves flow past shoulders, romantic and versatile |
| Middle Part Bob Wig | Straight bob wig with clean middle part, sleek and polished, chin to shoulder length, sharp cut ends |
| Side Part Bob Wig | Straight bob wig with deep side part, asymmetric drape, sleek and modern, one side tucked behind ear |
| Simple Ponytail Wig | Simple straight ponytail wig, low or mid ponytail, clean and sleek, everyday natural look |
| Wavy Bob Wig | Wavy bob wig, loose beach waves at chin to shoulder length, effortlessly chic and tousled texture |
| Wavy Long Wig | Long flowing wavy wig, cascading waves past mid-back, glamorous red-carpet volume, soft texture |

**Women - Braids:**
| styleName | styleDescription |
|-----------|------------------|
| Boho Braids Long | Long bohemian braids with loose curly ends, waist-length, boho goddess braids with wispy curls interspersed |
| Boho Braids Short | Short bohemian braids with curly ends, shoulder-length, boho braids with loose curly pieces mixed in |
| Boho Cornrow | Bohemian cornrow braids, feed-in cornrows with loose curly strands, artistic and free-spirited pattern |
| Knotless Braids Long | Long knotless box braids, waist-length, seamless feed-in technique, neat and uniform, lightweight tension-free braids |
| Knotless Braids Short | Short knotless box braids, shoulder-length, seamless starts, neat partings, lightweight protective style |
| Lemonade Braids | Lemonade side-swept braids (Beyonce-inspired), all braids swept to one side, cornrow feed-in pattern |
| Patewo Braids | Patewo braids (Nigerian-style all-back braids), straight-back braids gathered neatly at the nape, traditional and clean |
| Up-Do Braids | Braided updo hairstyle, braids gathered and pinned up into an elegant bun or high updo, formal and sophisticated |

**Women - Locs:**
| styleName | styleDescription |
|-----------|------------------|
| Locs Long | Long faux locs, waist-length dreadlocks, thick or medium-width locs hanging freely, natural bohemian vibe |
| Locs Medium | Medium-length faux locs, shoulder to chest length, neat uniform locs with natural texture |
| Locs Short | Short faux locs, bob-length dreadlocks, chin to shoulder length, edgy and manageable |

**Women - Curls:**
| styleName | styleDescription |
|-----------|------------------|
| French Curl Long | Long French curl crochet braids, tight spiral curls flowing past shoulders, voluminous bouncy texture |
| French Curls Short | Short French curl crochet style, chin-length tight spiral curls, full and bouncy, playful look |
| Jadawada | Jadawada curls style, unique defined curly pattern, voluminous textured curls with natural movement |

**Men - Fades:**
| styleName | styleDescription |
|-----------|------------------|
| Buzz Cut Low Fade | Short buzz cut with a clean low skin fade, tight textured crop on top, sharp lineup at the forehead and temples |
| Mid Taper Fade | Classic mid taper fade, skin-tight sides blending gradually into a short textured top, clean neckline taper |
| 360 Waves with Beard | 360 wave pattern with deep defined waves all around, mid skin fade on the sides, sharp lineup, paired with a full thick beard |
| 360 Waves Low Fade | Clean 360 wave pattern on top with a low skin fade, sharp temple and forehead lineup, waves flowing in a defined spiral pattern |
| Skin Fade | Clean skin fade with short textured top, sides faded down to skin, sharp beard lineup, fresh barbershop finish |
| Tapered Curly Top | Tapered sides with curly textured top, short tight curls on top with faded sides, modern African barber style |
| Finger Waves & Beard | Defined finger wave pattern on top with a full shaped beard, deep wave sculpting with clean edges |

**Men - Curls:**
| styleName | styleDescription |
|-----------|------------------|
| Curly Top Drop Fade | High curly top with a drop fade, voluminous defined coils on top, tapered sides fading to skin behind the ear |
| Curly High Top Fade | High top with tight defined curls, mid skin fade on the sides, sharp square lineup, voluminous curly texture on top |
| Natural Afro | Full natural afro, big rounded shape with voluminous coily texture, free-form pick-out afro with height and width |

**Men - Braids/Locs:**
| styleName | styleDescription |
|-----------|------------------|
| Cornrows | Men's cornrow braids, straight-back rows braided tight to the scalp, clean parallel lines from forehead to nape |
| Short Locs | Men's short to medium freeform dreadlocks, shoulder-length locs with natural texture, loose hanging style |

---

## 5. BOOKINGS

Requires JWT.

### Get Available Dates
```
GET /bookings/available-dates?stylistId=uuid&days=14
```
Call this first to show the date picker. Returns dates with slot counts.

### Get Available Times
```
GET /bookings/available-times?date=2026-03-28&stylistId=uuid
```
Call after user picks a date. Returns time slots.

### Create Booking
```
POST /bookings
```
```json
{
  "styleId": "uuid",
  "date": "2026-03-28",
  "time": "09:30",
  "stylistId": "uuid",              // optional
  "notes": "I want it shorter"      // optional
}
```

### List My Bookings
```
GET /bookings?status=confirmed&from=2026-03-01&to=2026-03-31&page=1&limit=20
```

### Get Booking Detail
```
GET /bookings/:id
```

### Update Booking (Reschedule)
```
PUT /bookings/:id
```
```json
{
  "date": "2026-03-29",
  "time": "14:00",
  "stylistId": "uuid"               // optional
}
```

### Cancel Booking
```
PUT /bookings/:id/cancel
```

---

## 6. STYLISTS

No auth required.

### List Active Stylists
```
GET /stylists
```

### Get Stylist Details
```
GET /stylists/:id
```

### Get Stylist Availability
```
GET /stylists/:id/availability?date=2026-03-28
```

---

## 7. SERVICES

No auth required.

### List All Services
```
GET /services
```

### Get Service Detail
```
GET /services/:id
```

---

## 8. CUSTOMER PROFILE

Requires JWT.

### Get Profile
```
GET /customer/profile
```

### Update Profile
```
PUT /customer/profile
```
```json
{
  "name": "Amara K.",
  "phone": "+237 691 000 001",
  "language": "fr"
}
```

### Upload Profile Photo
```
POST /customer/profile/photo
Content-Type: multipart/form-data
```
| Field | Type | Required |
|-------|------|----------|
| `file` | File | Yes |

### Delete Account
```
DELETE /customer/profile
```

### Saved Styles (Favorites)
```
GET /customer/saved-styles
POST /customer/saved-styles/:styleId
DELETE /customer/saved-styles/:styleId
```

---

## 9. LOYALTY PROGRAM

Requires JWT.

### Get Loyalty Profile
```
GET /loyalty/profile
```
Returns tier (BRONZE/SILVER/GOLD/PLATINUM), points, progress to next tier.

### Activity History
```
GET /loyalty/activities
```

### Punch Card
```
GET /loyalty/punch-card
```

### Referral Info
```
GET /loyalty/referral
```

### Redeem Points
```
POST /loyalty/redeem
```
```json
{
  "points": 100,
  "rewardType": "discount"          // "discount" | "free_service" | "product"
}
```

### Track Referral Share
```
POST /loyalty/referral/share
```

---

## 10. NOTIFICATIONS

Requires JWT.

```
GET /notifications                   // All notifications
GET /notifications/unread-count      // Just the count (for badge)
PUT /notifications/read-all          // Mark all read
PUT /notifications/:id/read          // Mark one read
```

---

## 11. EXPLORE FEED

**No auth required.** This is the home screen for all users, especially those without a salon.

### Get Full Feed
```
GET /explore/feed
```
**Response:**
```json
{
  "styleOfTheDay": {
    "id": "uuid",
    "caption": "Perfect for the weekend",
    "style": {
      "id": "uuid",
      "name": "Boho Braids Long",
      "imageUrl": "/uploads/style.jpg",
      "price": 8000,
      "category": "braids",
      "avgRating": 4.5,
      "tryOnCount": 67
    }
  },
  "collections": [
    {
      "id": "uuid",
      "title": "Festival Season Braids",
      "description": "Perfect styles for the holiday season",
      "coverImageUrl": "/uploads/collection-cover.jpg",
      "type": "seasonal",
      "styles": [
        { "id": "uuid", "name": "Boho Braids Long", "imageUrl": "...", "price": 8000 },
        { "id": "uuid", "name": "Lemonade Braids", "imageUrl": "...", "price": 6000 }
      ]
    }
  ],
  "trending": [
    { "id": "uuid", "name": "Knotless Braids Long", "tryOnCount": 120, "avgRating": 4.8 }
  ]
}
```

**How to use on the home screen:**
1. Show Style of the Day at the top with a big hero card + "Try it on" button
2. Show collections as horizontal scrollable sections
3. Show trending at the bottom as a grid

### Style of the Day (standalone)
```
GET /explore/style-of-the-day
```
If no admin-picked SOTD exists, returns the most popular style as fallback (`isFallback: true`).

### Collections
```
GET /explore/collections?page=1&limit=10
GET /explore/collections/:id
```

### Enhanced Trending
```
GET /explore/trending?period=week&limit=10
```
`period`: `week` | `month` | `all`

---

## 12. SOCIAL SHARING

Requires JWT.

### How it works:
1. User generates a try-on
2. User taps "Share" -> frontend opens native share sheet
3. Frontend calls this endpoint to TRACK the share (for badges + analytics)
4. The backend returns the image URL and deep link to include in the share

### Track a Share
```
POST /shares
```
```json
{
  "shareType": "tryon",             // "tryon" | "comparison" | "style" | "journal"
  "referenceId": "uuid-of-tryon",
  "platform": "whatsapp"            // "whatsapp" | "instagram" | "facebook" | "twitter" | "download" | "link"
}
```
**Response:**
```json
{
  "data": {
    "shareId": "uuid",
    "shareImageUrl": "/uploads/tryon/generated-abc.png",
    "deepLink": "/share/tryon/uuid",
    "platform": "whatsapp"
  }
}
```

### Share History
```
GET /shares/history?page=1&limit=20
```

### Resolve Deep Link (Public, no auth)
```
GET /shares/deeplink/tryon/:id
GET /shares/deeplink/style/:id
```
When someone clicks a shared link, call this to get the content. Use it to show the style page or try-on result to the new user.

**Frontend flow for sharing:**
```javascript
// 1. User taps share on a try-on result
const shareResult = await api.post('/shares', {
  shareType: 'tryon',
  referenceId: tryOnId,
  platform: 'whatsapp',
});

// 2. Open native share with the image and deep link
Share.open({
  title: `Check out this hairstyle on LisBeauty!`,
  url: `https://lisbeauty.com${shareResult.data.deepLink}`,
  type: 'image/png',
  // For WhatsApp, include the image directly
});
```

---

## 13. COMMUNITY REVIEWS

### Submit a Review (JWT required)
```
POST /styles/:styleId/reviews
```
```json
{
  "rating": 5,
  "comment": "This looks amazing on dark skin!",
  "hasTried": true                   // optional - "I've actually worn this style"
}
```
One review per user per style. Returns 409 if already reviewed.

### Get Reviews for a Style (Public)
```
GET /styles/:styleId/reviews?page=1&limit=20&sort=recent
```
`sort`: `recent` | `helpful`

**Response:**
```json
{
  "items": [
    {
      "id": "uuid",
      "rating": 5,
      "comment": "This looks amazing on dark skin!",
      "hasTried": true,
      "helpfulCount": 12,
      "customerName": "Amara K.",
      "createdAt": "2026-03-26T10:00:00Z"
    }
  ],
  "total": 25,
  "page": 1,
  "totalPages": 2
}
```

### Edit / Delete Own Review (JWT)
```
PUT /styles/:styleId/reviews/:reviewId
DELETE /styles/:styleId/reviews/:reviewId
```

### Mark Review as Helpful (JWT)
```
POST /reviews/:reviewId/helpful
DELETE /reviews/:reviewId/helpful
```

### Get All My Reviews (JWT)
```
GET /customer/reviews
```

**Frontend tips:**
- Show star rating + review count on every style card (from `avgRating` and `reviewCount` fields)
- Show "Verified - I've tried this" badge next to reviews where `hasTried: true`
- Let users tap a thumbs-up icon to mark helpful

---

## 14. STYLE COMPARISON

Requires JWT. This lets users compare multiple try-on results side by side.

### How to use:
1. User does 2-4 try-ons first
2. Then creates a comparison from those try-on IDs
3. They can swipe between results and pick a favorite

### Create Comparison
```
POST /comparisons
```
```json
{
  "title": "My braids comparison",      // optional
  "tryOnIds": ["uuid-1", "uuid-2", "uuid-3"]
}
```
**Response:**
```json
{
  "id": "uuid",
  "title": "My braids comparison",
  "userPhotoUrl": "/uploads/tryon-original.jpg",
  "createdAt": "2026-03-26T10:00:00Z",
  "items": [
    {
      "id": "item-uuid-1",
      "styleName": "Knotless Braids Long",
      "generatedImageUrl": "/uploads/tryon/generated-1.png",
      "isFavorite": false
    },
    {
      "id": "item-uuid-2",
      "styleName": "Boho Braids Long",
      "generatedImageUrl": "/uploads/tryon/generated-2.png",
      "isFavorite": false
    }
  ]
}
```

### List Comparisons
```
GET /comparisons?page=1&limit=20
```

### Get Comparison Detail
```
GET /comparisons/:id
```

### Pick Favorite
```
PUT /comparisons/:comparisonId/favorite/:itemId
```
This marks one item as the winner. Only one favorite per comparison.

### Delete Comparison
```
DELETE /comparisons/:id
```

**Frontend UI suggestion:**
- Show items in a horizontal swipeable carousel or 2x2 grid
- Each item shows the generated image + style name
- Tap to expand, long-press or heart icon to mark as favorite
- "Share comparison" button at the bottom

---

## 15. BADGES & ACHIEVEMENTS

### Get All Badges (Public)
```
GET /badges
```
**Response:**
```json
[
  {
    "id": "uuid",
    "code": "tryon_1",
    "name": "First Try-On",
    "description": "Generated your first AI try-on",
    "iconUrl": null,
    "category": "tryon",
    "threshold": 1,
    "pointsAwarded": 10
  },
  {
    "id": "uuid",
    "code": "tryon_5",
    "name": "Try-On Explorer",
    "description": "Generated 5 AI try-ons",
    "category": "tryon",
    "threshold": 5,
    "pointsAwarded": 25
  }
]
```

### Get My Earned Badges (JWT)
```
GET /badges/my
```
Returns only badges the user has earned, with `earnedAt` timestamp.

### Get Full Progress (JWT)
```
GET /badges/progress
```
**Response:**
```json
[
  {
    "id": "uuid",
    "code": "tryon_1",
    "name": "First Try-On",
    "description": "Generated your first AI try-on",
    "category": "tryon",
    "threshold": 1,
    "pointsAwarded": 10,
    "earned": true,
    "earnedAt": "2026-03-25T14:00:00Z"
  },
  {
    "id": "uuid",
    "code": "tryon_5",
    "name": "Try-On Explorer",
    "description": "Generated 5 AI try-ons",
    "category": "tryon",
    "threshold": 5,
    "pointsAwarded": 25,
    "earned": false,
    "earnedAt": null
  }
]
```

**Available badge categories:**
| Category | Badges | How to earn |
|----------|--------|-------------|
| `tryon` | First Try-On (1), Try-On Explorer (5), Try-On Master (25) | Generate AI try-ons |
| `review` | First Review (1), Style Critic (10) | Post style reviews |
| `journal` | Journey Begins (1), Consistent Tracker (7) | Create hair journal entries |
| `social` | First Share (1), Social Butterfly (5) | Share try-on results |
| `collection` | Style Collector (10), Style Hoarder (50) | Save styles to favorites |
| `salon` | Salon Discoverer (1 follow), First Booking (1 booking) | Connect with salons |

**Frontend tips:**
- Show a badge wall in the profile tab
- Earned badges are full color, unearned are greyed out
- Show a toast/popup when a new badge is earned
- Salon badges should have a special "Connect to a salon to unlock" treatment

---

## 16. HAIR JOURNEY TRACKER

Requires JWT. A personal photo diary tracking hair over time.

### Add Journal Entry
```
POST /hair-journey
Content-Type: multipart/form-data
```

| Field | Type | Required | Description |
|-------|------|----------|-------------|
| `photo` | File | Yes | Hair photo |
| `entryDate` | String | Yes | Date (YYYY-MM-DD) |
| `caption` | String | No | "Loving my new braids!" |
| `hairStatus` | String | No | "natural", "styled", "transitioning", "protective", "colored", "treatment" |
| `products` | String | No | Comma-separated: "Shea butter,Coconut oil" |
| `styleName` | String | No | "Knotless Braids Long" |
| `styleId` | UUID | No | Link to a catalog style |
| `tryOnId` | UUID | No | Link to a try-on result |
| `rating` | Integer | No | 1-5 self-satisfaction rating |

### Get Timeline
```
GET /hair-journey?page=1&limit=20
```
**Response:**
```json
{
  "items": [
    {
      "id": "uuid",
      "photoUrl": "/uploads/journal-123.jpg",
      "caption": "Loving my new braids!",
      "hairStatus": "styled",
      "styleName": "Knotless Braids Long",
      "products": ["Shea butter", "Coconut oil"],
      "rating": 5,
      "entryDate": "2026-03-26",
      "createdAt": "2026-03-26T10:00:00Z"
    }
  ],
  "total": 15,
  "page": 1,
  "totalPages": 1
}
```

### Get Summary Stats
```
GET /hair-journey/summary
```
**Response:**
```json
{
  "totalEntries": 15,
  "mostUsedStyle": "Knotless Braids Long",
  "avgSatisfaction": "4.2"
}
```

### Compare Two Entries (Then vs Now)
```
GET /hair-journey/compare?id1=uuid&id2=uuid
```
Returns both entries side by side.

### Single Entry / Update / Delete
```
GET /hair-journey/:id
PUT /hair-journey/:id
DELETE /hair-journey/:id
```

**Frontend tips:**
- Show as a vertical timeline (like Instagram Stories highlights, but permanent)
- "Add entry" button with camera icon always visible
- Show satisfaction rating as star icons
- "Compare" button to pick two entries for a before/after view
- Auto-suggest adding a journal entry after a salon visit or try-on

---

## 17. SMART RECOMMENDATIONS

### Get Personalized Recommendations (JWT)
```
GET /recommendations?limit=10
```
**Response:**
```json
{
  "recommendations": [
    {
      "id": "uuid",
      "name": "Boho Braids Long",
      "category": "braids",
      "gender": "women",
      "price": 8000,
      "imageUrl": "/uploads/style.jpg",
      "avgRating": 4.7,
      "tryOnCount": 89
    }
  ]
}
```
Returns styles the user hasn't tried yet, weighted by their preferences and popularity.

### "More Like This" (Public)
```
GET /recommendations/similar/:styleId?limit=8
```
Returns styles similar by category and gender. Use this on the style detail page.

### Style Quiz / Preferences (JWT)

#### Get Current Preferences
```
GET /customer/preferences
```

#### Update Preferences (Style Quiz)
```
PUT /customer/preferences
```
```json
{
  "faceShape": "oval",              // "oval" | "round" | "square" | "heart" | "oblong"
  "preferredLength": "long",        // "short" | "medium" | "long" | "extra_long"
  "preferredCategories": ["braids", "locs", "curls"],
  "lifestyle": "moderate",          // "low_maintenance" | "moderate" | "glam"
  "hairTexture": "coily"            // "straight" | "wavy" | "curly" | "coily" | "kinky"
}
```

All fields are optional. Send only the ones the user answered.

### Track Style View (Public)
```
POST /styles/:styleId/view?source=explore
```
`source`: `explore` | `search` | `collection` | `recommendation` | `share_link`

Call this when a user views a style detail page. This improves future recommendations.

**Frontend tips:**
- Show a "Style Quiz" onboarding screen (3-5 taps) asking face shape, preferred length, lifestyle
- Show "Recommended for you" section on home screen after quiz
- Show "More like this" grid below every style detail page
- Silently track views in the background for better recs

---

## 18. ENUMS REFERENCE

### Gender
```
women | men | unisex
```

### StyleCategory
```
wigs | braids | locs | curls | fades | twists | weaves | natural | cornrows | updos | color
```

### HairLength
```
short | medium | long | extra_long
```

### StyleDifficulty
```
simple | moderate | complex
```

### BookingStatus
```
pending | confirmed | checked_in | cancelled
```

### LoyaltyTier
```
bronze | silver | gold | platinum
```

### HairStatus (for journal)
```
natural | styled | transitioning | protective | colored | treatment
```

### SharePlatform
```
whatsapp | instagram | facebook | twitter | download | link
```

### ShareType
```
tryon | comparison | style | journal
```

### FaceShape
```
oval | round | square | heart | oblong
```

### HairTexture
```
straight | wavy | curly | coily | kinky
```

### Lifestyle
```
low_maintenance | moderate | glam
```

### BadgeCategory
```
tryon | review | journal | social | collection | salon | special
```

---

## 19. TYPICAL USER FLOWS

### Flow 1: New User (No Salon)
```
1. Register                          POST /auth/register
2. See home screen                   GET /explore/feed
3. Browse Style of the Day           GET /explore/style-of-the-day
4. Browse trending                   GET /explore/trending?period=week
5. View a style                      GET /styles/:id
6. Track the view                    POST /styles/:id/view?source=explore
7. Generate try-on                   POST /try-on/generate (with photo)
8. Share result on WhatsApp          POST /shares (track it)
9. Save the style                    POST /customer/saved-styles/:styleId
10. Leave a review                   POST /styles/:id/reviews
11. Check earned badges              GET /badges/progress
```

### Flow 2: Style Quiz + Recommendations
```
1. Open style quiz                   GET /customer/preferences
2. User answers questions            PUT /customer/preferences
3. Show recommendations              GET /recommendations
4. User taps a style                 GET /styles/:id
5. "More like this"                  GET /recommendations/similar/:id
```

### Flow 3: Try-On Comparison
```
1. Upload photo                      POST /try-on/upload
2. Try style 1                       POST /try-on/generate
3. Try style 2                       POST /try-on/generate
4. Try style 3                       POST /try-on/generate
5. Create comparison                 POST /comparisons { tryOnIds: [...] }
6. View comparison                   GET /comparisons/:id
7. Pick favorite                     PUT /comparisons/:id/favorite/:itemId
8. Share comparison                  POST /shares { shareType: "comparison" }
```

### Flow 4: Hair Journey
```
1. Take a photo today               POST /hair-journey (with photo)
2. View timeline                     GET /hair-journey
3. Compare with older entry          GET /hair-journey/compare?id1=&id2=
4. Check summary                     GET /hair-journey/summary
```

### Flow 5: Salon Connection (Funnel)
```
1. User sees "Available at Salon X"  (from explore/trending)
2. View salon                        GET /salons/:id
3. Follow salon                      POST /salons/:id/follow
4. Earns "Salon Discoverer" badge
5. Select salon                      PUT /salons/:id/select
6. Browse salon stylists             GET /stylists
7. Check availability                GET /bookings/available-dates
8. Book appointment                  POST /bookings
9. Earns "First Booking" badge
```

---

## ERROR HANDLING

All errors follow this format:
```json
{
  "statusCode": 404,
  "message": "Style not found",
  "error": "Not Found"
}
```

Common status codes:
- `200` - Success (GET, PUT)
- `201` - Created (POST)
- `400` - Validation error (bad input)
- `401` - Unauthorized (missing/expired token)
- `404` - Not found
- `409` - Conflict (duplicate: already reviewed, already following, etc.)

---

## IMAGES

All image URLs returned by the API are relative paths like `/uploads/style-123.jpg`.

To get the full URL:
```
Full URL = BASE_SERVER_URL + imageUrl
Example:  https://api.lisbeauty.com/uploads/style-123.jpg
```

Make sure your app serves the `/uploads` directory as static files (already configured).
