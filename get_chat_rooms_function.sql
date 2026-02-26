
-- Função para obter todas as salas de chat para o utilizador atual.
-- Esta função é o coração do ecrã de lista de conversas.
CREATE OR REPLACE FUNCTION get_chat_rooms_for_user()
RETURNS JSON AS $$
DECLARE
    result JSON;
BEGIN
    SELECT json_agg(json_build_object(
        'room_id', r.id,
        'is_group', r.is_group,
        'group_name', r.group_name,
        'group_avatar_url', r.group_avatar_url,
        'last_message', (SELECT content FROM chat_messages WHERE room_id = r.id ORDER BY created_at DESC LIMIT 1),
        'last_message_at', (SELECT created_at FROM chat_messages WHERE room_id = r.id ORDER BY created_at DESC LIMIT 1),
        'other_participant', CASE 
            WHEN r.is_group = FALSE THEN (
                SELECT json_build_object(
                    'id', p.id,
                    'username', p.username,
                    'avatar_url', p.avatar_url
                )
                FROM chat_participants cp
                JOIN profiles p ON p.id = cp.user_id
                WHERE cp.room_id = r.id AND cp.user_id <> auth.uid()
                LIMIT 1
            )
            ELSE NULL
        END
    ))
    INTO result
    FROM chat_rooms r
    JOIN chat_participants cp ON r.id = cp.room_id
    WHERE cp.user_id = auth.uid();

    RETURN COALESCE(result, '[]');
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

