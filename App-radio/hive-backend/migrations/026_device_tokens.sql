-- 026: FCM device tokens for Android push notifications.
-- Sin FK a users (igual que `notifications`): la relación es por email.
CREATE TABLE IF NOT EXISTS device_tokens (
  id            BIGINT UNSIGNED AUTO_INCREMENT PRIMARY KEY,
  email         VARCHAR(255) NOT NULL,
  token         VARCHAR(512) NOT NULL,
  platform      ENUM('android','ios','web') NOT NULL DEFAULT 'android',
  created_at    DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
  last_seen_at  DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
  UNIQUE KEY uq_token (token(191)),
  KEY idx_email (email)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;
