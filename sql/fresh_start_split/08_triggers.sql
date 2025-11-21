-- ===============================================
-- 8. TRIGGERS
-- ===============================================

-- Updated_at triggers
DO $$
BEGIN
    IF NOT EXISTS (SELECT 1 FROM information_schema.triggers WHERE trigger_name = 'update_assistants_updated_at') THEN
        CREATE TRIGGER update_assistants_updated_at BEFORE UPDATE ON assistants FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();
    END IF;
    IF NOT EXISTS (SELECT 1 FROM information_schema.triggers WHERE trigger_name = 'update_bots_updated_at') THEN
        CREATE TRIGGER update_bots_updated_at BEFORE UPDATE ON bots FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();
    END IF;
    IF NOT EXISTS (SELECT 1 FROM information_schema.triggers WHERE trigger_name = 'update_subscriptions_updated_at') THEN
        CREATE TRIGGER update_subscriptions_updated_at BEFORE UPDATE ON subscriptions FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();
    END IF;
    IF NOT EXISTS (SELECT 1 FROM information_schema.triggers WHERE trigger_name = 'update_message_violations_updated_at') THEN
        CREATE TRIGGER update_message_violations_updated_at BEFORE UPDATE ON message_violations FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();
    END IF;
END $$;

-- Partition month triggers (to avoid GENERATED column immutability issues)
-- Note: set_partition_month function is defined in 07_functions.sql

DROP TRIGGER IF EXISTS rooms_set_partition_month ON rooms;
CREATE TRIGGER rooms_set_partition_month
  BEFORE INSERT OR UPDATE ON rooms
  FOR EACH ROW
  EXECUTE FUNCTION set_partition_month();

DROP TRIGGER IF EXISTS messages_set_partition_month ON messages;
CREATE TRIGGER messages_set_partition_month
  BEFORE INSERT OR UPDATE ON messages
  FOR EACH ROW
  EXECUTE FUNCTION set_partition_month();
