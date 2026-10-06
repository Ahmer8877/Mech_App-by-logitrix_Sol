-- ================================================================
-- MECHX NOTIFICATION PUSH SETUP
-- Run this once in Supabase SQL Editor after the mobile code update.
-- ================================================================

-- Store optional routing payload alongside existing notifications.
ALTER TABLE public.notifications
  ADD COLUMN IF NOT EXISTS data JSONB NOT NULL DEFAULT '{}'::jsonb;

ALTER TABLE public.notifications REPLICA IDENTITY FULL;

-- Offer accepted -> mechanic receives a routable push notification.
CREATE OR REPLACE FUNCTION public.accept_offer(p_offer_id uuid,p_customer_id uuid)
RETURNS void
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path=public
AS $$
DECLARE
  v_booking uuid;
  v_mechanic uuid;
  v_price numeric;
BEGIN
  SELECT booking_id,mechanic_id,price
  INTO v_booking,v_mechanic,v_price
  FROM public.offers
  WHERE id=p_offer_id
  FOR UPDATE;

  IF v_booking IS NULL THEN
    RAISE EXCEPTION 'Offer not found';
  END IF;

  IF NOT EXISTS (
    SELECT 1 FROM public.bookings
    WHERE id=v_booking AND customer_id=p_customer_id AND mechanic_id IS NULL
  ) THEN
    RAISE EXCEPTION 'Not allowed to accept this offer';
  END IF;

  UPDATE public.offers
  SET status=CASE WHEN id=p_offer_id THEN 'accepted' ELSE 'rejected' END
  WHERE booking_id=v_booking;

  UPDATE public.bookings
  SET mechanic_id=v_mechanic,status='accepted',agreed_price=v_price
  WHERE id=v_booking;

  INSERT INTO public.notifications(user_id,title,subtitle,icon_name,data)
  VALUES (
    v_mechanic,
    'Offer accepted',
    'Your offer was selected by the customer',
    'check_circle_outline',
    jsonb_build_object('type','offer_accepted','booking_id',v_booking::text)
  );
END;
$$;

GRANT EXECUTE ON FUNCTION public.accept_offer(uuid,uuid) TO authenticated;

-- Booking status -> customer/mechanic receives a routable push notification.
CREATE OR REPLACE FUNCTION public.notify_booking_status()
RETURNS TRIGGER
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path=public
AS $$
BEGIN
  IF TG_OP='UPDATE' AND NEW.status IS DISTINCT FROM OLD.status THEN
    IF NEW.customer_id IS NOT NULL THEN
      INSERT INTO public.notifications(user_id,title,subtitle,icon_name,data)
      VALUES (
        NEW.customer_id,
        'Booking update',
        'Your booking status is now ' || replace(NEW.status,'_',' '),
        'notifications_outlined',
        jsonb_build_object(
          'type','booking_status',
          'booking_id',NEW.id::text,
          'status',NEW.status,
          'role','customer'
        )
      );
    END IF;

    IF NEW.mechanic_id IS NOT NULL THEN
      INSERT INTO public.notifications(user_id,title,subtitle,icon_name,data)
      VALUES (
        NEW.mechanic_id,
        'Booking update',
        'Booking status is now ' || replace(NEW.status,'_',' '),
        'notifications_outlined',
        jsonb_build_object(
          'type','booking_status',
          'booking_id',NEW.id::text,
          'status',NEW.status,
          'role','mechanic'
        )
      );
    END IF;
  END IF;

  RETURN NEW;
END;
$$;

DROP TRIGGER IF EXISTS booking_status_notification_trigger ON public.bookings;
CREATE TRIGGER booking_status_notification_trigger
AFTER UPDATE ON public.bookings
FOR EACH ROW
EXECUTE FUNCTION public.notify_booking_status();
