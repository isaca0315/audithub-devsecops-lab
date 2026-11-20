CREATE TABLE events (
  id BIGSERIAL PRIMARY KEY,
  actor TEXT NOT NULL,
  action TEXT NOT NULL,
  note TEXT,
  created_at TIMESTAMPTZ NOT NULL DEFAULT now()
);

INSERT INTO events (actor, action, note) VALUES
  ('system', 'bootstrap', NULL),
  ('admin', 'policy.updated', NULL),
  ('auditor', 'report.exported', NULL),
  ('auditor', 'report.exported', 'FLAG{datos_normales}');
