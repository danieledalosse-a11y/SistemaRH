-- Bucket criado via dashboard Supabase: nome = admissao-docs, public = false
-- Políticas RLS para o bucket:
INSERT INTO storage.buckets (id, name, public, file_size_limit, allowed_mime_types)
VALUES ('admissao-docs', 'admissao-docs', false, 10485760, ARRAY['image/jpeg','image/png','image/webp','application/pdf'])
ON CONFLICT (id) DO NOTHING;

-- Permite candidatos (anon) fazerem upload
CREATE POLICY "anon_upload_admissao" ON storage.objects
FOR INSERT TO anon WITH CHECK (bucket_id = 'admissao-docs');

-- Permite leitura autenticada (RH)
CREATE POLICY "auth_read_admissao" ON storage.objects
FOR SELECT TO authenticated USING (bucket_id = 'admissao-docs');
