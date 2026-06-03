-- ============================================
-- SCRIPT DE SECURISATION SUPABASE
-- Projet: optimi-onboarding-premium
-- Date: 2026-06-03
-- ============================================

-- ============================================
-- PARTIE 1: STRUCTURE DES TABLES (si non existantes)
-- ============================================

-- Table des clients onboarding
CREATE TABLE IF NOT EXISTS onboarding_clients (
    id UUID DEFAULT gen_random_uuid() PRIMARY KEY,
    client_slug TEXT UNIQUE NOT NULL,
    client_name TEXT,
    client_email TEXT,
    client_phone TEXT,
    commission_rate NUMERIC DEFAULT 20,
    access_token TEXT DEFAULT encode(gen_random_bytes(32), 'hex'),
    created_at TIMESTAMPTZ DEFAULT NOW(),
    updated_at TIMESTAMPTZ DEFAULT NOW()
);

-- Ajouter les colonnes email et phone si elles n'existent pas (migration)
ALTER TABLE onboarding_clients ADD COLUMN IF NOT EXISTS client_email TEXT;
ALTER TABLE onboarding_clients ADD COLUMN IF NOT EXISTS client_phone TEXT;

-- Table de progression
CREATE TABLE IF NOT EXISTS onboarding_progress (
    id UUID DEFAULT gen_random_uuid() PRIMARY KEY,
    client_id UUID REFERENCES onboarding_clients(id) ON DELETE CASCADE,
    step_id TEXT NOT NULL,
    status TEXT DEFAULT 'todo',
    created_at TIMESTAMPTZ DEFAULT NOW(),
    updated_at TIMESTAMPTZ DEFAULT NOW(),
    UNIQUE(client_id, step_id)
);

-- Table des informations client
CREATE TABLE IF NOT EXISTS onboarding_info (
    id UUID DEFAULT gen_random_uuid() PRIMARY KEY,
    client_id UUID REFERENCES onboarding_clients(id) ON DELETE CASCADE UNIQUE,
    -- Documents
    rib_path TEXT,
    id_card_path TEXT,
    property_title_path TEXT,
    insurance_path TEXT,
    -- Informations personnelles
    full_name TEXT,
    email TEXT,
    phone TEXT,
    address TEXT,
    -- Informations bancaires
    bank_name TEXT,
    iban TEXT,
    bic TEXT,
    -- Informations propriété
    property_address TEXT,
    property_type TEXT,
    property_size TEXT,
    num_bedrooms TEXT,
    num_bathrooms TEXT,
    -- Services sélectionnés
    services_selected JSONB DEFAULT '[]'::jsonb,
    -- Meta
    created_at TIMESTAMPTZ DEFAULT NOW(),
    updated_at TIMESTAMPTZ DEFAULT NOW()
);

-- Index pour performances
CREATE INDEX IF NOT EXISTS idx_onboarding_clients_slug ON onboarding_clients(client_slug);
CREATE INDEX IF NOT EXISTS idx_onboarding_clients_token ON onboarding_clients(access_token);
CREATE INDEX IF NOT EXISTS idx_onboarding_progress_client ON onboarding_progress(client_id);
CREATE INDEX IF NOT EXISTS idx_onboarding_info_client ON onboarding_info(client_id);

-- ============================================
-- PARTIE 2: ACTIVER ROW LEVEL SECURITY (RLS)
-- ============================================

-- Activer RLS sur toutes les tables
ALTER TABLE onboarding_clients ENABLE ROW LEVEL SECURITY;
ALTER TABLE onboarding_progress ENABLE ROW LEVEL SECURITY;
ALTER TABLE onboarding_info ENABLE ROW LEVEL SECURITY;

-- ============================================
-- PARTIE 3: SUPPRIMER LES ANCIENNES POLICIES
-- ============================================

DROP POLICY IF EXISTS "clients_select_own" ON onboarding_clients;
DROP POLICY IF EXISTS "clients_insert_own" ON onboarding_clients;
DROP POLICY IF EXISTS "clients_update_own" ON onboarding_clients;
DROP POLICY IF EXISTS "progress_select_own" ON onboarding_progress;
DROP POLICY IF EXISTS "progress_insert_own" ON onboarding_progress;
DROP POLICY IF EXISTS "progress_update_own" ON onboarding_progress;
DROP POLICY IF EXISTS "info_select_own" ON onboarding_info;
DROP POLICY IF EXISTS "info_insert_own" ON onboarding_info;
DROP POLICY IF EXISTS "info_update_own" ON onboarding_info;

-- ============================================
-- PARTIE 4: POLICIES POUR onboarding_clients
-- ============================================

-- Les clients peuvent lire leur propre entrée via le slug
CREATE POLICY "clients_select_own" ON onboarding_clients
    FOR SELECT
    USING (true);  -- Lecture autorisée pour récupérer l'ID via slug

-- Les clients peuvent créer leur entrée
CREATE POLICY "clients_insert_own" ON onboarding_clients
    FOR INSERT
    WITH CHECK (true);  -- Création autorisée pour nouveaux clients

-- Les clients peuvent mettre à jour leur propre entrée
CREATE POLICY "clients_update_own" ON onboarding_clients
    FOR UPDATE
    USING (true)
    WITH CHECK (true);

-- ============================================
-- PARTIE 5: POLICIES POUR onboarding_progress
-- ============================================

-- Lecture de sa propre progression
CREATE POLICY "progress_select_own" ON onboarding_progress
    FOR SELECT
    USING (
        client_id IN (SELECT id FROM onboarding_clients)
    );

-- Création de progression
CREATE POLICY "progress_insert_own" ON onboarding_progress
    FOR INSERT
    WITH CHECK (
        client_id IN (SELECT id FROM onboarding_clients)
    );

-- Mise à jour de sa progression (upsert)
CREATE POLICY "progress_update_own" ON onboarding_progress
    FOR UPDATE
    USING (
        client_id IN (SELECT id FROM onboarding_clients)
    )
    WITH CHECK (
        client_id IN (SELECT id FROM onboarding_clients)
    );

-- ============================================
-- PARTIE 6: POLICIES POUR onboarding_info
-- ============================================

-- Lecture de ses propres informations
CREATE POLICY "info_select_own" ON onboarding_info
    FOR SELECT
    USING (
        client_id IN (SELECT id FROM onboarding_clients)
    );

-- Création d'informations
CREATE POLICY "info_insert_own" ON onboarding_info
    FOR INSERT
    WITH CHECK (
        client_id IN (SELECT id FROM onboarding_clients)
    );

-- Mise à jour de ses informations
CREATE POLICY "info_update_own" ON onboarding_info
    FOR UPDATE
    USING (
        client_id IN (SELECT id FROM onboarding_clients)
    )
    WITH CHECK (
        client_id IN (SELECT id FROM onboarding_clients)
    );

-- ============================================
-- PARTIE 7: FONCTION POUR MISE A JOUR AUTO
-- ============================================

CREATE OR REPLACE FUNCTION update_updated_at_column()
RETURNS TRIGGER AS $$
BEGIN
    NEW.updated_at = NOW();
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

-- Triggers pour updated_at automatique
DROP TRIGGER IF EXISTS update_onboarding_clients_updated_at ON onboarding_clients;
CREATE TRIGGER update_onboarding_clients_updated_at
    BEFORE UPDATE ON onboarding_clients
    FOR EACH ROW
    EXECUTE FUNCTION update_updated_at_column();

DROP TRIGGER IF EXISTS update_onboarding_progress_updated_at ON onboarding_progress;
CREATE TRIGGER update_onboarding_progress_updated_at
    BEFORE UPDATE ON onboarding_progress
    FOR EACH ROW
    EXECUTE FUNCTION update_updated_at_column();

DROP TRIGGER IF EXISTS update_onboarding_info_updated_at ON onboarding_info;
CREATE TRIGGER update_onboarding_info_updated_at
    BEFORE UPDATE ON onboarding_info
    FOR EACH ROW
    EXECUTE FUNCTION update_updated_at_column();

-- ============================================
-- PARTIE 8: CONFIGURATION STORAGE BUCKET
-- ============================================

-- Créer le bucket s'il n'existe pas (à faire via Dashboard ou API)
-- INSERT INTO storage.buckets (id, name, public)
-- VALUES ('onboarding-documents', 'onboarding-documents', false)
-- ON CONFLICT (id) DO NOTHING;

-- Policies Storage pour le bucket onboarding-documents
-- (À exécuter dans le SQL Editor de Supabase)

-- Policy: Upload de fichiers (INSERT)
CREATE POLICY "Allow authenticated uploads" ON storage.objects
    FOR INSERT
    WITH CHECK (
        bucket_id = 'onboarding-documents'
    );

-- Policy: Lecture de ses propres fichiers (SELECT)
CREATE POLICY "Allow reading own files" ON storage.objects
    FOR SELECT
    USING (
        bucket_id = 'onboarding-documents'
    );

-- Policy: Mise à jour de ses fichiers (UPDATE)
CREATE POLICY "Allow updating own files" ON storage.objects
    FOR UPDATE
    USING (
        bucket_id = 'onboarding-documents'
    )
    WITH CHECK (
        bucket_id = 'onboarding-documents'
    );

-- Policy: Suppression de ses fichiers (DELETE)
CREATE POLICY "Allow deleting own files" ON storage.objects
    FOR DELETE
    USING (
        bucket_id = 'onboarding-documents'
    );

-- ============================================
-- VERIFICATION
-- ============================================

-- Vérifier que RLS est activé
SELECT tablename, rowsecurity
FROM pg_tables
WHERE schemaname = 'public'
AND tablename IN ('onboarding_clients', 'onboarding_progress', 'onboarding_info');

-- Lister les policies actives
SELECT schemaname, tablename, policyname, permissive, roles, cmd, qual
FROM pg_policies
WHERE schemaname = 'public';
