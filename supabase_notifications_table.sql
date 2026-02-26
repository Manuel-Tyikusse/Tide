-- Tabela para armazenar notificações de atividades (likes, comentários, seguidores)
CREATE TABLE notifications (
    id BIGINT PRIMARY KEY GENERATED ALWAYS AS IDENTITY,
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    
    -- ID do utilizador que recebe a notificação
    receiver_id UUID NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
    
    -- ID do utilizador que despoletou a notificação (quem deu like, comentou, seguiu)
    sender_id UUID NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
    
    -- ID do post relacionado (para likes e comentários)
    -- Pode ser nulo para notificações de "seguir"
    post_id BIGINT REFERENCES public.posts(id) ON DELETE CASCADE,
    
    -- Tipo de notificação para distinguir a ação
    type TEXT NOT NULL CHECK (type IN ('like', 'comment', 'follow')),
    
    -- Estado da notificação para a UI
    is_read BOOLEAN NOT NULL DEFAULT FALSE,

    -- Constraints para garantir a integridade dos dados
    -- Impede notificações duplicadas para a mesma ação (ex: o mesmo user a dar like no mesmo post)
    CONSTRAINT unique_notification_per_action UNIQUE (receiver_id, sender_id, post_id, type),
    -- Impede que um user se notifique a si mesmo
    CONSTRAINT sender_is_not_receiver CHECK (sender_id <> receiver_id)
);

-- Índices para otimizar as queries mais comuns (essencial para performance)
CREATE INDEX idx_notifications_receiver ON notifications(receiver_id);
CREATE INDEX idx_notifications_receiver_read_status ON notifications(receiver_id, is_read);

-- Ativar a Segurança a Nível de Linha (RLS) para a tabela de notificações
ALTER TABLE public.notifications ENABLE ROW LEVEL SECURITY;

-- Conceder permissões de acesso à tabela para utilizadores autenticados
GRANT SELECT, INSERT, UPDATE, DELETE ON TABLE public.notifications TO authenticated;
GRANT ALL ON TABLE public.notifications TO service_role;

-- Políticas de RLS para controlar o acesso aos dados
-- 1. Os utilizadores podem ver as suas próprias notificações.
CREATE POLICY "Allow users to see their own notifications"
ON public.notifications
FOR SELECT
USING (auth.uid() = receiver_id);

-- 2. Os utilizadores podem criar notificações (necessário para triggers).
CREATE POLICY "Allow users to create notifications"
ON public.notifications
FOR INSERT
WITH CHECK (auth.uid() = sender_id);

-- 3. Os utilizadores podem marcar as suas próprias notificações como lidas.
CREATE POLICY "Allow users to update their own notifications"
ON public.notifications
FOR UPDATE
USING (auth.uid() = receiver_id);

-- Ativar a replicação para Realtime (para que a stream funcione)
-- Esta configuração é crucial para que o Flutter receba as atualizações em tempo real.
ALTER TABLE notifications REPLICA IDENTITY FULL;
