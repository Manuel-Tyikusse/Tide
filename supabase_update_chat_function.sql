
-- Função para criar ou obter uma sala de chat 1-para-1 entre dois utilizadores.
-- Esta é a função chave para iniciar uma nova conversa.
CREATE OR REPLACE FUNCTION create_or_get_chat_room(
  p_other_user_id UUID
)
RETURNS INT AS $$
DECLARE
  existing_room_id INT;
  new_room_id INT;
  current_user_id UUID := auth.uid();
BEGIN
  -- 1. Verificar se já existe uma sala de chat 1-para-1 entre os dois utilizadores
  SELECT p1.room_id INTO existing_room_id
  FROM chat_participants p1
  JOIN chat_participants p2 ON p1.room_id = p2.room_id
  JOIN chat_rooms r ON p1.room_id = r.id
  WHERE p1.user_id = current_user_id
    AND p2.user_id = p_other_user_id
    AND r.is_group = FALSE
    AND (SELECT COUNT(*) FROM chat_participants WHERE room_id = p1.room_id) = 2;

  -- 2. Se a sala já existe, retorna o seu ID
  IF existing_room_id IS NOT NULL THEN
    RETURN existing_room_id;
  END IF;

  -- 3. Se não existe, cria uma nova sala
  INSERT INTO public.chat_rooms (is_group, created_by)
  VALUES (FALSE, current_user_id)
  RETURNING id INTO new_room_id;

  -- 4. Adiciona ambos os utilizadores como participantes da nova sala
  INSERT INTO public.chat_participants (room_id, user_id, role)
  VALUES (new_room_id, current_user_id, 'member');
  
  INSERT INTO public.chat_participants (room_id, user_id, role)
  VALUES (new_room_id, p_other_user_id, 'member');

  -- 5. Retorna o ID da nova sala criada
  RETURN new_room_id;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

