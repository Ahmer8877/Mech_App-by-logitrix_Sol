-- =====================================================================
-- MechX (mech_app) Complete Supabase Production Database Schema
-- Supports: Email and OAuth Auth
-- Features: Customers, Mechanics, Vehicles, Requests, Live Offers/Bidding,
--           Realtime Chat, Reviews, Notifications, and Admin Management.
-- =====================================================================

-- Enable UUID extension
CREATE EXTENSION IF NOT EXISTS "uuid-ossp";

-- ---------------------------------------------------------------------
-- 1. PROFILES TABLE (Extends auth.users)
-- ---------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS public.profiles (
  id UUID PRIMARY KEY REFERENCES auth.users(id) ON DELETE CASCADE,
  full_name TEXT NOT NULL,
  phone_number TEXT,
  email TEXT,
  avatar_url TEXT,
  role TEXT NOT NULL DEFAULT 'customer' CHECK (role IN ('customer', 'mechanic', 'admin')),
  cnic_number TEXT,
  is_verified BOOLEAN NOT NULL DEFAULT FALSE, -- Mechanic verification status (Admin approved)
  rating NUMERIC(3,2) NOT NULL DEFAULT 0.0,
  total_jobs INTEGER DEFAULT 0,
  is_online BOOLEAN DEFAULT TRUE,
  created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

-- ---------------------------------------------------------------------
-- 2. STORAGE BUCKET & RLS FOR PROFILE AVATARS
-- ---------------------------------------------------------------------
INSERT INTO storage.buckets (id, name, public)
VALUES ('avatars', 'avatars', true)
ON CONFLICT (id) DO UPDATE SET public = true;

-- Storage Policies
DROP POLICY IF EXISTS "Public Read Avatars" ON storage.objects;
CREATE POLICY "Public Read Avatars" ON storage.objects
  FOR SELECT USING (bucket_id = 'avatars');

DROP POLICY IF EXISTS "Public Insert Avatars" ON storage.objects;
DROP POLICY IF EXISTS "Users Insert Own Avatar" ON storage.objects;
CREATE POLICY "Users Insert Own Avatar" ON storage.objects
  FOR INSERT WITH CHECK (
    bucket_id = 'avatars'
    AND auth.uid() IS NOT NULL
    AND (storage.foldername(name))[1] = auth.uid()::text
  );

DROP POLICY IF EXISTS "Public Update Avatars" ON storage.objects;
DROP POLICY IF EXISTS "Users Update Own Avatar" ON storage.objects;
CREATE POLICY "Users Update Own Avatar" ON storage.objects
  FOR UPDATE USING (
    bucket_id = 'avatars'
    AND auth.uid() IS NOT NULL
    AND (storage.foldername(name))[1] = auth.uid()::text
  ) WITH CHECK (
    bucket_id = 'avatars'
    AND (storage.foldername(name))[1] = auth.uid()::text
  );

DROP POLICY IF EXISTS "Users Delete Own Avatar" ON storage.objects;
CREATE POLICY "Users Delete Own Avatar" ON storage.objects
  FOR DELETE USING (
    bucket_id = 'avatars'
    AND auth.uid() IS NOT NULL
    AND (storage.foldername(name))[1] = auth.uid()::text
  );

-- ---------------------------------------------------------------------
-- 3. VEHICLES TABLE
-- ---------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS public.vehicles (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  owner_id UUID NOT NULL REFERENCES public.profiles(id) ON DELETE CASCADE,
  make_model TEXT NOT NULL, -- e.g., 'Honda Civic'
  license_plate TEXT NOT NULL, -- e.g., 'LEB 2020'
  year TEXT,
  created_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

-- ---------------------------------------------------------------------
-- 4. SERVICES TABLE
-- ---------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS public.services (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  title TEXT NOT NULL,
  description TEXT,
  icon_name TEXT NOT NULL,
  base_price NUMERIC(10,2) DEFAULT 0.00,
  is_active BOOLEAN NOT NULL DEFAULT TRUE,
  created_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

-- Keep one canonical row per service title. This also repairs duplicates
-- left behind by older schema versions where `id` was the only unique key.
DO $$
BEGIN
  -- On an existing database, preserve booking references before removing
  -- duplicate service rows. Dynamic SQL keeps a fresh schema run valid
  -- because `bookings` is created later in this file.
  IF to_regclass('public.bookings') IS NOT NULL THEN
    EXECUTE $sql$
      UPDATE public.bookings b
      SET service_id = canonical.id
      FROM (
        SELECT DISTINCT ON (lower(trim(title)))
          lower(trim(title)) AS title_key,
          id
        FROM public.services
        ORDER BY lower(trim(title)), id
      ) canonical
      WHERE b.service_id IN (
        SELECT s2.id
        FROM public.services s2
        WHERE lower(trim(s2.title)) = canonical.title_key
          AND s2.id <> canonical.id
      )
    $sql$;
  END IF;

  DELETE FROM public.services s
  WHERE s.id NOT IN (
    SELECT DISTINCT ON (lower(trim(title))) id
    FROM public.services
    ORDER BY lower(trim(title)), id
  );
END $$;

CREATE UNIQUE INDEX IF NOT EXISTS services_title_unique
  ON public.services (lower(trim(title)));

-- Populate default popular services without creating duplicates on re-run.
INSERT INTO public.services (title, description, icon_name, base_price) VALUES
  ('General Service', 'Basic checkup & parts inspection', 'build_circle_outlined', 1500),
  ('Engine Repair', 'Engine related issues and overhaul', 'settings_outlined', 1800),
  ('Battery Jumpstart', 'Battery checkup and jumpstart', 'battery_charging_full_outlined', 1200),
  ('Air Conditioning', 'AC cooling and gas refill', 'ac_unit_outlined', 1650),
  ('Tyre Change', 'Flat tyre repair or replacement', 'tire_repair_outlined', 1000),
  ('Towing Service', 'Vehicle towing & emergency pickup', 'local_shipping_outlined', 2500)
ON CONFLICT (lower(trim(title))) DO NOTHING;

-- ---------------------------------------------------------------------
-- 5. BOOKINGS / SERVICE REQUESTS TABLE
-- ---------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS public.bookings (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  customer_id UUID NOT NULL REFERENCES public.profiles(id) ON DELETE CASCADE,
  mechanic_id UUID REFERENCES public.profiles(id) ON DELETE SET NULL,
  vehicle_id UUID REFERENCES public.vehicles(id) ON DELETE SET NULL,
  service_id UUID REFERENCES public.services(id) ON DELETE SET NULL,
  service_title TEXT NOT NULL,
  description TEXT,
  photo_urls TEXT[] DEFAULT '{}',
  pickup_address TEXT NOT NULL,
  latitude DOUBLE PRECISION,
  longitude DOUBLE PRECISION,
  status TEXT NOT NULL DEFAULT 'pending'
    CHECK (status IN ('pending', 'offered', 'accepted', 'on_the_way', 'in_progress', 'completed', 'cancelled')),
  budget_price NUMERIC(10,2) DEFAULT 0.00,
  agreed_price NUMERIC(10,2) DEFAULT 0.00,
  payment_method TEXT DEFAULT 'Cash',
  is_paid BOOLEAN NOT NULL DEFAULT FALSE,
  created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  completed_at TIMESTAMPTZ
);

ALTER TABLE public.bookings ADD COLUMN IF NOT EXISTS completed_at TIMESTAMPTZ;
-- Preserve the completion time for existing completed bookings.
UPDATE public.bookings
SET completed_at = COALESCE(completed_at, updated_at)
WHERE status = 'completed' AND completed_at IS NULL;

DO $$
BEGIN
  IF NOT EXISTS (SELECT 1 FROM pg_publication_tables WHERE pubname='supabase_realtime' AND schemaname='public' AND tablename='bookings') THEN
    ALTER PUBLICATION supabase_realtime ADD TABLE public.bookings;
  END IF;
END $$;

-- ---------------------------------------------------------------------
-- 6. OFFERS / BIDS TABLE (Realtime Bidding System)
-- ---------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS public.offers (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  booking_id UUID NOT NULL REFERENCES public.bookings(id) ON DELETE CASCADE,
  mechanic_id UUID NOT NULL REFERENCES public.profiles(id) ON DELETE CASCADE,
  price NUMERIC(10,2) NOT NULL,
  estimated_time TEXT DEFAULT '30 min',
  message TEXT,
  status TEXT NOT NULL DEFAULT 'pending' CHECK (status IN ('pending', 'accepted', 'rejected')),
  created_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

-- ---------------------------------------------------------------------
-- 7. CHAT MESSAGES TABLE (Realtime Messaging)
-- ---------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS public.chat_messages (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  booking_id UUID NOT NULL REFERENCES public.bookings(id) ON DELETE CASCADE,
  sender_id UUID NOT NULL REFERENCES public.profiles(id) ON DELETE CASCADE,
  receiver_id UUID NOT NULL REFERENCES public.profiles(id) ON DELETE CASCADE,
  message TEXT NOT NULL,
  is_read BOOLEAN NOT NULL DEFAULT FALSE,
  created_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

-- ---------------------------------------------------------------------
-- 7B. BOOKING LOCATIONS TABLE (Live mechanic tracking)
-- One row per active booking, upserted on every GPS ping so the customer's
-- tracking screen can subscribe and watch it move in real time. Required
-- by lib/cores/repositories/live_location_repository.dart — without this
-- table, live tracking throws at runtime (relation does not exist).
-- ---------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS public.booking_locations (
  booking_id UUID PRIMARY KEY REFERENCES public.bookings(id) ON DELETE CASCADE,
  mechanic_id UUID REFERENCES public.profiles(id) ON DELETE CASCADE,
  customer_id UUID REFERENCES public.profiles(id) ON DELETE CASCADE,
  latitude DOUBLE PRECISION,
  longitude DOUBLE PRECISION,
  accuracy DOUBLE PRECISION,
  heading DOUBLE PRECISION DEFAULT 0,
  speed DOUBLE PRECISION,
  customer_latitude DOUBLE PRECISION,
  customer_longitude DOUBLE PRECISION,
  customer_accuracy DOUBLE PRECISION,
  customer_heading DOUBLE PRECISION DEFAULT 0,
  updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

ALTER TABLE public.booking_locations ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.booking_locations ADD COLUMN IF NOT EXISTS customer_id UUID REFERENCES public.profiles(id) ON DELETE CASCADE;
ALTER TABLE public.booking_locations ADD COLUMN IF NOT EXISTS customer_latitude DOUBLE PRECISION;
ALTER TABLE public.booking_locations ADD COLUMN IF NOT EXISTS customer_longitude DOUBLE PRECISION;
ALTER TABLE public.booking_locations ADD COLUMN IF NOT EXISTS customer_accuracy DOUBLE PRECISION;
ALTER TABLE public.booking_locations ADD COLUMN IF NOT EXISTS customer_heading DOUBLE PRECISION DEFAULT 0;
ALTER TABLE public.booking_locations ALTER COLUMN mechanic_id DROP NOT NULL;
ALTER TABLE public.booking_locations ALTER COLUMN latitude DROP NOT NULL;
ALTER TABLE public.booking_locations ALTER COLUMN longitude DROP NOT NULL;

DROP POLICY IF EXISTS "Booking parties view live location" ON public.booking_locations;
CREATE POLICY "Booking parties view live location" ON public.booking_locations FOR SELECT USING (true);

DROP POLICY IF EXISTS "Mechanic writes own location" ON public.booking_locations;
CREATE POLICY "Mechanic writes own location" ON public.booking_locations FOR INSERT WITH CHECK (
  auth.uid() IS NOT NULL
);

DROP POLICY IF EXISTS "Mechanic updates own location" ON public.booking_locations;
CREATE POLICY "Mechanic updates own location" ON public.booking_locations FOR UPDATE USING (
  auth.uid() IS NOT NULL
) WITH CHECK (
  auth.uid() IS NOT NULL
);
DROP POLICY IF EXISTS "Customer writes own location" ON public.booking_locations;
CREATE POLICY "Customer writes own location" ON public.booking_locations FOR INSERT WITH CHECK (
  auth.uid() = customer_id AND EXISTS (SELECT 1 FROM public.bookings b WHERE b.id = booking_id AND b.customer_id = auth.uid())
);
DROP POLICY IF EXISTS "Customer updates own location" ON public.booking_locations;
CREATE POLICY "Customer updates own location" ON public.booking_locations FOR UPDATE USING (
  EXISTS (SELECT 1 FROM public.bookings b WHERE b.id = booking_locations.booking_id AND b.customer_id = auth.uid())
) WITH CHECK (
  EXISTS (SELECT 1 FROM public.bookings b WHERE b.id = booking_locations.booking_id AND b.customer_id = auth.uid())
);
DROP POLICY IF EXISTS "Mechanic deletes own location" ON public.booking_locations;
CREATE POLICY "Mechanic deletes own location" ON public.booking_locations FOR DELETE USING (
  EXISTS (SELECT 1 FROM public.bookings b WHERE b.id = booking_locations.booking_id AND b.mechanic_id = auth.uid())
);

-- Add the table to Supabase Realtime if it is not already published.
DO $$
BEGIN
  IF NOT EXISTS (
    SELECT 1
    FROM pg_publication_tables
    WHERE pubname = 'supabase_realtime'
      AND schemaname = 'public'
      AND tablename = 'booking_locations'
  ) THEN
    ALTER PUBLICATION supabase_realtime ADD TABLE public.booking_locations;
  END IF;
END $$;

-- IMPORTANT (manual step): Supabase Dashboard → Database → Replication →
-- enable Realtime on "booking_locations", same as you did for offers/
-- chat_messages/bookings — otherwise watchMechanicLocation() will never
-- receive updates even though the table now exists.

-- ---------------------------------------------------------------------
-- 8. REVIEWS & RATINGS TABLE
-- ---------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS public.reviews (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  booking_id UUID NOT NULL REFERENCES public.bookings(id) ON DELETE CASCADE,
  customer_id UUID NOT NULL REFERENCES public.profiles(id) ON DELETE CASCADE,
  mechanic_id UUID NOT NULL REFERENCES public.profiles(id) ON DELETE CASCADE,
  rating INTEGER NOT NULL CHECK (rating >= 1 AND rating <= 5),
  comment TEXT,
  created_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

-- ---------------------------------------------------------------------
-- 9. NOTIFICATIONS TABLE
-- ---------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS public.notifications (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id UUID NOT NULL REFERENCES public.profiles(id) ON DELETE CASCADE,
  title TEXT NOT NULL,
  subtitle TEXT NOT NULL,
  icon_name TEXT DEFAULT 'notifications_outlined',
  is_read BOOLEAN NOT NULL DEFAULT FALSE,
  created_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

-- ---------------------------------------------------------------------
-- AUTOMATIC PROFILE CREATION TRIGGER
-- When a user signs up via Email, Google, or Facebook, create profile
-- ---------------------------------------------------------------------
CREATE OR REPLACE FUNCTION public.handle_new_user()
RETURNS TRIGGER AS $$
BEGIN
  INSERT INTO public.profiles (id, full_name, email, role)
  VALUES (
    NEW.id,
    COALESCE(NEW.raw_user_meta_data->>'full_name', NEW.raw_user_meta_data->>'name', 'User'),
    NEW.email,
    CASE WHEN NEW.raw_user_meta_data->>'role' = 'mechanic' THEN 'mechanic' ELSE 'customer' END
  )
  ON CONFLICT (id) DO UPDATE SET
    full_name = EXCLUDED.full_name,
    email = EXCLUDED.email;
  RETURN NEW;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

DROP TRIGGER IF EXISTS on_auth_user_created ON auth.users;
CREATE TRIGGER on_auth_user_created
  AFTER INSERT ON auth.users
  FOR EACH ROW EXECUTE FUNCTION public.handle_new_user();

-- ---------------------------------------------------------------------
-- PROFILE PROTECTION
-- Client users may edit profile presentation/contact fields only.
-- Role, verification, rating, job counters and CNIC stay server-controlled.
-- ---------------------------------------------------------------------
CREATE OR REPLACE FUNCTION public.protect_profile_fields()
RETURNS TRIGGER AS $$
BEGIN
  IF auth.uid() = OLD.id
     AND COALESCE(current_setting('app.allow_server_profile_fields', true), '') <> 'on' THEN
    NEW.id := OLD.id;
    NEW.role := OLD.role;
    NEW.cnic_number := OLD.cnic_number;
    NEW.is_verified := OLD.is_verified;
    NEW.rating := OLD.rating;
    NEW.total_jobs := OLD.total_jobs;
    NEW.created_at := OLD.created_at;
  END IF;
  NEW.updated_at := NOW();
  RETURN NEW;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER SET search_path = public;

DROP TRIGGER IF EXISTS protect_profile_fields_trigger ON public.profiles;
CREATE TRIGGER protect_profile_fields_trigger
  BEFORE UPDATE ON public.profiles
  FOR EACH ROW EXECUTE FUNCTION public.protect_profile_fields();

-- Generic updated_at trigger for mutable application tables.
CREATE OR REPLACE FUNCTION public.set_updated_at()
RETURNS TRIGGER AS $$
BEGIN
  NEW.updated_at := NOW();
  RETURN NEW;
END;
$$ LANGUAGE plpgsql;

DROP TRIGGER IF EXISTS bookings_set_updated_at ON public.bookings;
CREATE TRIGGER bookings_set_updated_at BEFORE UPDATE ON public.bookings
FOR EACH ROW EXECUTE FUNCTION public.set_updated_at();

-- ---------------------------------------------------------------------
-- ROW LEVEL SECURITY (RLS) POLICIES
-- ---------------------------------------------------------------------
ALTER TABLE public.profiles ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.vehicles ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.services ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.bookings ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.offers ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.chat_messages ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.reviews ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.notifications ENABLE ROW LEVEL SECURITY;

-- Drop existing policies so this script can be safely re-run.
DO $$
DECLARE r RECORD;
BEGIN
  FOR r IN SELECT policyname, tablename FROM pg_policies WHERE schemaname = 'public'
    AND tablename IN ('profiles','vehicles','services','bookings','offers','chat_messages','reviews','notifications')
  LOOP
    EXECUTE format('DROP POLICY IF EXISTS %I ON public.%I', r.policyname, r.tablename);
  END LOOP;
END $$;

-- Helper used by RLS without recursively querying the profiles policy.
CREATE OR REPLACE FUNCTION public.is_verified_mechanic()
RETURNS BOOLEAN
LANGUAGE sql
STABLE
SECURITY DEFINER
SET search_path = public
AS $$
  SELECT EXISTS (
    SELECT 1
    FROM public.profiles
    WHERE id = auth.uid()
      AND role = 'mechanic'
      AND is_verified = true
  );
$$;

CREATE OR REPLACE FUNCTION public.can_read_booking_profile(p_profile_id UUID)
RETURNS BOOLEAN LANGUAGE sql STABLE SECURITY DEFINER SET search_path=public AS $$
  SELECT p_profile_id = auth.uid() OR EXISTS (
    SELECT 1 FROM public.bookings b
    WHERE (b.customer_id=auth.uid() AND b.mechanic_id=p_profile_id)
       OR (b.mechanic_id=auth.uid() AND b.customer_id=p_profile_id)
       OR (b.customer_id=p_profile_id AND b.mechanic_id IS NULL AND b.status='pending' AND public.is_verified_mechanic())
  );
$$;

-- Profiles: users can read/update their own private profile.
CREATE POLICY "Users read own profile" ON public.profiles
  FOR SELECT USING (auth.uid() = id);
CREATE POLICY "Users update own profile" ON public.profiles
  FOR UPDATE USING (auth.uid() = id)
  WITH CHECK (auth.uid() = id);

DROP POLICY IF EXISTS "Users read booking participant profiles" ON public.profiles;
CREATE POLICY "Users read booking participant profiles" ON public.profiles
  FOR SELECT USING (public.can_read_booking_profile(id));

-- Vehicles: owner-only CRUD.
CREATE POLICY "Users read own vehicles" ON public.vehicles FOR SELECT USING (auth.uid() = owner_id);
CREATE POLICY "Users insert own vehicles" ON public.vehicles FOR INSERT WITH CHECK (auth.uid() = owner_id);
CREATE POLICY "Users update own vehicles" ON public.vehicles FOR UPDATE USING (auth.uid() = owner_id) WITH CHECK (auth.uid() = owner_id);
CREATE POLICY "Users delete own vehicles" ON public.vehicles FOR DELETE USING (auth.uid() = owner_id);

-- Services are public catalogue data, but only active services are exposed.
CREATE POLICY "Anyone read active services" ON public.services FOR SELECT USING (is_active = true);

-- Bookings: customer sees own bookings; assigned mechanic sees assigned jobs;
-- unassigned pending requests are visible only to verified mechanics.
CREATE POLICY "Users read relevant bookings" ON public.bookings FOR SELECT USING (
  auth.uid() = customer_id
  OR auth.uid() = mechanic_id
  OR (mechanic_id IS NULL AND public.is_verified_mechanic())
);
CREATE POLICY "Customers create bookings" ON public.bookings FOR INSERT WITH CHECK (
  auth.uid() = customer_id
);
CREATE POLICY "Users update relevant bookings" ON public.bookings FOR UPDATE USING (
  auth.uid() = customer_id OR auth.uid() = mechanic_id
) WITH CHECK (
  auth.uid() = customer_id OR auth.uid() = mechanic_id
);

-- Offers: customer sees offers for their own booking; mechanics see their own.
CREATE POLICY "Users read relevant offers" ON public.offers FOR SELECT USING (
  auth.uid() = mechanic_id
  OR EXISTS (SELECT 1 FROM public.bookings b WHERE b.id = booking_id AND b.customer_id = auth.uid())
);
CREATE POLICY "Verified mechanics create offers" ON public.offers FOR INSERT WITH CHECK (
  auth.uid() = mechanic_id
  AND EXISTS (SELECT 1 FROM public.profiles p WHERE p.id = auth.uid() AND p.role = 'mechanic' AND p.is_verified = true)
);
CREATE POLICY "Mechanics update own offers" ON public.offers FOR UPDATE USING (auth.uid() = mechanic_id) WITH CHECK (auth.uid() = mechanic_id);

-- Chat: only booking participants can read/send.
CREATE POLICY "Participants read chat" ON public.chat_messages FOR SELECT USING (
  auth.uid() = sender_id OR auth.uid() = receiver_id
);
CREATE POLICY "Participants send chat" ON public.chat_messages FOR INSERT WITH CHECK (
  auth.uid() = sender_id
  AND EXISTS (
    SELECT 1 FROM public.bookings b
    WHERE b.id = booking_id
      AND (auth.uid() = b.customer_id OR auth.uid() = b.mechanic_id)
      AND receiver_id IN (b.customer_id, b.mechanic_id)
  )
);

-- Reviews: public read is acceptable; booking customers can submit/update their review.
CREATE POLICY "Anyone read reviews" ON public.reviews FOR SELECT USING (true);
DROP POLICY IF EXISTS "Customers create reviews" ON public.reviews;
CREATE POLICY "Customers create reviews" ON public.reviews FOR INSERT WITH CHECK (
  auth.uid() = customer_id
  AND EXISTS (SELECT 1 FROM public.bookings b WHERE b.id = booking_id AND b.customer_id = auth.uid())
);
DROP POLICY IF EXISTS "Customers update reviews" ON public.reviews;
CREATE POLICY "Customers update reviews" ON public.reviews FOR UPDATE USING (
  auth.uid() = customer_id
) WITH CHECK (
  auth.uid() = customer_id
);

-- Notifications: owner-only read/update/delete.
CREATE POLICY "Users read own notifications" ON public.notifications FOR SELECT USING (auth.uid() = user_id);
CREATE POLICY "Users mark own notifications read" ON public.notifications FOR UPDATE USING (auth.uid() = user_id) WITH CHECK (auth.uid() = user_id);
DROP POLICY IF EXISTS "Users delete own notifications" ON public.notifications;
CREATE POLICY "Users delete own notifications" ON public.notifications FOR DELETE USING (auth.uid() = user_id);

-- =====================================================================
-- LIVE BOOKING FLOW ADDITIONS
-- =====================================================================
INSERT INTO storage.buckets (id, name, public)
VALUES ('booking-photos','booking-photos',true)
ON CONFLICT (id) DO UPDATE SET public=true;

DROP POLICY IF EXISTS "Users upload own booking photos" ON storage.objects;
CREATE POLICY "Users upload own booking photos" ON storage.objects FOR INSERT WITH CHECK (
  bucket_id='booking-photos' AND auth.uid() IS NOT NULL AND (storage.foldername(name))[1]=auth.uid()::text
);
DROP POLICY IF EXISTS "Public read booking photos" ON storage.objects;
CREATE POLICY "Public read booking photos" ON storage.objects FOR SELECT USING (bucket_id='booking-photos');
DROP POLICY IF EXISTS "Users delete own booking photos" ON storage.objects;
CREATE POLICY "Users delete own booking photos" ON storage.objects FOR DELETE USING (
  bucket_id='booking-photos' AND (storage.foldername(name))[1]=auth.uid()::text
);

CREATE UNIQUE INDEX IF NOT EXISTS offers_one_per_mechanic_per_booking ON public.offers(booking_id, mechanic_id);
CREATE UNIQUE INDEX IF NOT EXISTS reviews_one_per_customer_per_booking ON public.reviews(booking_id, customer_id);

CREATE OR REPLACE FUNCTION public.accept_offer(p_offer_id UUID, p_customer_id UUID)
RETURNS VOID AS $$
DECLARE
  v_booking UUID;
  v_mechanic UUID;
  v_price NUMERIC;
BEGIN
  SELECT booking_id, mechanic_id, price INTO v_booking, v_mechanic, v_price FROM public.offers WHERE id=p_offer_id AND status='pending';
  IF v_booking IS NULL THEN RAISE EXCEPTION 'Offer not found or unavailable'; END IF;
  IF auth.uid() <> p_customer_id THEN RAISE EXCEPTION 'Unauthorized'; END IF;
  UPDATE public.bookings SET mechanic_id=v_mechanic, agreed_price=v_price, status='accepted' WHERE id=v_booking AND customer_id=p_customer_id;
  IF NOT FOUND THEN RAISE EXCEPTION 'Booking not found or unauthorized'; END IF;
  UPDATE public.offers SET status=CASE WHEN id=p_offer_id THEN 'accepted' ELSE 'rejected' END WHERE booking_id=v_booking;
  INSERT INTO public.notifications(user_id,title,subtitle,icon_name) VALUES(v_mechanic,'Offer accepted','A customer accepted your offer.','check_circle_outline');
END;
$$ LANGUAGE plpgsql SECURITY DEFINER SET search_path=public;

CREATE OR REPLACE FUNCTION public.notify_booking_status()
RETURNS TRIGGER AS $$
BEGIN
  IF TG_OP='UPDATE' AND NEW.status IS DISTINCT FROM OLD.status THEN
    IF NEW.customer_id IS NOT NULL THEN
      INSERT INTO public.notifications(user_id,title,subtitle,icon_name)
      VALUES(NEW.customer_id,'Booking update','Your booking status is now ' || replace(NEW.status,'_',' '),'notifications_outlined');
    END IF;
    IF NEW.mechanic_id IS NOT NULL THEN
      INSERT INTO public.notifications(user_id,title,subtitle,icon_name)
      VALUES(NEW.mechanic_id,'Booking update','Booking status is now ' || replace(NEW.status,'_',' '),'notifications_outlined');
    END IF;
  END IF;
  RETURN NEW;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER SET search_path=public;
DROP TRIGGER IF EXISTS booking_status_notification_trigger ON public.bookings;
CREATE TRIGGER booking_status_notification_trigger AFTER UPDATE ON public.bookings FOR EACH ROW EXECUTE FUNCTION public.notify_booking_status();

-- =====================================================================
-- LIVE APP PATCH: booking photos, offer acceptance and data integrity
-- Run this section once if the base schema was already applied.
-- =====================================================================
INSERT INTO storage.buckets (id,name,public) VALUES ('booking-photos','booking-photos',true) ON CONFLICT (id) DO UPDATE SET public=true;
DROP POLICY IF EXISTS "Public read booking photos" ON storage.objects;
CREATE POLICY "Public read booking photos" ON storage.objects FOR SELECT USING (bucket_id='booking-photos');
DROP POLICY IF EXISTS "Users upload own booking photos" ON storage.objects;
CREATE POLICY "Users upload own booking photos" ON storage.objects FOR INSERT WITH CHECK (bucket_id='booking-photos' AND auth.uid() IS NOT NULL AND (storage.foldername(name))[1]=auth.uid()::text);
DROP POLICY IF EXISTS "Users delete own booking photos" ON storage.objects;
CREATE POLICY "Users delete own booking photos" ON storage.objects FOR DELETE USING (bucket_id='booking-photos' AND auth.uid() IS NOT NULL AND (storage.foldername(name))[1]=auth.uid()::text);
CREATE UNIQUE INDEX IF NOT EXISTS offers_booking_mechanic_unique ON public.offers(booking_id,mechanic_id);
CREATE UNIQUE INDEX IF NOT EXISTS reviews_booking_customer_unique ON public.reviews(booking_id,customer_id);
CREATE OR REPLACE FUNCTION public.accept_offer(p_offer_id uuid,p_customer_id uuid) RETURNS void LANGUAGE plpgsql SECURITY DEFINER SET search_path=public AS $$
DECLARE v_booking uuid; v_mechanic uuid; v_price numeric;
BEGIN
 SELECT booking_id,mechanic_id,price INTO v_booking,v_mechanic,v_price FROM public.offers WHERE id=p_offer_id FOR UPDATE;
 IF v_booking IS NULL THEN RAISE EXCEPTION 'Offer not found'; END IF;
 IF NOT EXISTS (SELECT 1 FROM public.bookings WHERE id=v_booking AND customer_id=p_customer_id AND mechanic_id IS NULL) THEN RAISE EXCEPTION 'Not allowed to accept this offer'; END IF;
 UPDATE public.offers SET status=CASE WHEN id=p_offer_id THEN 'accepted' ELSE 'rejected' END WHERE booking_id=v_booking;
 UPDATE public.bookings SET mechanic_id=v_mechanic,status='accepted',agreed_price=v_price WHERE id=v_booking;
 INSERT INTO public.notifications(user_id,title,subtitle,icon_name) VALUES (v_mechanic,'Offer accepted','Your offer was selected by the customer','check_circle_outline');
END; $$;
GRANT EXECUTE ON FUNCTION public.accept_offer(uuid,uuid) TO authenticated;

-- ---------------------------------------------------------------------
-- 14. REALTIME ROBUSTNESS FOR LIVE DASHBOARD / LOCATION
-- ---------------------------------------------------------------------
-- FULL replica identity makes UPDATE/DELETE payloads complete, including
-- mechanic_id/status changes that move a booking between realtime views.
ALTER TABLE public.bookings REPLICA IDENTITY FULL;
ALTER TABLE public.booking_locations REPLICA IDENTITY FULL;

DO $$
BEGIN
  IF NOT EXISTS (
    SELECT 1 FROM pg_publication_tables
    WHERE pubname = 'supabase_realtime'
      AND schemaname = 'public'
      AND tablename = 'bookings'
  ) THEN
    ALTER PUBLICATION supabase_realtime ADD TABLE public.bookings;
  END IF;

  IF NOT EXISTS (
    SELECT 1 FROM pg_publication_tables
    WHERE pubname = 'supabase_realtime'
      AND schemaname = 'public'
      AND tablename = 'booking_locations'
  ) THEN
    ALTER PUBLICATION supabase_realtime ADD TABLE public.booking_locations;
  END IF;
END $$;

-- Keep mechanic job counters synchronized with completed bookings.
CREATE OR REPLACE FUNCTION public.recalculate_mechanic_total_jobs()
RETURNS TRIGGER AS $$
DECLARE
  v_mechanic UUID;
BEGIN
  v_mechanic := CASE
    WHEN TG_OP = 'DELETE' THEN OLD.mechanic_id
    ELSE NEW.mechanic_id
  END;

  -- Allow this trusted server-side trigger to update the protected counter.
  PERFORM set_config('app.allow_server_profile_fields', 'on', true);

  UPDATE public.profiles p
  SET total_jobs = (
    SELECT COUNT(*)
    FROM public.bookings b
    WHERE b.mechanic_id = p.id
      AND b.status = 'completed'
  )
  WHERE p.id = v_mechanic;

  -- If a booking changes mechanic, also refresh the previous mechanic.
  IF TG_OP = 'UPDATE' AND OLD.mechanic_id IS DISTINCT FROM NEW.mechanic_id
     AND OLD.mechanic_id IS NOT NULL THEN
    UPDATE public.profiles p
    SET total_jobs = (
      SELECT COUNT(*)
      FROM public.bookings b
      WHERE b.mechanic_id = p.id
        AND b.status = 'completed'
    )
    WHERE p.id = OLD.mechanic_id;
  END IF;

  RETURN NEW;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER SET search_path = public;

DROP TRIGGER IF EXISTS on_booking_change_update_jobs ON public.bookings;
CREATE TRIGGER on_booking_change_update_jobs
AFTER INSERT OR UPDATE OR DELETE ON public.bookings
FOR EACH ROW EXECUTE FUNCTION public.recalculate_mechanic_total_jobs();

-- Backfill counters once after installing the trigger.
UPDATE public.profiles p
SET total_jobs = (
  SELECT COUNT(*)
  FROM public.bookings b
  WHERE b.mechanic_id = p.id
    AND b.status = 'completed'
)
WHERE p.role = 'mechanic';

-- =====================================================================
-- MECHANIC RATING PATCH
-- Rating is calculated only from customer reviews of that mechanic.
-- Customer profiles do not use the profiles.rating field.
-- =====================================================================

CREATE OR REPLACE FUNCTION public.recalculate_mechanic_rating()
RETURNS TRIGGER AS $$
DECLARE
  v_mechanic UUID;
  v_old_mechanic UUID;
BEGIN
  v_mechanic := CASE WHEN TG_OP = 'DELETE' THEN OLD.mechanic_id ELSE NEW.mechanic_id END;
  v_old_mechanic := CASE WHEN TG_OP = 'UPDATE' THEN OLD.mechanic_id ELSE NULL END;

  -- Rating is server-controlled, so temporarily allow this trusted trigger
  -- to update the protected profile field.
  PERFORM set_config('app.allow_server_profile_fields', 'on', true);

  UPDATE public.profiles
  SET rating = COALESCE(
    (SELECT ROUND(AVG(r.rating)::numeric, 2)
     FROM public.reviews r
     WHERE r.mechanic_id = v_mechanic),
    5.0
  )
  WHERE id = v_mechanic
    AND role = 'mechanic';

  -- If a review is moved from one mechanic to another, refresh both.
  IF v_old_mechanic IS NOT NULL AND v_old_mechanic IS DISTINCT FROM v_mechanic THEN
    UPDATE public.profiles
    SET rating = COALESCE(
      (SELECT ROUND(AVG(r.rating)::numeric, 2)
       FROM public.reviews r
       WHERE r.mechanic_id = v_old_mechanic),
      5.0
    )
    WHERE id = v_old_mechanic
      AND role = 'mechanic';
  END IF;

  RETURN COALESCE(NEW, OLD);
END;
$$ LANGUAGE plpgsql SECURITY DEFINER SET search_path = public;

DROP TRIGGER IF EXISTS on_review_change_update_rating ON public.reviews;
CREATE TRIGGER on_review_change_update_rating
AFTER INSERT OR UPDATE OR DELETE ON public.reviews
FOR EACH ROW EXECUTE FUNCTION public.recalculate_mechanic_rating();

-- Existing mechanic ratings: calculate them from real reviews.
UPDATE public.profiles p
SET rating = COALESCE(
  (SELECT ROUND(AVG(r.rating)::numeric, 2)
   FROM public.reviews r
   WHERE r.mechanic_id = p.id),
  5.0
)
WHERE p.role = 'mechanic';

-- New mechanics start at 0 until they receive a customer review.
ALTER TABLE public.profiles ALTER COLUMN rating SET DEFAULT 0.0;
UPDATE public.profiles p
SET rating = 0
WHERE p.role = 'mechanic'
  AND NOT EXISTS (SELECT 1 FROM public.reviews r WHERE r.mechanic_id = p.id);

-- Customer profiles do not have a mechanic rating.
UPDATE public.profiles
SET rating = 0
WHERE role <> 'mechanic';
