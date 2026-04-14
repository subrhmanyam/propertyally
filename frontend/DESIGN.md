# Frontend Design Document — Property Management Platform
### Flutter Web + Mobile | Bogineni Group Theme

---

## 1. Overview

A full-featured property management SaaS platform built in Flutter (targeting Web + Mobile). Inspired by the Buildium/AppFolio-style dashboard, reskinned with the **Bogineni Group luxury minimalist aesthetic** — black, charcoal, and silver with sharp corners, restrained typography, and purposeful whitespace.

### Core Feature Modules
| Module | Description |
|---|---|
| Dashboard | Overview, tasks, accounting summary, recently viewed |
| Property Listings | Add, edit, view properties and units |
| Tenant Management | Tenant profiles, screening, documents |
| Customized Applications | Rental application forms builder |
| Rent & Accounting | Rent roll, payments, expenses, ledger |
| Maintenance Tracking | Request submission, work order management |
| Listing Website | Public-facing property listing site |
| Reports | Financial, occupancy, and tenant reports |

---

## 2. Design System

### 2.1 Color Palette

Sourced from **boginenigroup.com** — luxury minimalist, high-contrast black/silver.

```dart
// lib/core/constants/app_colors.dart

// Backgrounds
static const Color bgPrimary     = Color(0xFF000000); // Pure black
static const Color bgSurface     = Color(0xFF131313); // Page background
static const Color bgCard        = Color(0xFF1E1E1E); // Card surface
static const Color bgElevated    = Color(0xFF313131); // Charcoal — sidebars, modals
static const Color bgHover       = Color(0xFF464444); // Hover / selected state

// Text
static const Color textPrimary   = Color(0xFFC0C0C0); // Silver — primary body text
static const Color textHeading   = Color(0xFFFFFFFF); // White — headings
static const Color textMuted     = Color(0xFF797373); // Muted — captions, labels
static const Color textSecondary = Color(0xFF908787); // Secondary text

// Borders & Dividers
static const Color border        = Color(0xFF2A2A2A); // Subtle divider
static const Color borderAccent  = Color(0xFF464444); // Stronger border

// Accent
static const Color accentSilver  = Color(0xFFC0C0C0); // Silver accent (buttons, icons)
static const Color accentGold    = Color(0xFFD4AF37); // Gold — luxury highlights, badges
static const Color accentGoldSub = Color(0xFF9E7C1A); // Muted gold for backgrounds

// Semantic
static const Color success       = Color(0xFF4CAF50); // Rent received, active
static const Color warning       = Color(0xFFFFA726); // Pending, due soon
static const Color error         = Color(0xFFCF6679); // Overdue, failed
static const Color info          = Color(0xFF64B5F6); // Informational

// Overlay
static const Color overlay       = Color(0x94000000); // Semi-transparent black
```

### 2.2 Typography

Font family sourced from Bogineni Group site — DTLNobel (light + bold weight), fallback to Inter.

```dart
// lib/core/constants/app_dimensions.dart — font sizes

// Headings
static const double fontDisplay    = 35.0; // Hero / page titles
static const double fontH1         = 28.0;
static const double fontH2         = 22.0;
static const double fontH3         = 18.0;

// Body
static const double fontBody       = 16.0;
static const double fontBodySm     = 14.0;
static const double fontCaption    = 12.0;
static const double fontLabel      = 11.0; // Tags, badges

// Nav / Button
static const double fontNav        = 15.0;
static const double fontButton     = 13.0; // Uppercase
```

**Text style rules:**
- Headings: White (`#FFFFFF`), Bold weight, uppercase for section labels
- Body: Silver (`#C0C0C0`), Light weight
- Captions: Muted (`#797373`)
- Button labels: Uppercase, letter-spacing 1.2

### 2.3 Spacing & Dimensions

```dart
// lib/core/constants/app_dimensions.dart

static const double spaceXS   = 4.0;
static const double spaceSM   = 8.0;
static const double spaceMD   = 16.0;
static const double spaceLG   = 24.0;
static const double spaceXL   = 32.0;
static const double spaceXXL  = 48.0;

static const double radiusNone   = 0.0;  // Default — sharp corners (brand style)
static const double radiusSM     = 4.0;  // Only used for tags/badges
static const double radiusMD     = 8.0;  // Cards in softer contexts
static const double radiusFull   = 100.0; // Avatar, pills

static const double cardPadding       = 20.0;
static const double sidebarWidth      = 240.0;
static const double sidebarCollapsed  = 64.0;
static const double topBarHeight      = 64.0;
static const double maxContentWidth   = 1400.0;
```

### 2.4 Button Styles

```
Primary Button:   Black bg (#000), Silver text (#C0C0C0), NO border radius, uppercase
Secondary Button: Transparent bg, Silver border (1px), Silver text, NO border radius
Ghost Button:     No bg, No border, Silver text, underline on hover
Danger Button:    Error red bg, White text, NO border radius
```

### 2.5 Shadows & Elevation

```dart
static const BoxShadow cardShadow = BoxShadow(
  color: Color(0x40231F20),
  blurRadius: 20,
  offset: Offset(4, 4),
);
static const BoxShadow dropdownShadow = BoxShadow(
  color: Color(0x33000000),
  blurRadius: 16,
  offset: Offset(0, 8),
);
```

---

## 3. Flutter Project Structure

```
frontend/
├── lib/
│   ├── core/
│   │   ├── constants/
│   │   │   ├── app_colors.dart       ← all Color values
│   │   │   ├── app_dimensions.dart   ← spacing, font sizes, radii
│   │   │   ├── app_strings.dart      ← all UI labels / copy
│   │   │   └── app_assets.dart       ← image & icon asset paths
│   │   ├── theme/
│   │   │   └── app_theme.dart        ← ThemeData built from constants
│   │   ├── network/
│   │   │   ├── api_client.dart       ← Dio instance + interceptors
│   │   │   └── interceptors/
│   │   │       ├── auth_interceptor.dart
│   │   │       └── error_interceptor.dart
│   │   ├── base/
│   │   │   ├── base_screen.dart      ← scaffold + app bar + side nav
│   │   │   ├── base_provider.dart    ← loading/error state mixin
│   │   │   └── base_repository.dart  ← Dio call wrapper
│   │   └── router/
│   │       └── app_router.dart       ← GoRouter route definitions
│   │
│   ├── shared/
│   │   └── widgets/
│   │       ├── app_button.dart         ← primary / secondary / ghost
│   │       ├── app_text_field.dart
│   │       ├── app_card.dart
│   │       ├── stat_card.dart          ← KPI tiles (revenue, expenses)
│   │       ├── property_tile.dart      ← listing card in grid/list
│   │       ├── status_badge.dart       ← Occupied / Vacant / Overdue
│   │       ├── avatar.dart
│   │       ├── search_bar.dart
│   │       ├── sidebar_nav.dart        ← collapsible left navigation
│   │       ├── top_bar.dart            ← top app bar with search
│   │       ├── data_table_widget.dart  ← reusable sortable table
│   │       ├── chart_bar.dart          ← bar chart (accounting)
│   │       └── empty_state.dart        ← empty list illustrations
│   │
│   └── features/
│       ├── auth/
│       │   ├── data/          ← AuthRepository, AuthApiService
│       │   ├── domain/        ← User model, AuthState
│       │   └── presentation/
│       │       ├── login_screen.dart
│       │       └── auth_provider.dart
│       │
│       ├── dashboard/
│       │   ├── data/
│       │   ├── domain/
│       │   └── presentation/
│       │       ├── dashboard_screen.dart
│       │       ├── widgets/
│       │       │   ├── task_list_widget.dart
│       │       │   ├── accounting_summary_widget.dart
│       │       │   └── recently_viewed_widget.dart
│       │       └── dashboard_provider.dart
│       │
│       ├── properties/
│       │   ├── data/
│       │   ├── domain/        ← Property, Unit models
│       │   └── presentation/
│       │       ├── property_list_screen.dart
│       │       ├── property_detail_screen.dart
│       │       ├── add_property_screen.dart
│       │       └── properties_provider.dart
│       │
│       ├── tenants/
│       │   ├── data/
│       │   ├── domain/        ← Tenant, ScreeningResult models
│       │   └── presentation/
│       │       ├── tenant_list_screen.dart
│       │       ├── tenant_detail_screen.dart
│       │       ├── screening_screen.dart
│       │       └── tenants_provider.dart
│       │
│       ├── applications/
│       │   ├── data/
│       │   ├── domain/        ← Application, ApplicationForm models
│       │   └── presentation/
│       │       ├── application_list_screen.dart
│       │       ├── application_form_screen.dart
│       │       └── applications_provider.dart
│       │
│       ├── accounting/
│       │   ├── data/
│       │   ├── domain/        ← Transaction, Invoice, RentRoll models
│       │   └── presentation/
│       │       ├── accounting_screen.dart
│       │       ├── rent_roll_screen.dart
│       │       ├── invoice_screen.dart
│       │       └── accounting_provider.dart
│       │
│       ├── maintenance/
│       │   ├── data/
│       │   ├── domain/        ← MaintenanceRequest, WorkOrder models
│       │   └── presentation/
│       │       ├── maintenance_list_screen.dart
│       │       ├── request_detail_screen.dart
│       │       └── maintenance_provider.dart
│       │
│       ├── listings/
│       │   ├── data/
│       │   ├── domain/        ← PublicListing model
│       │   └── presentation/
│       │       ├── listing_website_screen.dart
│       │       ├── listing_detail_screen.dart
│       │       └── listings_provider.dart
│       │
│       └── reports/
│           ├── data/
│           ├── domain/        ← ReportFilter, ReportData models
│           └── presentation/
│               ├── reports_screen.dart
│               ├── report_detail_screen.dart
│               └── reports_provider.dart
│
├── assets/
│   ├── images/
│   ├── icons/
│   └── fonts/
│       ├── DTLNobel-Light.ttf
│       └── DTLNobel-Bold.ttf
└── pubspec.yaml
```

---

## 4. Screen Designs

### 4.1 Layout Shell
- **Left sidebar** (240px expanded / 64px collapsed): Logo, nav items with icons, collapse toggle
- **Top bar** (64px): Global search, notifications bell, messages icon, user avatar + name
- **Content area**: Max-width 1400px, padding 24px, scrollable

### 4.2 Dashboard
```
┌─────────────────────────────────────────────────────────────┐
│  Today: Apr 15 · [progress ring 75%]  ·  Onboarding CTA    │
├──────────────────────┬──────────────────────────────────────┤
│  Tasks               │  Recently Viewed (horizontal scroll)  │
│  ┌──────────────┐    │  [Prop Card] [Prop Card] [Prop Card]  │
│  │ Task 1  ○ ○  │    │                                       │
│  │ Task 2  ○ ○  │    ├──────────────────────────────────────┤
│  │ Task 3  ○ ○  │    │  Accounting Summary                   │
│  └──────────────┘    │  [Bar Chart]  Revenue $16,920        │
│                      │               Expenses $4,884        │
└──────────────────────┴──────────────────────────────────────┘
```

### 4.3 Property Listings
- Grid / List toggle view
- Filter bar: status (Occupied/Vacant/All), property type, city
- Property card: photo, address, unit count, occupancy %, quick actions
- Detail view: unit table, lease summaries, financials tab

### 4.4 Rent & Accounting
- Rent roll table: tenant, unit, due date, amount, status badge
- Accounting ledger: date, description, debit/credit, balance
- Revenue vs Expenses bar chart (monthly)
- KPI tiles: Total Revenue, Total Expenses, Net Income, Outstanding

### 4.5 Tenant Screening
- Application queue table
- Screening result card: credit score, background check, eviction history
- Status flow: Pending → Screening → Approved / Denied

### 4.6 Maintenance Tracking
- Kanban-style: Open → In Progress → Completed
- Request card: property, unit, priority badge, assigned vendor, date
- Detail: photo uploads, vendor communication thread

### 4.7 Reports
- Report type selector: Financial, Occupancy, Rent Roll, Maintenance
- Date range picker
- Export buttons: PDF, CSV
- Chart + table view of results

---

## 5. Navigation Items

```
─────────────────
  [Logo]
─────────────────
  ⊞  Dashboard
  🏠  Properties
  👥  Tenants
  📋  Applications
  💰  Accounting
  🔧  Maintenance
  🌐  Listing Site
  📊  Reports
─────────────────
  ⚙️  Settings
  ❓  Help
```

---

## 6. Key Dependencies (pubspec.yaml)

```yaml
dependencies:
  flutter:
  go_router:           # Navigation
  provider:            # State management
  dio:                 # HTTP client
  flutter_secure_storage:  # Token storage
  cached_network_image:    # Image caching
  fl_chart:            # Charts (accounting, dashboard)
  intl:                # Date/currency formatting
  file_picker:         # Document uploads
  data_table_2:        # Advanced data tables
  shimmer:             # Loading skeletons
  
dev_dependencies:
  flutter_test:
  integration_test:
  mockito:
  build_runner:
  json_serializable:
```

---

## 7. State Management Pattern

Each feature follows this pattern:

```
Screen (Consumer) → FeatureProvider (ChangeNotifier) → Repository → ApiClient (Dio)
```

- `BaseProvider` holds `isLoading`, `errorMessage`, `notifyListeners()` helpers
- Providers registered in `main.dart` via `MultiProvider`
- No provider talks directly to `Dio` — always through repository

---

## 8. API Integration

Base URL configured per environment in `app_config.dart`:

```
DEV:   https://dev-api.boginenigroup.com
PROD:  https://api.boginenigroup.com
```

All requests include `Authorization: Bearer <token>` injected by `AuthInterceptor`.  
Errors mapped to `AppException` by `ErrorInterceptor` before reaching providers.
