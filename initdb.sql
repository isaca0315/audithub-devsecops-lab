CREATE TABLE events (
  id BIGSERIAL PRIMARY KEY,
  actor TEXT NOT NULL,
  action TEXT NOT NULL,
  created_at TIMESTAMPTZ NOT NULL DEFAULT now()
);

INSERT INTO events (actor, action) VALUES
  ('system', 'bootstrap'),
  ('admin', 'policy.updated'),
  ('auditor', 'report.exported'),
  ('auditor', 'report.exported FLAG{datos_normales}');
