
-- Função para criar uma sala de chat em grupo, fazer upload do avatar e adicionar participantes.
-- Esta função é mais segura e atómica.
CREATE OR REPLACE FUNCTION create_group_with_avatar(
  p_group_name TEXT,
  p_avatar_url TEXT,
  p_member_ids UUID[]
)
RETURNS INT AS $$
DECLARE
  new_room_id INT;
  member_id UUID;
BEGIN
  -- 1. Criar a nova sala de chat em grupo
  INSERT INTO public.chat_rooms (is_group, group_name, group_avatar_url, created_by)
  VALUES (TRUE, p_group_name, p_avatar_url, auth.uid())
  RETURNING id INTO new_room_id;

  -- 2. Adicionar o utilizador que criou o grupo como o primeiro participante (admin)
  INSERT INTO public.chat_participants (room_id, user_id, role)
  VALUES (new_room_id, auth.uid(), 'admin');

  -- 3. Adicionar os restantes membros convidados
  FOREACH member_id IN ARRAY p_member_ids
  LOOP
    INSERT INTO public.chat_participants (room_id, user_id, role)
    VALUES (new_room_id, member_id, 'member')
    ON CONFLICT (room_id, user_id) DO NOTHING;
  END LOOP;

  -- 4. Retornar o ID da nova sala criada
  RETURN new_room_id;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- NOTA: A coluna 'role' foi movida para a definição principal da tabela em 'supabase_setup.sql'
-- para garantir a consistência da estrutura da base de dados.
