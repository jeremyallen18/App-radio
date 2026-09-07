-- 027: ensanchar columnas sensibles para alojar ciphertext AES-256-GCM
-- (crypto.php). El envelope "v1:" + base64(iv+tag+ct) de 1000 caracteres de
-- texto ocupa ~5.4 KB; de un mensaje de chat de 4000, ~21 KB. VARCHAR se queda
-- corto; TEXT (64 KB) sobra. chat_messages.body ya es TEXT.
ALTER TABLE notifications         MODIFY message             TEXT NOT NULL;
ALTER TABLE leave_requests        MODIFY reason              TEXT NULL;
ALTER TABLE leave_requests        MODIFY rejection_reason    TEXT NULL;
ALTER TABLE leave_requests        MODIFY cancellation_reason TEXT NULL;
ALTER TABLE absence_justifications MODIFY reason              TEXT NULL;
ALTER TABLE absence_justifications MODIFY review_note         TEXT NULL;
