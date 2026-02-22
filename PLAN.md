# EKATAN — Phase 1 Development Roadmap

This document outlines the strict, step-by-step development roadmap for Phase 1. Each step must be completed before the next begins. Features are developed as self-contained modules under `src/features/`.

**Refactoring guideline:** At each step, enforce module boundaries — features import only from `core/` and `shared/`. Document any new feature in `src/features/{name}/README.md` with its public API (Server Actions, components). This keeps the path clear for future extraction into packages or services.

---

## Step 1: Initialize Next.js & Supabase

**Goal:** Bootstrap the project with the correct stack and modular folder structure.

**Deliverables:**

1. **Create Next.js app**
   - Run: `npx create-next-app@latest ekatan --typescript --tailwind --eslint --app --src-dir --import-alias "@/*"`
   - Ensure: TypeScript, Tailwind, App Router, `src/` directory are selected.

2. **Create Supabase project**
   - Sign up / log in at [supabase.com](https://supabase.com); create a new project.
   - Note: Project URL, anon (public) key, and service role key.

3. **Environment**
   - In project root (e.g. `ekatan`), create `.env.local` with:
     - `NEXT_PUBLIC_SUPABASE_URL`
     - `NEXT_PUBLIC_SUPABASE_ANON_KEY`
     - `SUPABASE_SERVICE_ROLE_KEY` (server-only; never expose to client)

4. **Optional: Supabase CLI**
   - Run `supabase init` in project root if you will manage migrations via CLI.

5. **Modular folder structure**
   - Under `src/`, create:
     - `src/core/` (subdirs: `auth/`, `db/`, `config/`)
     - `src/shared/` (subdirs: `components/`, `lib/`, `types/`)
     - `src/features/` (empty initially; feature modules added in later steps)

**Dependencies:** None.

---

## Step 2: Route Groups, RBAC & Security

**Goal:** Six isolated portals with role-gated access and secure Server Actions.

**Deliverables:**

1. **Route groups**
   - Under `src/app/`, create:
     - `(public)/` — layout + page for marketing; `/` resolves here.
     - `(customer)/` — layout + placeholder page; prefix routes e.g. `/cart`, `/quote`.
     - `(admin)/` — layout + placeholder page; prefix `/admin`.
     - `(designer)/` — layout + placeholder page; prefix `/designer`.
     - `(supervisor)/` — layout + placeholder page; prefix `/supervisor`.
     - `(analytics)/` — layout + placeholder page; prefix `/analytics`.
   - Each group has its own `layout.tsx` that performs role checks and redirects unauthorized users.

2. **Supabase Auth**
   - Configure email/password auth in Supabase Dashboard.
   - Implement auth callback route (e.g. `src/app/auth/callback/route.ts`).
   - Use Supabase Auth Hook (or equivalent) to inject role into JWT custom claims from `profiles.role_id` (or `user_roles`).

3. **Middleware**
   - Add middleware (e.g. `src/middleware.ts`) to protect routes by role and redirect to login or forbidden.

4. **Database: profiles & RBAC**
   - Create tables: `roles`, `permissions`, `role_permissions`, `profiles`, and optionally `user_roles` (see `db_schema.md`).
   - Enable RLS on these tables; attach policies based on `auth.uid()` and role claims.
   - Trigger: on `auth.users` insert, create corresponding `profiles` row with default role.

5. **Security**
   - Add Zod (or similar) for Server Action input validation; reject invalid payloads.
   - Configure secure headers in `next.config` (e.g. Content-Security-Policy, X-Frame-Options).
   - Ensure `SUPABASE_SERVICE_ROLE_KEY` is used only in server context (Server Actions, server components).

**Dependencies:** Step 1 complete; Supabase project and env vars in place.

---

## Step 3: Admin — Dynamic Masters & L1–L2

**Goal:** Admin panel to manage all dynamic master data and L1–L2 cost engine entities.

**Deliverables:**

1. **Admin layout and navigation**
   - Persistent admin layout with sidebar or nav for: Brands, Segmentations, GST Slabs, UOM, Ingredients, Recipes, Zones.

2. **CRUD for dynamic masters**
   - **Brands:** list, create, edit, soft-deactivate; optional logo upload.
   - **Segmentations:** list, create, edit (name, code, description).
   - **GST slabs:** list, create, edit (rate, hsn_code, effective_from, effective_to).
   - **UOM:** list, create, edit; **UOM conversions:** manage from_uom, to_uom, multiplier.

3. **CRUD for L1 (Ingredients)**
   - List, create, edit ingredients with: name, uom_id, category_id, brand_id, rate_per_unit, wastage_coefficient, gst_slab_id, segmentation_id, is_active.
   - Ingredient categories: seed or manage via admin (Raw Material, Labor, Hardware, etc.).

4. **CRUD for L2 (Recipes)**
   - List, create, edit recipes (name, description, output_uom_id, output_quantity_per_unit).
   - **Recipe ingredients:** for each recipe, add/remove rows (ingredient_id, quantity_per_output, wastage_override optional).

5. **Zone management**
   - List, create, edit zones; optionally define zone boundaries (PostGIS) if required in Phase 1.

6. **Media upload**
   - Use Supabase Storage for images; store URLs in `media` table.
   - Support entity_type + entity_id for design, ingredient, system, brand.
   - Enforce RLS on storage bucket so only allowed roles (e.g. admin) can upload.

**Dependencies:** Step 2 complete; schema for brands, segmentations, gst_slabs, uom, ingredient_categories, ingredients, recipes, recipe_ingredients, zones, media applied (see `db_schema.md`).

---

## Step 4: Cost Engine (Feature Module)

**Goal:** Self-contained cost engine feature that computes cost from L4 down to L1 with dynamic GST and variations.

**Deliverables:**

1. **Feature structure**
   - Create `src/features/cost-engine/` with subdirs: `actions/`, `components/` (if any), `types/`, `utils/`.
   - Add `src/features/cost-engine/README.md` documenting the public API (Server Action names, inputs, outputs).

2. **Server Actions**
   - `calculateRecipeCost(recipeId)`: resolve recipe_ingredients, fetch ingredients (rate, wastage, gst_slab), compute cost per output unit.
   - `calculateSystemCost(systemId, dims)`: resolve system_recipes and system_hardware; compute recipe costs and scale by dimensions where applicable; add hardware cost.
   - `calculateDesignCost(designId, params, quantity, variationOptionIds?)`: resolve design_systems and design_params; compute system cost with parametric dimensions; add variation cost_delta for selected options; multiply by quantity.
   - Resolve GST from `gst_slabs` by effective date (e.g. today between effective_from and effective_to).

3. **Recursive resolution**
   - L4 → design_systems → systems; L3 → system_recipes → recipes; L2 → recipe_ingredients → ingredients (L1). No cross-feature imports; use only `core/` and `shared/`.

4. **Unit tests**
   - Add tests for edge cases: missing ingredient, zero quantity, invalid dimensions, multiple variations, GST slab boundaries.

**Dependencies:** Step 3 complete; L1 and L2 data and schema for L3/L4 (systems, system_recipes, system_hardware, designs, design_systems, design_params, design_variations, variation_types, variation_options) applied.

---

## Step 5: Customer Visual Cart

**Goal:** Customer-facing portal to browse designs, configure parameters and variations, and request quotes.

**Deliverables:**

1. **Feature structure**
   - Create or extend `src/features/quotes/` with actions and components for cart and quote request.
   - Customer portal layout under `app/(customer)/` with clear navigation (e.g. Browse, Cart, My Quotes).

2. **Design browser**
   - List designs with filters: brand, segmentation, search by name/slug.
   - Display design images from `media` table (Supabase Storage URLs).

3. **Parametric configurator**
   - For a selected design, load design_params and dimension_formula; render inputs (W×D×H or as defined).
   - Validate min/max from design_params; call cost-engine `calculateDesignCost` for live preview.

4. **Variation selector**
   - Load variation_types and variation_options for the design; display design_variations (options + cost_delta).
   - Allow customer to select one option per type (or as per business rules); include selected variation_option_ids in cost and in quote_items.

5. **Add to cart**
   - Cart state (client or server session); store design_id, params, variation_option_ids, quantity, unit_cost, total_cost.
   - Persist to `quote_items` when user submits quote request (linked to project/quote).

6. **Quote request flow**
   - Customer creates or selects project; submits cart as quote request (creates quote + quote_items with status e.g. pending).
   - Show confirmation and link to "My Quotes" or project view.

**Dependencies:** Step 4 complete; designs, design_systems, design_params, design_variations, media populated; projects and quotes tables and RLS in place.

---

## Post–Phase 1

- **Schema approval:** After reviewing `db_schema.md`, confirm any changes to the database schema before implementing migrations.
- **Initialization command (reference):** From project root (e.g. parent of `ekatan`):
  ```powershell
  npx create-next-app@latest ekatan --typescript --tailwind --eslint --app --src-dir --import-alias "@/*"
  ```
  Then `cd ekatan`, create `.env.local` with Supabase credentials, and run Supabase migrations (via Dashboard SQL editor or `supabase db push`) as per `db_schema.md`.
