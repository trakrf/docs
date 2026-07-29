-- Seeds the TrakRF Docs org used for documentation screenshots.
-- Idempotent: safe to re-run. Targets a LOCAL database only.
-- Usage: just database psql < scripts/seed-docs-org.sql
\set ON_ERROR_STOP on

DO $$
DECLARE
    v_org       BIGINT;
    v_receiving BIGINT;
    v_warehouse BIGINT;
    v_bay3      BIGINT;
    v_office    BIGINT;
    v_lab       BIGINT;
BEGIN
    SELECT id INTO v_org
      FROM trakrf.organizations
     WHERE name = 'TrakRF Docs' AND deleted_at IS NULL;

    IF v_org IS NULL THEN
        RAISE EXCEPTION 'Org "TrakRF Docs" not found — sign up through the UI first';
    END IF;

    -- Geofence unlocks the Outputs and Geofence defaults pages. Without it they
    -- render as locked upsell pages. Mustering and kitting stay ungranted on
    -- purpose: those surfaces are out of scope and must not appear unlocked.
    INSERT INTO trakrf.org_capabilities (org_id, capability, granted_at)
    VALUES (v_org, 'geofence', now())
    ON CONFLICT DO NOTHING;

    IF EXISTS (SELECT 1 FROM trakrf.assets
                WHERE org_id = v_org AND external_key = 'ASSET-CAMERA'
                  AND deleted_at IS NULL) THEN
        RAISE NOTICE 'Seed data already present — skipping';
        RETURN;
    END IF;

    SELECT location_id INTO v_receiving FROM trakrf.create_location_with_tags(
        v_org, 'LOC-RECEIVING', 'Receiving', 'Inbound dock',
        NULL, now(), NULL, TRUE, '{}'::jsonb, '[]'::jsonb);

    SELECT location_id INTO v_warehouse FROM trakrf.create_location_with_tags(
        v_org, 'LOC-WAREHOUSE-A', 'Warehouse A', 'Main storage',
        NULL, now(), NULL, TRUE, '{}'::jsonb, '[]'::jsonb);

    SELECT location_id INTO v_bay3 FROM trakrf.create_location_with_tags(
        v_org, 'LOC-BAY-3', 'Bay 3', 'Warehouse A, bay 3',
        v_warehouse, now(), NULL, TRUE, '{}'::jsonb,
        '[{"type":"rfid","value":"E280689400005015C9E1A101"}]'::jsonb);

    SELECT location_id INTO v_office FROM trakrf.create_location_with_tags(
        v_org, 'LOC-OFFICE', 'Office', 'Front office',
        NULL, now(), NULL, TRUE, '{}'::jsonb, '[]'::jsonb);

    SELECT location_id INTO v_lab FROM trakrf.create_location_with_tags(
        v_org, 'LOC-LAB', 'Lab', 'Test bench',
        NULL, now(), NULL, TRUE, '{}'::jsonb, '[]'::jsonb);

    -- ASSET-CAMERA carries the physical bench reader's test tag (10021) so a
    -- live scan resolves to a named asset instead of showing as an unknown
    -- EPC. Every other asset keeps a placeholder EPC.
    PERFORM trakrf.create_asset_with_tags(v_org, 'ASSET-CAMERA', 'Camera',
        'Canon EOS R6 body', now(), NULL, TRUE, '{}'::jsonb,
        '[{"type":"rfid","value":"10021"}]'::jsonb);

    PERFORM trakrf.create_asset_with_tags(v_org, 'ASSET-LAPTOP', 'Laptop',
        'ThinkPad X1 Carbon', now(), NULL, TRUE, '{}'::jsonb,
        '[{"type":"rfid","value":"E280689400005015C9E1B202"}]'::jsonb);

    PERFORM trakrf.create_asset_with_tags(v_org, 'ASSET-TABLET', 'Tablet',
        'iPad Pro 11-inch', now(), NULL, TRUE, '{}'::jsonb,
        '[{"type":"rfid","value":"E280689400005015C9E1B203"}]'::jsonb);

    PERFORM trakrf.create_asset_with_tags(v_org, 'ASSET-PROJECTOR', 'Projector',
        'Epson conference room projector', now(), NULL, TRUE, '{}'::jsonb,
        '[{"type":"rfid","value":"E280689400005015C9E1B204"}]'::jsonb);

    PERFORM trakrf.create_asset_with_tags(v_org, 'ASSET-TOOLBOX', 'Toolbox',
        'Field service toolkit', now(), NULL, TRUE, '{}'::jsonb,
        '[{"type":"rfid","value":"E280689400005015C9E1B205"}]'::jsonb);

    PERFORM trakrf.create_asset_with_tags(v_org, 'ASSET-PALLET-JACK', 'Pallet Jack',
        'Electric pallet jack', now(), NULL, TRUE, '{}'::jsonb,
        '[{"type":"rfid","value":"E280689400005015C9E1B206"}]'::jsonb);

    PERFORM trakrf.create_asset_with_tags(v_org, 'ASSET-MICROSCOPE', 'Microscope',
        'Lab inspection microscope', now(), NULL, TRUE, '{}'::jsonb,
        '[{"type":"rfid","value":"E280689400005015C9E1B207"}]'::jsonb);

    PERFORM trakrf.create_asset_with_tags(v_org, 'ASSET-LABEL-PRINTER', 'Label Printer',
        'Zebra ZT411 tag printer', now(), NULL, TRUE, '{}'::jsonb,
        '[{"type":"rfid","value":"E280689400005015C9E1B208"}]'::jsonb);

    RAISE NOTICE 'Seeded org % with 5 locations and 8 assets', v_org;
END $$;
