-- ============================================================================
-- EKATAN Foundation Migration
-- Run in Supabase SQL Editor. Auth Hook is in public schema to avoid auth schema permission errors.
-- ============================================================================

-- 1. Enable PostGIS
CREATE EXTENSION IF NOT EXISTS postgis SCHEMA extensions;

-- 2. Roles table and seed data
CREATE TABLE IF NOT EXISTS public.roles (
    id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
    name text NOT NULL UNIQUE,
    description text
);

INSERT INTO public.roles (name, description) VALUES
    ('admin', 'System administrator with full access'),
    ('designer', 'Designer who creates quotes'),
    ('supervisor', 'Site supervisor for project management'),
    ('customer', 'End customer who requests quotes'),
    ('analyst', 'Analyst with read-only access to analytics')
ON CONFLICT (name) DO NOTHING;

-- 3. Permissions table
CREATE TABLE IF NOT EXISTS public.permissions (
    id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
    name text NOT NULL,
    resource text NOT NULL,
    action text NOT NULL
);

-- 4. Role permissions junction table
CREATE TABLE IF NOT EXISTS public.role_permissions (
    role_id uuid NOT NULL REFERENCES public.roles(id) ON DELETE CASCADE,
    permission_id uuid NOT NULL REFERENCES public.permissions(id) ON DELETE CASCADE,
    PRIMARY KEY (role_id, permission_id)
);

-- 5. Zones table
CREATE TABLE IF NOT EXISTS public.zones (
    id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
    name text NOT NULL,
    description text,
    is_active boolean DEFAULT true
);

-- 6. Zone boundaries with PostGIS (extensions schema)
CREATE TABLE IF NOT EXISTS public.zone_boundaries (
    id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
    zone_id uuid NOT NULL REFERENCES public.zones(id) ON DELETE CASCADE,
    boundary extensions.geography(POLYGON, 4326),
    radius_km numeric(6,2)
);

CREATE INDEX IF NOT EXISTS zone_boundaries_geo_idx ON public.zone_boundaries USING GIST (boundary);

-- 7. Profiles table
CREATE TABLE IF NOT EXISTS public.profiles (
    id uuid PRIMARY KEY REFERENCES auth.users(id) ON DELETE CASCADE,
    role_id uuid NOT NULL REFERENCES public.roles(id),
    zone_id uuid REFERENCES public.zones(id),
    full_name text,
    created_at timestamptz DEFAULT now(),
    updated_at timestamptz DEFAULT now()
);

-- 8. User roles junction table
CREATE TABLE IF NOT EXISTS public.user_roles (
    user_id uuid NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
    role_id uuid NOT NULL REFERENCES public.roles(id) ON DELETE CASCADE,
    PRIMARY KEY (user_id, role_id)
);

-- 9. Ingredient categories table
CREATE TABLE IF NOT EXISTS public.ingredient_categories (
    id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
    name text NOT NULL
);

-- 10. UOM table with self-reference
CREATE TABLE IF NOT EXISTS public.uom (
    id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
    code text NOT NULL UNIQUE,
    name text NOT NULL,
    base_uom_id uuid REFERENCES public.uom(id)
);

-- 11. UOM conversions table
CREATE TABLE IF NOT EXISTS public.uom_conversions (
    from_uom_id uuid NOT NULL REFERENCES public.uom(id),
    to_uom_id uuid NOT NULL REFERENCES public.uom(id),
    multiplier numeric(12,6) NOT NULL,
    PRIMARY KEY (from_uom_id, to_uom_id)
);

-- 12. Brands table
CREATE TABLE IF NOT EXISTS public.brands (
    id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
    name text NOT NULL,
    logo_url text,
    description text,
    is_active boolean DEFAULT true,
    created_at timestamptz DEFAULT now(),
    updated_at timestamptz DEFAULT now()
);

-- 13. Segmentations table
CREATE TABLE IF NOT EXISTS public.segmentations (
    id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
    name text NOT NULL,
    code text NOT NULL UNIQUE,
    description text,
    created_at timestamptz DEFAULT now()
);

-- 14. GST slabs table
CREATE TABLE IF NOT EXISTS public.gst_slabs (
    id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
    rate numeric(5,2) NOT NULL,
    hsn_code text,
    description text,
    effective_from date NOT NULL,
    effective_to date,
    created_at timestamptz DEFAULT now()
);

-- 15. Ingredients table
CREATE TABLE IF NOT EXISTS public.ingredients (
    id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
    name text NOT NULL,
    uom_id uuid NOT NULL REFERENCES public.uom(id),
    category_id uuid NOT NULL REFERENCES public.ingredient_categories(id),
    brand_id uuid REFERENCES public.brands(id),
    rate_per_unit numeric(14,4) NOT NULL,
    wastage_coefficient numeric(6,4) NOT NULL DEFAULT 1,
    gst_slab_id uuid NOT NULL REFERENCES public.gst_slabs(id),
    segmentation_id uuid REFERENCES public.segmentations(id),
    is_active boolean DEFAULT true,
    created_at timestamptz DEFAULT now(),
    updated_at timestamptz DEFAULT now()
);

-- 16. Recipes table
CREATE TABLE IF NOT EXISTS public.recipes (
    id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
    name text NOT NULL,
    description text,
    output_uom_id uuid NOT NULL REFERENCES public.uom(id),
    output_quantity_per_unit numeric(12,6) NOT NULL,
    created_at timestamptz DEFAULT now(),
    updated_at timestamptz DEFAULT now()
);

-- 17. Recipe ingredients table
CREATE TABLE IF NOT EXISTS public.recipe_ingredients (
    id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
    recipe_id uuid NOT NULL REFERENCES public.recipes(id) ON DELETE CASCADE,
    ingredient_id uuid NOT NULL REFERENCES public.ingredients(id),
    quantity_per_output numeric(12,6) NOT NULL,
    wastage_override numeric(6,4)
);

-- 18. Systems table
CREATE TABLE IF NOT EXISTS public.systems (
    id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
    name text NOT NULL,
    description text,
    brand_id uuid REFERENCES public.brands(id),
    segmentation_id uuid REFERENCES public.segmentations(id),
    base_width_mm numeric(10,2),
    base_depth_mm numeric(10,2),
    base_height_mm numeric(10,2),
    created_at timestamptz DEFAULT now(),
    updated_at timestamptz DEFAULT now()
);

-- 19. System recipes table
CREATE TABLE IF NOT EXISTS public.system_recipes (
    id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
    system_id uuid NOT NULL REFERENCES public.systems(id) ON DELETE CASCADE,
    recipe_id uuid NOT NULL REFERENCES public.recipes(id),
    quantity numeric(12,6) NOT NULL,
    applies_to text
);

-- 20. System hardware table
CREATE TABLE IF NOT EXISTS public.system_hardware (
    id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
    system_id uuid NOT NULL REFERENCES public.systems(id) ON DELETE CASCADE,
    ingredient_id uuid NOT NULL REFERENCES public.ingredients(id),
    quantity_per_unit numeric(12,6) NOT NULL
);

-- 21. Designs table
CREATE TABLE IF NOT EXISTS public.designs (
    id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
    name text NOT NULL,
    slug text NOT NULL UNIQUE,
    description text,
    brand_id uuid REFERENCES public.brands(id),
    segmentation_id uuid REFERENCES public.segmentations(id),
    is_active boolean DEFAULT true,
    created_at timestamptz DEFAULT now(),
    updated_at timestamptz DEFAULT now()
);

-- 22. Design systems table
CREATE TABLE IF NOT EXISTS public.design_systems (
    id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
    design_id uuid NOT NULL REFERENCES public.designs(id) ON DELETE CASCADE,
    system_id uuid NOT NULL REFERENCES public.systems(id),
    dimension_formula jsonb
);

-- 23. Design params table
CREATE TABLE IF NOT EXISTS public.design_params (
    id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
    design_id uuid NOT NULL REFERENCES public.designs(id) ON DELETE CASCADE,
    param_name text NOT NULL,
    param_type text NOT NULL,
    default_value numeric(12,4),
    min numeric(12,4),
    max numeric(12,4)
);

-- 24. Media table
CREATE TABLE IF NOT EXISTS public.media (
    id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
    entity_type text NOT NULL,
    entity_id uuid NOT NULL,
    url text NOT NULL,
    alt_text text,
    sort_order int DEFAULT 0,
    created_at timestamptz DEFAULT now()
);

-- 25. Variation types table
CREATE TABLE IF NOT EXISTS public.variation_types (
    id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
    name text NOT NULL,
    code text NOT NULL UNIQUE
);

-- 26. Variation options table
CREATE TABLE IF NOT EXISTS public.variation_options (
    id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
    variation_type_id uuid NOT NULL REFERENCES public.variation_types(id) ON DELETE CASCADE,
    name text NOT NULL,
    code text NOT NULL
);

-- 27. Design variations table
CREATE TABLE IF NOT EXISTS public.design_variations (
    id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
    design_id uuid NOT NULL REFERENCES public.designs(id) ON DELETE CASCADE,
    variation_option_id uuid NOT NULL REFERENCES public.variation_options(id) ON DELETE CASCADE,
    cost_delta numeric(14,4) NOT NULL,
    is_default boolean DEFAULT false
);

-- 28. Projects table
CREATE TABLE IF NOT EXISTS public.projects (
    id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
    customer_id uuid NOT NULL REFERENCES auth.users(id),
    zone_id uuid REFERENCES public.zones(id),
    status text NOT NULL,
    created_at timestamptz DEFAULT now(),
    updated_at timestamptz DEFAULT now()
);

-- 29. Quotes table
CREATE TABLE IF NOT EXISTS public.quotes (
    id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
    project_id uuid NOT NULL REFERENCES public.projects(id) ON DELETE CASCADE,
    designer_id uuid REFERENCES auth.users(id),
    total_cost numeric(14,4),
    status text NOT NULL,
    created_at timestamptz DEFAULT now(),
    updated_at timestamptz DEFAULT now()
);

-- 30. Quote items table
CREATE TABLE IF NOT EXISTS public.quote_items (
    id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
    quote_id uuid NOT NULL REFERENCES public.quotes(id) ON DELETE CASCADE,
    design_id uuid NOT NULL REFERENCES public.designs(id),
    params jsonb,
    variation_option_ids jsonb,
    quantity numeric(12,4) NOT NULL,
    unit_cost numeric(14,4),
    total_cost numeric(14,4),
    created_at timestamptz DEFAULT now()
);

-- 31. Snags table
CREATE TABLE IF NOT EXISTS public.snags (
    id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
    project_id uuid NOT NULL REFERENCES public.projects(id) ON DELETE CASCADE,
    description text NOT NULL,
    status text NOT NULL,
    location text,
    reported_by uuid REFERENCES auth.users(id),
    created_at timestamptz DEFAULT now(),
    updated_at timestamptz DEFAULT now()
);

-- 32. Trigger function: handle_new_user() in public schema
CREATE OR REPLACE FUNCTION public.handle_new_user()
RETURNS TRIGGER
SECURITY DEFINER
SET search_path = public
LANGUAGE plpgsql
AS $$
DECLARE
    customer_role_id uuid;
BEGIN
    SELECT id INTO customer_role_id FROM public.roles WHERE name = 'customer' LIMIT 1;

    INSERT INTO public.profiles (id, role_id)
    VALUES (NEW.id, customer_role_id);

    RETURN NEW;
END;
$$;

-- 33. Trigger: on_auth_user_created (runs in DB context that can attach to auth.users)
DROP TRIGGER IF EXISTS on_auth_user_created ON auth.users;
CREATE TRIGGER on_auth_user_created
    AFTER INSERT ON auth.users
    FOR EACH ROW
    EXECUTE FUNCTION public.handle_new_user();

-- 34. Custom Access Token Hook in PUBLIC schema (avoids "permission denied for schema auth")
-- Then in Dashboard: Authentication → Hooks → Customize Access Token → set to public.custom_access_token_hook
CREATE OR REPLACE FUNCTION public.custom_access_token_hook(event jsonb)
RETURNS jsonb
SECURITY DEFINER
SET search_path = public
LANGUAGE plpgsql
AS $$
DECLARE
    user_role_name text;
    user_id_claim text;
BEGIN
    user_id_claim := coalesce(event->>'user_id', event->'payload'->>'sub', event->'user'->>'id');
    IF user_id_claim IS NULL THEN
        RETURN event;
    END IF;

    SELECT r.name INTO user_role_name
    FROM public.profiles p
    JOIN public.roles r ON p.role_id = r.id
    WHERE p.id = user_id_claim::uuid
    LIMIT 1;

    IF user_role_name IS NOT NULL THEN
        event := jsonb_set(
            coalesce(event, '{}'::jsonb),
            '{claims,role}',
            to_jsonb(user_role_name::text),
            true
        );
    END IF;

    RETURN event;
END;
$$;

GRANT USAGE ON SCHEMA public TO supabase_auth_admin;
GRANT EXECUTE ON FUNCTION public.custom_access_token_hook(jsonb) TO supabase_auth_admin;

-- 35. Enable RLS on all public tables
ALTER TABLE public.roles ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.permissions ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.role_permissions ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.zones ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.zone_boundaries ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.profiles ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.user_roles ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.ingredient_categories ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.uom ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.uom_conversions ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.brands ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.segmentations ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.gst_slabs ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.ingredients ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.recipes ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.recipe_ingredients ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.systems ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.system_recipes ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.system_hardware ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.designs ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.design_systems ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.design_params ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.media ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.variation_types ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.variation_options ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.design_variations ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.projects ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.quotes ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.quote_items ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.snags ENABLE ROW LEVEL SECURITY;

-- 36. RLS Policies

-- Profiles: authenticated users select and update own row only
CREATE POLICY "profiles_select_own" ON public.profiles
    FOR SELECT
    USING (auth.uid() = id);

CREATE POLICY "profiles_update_own" ON public.profiles
    FOR UPDATE
    USING (auth.uid() = id);

-- Roles and permissions: allow read for authenticated (for role checks)
CREATE POLICY "roles_select_authenticated" ON public.roles
    FOR SELECT
    USING (auth.role() = 'authenticated');

CREATE POLICY "permissions_select_authenticated" ON public.permissions
    FOR SELECT
    USING (auth.role() = 'authenticated');

CREATE POLICY "role_permissions_select_authenticated" ON public.role_permissions
    FOR SELECT
    USING (auth.role() = 'authenticated');

-- Catalog tables: authenticated select; admin only insert/update/delete
CREATE POLICY "brands_select_authenticated" ON public.brands
    FOR SELECT
    USING (auth.role() = 'authenticated');

CREATE POLICY "brands_modify_admin" ON public.brands
    FOR ALL
    USING (
        EXISTS (
            SELECT 1 FROM public.profiles p
            JOIN public.roles r ON p.role_id = r.id
            WHERE p.id = auth.uid() AND r.name = 'admin'
        )
    );

CREATE POLICY "segmentations_select_authenticated" ON public.segmentations
    FOR SELECT
    USING (auth.role() = 'authenticated');

CREATE POLICY "segmentations_modify_admin" ON public.segmentations
    FOR ALL
    USING (
        EXISTS (
            SELECT 1 FROM public.profiles p
            JOIN public.roles r ON p.role_id = r.id
            WHERE p.id = auth.uid() AND r.name = 'admin'
        )
    );

CREATE POLICY "gst_slabs_select_authenticated" ON public.gst_slabs
    FOR SELECT
    USING (auth.role() = 'authenticated');

CREATE POLICY "gst_slabs_modify_admin" ON public.gst_slabs
    FOR ALL
    USING (
        EXISTS (
            SELECT 1 FROM public.profiles p
            JOIN public.roles r ON p.role_id = r.id
            WHERE p.id = auth.uid() AND r.name = 'admin'
        )
    );

CREATE POLICY "uom_select_authenticated" ON public.uom
    FOR SELECT
    USING (auth.role() = 'authenticated');

CREATE POLICY "uom_modify_admin" ON public.uom
    FOR ALL
    USING (
        EXISTS (
            SELECT 1 FROM public.profiles p
            JOIN public.roles r ON p.role_id = r.id
            WHERE p.id = auth.uid() AND r.name = 'admin'
        )
    );

CREATE POLICY "uom_conversions_select_authenticated" ON public.uom_conversions
    FOR SELECT
    USING (auth.role() = 'authenticated');

CREATE POLICY "uom_conversions_modify_admin" ON public.uom_conversions
    FOR ALL
    USING (
        EXISTS (
            SELECT 1 FROM public.profiles p
            JOIN public.roles r ON p.role_id = r.id
            WHERE p.id = auth.uid() AND r.name = 'admin'
        )
    );

CREATE POLICY "ingredient_categories_select_authenticated" ON public.ingredient_categories
    FOR SELECT
    USING (auth.role() = 'authenticated');

CREATE POLICY "ingredient_categories_modify_admin" ON public.ingredient_categories
    FOR ALL
    USING (
        EXISTS (
            SELECT 1 FROM public.profiles p
            JOIN public.roles r ON p.role_id = r.id
            WHERE p.id = auth.uid() AND r.name = 'admin'
        )
    );

CREATE POLICY "ingredients_select_authenticated" ON public.ingredients
    FOR SELECT
    USING (auth.role() = 'authenticated');

CREATE POLICY "ingredients_modify_admin" ON public.ingredients
    FOR ALL
    USING (
        EXISTS (
            SELECT 1 FROM public.profiles p
            JOIN public.roles r ON p.role_id = r.id
            WHERE p.id = auth.uid() AND r.name = 'admin'
        )
    );

CREATE POLICY "recipes_select_authenticated" ON public.recipes
    FOR SELECT
    USING (auth.role() = 'authenticated');

CREATE POLICY "recipes_modify_admin" ON public.recipes
    FOR ALL
    USING (
        EXISTS (
            SELECT 1 FROM public.profiles p
            JOIN public.roles r ON p.role_id = r.id
            WHERE p.id = auth.uid() AND r.name = 'admin'
        )
    );

CREATE POLICY "recipe_ingredients_select_authenticated" ON public.recipe_ingredients
    FOR SELECT
    USING (auth.role() = 'authenticated');

CREATE POLICY "recipe_ingredients_modify_admin" ON public.recipe_ingredients
    FOR ALL
    USING (
        EXISTS (
            SELECT 1 FROM public.profiles p
            JOIN public.roles r ON p.role_id = r.id
            WHERE p.id = auth.uid() AND r.name = 'admin'
        )
    );

CREATE POLICY "systems_select_authenticated" ON public.systems
    FOR SELECT
    USING (auth.role() = 'authenticated');

CREATE POLICY "systems_modify_admin" ON public.systems
    FOR ALL
    USING (
        EXISTS (
            SELECT 1 FROM public.profiles p
            JOIN public.roles r ON p.role_id = r.id
            WHERE p.id = auth.uid() AND r.name = 'admin'
        )
    );

CREATE POLICY "system_recipes_select_authenticated" ON public.system_recipes
    FOR SELECT
    USING (auth.role() = 'authenticated');

CREATE POLICY "system_recipes_modify_admin" ON public.system_recipes
    FOR ALL
    USING (
        EXISTS (
            SELECT 1 FROM public.profiles p
            JOIN public.roles r ON p.role_id = r.id
            WHERE p.id = auth.uid() AND r.name = 'admin'
        )
    );

CREATE POLICY "system_hardware_select_authenticated" ON public.system_hardware
    FOR SELECT
    USING (auth.role() = 'authenticated');

CREATE POLICY "system_hardware_modify_admin" ON public.system_hardware
    FOR ALL
    USING (
        EXISTS (
            SELECT 1 FROM public.profiles p
            JOIN public.roles r ON p.role_id = r.id
            WHERE p.id = auth.uid() AND r.name = 'admin'
        )
    );

CREATE POLICY "designs_select_authenticated" ON public.designs
    FOR SELECT
    USING (auth.role() = 'authenticated');

CREATE POLICY "designs_modify_admin" ON public.designs
    FOR ALL
    USING (
        EXISTS (
            SELECT 1 FROM public.profiles p
            JOIN public.roles r ON p.role_id = r.id
            WHERE p.id = auth.uid() AND r.name = 'admin'
        )
    );

CREATE POLICY "design_systems_select_authenticated" ON public.design_systems
    FOR SELECT
    USING (auth.role() = 'authenticated');

CREATE POLICY "design_systems_modify_admin" ON public.design_systems
    FOR ALL
    USING (
        EXISTS (
            SELECT 1 FROM public.profiles p
            JOIN public.roles r ON p.role_id = r.id
            WHERE p.id = auth.uid() AND r.name = 'admin'
        )
    );

CREATE POLICY "design_params_select_authenticated" ON public.design_params
    FOR SELECT
    USING (auth.role() = 'authenticated');

CREATE POLICY "design_params_modify_admin" ON public.design_params
    FOR ALL
    USING (
        EXISTS (
            SELECT 1 FROM public.profiles p
            JOIN public.roles r ON p.role_id = r.id
            WHERE p.id = auth.uid() AND r.name = 'admin'
        )
    );

CREATE POLICY "variation_types_select_authenticated" ON public.variation_types
    FOR SELECT
    USING (auth.role() = 'authenticated');

CREATE POLICY "variation_types_modify_admin" ON public.variation_types
    FOR ALL
    USING (
        EXISTS (
            SELECT 1 FROM public.profiles p
            JOIN public.roles r ON p.role_id = r.id
            WHERE p.id = auth.uid() AND r.name = 'admin'
        )
    );

CREATE POLICY "variation_options_select_authenticated" ON public.variation_options
    FOR SELECT
    USING (auth.role() = 'authenticated');

CREATE POLICY "variation_options_modify_admin" ON public.variation_options
    FOR ALL
    USING (
        EXISTS (
            SELECT 1 FROM public.profiles p
            JOIN public.roles r ON p.role_id = r.id
            WHERE p.id = auth.uid() AND r.name = 'admin'
        )
    );

CREATE POLICY "design_variations_select_authenticated" ON public.design_variations
    FOR SELECT
    USING (auth.role() = 'authenticated');

CREATE POLICY "design_variations_modify_admin" ON public.design_variations
    FOR ALL
    USING (
        EXISTS (
            SELECT 1 FROM public.profiles p
            JOIN public.roles r ON p.role_id = r.id
            WHERE p.id = auth.uid() AND r.name = 'admin'
        )
    );

CREATE POLICY "media_select_authenticated" ON public.media
    FOR SELECT
    USING (auth.role() = 'authenticated');

CREATE POLICY "media_modify_admin" ON public.media
    FOR ALL
    USING (
        EXISTS (
            SELECT 1 FROM public.profiles p
            JOIN public.roles r ON p.role_id = r.id
            WHERE p.id = auth.uid() AND r.name = 'admin'
        )
    );

CREATE POLICY "zones_select_authenticated" ON public.zones
    FOR SELECT
    USING (auth.role() = 'authenticated');

CREATE POLICY "zones_modify_admin" ON public.zones
    FOR ALL
    USING (
        EXISTS (
            SELECT 1 FROM public.profiles p
            JOIN public.roles r ON p.role_id = r.id
            WHERE p.id = auth.uid() AND r.name = 'admin'
        )
    );

CREATE POLICY "zone_boundaries_select_authenticated" ON public.zone_boundaries
    FOR SELECT
    USING (auth.role() = 'authenticated');

CREATE POLICY "zone_boundaries_modify_admin" ON public.zone_boundaries
    FOR ALL
    USING (
        EXISTS (
            SELECT 1 FROM public.profiles p
            JOIN public.roles r ON p.role_id = r.id
            WHERE p.id = auth.uid() AND r.name = 'admin'
        )
    );

-- Projects: customer own rows; admin and designer select all
CREATE POLICY "projects_select_own" ON public.projects
    FOR SELECT
    USING (
        customer_id = auth.uid() OR
        EXISTS (
            SELECT 1 FROM public.profiles p
            JOIN public.roles r ON p.role_id = r.id
            WHERE p.id = auth.uid() AND r.name IN ('admin', 'designer')
        )
    );

CREATE POLICY "projects_insert_own" ON public.projects
    FOR INSERT
    WITH CHECK (customer_id = auth.uid());

CREATE POLICY "projects_update_own" ON public.projects
    FOR UPDATE
    USING (customer_id = auth.uid());

-- Quotes
CREATE POLICY "quotes_select_own_or_admin_designer" ON public.quotes
    FOR SELECT
    USING (
        EXISTS (
            SELECT 1 FROM public.projects pr
            WHERE pr.id = quotes.project_id AND pr.customer_id = auth.uid()
        ) OR
        EXISTS (
            SELECT 1 FROM public.profiles p
            JOIN public.roles r ON p.role_id = r.id
            WHERE p.id = auth.uid() AND r.name IN ('admin', 'designer')
        )
    );

CREATE POLICY "quotes_insert_own" ON public.quotes
    FOR INSERT
    WITH CHECK (
        EXISTS (
            SELECT 1 FROM public.projects pr
            WHERE pr.id = project_id AND pr.customer_id = auth.uid()
        )
    );

CREATE POLICY "quotes_update_own" ON public.quotes
    FOR UPDATE
    USING (
        EXISTS (
            SELECT 1 FROM public.projects pr
            WHERE pr.id = quotes.project_id AND pr.customer_id = auth.uid()
        )
    );

-- Quote items
CREATE POLICY "quote_items_select_own_or_admin_designer" ON public.quote_items
    FOR SELECT
    USING (
        EXISTS (
            SELECT 1 FROM public.quotes q
            JOIN public.projects pr ON q.project_id = pr.id
            WHERE q.id = quote_items.quote_id AND pr.customer_id = auth.uid()
        ) OR
        EXISTS (
            SELECT 1 FROM public.profiles p
            JOIN public.roles r ON p.role_id = r.id
            WHERE p.id = auth.uid() AND r.name IN ('admin', 'designer')
        )
    );

CREATE POLICY "quote_items_insert_own" ON public.quote_items
    FOR INSERT
    WITH CHECK (
        EXISTS (
            SELECT 1 FROM public.quotes q
            JOIN public.projects pr ON q.project_id = pr.id
            WHERE q.id = quote_id AND pr.customer_id = auth.uid()
        )
    );

CREATE POLICY "quote_items_update_own" ON public.quote_items
    FOR UPDATE
    USING (
        EXISTS (
            SELECT 1 FROM public.quotes q
            JOIN public.projects pr ON q.project_id = pr.id
            WHERE q.id = quote_items.quote_id AND pr.customer_id = auth.uid()
        )
    );

-- Snags: supervisor and admin select/insert/update
CREATE POLICY "snags_select_supervisor_admin" ON public.snags
    FOR SELECT
    USING (
        EXISTS (
            SELECT 1 FROM public.profiles p
            JOIN public.roles r ON p.role_id = r.id
            WHERE p.id = auth.uid() AND r.name IN ('supervisor', 'admin')
        )
    );

CREATE POLICY "snags_insert_supervisor_admin" ON public.snags
    FOR INSERT
    WITH CHECK (
        EXISTS (
            SELECT 1 FROM public.profiles p
            JOIN public.roles r ON p.role_id = r.id
            WHERE p.id = auth.uid() AND r.name IN ('supervisor', 'admin')
        )
    );

CREATE POLICY "snags_update_supervisor_admin" ON public.snags
    FOR UPDATE
    USING (
        EXISTS (
            SELECT 1 FROM public.profiles p
            JOIN public.roles r ON p.role_id = r.id
            WHERE p.id = auth.uid() AND r.name IN ('supervisor', 'admin')
        )
    );
```
